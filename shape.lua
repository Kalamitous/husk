local DIR = (...):gsub('shape', '')
local Vector = require(DIR .. 'vector')

local Shape = {}
Shape.__index = Shape

-- https://stackoverflow.com/a/16691908
local function getOverlap(x1, x2, y1, y2)
    return math.max(0, math.min(x2, y2) - math.max(x1, y1), math.min(x1, y1) - math.max(x2, y2))
end

local function sign(n)
	return n < 0 and -1 or n > 0 and 1 or 0
end

function Shape:remove()
    self.world:_removeShape(self)
end

-- takes in velocities
function Shape:move(x, y, filter)
    local offset = Vector:new(x, y)
    if offset:getMagnitude() == 0 then return end

    self.world:_removeShape(self)
    self.prev_pos = self.pos
    self.pos = self.pos + offset
    if self.lock_dir then
        local dir = self.pos - self.prev_pos
        if dir:angleTo(self.lock_dir) < self.lock_angle then
            self.pos = self.prev_pos
        else
            self.lock_dir = nil
        end
    end

    self.pos = self.pos + Vector:new(self:_resolveCollisions(filter))
    self.world:_addShape(self)
end

-- takes in positions and ignores collisions
function Shape:moveTo(x, y)
    self.world:_removeShape(self)
    self.pos = Vector:new(x, y)
    self.world:_addShape(self)
end

function Shape:rotate(deg, filter)
    local center_x, center_y = self:getCenter()
    for i = 1, #self.vertices, 2 do
        local x = self.vertices[i] + self.pos.x
        local y = self.vertices[i + 1] + self.pos.y
        local rotated_x = center_x + (x - center_x) * math.cos(deg) - (y - center_y) * math.sin(deg)
        local rotated_y = center_y + (x - center_x) * math.sin(deg) + (y - center_y) * math.cos(deg)
        self.vertices[i] = rotated_x - self.pos.x
        self.vertices[i + 1] = rotated_y - self.pos.y
    end
    self.world:_removeShape(self)
    self.pos = self.pos + Vector:new(self:_resolveCollisions(filter, true))
    self.world:_addShape(self)
end

function Shape:draw()
    love.graphics.polygon('line', unpack(self:_getVertices()))
end

function Shape:collidesWith(other)
    local axes = self:_calculateNormals()
    for _, v in ipairs(other:_calculateNormals()) do
        table.insert(axes, v)
    end

    local minimum_axis
    local minimum_overlap = math.huge
    for _, v in ipairs(axes) do
        local p1 = self:_projectOntoAxis(v.x, v.y)
        local p2 = other:_projectOntoAxis(v.x, v.y)
        local overlap = getOverlap(p1.x, p1.y, p2.x, p2.y)
        if overlap ~= 0 then
            if minimum_overlap >= overlap then
                minimum_axis = v
                minimum_overlap = overlap
            end
        else
            return false, 0, 0
        end
    end

    -- mtv should always be facing away from the other shape
    local s = Vector:new(self:getCenter())
    local o = Vector:new(other:getCenter())
    local dir = o - s
    if dir:dot(minimum_axis) < 0 then
        minimum_axis = -minimum_axis
    end

    local mtv = -minimum_axis * minimum_overlap
    return true, mtv.x, mtv.y
end

function Shape:getBoundingBox()
    local vertices = self:_getVertexPairs()
    local min = Vector:new(math.huge, math.huge)
    local max = -Vector:new(math.huge, math.huge)
    for _, v in ipairs(vertices) do
        min = Vector:new(math.min(min.x, v.x), math.min(min.y, v.y))
        max = Vector:new(math.max(max.x, v.x), math.max(max.y, v.y))
    end
    return min.x, min.y, max.x - min.x, max.y - min.y
end

function Shape:getCenter()
    local x, y, w, h = self:getBoundingBox()
    return x + w / 2, y + h / 2
end

-- gets all shapes in the current cell(s) of the spatial hash map
function Shape:getNeighbors(filter)
    local neighbors = {}
    local buckets = self.world:_getBuckets(self)
    for _, v in ipairs(buckets) do
        for _, s in ipairs(v) do
            if s ~= self then
                local is_duplicate
                for _, n in ipairs(neighbors) do
                    if n == s then
                        is_duplicate = true
                        break
                    end
                end
                if not is_duplicate then
                    if not filter or filter(self, s) then
                        table.insert(neighbors, s)
                    end
                end
            end
        end
    end
    return neighbors
end

function Shape:getCollisions(filter)
    local collisions = {}
    for _, v in ipairs(self:getNeighbors(filter)) do
        if v ~= self then
            local collides, x, y = self:collidesWith(v)
            if collides then
                table.insert(collisions, v)
            end
        end
    end
    return collisions
end

function Shape:_resolveCollisions(filter, is_rotating)
    if not is_rotating and self.lock_dir then return 0, 0 end

    local axes = {}
    local major_magnitude = 0
    local major_mtv = Vector:new()
    local delta = Vector:new()
    for _, v in ipairs(self:getNeighbors(filter)) do
        if v ~= self then
            local collides, x, y = self:collidesWith(v)
            if collides then
                local mtv = Vector:new(x, y)
                local magnitude = mtv:getMagnitude()
                delta = delta + mtv
                if major_magnitude < magnitude then
                    major_magnitude = magnitude
                    major_mtv = mtv
                end
                table.insert(axes, mtv)
            end
        end
    end

    if #axes == 0 then return 0, 0 end

    -- assumes that 2 distinct axes must be involved in a concave collision
    local real_mtv = Vector:new()
    local concave_collision = #axes == 2 and axes[1] ~= axes[2]
    if concave_collision then
        local collision_angle = math.pi - axes[1]:angleTo(axes[2])
        -- the direction pointing directly away from the concave
        local collision_normal = axes[1]:getNormalized() + axes[2]:getNormalized()
        if collision_angle < math.pi / 2 then
            local corrected_delta = Vector:new()
            local correction_angle = math.pi / 2 - collision_angle
            -- correct magnitude and direction of the mtvs to be parallel to the concave surfaces
            for _, v in ipairs(axes) do
                -- determines whether the current axis is above/below the collision normal
                local angle_difference = collision_normal:getAngle() - (collision_normal:getNormalized() - v:getNormalized()):getAngle()
                local corrected_magnitude = v:getMagnitude() / math.cos(correction_angle)
                local corrected_angle = v:getAngle() + correction_angle * -sign(angle_difference)
                local corrected_mtv = Vector:new(math.cos(corrected_angle), math.sin(corrected_angle)) * corrected_magnitude
                corrected_delta = corrected_delta + corrected_mtv
            end
            -- note: `corrected_delta` may not point in the same direction as `collision_normal`
            real_mtv = corrected_delta
            -- lock movement until the shape moves at an angle greater than the
            -- collision normal and in a direction away from the concave to prevent
            -- stuttering from the shape alternating between one and two axes
            -- of collision when moving at an off-angle towards the concave
            self.lock_dir = -collision_normal
            self.lock_angle = math.pi / 2 - collision_angle / 2
        else
            real_mtv = delta
        end
    else
        -- go with the larger mtv since the other mtv (if it exists)
        -- is likely from a sub-pixel collision
        real_mtv = major_mtv
    end

    return real_mtv.x, real_mtv.y
end

-- returns the start and end of the 1D 'shadow'
function Shape:_projectOntoAxis(x, y)
    local axis = Vector:new(x, y)
    local vertices = self:_getVertexPairs()
    local p = axis:dot(vertices[1])
    local result = Vector:new(p, p)
    for i = 2, #vertices do
        p = axis:dot(vertices[i])
        result = Vector:new(math.min(result.x, p),  math.max(result.y, p))
    end
    return result
end

function Shape:_calculateNormals()
    local normals = {}
    local vertices = self:_getVertexPairs()
    for i = 1, #vertices do
        local v1 = vertices[i]
        local v2
        if i == #vertices then
            v2 = vertices[1]
        else
            v2 = vertices[i + 1]
        end
        local edge = v1 - v2
        local normal = edge:getPerpendicular():getNormalized()
        table.insert(normals, normal)
    end
    return normals
end

function Shape:_drawNormals()
    local normals = self:_calculateNormals()
    local vertices = self:_getVertexPairs()
    for i = 1, #vertices do
        local v1 = vertices[i]
        local v2
        if i == #vertices then
            v2 = vertices[1]
        else
            v2 = vertices[i + 1]
        end
        local middle = v1 + (v2 - v1) / 2
        love.graphics.line(middle.x, middle.y, middle.x + normals[i].x * 16, middle.y + normals[i].y * 16)
    end
end

function Shape:_getVertices()
    local vertices = {}
    for k, v in ipairs(self.vertices) do
        if k % 2 == 0 then
            table.insert(vertices, v + self.pos.y)
        else
            table.insert(vertices, v + self.pos.x)
        end
    end
    return vertices
end

function Shape:_getVertexPairs()
    local vertices = {}
    for i = 1, #self.vertices, 2 do
        local x = self.vertices[i] + self.pos.x
        local y = self.vertices[i + 1] + self.pos.y
        table.insert(vertices, Vector:new(x, y))
    end
    return vertices
end

return Shape
