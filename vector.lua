local Vector = {}
Vector.__index = Vector

-- rounding helps with sub-pixel leniancy to prevent visually-inaccurate collisions
local function round(n, decimals)
    decimals = decimals or 3
    return math.floor(n * 10 ^ decimals + 0.5) / 10 ^ decimals
end

function Vector:__call(x, y)
    return setmetatable({x = x or 0, y = y or 0}, Vector)
end

function Vector:__add(other)
    return Vector:new(self.x + other.x, self.y + other.y)
end

function Vector:__sub(other)
    return Vector:new(self.x - other.x, self.y - other.y)
end

function Vector:__mul(scalar)
    return Vector:new(self.x * scalar, self.y * scalar)
end

function Vector:__div(scalar)
    return Vector:new(self.x / scalar, self.y / scalar)
end

function Vector:__eq(other)
    return round(self.x) == round(other.x) and round(self.y) == round(other.y)
end

function Vector:__tostring()
    return '(' .. tostring(self.x) .. ', ' .. self.y .. ')'
end

function Vector:__unm()
    return self * -1
end

function Vector:new(x, y)
    return setmetatable({x = x or 0, y = y or 0}, Vector)
end

function Vector:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector:angleTo(other)
    local a = self:getNormalized()
    local b = other:getNormalized()
    return math.acos(a:dot(b))
end

function Vector:getMagnitude()
    return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

function Vector:getAngle()
    return math.atan2(self.y, self.x)
end

function Vector:getNormalized()
    local magnitude = self:getMagnitude()
    return Vector:new(self.x, self.y) / magnitude
end

function Vector:getPerpendicular()
    return Vector:new(-self.y, self.x)
end

return Vector
