local enet   = require "enet"
local Client = {}
Client.__index = Client

function Client:new(global, address)
    local c = setmetatable({}, self)

    c.global = global
    c.host = enet.host_create()
    c.server = c.host:connect(address or "localhost:1990")

    c.id = nil
    c.ready = false
    c.connectionTime = love.timer.getTime()
    c.sampleRate = 44100
    c.bufferSize = 1024
    c.phase1 = 0
    c.phase2 = 0
    c.fmPhase = 0
    c.prevBallDX = global.ball.dx
    c.prevBallDY = global.ball.dy
    c.prevScore1 = global.score.p1
    c.prevScore2 = global.score.p2
    c.lowpassState = 0
    c.source = love.audio.newQueueableSource(
        c.sampleRate,
        16,
        2,        -- stereo
        8
    )
    --love.audio.play(c.source)

    return c
end

local function softclip(x)
    return x / (1 + math.abs(x))
end

function Client:playNoiseBurst(intensity, length)
    local data = love.sound.newSoundData(
        length,
        self.sampleRate,
        16,
        1
    )

    for i = 0, length - 1 do
        local decay = 1 - (i / length)
        local noise = (love.math.random() * 2 - 1)
        data:setSample(i, noise * decay * intensity)
    end

    love.audio.newSource(data):play()
end

function Client:playScoreTone()
    local length = 22050
    local data = love.sound.newSoundData(
        length,
        self.sampleRate,
        16,
        1
    )

    local freq = 880

    for i = 0, length - 1 do
        local t = i / self.sampleRate
        local env = 1 - (i / length)
        local sample = math.sin(2 * math.pi * freq * t)
        data:setSample(i, sample * env * 0.6)
    end

    love.audio.newSource(data):play()
end

function Client:generateAudio()
    local g = self.global
    if not g then return end

    if self.source:getFreeBufferCount() == 0 then return end

    local data = love.sound.newSoundData(
        self.bufferSize,
        self.sampleRate,
        16,
        2
    )

    local speed = math.sqrt(g.ball.dx^2 + g.ball.dy^2)

    local baseFreq = 80
    local freq = baseFreq + speed * 0.6

    local modFreq = 0.5 + math.abs(g.players[1].y - g.players[2].y) * 0.01

    local pan = (g.ball.x / g.VIRTUAL_WIDTH) * 2 - 1

    local cutoff = math.min(0.2, speed / 1000)

    for i = 0, self.bufferSize - 1 do
        self.phase1 = self.phase1 + freq / self.sampleRate
        self.phase2 = self.phase2 + (freq * 2.01) / self.sampleRate
        self.fmPhase = self.fmPhase + modFreq / self.sampleRate

        if self.phase1 > 1 then self.phase1 = self.phase1 - 1 end
        if self.phase2 > 1 then self.phase2 = self.phase2 - 1 end
        if self.fmPhase > 1 then self.fmPhase = self.fmPhase - 1 end

        local fm = math.sin(self.fmPhase * 2 * math.pi) * 20

        local s1 = math.sin((self.phase1 * 2 * math.pi) + fm)
        local s2 = 0.5 * math.sin(self.phase2 * 2 * math.pi)

        local sample = (s1 + s2) * 0.3

        -- low pass filter
        self.lowpassState = self.lowpassState + cutoff * (sample - self.lowpassState)
        sample = self.lowpassState

        sample = softclip(sample)

        local left  = sample * (1 - pan * 0.5)
        local right = sample * (1 + pan * 0.5)

        data:setSample(i * 2, left)
        data:setSample(i * 2 + 1, right)
    end

    self.source:queue(data)
end

function Client:handleNetwork()
    local event = self.host:service(0)

    while event do
        if event.type == "receive" then
            if event.data:sub(1,3) == "id|" then
                self.id = tonumber(event.data:sub(4))
            elseif event.data == "start" then
                self.ready = false
            else
                self.global:deserialize(event.data)
            end
        end
        event = self.host:service(0)
    end
end

function Client:update(dt)
    self:handleNetwork()

    local g = self.global

    -- EVENT DETECTION
    if g then
        if g.ball.dx ~= self.prevBallDX then
            self:playNoiseBurst(0.5, 256)
        end

        if g.ball.dy ~= self.prevBallDY then
            self:playNoiseBurst(0.3, 200)
        end

        if g.score.p1 ~= self.prevScore1 or
           g.score.p2 ~= self.prevScore2 then
            self:playScoreTone()
        end

        self.prevBallDX = g.ball.dx
        self.prevBallDY = g.ball.dy
        self.prevScore1 = g.score.p1
        self.prevScore2 = g.score.p2
    end

    self:generateAudio()

    -- INPUT
    if self.id then
        if love.keyboard.isDown("space") and not self.ready then
            self.server:send("ready|" .. self.id)
            self.ready = true
        end

        if not self.ready then
            local input = "idle"
            if love.keyboard.isDown("w") then input = "up" end
            if love.keyboard.isDown("s") then input = "down" end
            self.server:send(self.id .. "|" .. input)
        end
    end
end

function Client:draw()
    local g = self.global

    local windowW, windowH = love.graphics.getDimensions()
    local virtualW = g.VIRTUAL_WIDTH
    local virtualH = g.VIRTUAL_HEIGHT

    local scale = math.min(windowW / virtualW, windowH / virtualH)
    local offsetX = (windowW - virtualW * scale) / 2
    local offsetY = (windowH - virtualH * scale) / 2

    love.graphics.clear(0.6, 0.8, 1.0)

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill",0,0,virtualW,virtualH)

    love.graphics.setColor(1,1,1)

    love.graphics.rectangle("fill", g.P1_X, g.players[1].y, g.PADDLE_WIDTH, g.PADDLE_HEIGHT)
    love.graphics.rectangle("fill", g.P2_X, g.players[2].y, g.PADDLE_WIDTH, g.PADDLE_HEIGHT)
    love.graphics.rectangle("fill", g.ball.x, g.ball.y, g.BALL_SIZE, g.BALL_SIZE)

    local scoreText = g.score.p1 .. " - " .. g.score.p2
    local w = love.graphics.getFont():getWidth(scoreText)
    love.graphics.print(scoreText, (virtualW - w)/2, 10)

    local infoY = 30

    if (not self.ready) or g.gameState ~= "playing" then
        local txt = "Press SPACE to Ready Up"
        local w2 = love.graphics.getFont():getWidth(txt)
        love.graphics.print(txt, (virtualW - w2)/2, infoY)
    else
        local elapsed = math.floor(love.timer.getTime() - self.connectionTime)
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        local t = string.format("Session: %02d:%02d:%02d", h, m, s)

        local w3 = love.graphics.getFont():getWidth(t)
        love.graphics.print(t, (virtualW - w3)/2, infoY)
    end

    love.graphics.pop()
end

return Client