local DIR = (...) .. '/'
local World = require(DIR .. 'world')

local Husk = {}

-- initializes new spatial hash map
function Husk:newWorld(cell_size)
    return setmetatable({
        cell_size = cell_size or 128,
        spatial_hash = {}
    }, World)
end

return Husk
