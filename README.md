# husk

**husk** is a simple 2D collision detection library in Lua for complex polygons. It can handle collisions involving concave surfaces.

## Table of Contents

* [Example](#example)
* [API](#api)
* [Installing](#installing)
* [Contributing](#contributing)
* [License](#license)


## Example

![Example](https://i.imgur.com/4gTsgcU.gif)

This example uses [LÖVE](https://love2d.org/), but **husk** supports any Lua-based graphics framework.

```lua
local husk = require 'husk'

function love.load()
    world = husk:newWorld()
    shape1 = world:addRectangle(250, -100, 75, 75)
    shape2 = world:addPolygon(150, 400, 350, 400, 250, 225)
    shape3 = world:addCircle(500, 310, 90, 50)
end

function love.update(dt)
    local dir = {x = 0, y = 0}
    if love.keyboard.isDown('up') then dir.y = -1 end
    if love.keyboard.isDown('down') then dir.y = 1 end
    if love.keyboard.isDown('left') then dir.x = -1 end
    if love.keyboard.isDown('right') then dir.x = 1 end
    shape1:move(200 * dir.x * dt, 200 * dir.y * dt)
end

function love.draw()
    shape1:draw()
    shape2:draw()
    shape3:draw()
end
```


## API

* [husk](#husk-1)
* [world](#world)
* [shape](#shape)

### husk

```lua
local world = husk:newWorld(< cell_size = 128 >)
```
Creates a world. Shapes in the same world can interact with each other.
- `cell_size` Optional number. Under the hood, **husk** utilizes a spatial hash to optimize memory usage for large amounts of shapes. Increasing `cell_size` if shapes are sparsely populated or decreasing `cell_size` if shapes are densely populated may result in a slight performance boost.

### world

```lua
local rectangle = world:addRectangle(x, y, w, h)
```
Adds a rectangle shape to the world.
- `x, y` Top-left position.
- `w, h` Width and height.

```lua
local polygon = world:addPolygon(x1, y1, ..., xn, yn)
```
Adds a polygon shape to the world.
- `x1, y1, ..., xn, yn` Points that form the polygon.

```lua
local circle = world:addCircle(x, y, r, s)
```
Adds a circle shape to the world.
- `x, y` Center position.
- `r` Radius.
- `s` Segments. In **husk**, a circle is actually a highly-segmented polygon. `s` determines the number of segments that form the circle.

### shape

```lua
shape:remove()
```
Removes the shape from the world it belongs to. Other shapes can no longer interact with this shape.

```lua
shape:move(x, y, < filter >)
```
Moves the shape at the given velocity and resolves collisions that occur as a result.
- `x, y` Velocity.
- `filter` Optional function to filter which shapes can collide with this shape. Must have signature `filter(shape, other)`.
  - `shape` Current shape.
  - `other` Other shape.
  - If `filter` returns `true`, `other` can collide with `shape`. Otherwise, `other` cannot collide with `shape`.

```lua
shape:moveTo(x, y)
```
Moves the shape to the given position and does not check for collisions.
- `x, y` Top-left position.

```lua
shape:rotate(deg, filter)
```
Rotates the shape around its center.
- `deg` Degree in radians.
- `filter` Optional function to filter which shapes can collide with this shape. See `shape:move()` for more information.

```lua
shape:draw()
```
Draws the shape if you are using [LÖVE](https://love2d.org/). Otherwise, you must implement this function to be compatible with your graphics framework.

```lua
local collides, x, y = shape:collidesWith(other)
```
Checks for a collision with another shape.
- `other` Other shape.
- `collides` Returns `true` if the shape collides with `other`. Returns `false` if the shape does not collide with `other`.
- `x, y` The minimum translation vector needed to offset the shape so that it no longer collides with `other`. It is `0, 0` if the shape does not collide with `other`.

```lua
local x, y, w, h = shape:getBoundingBox()
```
Gets the bounding box of the shape.
- `x, y` Top-left position.
- `w, h` Width and height.

```lua
local x, y = shape:getCenter()
```
Gets the center position of the shape.
- `x, y` Center position.

```lua
local neighbors = shape:getNeighbors(< filter >)
```
Gets shapes neighboring this shape.
- `neighbors` A table of neighboring shapes. More specifically, these are the shapes that share the same spatial hash cell(s) where this shape is located.
- `filter` Optional function to filter which shapes to include. See `shape:move()` for more information.

```lua
local collisions = shape:getCollisions(< filter >)
```
Gets shapes that are colliding this shape.
- `collisions` A table of colliding shapes.
- `filter` Optional function to filter which shapes to include. See `shape:move()` for more information.


## Installing

1. Clone the repository
```sh
git clone https://github.com/Kalamitous/husk.git
```
2. Require the repository folder in your project file(s)
```lua
local husk = require 'path.to.husk'
```

## Contributing

Contributions to add features or resolve issues are welcome.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/Name`) or issue branch (`git checkout -b issue/Name`)
3. Commit your changes (`git commit -m 'Message'`)
4. Push to the branch (`git push origin feature/Name`)
5. Open a pull request


## License

Distributed under the MIT License. See `LICENSE` for more information.
