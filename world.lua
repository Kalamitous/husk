local DIR = (...):gsub('world', '')
local Shape = require(DIR .. 'shape')
local Vector = require(DIR .. 'vector')

local World = {}
World.__index = World

-- rounding helps with sub-pixel leniancy to prevent visually-inaccurate collisions
local function round(n, decimals)
    decimals = decimals or 3
    return math.floor(n * 10 ^ decimals + 0.5) / 10 ^ decimals
end

function World:addRectangle(x, y, w, h)
    return self:addPolygon(x,y, x+w,y, x+w,y+h, x,y+h)
end

-- takes in vertices: x1,y1, x2,y2, x3,y3, ...
function World:addPolygon(...)
    local raw_vertices = {...}
    local shape = setmetatable({
        pos = Vector:new(),
        vertices = raw_vertices
    }, Shape)

    -- isolate position from vertices
    local x, y, _, _ = shape:getBoundingBox()
    local vertices = {}
    for k, v in ipairs(raw_vertices) do
        if k % 2 == 0 then
            table.insert(vertices, round(v) - y)
        else
            table.insert(vertices, round(v) - x)
        end
    end
    shape = setmetatable({
        pos = Vector:new(x, y),
        prev_pos = Vector:new(),
        vertices = vertices,
        world = self
    }, Shape)

    self:_addShape(shape)
    return shape
end

-- a circle is actually a highly-segmented polygon
-- takes in position, radius, and segment count
function World:addCircle(x, y, r, s)
    s = math.max(s, 3)
    local angle_increment = 2 * math.pi / s
    local vertices = {}
    for i = 1, s do
        local _x = x + r * math.cos(angle_increment * i)
        local _y = y + r * math.sin(angle_increment * i)
        table.insert(vertices, _x)
        table.insert(vertices, _y)
    end
    return self:addPolygon(unpack(vertices))
end

function World:_addShape(shape)
    local cells = self:_getCells(shape)
    for _, v in ipairs(cells) do
        table.insert(v, shape)
    end
end

function World:_removeShape(shape)
    local cells = self:_getCells(shape)
    for _, v in ipairs(cells) do
        for k, s in ipairs(v) do
            if s == shape then
                table.remove(v, k)
            end
        end
    end
end

function World:_hash(x, y)
    return math.floor(x / self.cell_size), math.floor(y / self.cell_size)
end

function World:_getCells(shape)
    local cells = {}
    local x, y, w, h = shape:getBoundingBox()
    local i1, j1 = self:_hash(x, y)
    local i2, j2 = self:_hash(x + w, y + h)
    for i = i1, i2 + 1 do
        for j = j1, j2 + 1 do
            table.insert(cells, self:_getCell(i, j))
        end
    end
    return cells
end

function World:_getCell(i, j)
    self.spatial_hash[i] = self.spatial_hash[i] or {}
    self.spatial_hash[i][j] = self.spatial_hash[i][j] or {}
    return self.spatial_hash[i][j]
end

return World
