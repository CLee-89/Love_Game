function love.conf(t)
    t.window.title = "Snake"
    t.window.width = 720      -- 20 tiles × 20px
    t.window.height = 720      -- matches your grid
    t.window.resizable = false
    t.window.vsync = 1
    t.window.fullscreen = false
    t.identity = "snake_game"  -- save folder name
end