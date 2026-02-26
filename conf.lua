function love.conf(t)
    if true then -- set to false for no window / headless mode mode
        t.console = true
        t.modules.audio = false
        t.modules.window = false
        t.modules.graphics = false
    end
end
