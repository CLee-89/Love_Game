-- This is a simple snake game. The map is made by splitting the window into a 20 x 20 grid. The snake moves by adding a head new head to where it's moving next, and removing the tail.
-- If the snake eats the food, the tail is not removed on movement, making the snake grow one. Snake uses different sprites for direction of snake. Snake also changes colors.


-- Grid settings
local gridWidth = 20
local gridHeight = 20

-- Load tileset
local sprite = love.graphics.newImage("assets/snake_spritesheet.png")
local quads = {}
-- Spitting sprite sheet into seperate images
for i = 0, 6 do
    quads[i + 1] = love.graphics.newQuad(i * 20, 0, 20, 20, sprite:getDimensions())
end

-- Snake data
local snake = {
    -- head, middle and tail
     -- must start as three pieces because I didn't make a head and tail combination sprite.
    {x = 10, y = 10},
    {x = 9, y = 10},
    {x = 8, y = 10}
}
-- start as moving right
local dir = {x = 1, y = 0}
local canChangeDir = true
local time = 0
local moveDelay = 0.1

-- Particles table for particle effects
local particles = {}

-- Food
local food = {x = 5, y = 5}

-- Variable to determine scene
local gameState = "title"

-- Calculates the shortest wrapped distance between two grid positions (used to determine shape of sprites/direction even with wrapping around to other side).
local function getOffset(currentPos, targetPos, gridLength)
    -- Raw difference between positions
    local diff = currentPos - targetPos

    -- Adjust the difference so it always represents
    -- the shortest direction (considers snake wrapping around to other side).
    if diff > gridLength / 2 then
        diff = diff - gridLength
    elseif diff < -gridLength / 2 then
        diff = diff + gridLength
    end

    return diff
end

-- Gets color from rainbow determined by time
local function getRainbowColor(time)
    local r = 0.5 + 0.5 * math.sin(time * 2)
    local g = 0.5 + 0.5 * math.sin(time * 2 + 2*math.pi/3)
    local b = 0.5 + 0.5 * math.sin(time * 2 + 4*math.pi/3)
    return r, g, b
end

-- Particle spawn
local function spawnParticles(x, y, color)
    for i = 1, 15 do
        -- Create and insert particles 15 times for table particles
        table.insert(particles, {
            x = x,
            y = y,
            radius = 5,
            speed = 20 + love.math.random(0, 20),
            alpha = 1,
            r = color[1],
            g = color[2],
            b = color[3],
            angle = love.math.random() * 2 * math.pi
        })
    end
end

-- Determine tile index for a specific segment of snake, each index corresponds to a particular image in sprite sheet
local function getSegmentTile(segment, prev, next, isHead, isTail)
    if isHead then return 6 end
    if isTail then return 7 end

    -- Calculate offsets of segment from the previous segment and next segment, to determine what shape snake segment should make
    local dxPrev = getOffset(prev.x, segment.x, gridWidth)
    local dyPrev = getOffset(prev.y, segment.y, gridHeight)
    local dxNext = getOffset(next.x, segment.x, gridWidth)
    local dyNext = getOffset(next.y, segment.y, gridHeight)

    -- Straight segments
    -- If the previous x and next x are a straight line, return straight segment
    if dxPrev == dxNext and dxPrev ~= 0 then
        -- horizontal
        return 1
    -- If the previous y and next y make a straight line, return straight segment
    elseif dyPrev == dyNext and dyPrev ~= 0 then
        -- vertical
        return 1
    end

    -- Determine which corner segment should be used based on locations of previous and next snake segments. (Could only use 2 different sprites but oh well)
    -- Left → Up
    if (dxPrev == -1 and dyNext == -1) or (dxNext == -1 and dyPrev == -1) then
        return 2
    end
    -- Up → Right
    if (dxPrev == 1 and dyNext == -1) or (dxNext == 1 and dyPrev == -1) then
        return 3
    end
    -- Left → Down
    if (dxPrev == -1 and dyNext == 1) or (dxNext == -1 and dyPrev == 1) then
        return 4
    end
    -- Down → Right
    if (dxPrev == 1 and dyNext == 1) or (dxNext == 1 and dyPrev == 1) then
        return 5
    end

    -- fallback
    return 1
end

-- Determine rotation for segments
local function getRotation(segment, prev, next, isHead, isTail)
    local dx, dy

    -- If the segment is the head, and a head segment is created infront of it, get difference in x's and y's from new head and original head
    if isHead then
        if next then
            dx = getOffset(segment.x, next.x, gridWidth)
            dy = getOffset(segment.y, next.y, gridHeight)
        else
            dx, dy = dir.x, dir.y
        end
    -- If tail then get difference in x's and y's from body segment before it to determine which direction tail is pointing
    elseif isTail then
        if prev then
            dx = getOffset(segment.x, prev.x, gridWidth)
            dy = getOffset(segment.y, prev.y, gridHeight)
        else
            dx, dy = 0, 0
        end
    else
        -- If previous, current, and next x coordinates are the same, snake is moving vertically, and determine if it's moving up or down
        if prev.x == segment.x and next.x == segment.x then
            dx, dy = 0, getOffset(next.y, segment.y, gridHeight)
        -- Same for y coordinates
        elseif prev.y == segment.y and next.y == segment.y then
            dx, dy = getOffset(next.x, segment.x, gridWidth), 0
        else
            -- Else it must be a corner segment
            return 0
        end
    end

    -- Determine rotation based on direction (one math.pi is 180 degrees)
    local rotation = 0
    if dx == 1 then rotation = 0 end
    if dx == -1 then rotation = math.pi end
    if dy == 1 then rotation = math.pi/2 end
    if dy == -1 then rotation = -math.pi/2 end

    -- Tail points backwards than other segments so add one extra 180 degrees
    if isTail then rotation = rotation + math.pi end

    return rotation
end

-- Spawn food randomly
local function spawnFood()
    food.x = love.math.random(1, gridWidth)
    food.y = love.math.random(1, gridHeight)
end

-- Controls
function love.keypressed(key)
    -- When key is pressed in title screen, start game
    if gameState == "title" then
        gameState = "playing"
        return
    end

    -- only allow one change per update
    if not canChangeDir then return end

    -- Actions for keys, snake direction, making sure you can only change directions once until snake moves again using canChangeDir,
    -- and making sure snake can't turn into itself
    if key == "w" and dir.y ~= 1 then
        dir = {x = 0, y = -1}
        canChangeDir = false
    elseif key == "s" and dir.y ~= -1 then
        dir = {x = 0, y = 1}
        canChangeDir = false
    elseif key == "a" and dir.x ~= 1 then
        dir = {x = -1, y = 0}
        canChangeDir = false
    elseif key == "d" and dir.x ~= -1 then
        dir = {x = 1, y = 0}
        canChangeDir = false
    end
end

-- Game world is a 20 x 20 grid
local gridWidth, gridHeight = 20, 20
-- How big each tile is on screen
local tileSize
-- How much to scale graphics sprite
local scaleX, scaleY

--  
function love.load()
    -- Scale game world and sprites to window size
    local w, h = love.graphics.getDimensions()
    tileSize = math.min(w / gridWidth, h / gridHeight)
    -- 20 is sprite tile size
    scaleX = tileSize / 20
    scaleY = tileSize / 20
end

-- If window is resizable
function love.resize(w, h)
    tileSize = math.min(w / gridWidth, h / gridHeight)
    scaleX = tileSize / 20
    scaleY = tileSize / 20
end

-- Update snake movement
function love.update(dt)

    -- If in titlescreen end update function here
    if gameState ~= "playing" then return end

    time = time + dt
    if time >= moveDelay then
        -- If time passed is greater than movement delay, move the snake
        time = 0

        -- Move snake
        local head = snake[1]
        -- New head equals current head position plus direction
        local newHead = {x = head.x + dir.x, y = head.y + dir.y}

        -- If snake head goes out of bounds, then reset on the other side
        if newHead.x > gridWidth then newHead.x = 1 end
        if newHead.x < 1 then newHead.x = gridWidth end
        if newHead.y > gridHeight then newHead.y = 1 end
        if newHead.y < 1 then newHead.y = gridHeight end

        -- Determine if any segment collides with the new head position
        for _, segment in ipairs(snake) do
            if segment.x == newHead.x and segment.y == newHead.y then
                -- Reset snake and everything
                snake = {
                    {x = 10, y = 10},
                    {x = 9, y = 10},
                    {x = 8, y = 10}
                }

                spawnFood()
                canChangeDir = true
                return
            end
        end

        -- Every movement, add a new head to snake
        table.insert(snake, 1, newHead)

        -- Checks every move to see if snake ate food or not
        if newHead.x == food.x and newHead.y == food.y then
            -- Get color based on time
            local r,g,b = getRainbowColor(love.timer.getTime())
            -- Spawn particles where food was, using color
            spawnParticles(food.x, food.y, {r,g,b})
            -- Spawn new food
            spawnFood()
        else
            -- If didn't eat food, remove the last segment
            table.remove(snake)
        end

        canChangeDir = true
    end

    -- Update each particle in particles(# is length operator), count backwards to 1, jump by -1 (looping backwards avoids element removal issues)
    for i = #particles, 1, -1 do
        local p = particles[i]
        -- Move particle
        p.radius = p.radius + p.speed * dt
        -- Update particle transparency
        p.alpha = p.alpha - dt * .05
        -- When particle is fully faded out, remove it
        if p.alpha <= 0 then table.remove(particles, i) end
    end
end

-- Draw everything
function love.draw()

    -- If at titlescreen draw title screen
    if gameState == "title" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("SNEK GAME", 0, love.graphics.getHeight()/3, love.graphics.getWidth(), "center")
        love.graphics.printf("Press any key to start", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
        return
    end


    -- Draw every particle in particles table
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.r, p.g, p.b, p.alpha)
        local px = (p.x - 1) * tileSize + tileSize/2 + math.cos(p.angle) * p.radius
        local py = (p.y - 1) * tileSize + tileSize/2 + math.sin(p.angle) * p.radius
        love.graphics.circle("fill", px, py, 15)
    end

    -- Draw every segment in the snake
    for i, segment in ipairs(snake) do
        local prev = snake[i-1]
        local next = snake[i+1]
        local isHead = (i == 1)
        local isTail = (i == #snake)
        local tileIndex = getSegmentTile(segment, prev, next, isHead, isTail)
        local rotation = getRotation(segment, prev, next, isHead, isTail)
        
        -- Rainbow color based on time + segment index
        local r, g, b = getRainbowColor(love.timer.getTime() + i * 0.2)
        love.graphics.setColor(r, g, b)
        
        -- Draw the segments
        love.graphics.draw(sprite, quads[tileIndex],
            (segment.x-1) * tileSize + tileSize/2,
            (segment.y-1) * tileSize + tileSize/2,
            rotation, scaleX, scaleY, 10, 10)
    end

    -- Reset color to white for food and other stuff
    love.graphics.setColor(1, 1, 1)

    -- Draw food
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill",
        -- Grid starts at one, but pixels start at 0
        (food.x-1) * tileSize,
        (food.y-1) * tileSize,
        -- -1 so grids don't overlap
        tileSize-1, tileSize-1)
    love.graphics.setColor(1, 1, 1)
end