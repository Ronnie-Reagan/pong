function love.conf(t)
    if not true then -- set to false for no window / headless mode mode
        t.console = true
        t.modules.audio = false
        t.modules.window = false
        t.modules.graphics = false
    else
        t.window.icon = "logo.png"
    end
end
