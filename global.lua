local Global          = {}
Global.__index        = Global
Global.VIRTUAL_WIDTH  = 432
Global.VIRTUAL_HEIGHT = 243
Global.PADDLE_SPEED   = 200
Global.BALL_SIZE      = 4
Global.PADDLE_HEIGHT  = 20
Global.PADDLE_WIDTH   = 5
Global.TICKRATE       = 240
Global.TICKTIME       = 1 / Global.TICKRATE
Global.P1_X           = 10
Global.P2_X           = Global.VIRTUAL_WIDTH - 10 - Global.PADDLE_WIDTH

function Global:new(seed)
    local g        = setmetatable({}, self)

    g.tick         = 0
    g.seed         = seed or os.time()
    g.rng          = love.math.newRandomGenerator(g.seed)
    g.players      = {
        [1] = { y = 30, connected = false },
        [2] = { y = Global.VIRTUAL_HEIGHT - 30, connected = false }
    }
    g.playerInputs = {
        [1] = "idle",
        [2] = "idle"
    }
    g.ball         = {
        x = Global.VIRTUAL_WIDTH / 2,
        y = Global.VIRTUAL_HEIGHT / 2,
        dx = 150,
        dy = 60
    }
    g.score        = { p1 = 0, p2 = 0 }
    g.gameState    = "play"

    return g
end

function Global:resetBall(direction)
    self.ball.x  = Global.VIRTUAL_WIDTH / 2
    self.ball.y  = Global.VIRTUAL_HEIGHT / 2
    self.ball.dx = direction * 150
    self.ball.dy = self.rng:random(-100, 100)
end

function Global:applyInputs(dt)
    for id, input in pairs(self.playerInputs) do
        if input == "up" then
            self.players[id].y =
                math.max(0, self.players[id].y - Global.PADDLE_SPEED * dt)
        elseif input == "down" then
            self.players[id].y =
                math.min(
                    Global.VIRTUAL_HEIGHT - Global.PADDLE_HEIGHT,
                    self.players[id].y + Global.PADDLE_SPEED * dt
                )
        end
    end
end

local function broadPhase(bx, by, bw, bh, vx, vy, dt,
                          px, py, pw, ph)
    local futureX = bx + vx * dt
    local futureY = by + vy * dt

    local minX = math.min(bx, futureX)
    local minY = math.min(by, futureY)
    local maxX = math.max(bx + bw, futureX + bw)
    local maxY = math.max(by + bh, futureY + bh)

    return not (
        maxX < px or
        minX > px + pw or
        maxY < py or
        minY > py + ph
    )
end

local function sweptAABB(bx, by, bw, bh, vx, vy,
                         px, py, pw, ph)
    local xInvEntry, yInvEntry
    local xInvExit, yInvExit

    if vx > 0 then
        xInvEntry = px - (bx + bw)
        xInvExit  = (px + pw) - bx
    else
        xInvEntry = (px + pw) - bx
        xInvExit  = px - (bx + bw)
    end

    if vy > 0 then
        yInvEntry = py - (by + bh)
        yInvExit  = (py + ph) - by
    else
        yInvEntry = (py + ph) - by
        yInvExit  = py - (by + bh)
    end

    local xEntry    = vx == 0 and -math.huge or xInvEntry / vx
    local xExit     = vx == 0 and math.huge or xInvExit / vx
    local yEntry    = vy == 0 and -math.huge or yInvEntry / vy
    local yExit     = vy == 0 and math.huge or yInvExit / vy

    local entryTime = math.max(xEntry, yEntry)
    local exitTime  = math.min(xExit, yExit)

    if entryTime > exitTime or
        entryTime < 0 or
        entryTime > 1 then
        return nil
    end

    local nx, ny = 0, 0
    if xEntry > yEntry then
        nx = xInvEntry < 0 and 1 or -1
    else
        ny = yInvEntry < 0 and 1 or -1
    end

    return entryTime, nx, ny
end


function Global:update(dt)
    -- Inputs first
    for id, input in pairs(self.playerInputs) do
        local p = self.players[id]

        if input == "up" then
            p.y = math.max(0, p.y - Global.PADDLE_SPEED * dt)
        elseif input == "down" then
            p.y = math.min(
                Global.VIRTUAL_HEIGHT - Global.PADDLE_HEIGHT,
                p.y + Global.PADDLE_SPEED * dt
            )
        end
    end

    local remaining = dt

    while remaining > 0 do
        local earliestTime = 1
        local normalX, normalY = 0, 0
        local collided = false

        -- Paddle collisions
        for i = 1, 2 do
            local px = (i == 1) and Global.P1_X or Global.P2_X
            local py = self.players[i].y

            if broadPhase(
                    self.ball.x, self.ball.y,
                    Global.BALL_SIZE, Global.BALL_SIZE,
                    self.ball.dx, self.ball.dy,
                    remaining,
                    px, py,
                    Global.PADDLE_WIDTH, Global.PADDLE_HEIGHT
                ) then
                local t, nx, ny = sweptAABB(
                    self.ball.x, self.ball.y,
                    Global.BALL_SIZE, Global.BALL_SIZE,
                    self.ball.dx,
                    self.ball.dy,
                    px, py,
                    Global.PADDLE_WIDTH, Global.PADDLE_HEIGHT
                )

                if t and t < earliestTime then
                    earliestTime = t
                    normalX = nx or px
                    normalY = ny or py
                    collided = true
                end
            end
        end

        -- Wall collisions
        if self.ball.dy < 0 then
            local t = (0 - self.ball.y) / (self.ball.dy * remaining)
            if t >= 0 and t < earliestTime then
                earliestTime = t
                normalX, normalY = 0, 1
                collided = true
            end
        elseif self.ball.dy > 0 then
            local t = ((Global.VIRTUAL_HEIGHT - Global.BALL_SIZE) - self.ball.y)
                / (self.ball.dy * remaining)
            if t >= 0 and t < earliestTime then
                earliestTime = t
                normalX, normalY = 0, -1
                collided = true
            end
        end

        -- Move to impact
        self.ball.x = self.ball.x + self.ball.dx * remaining * earliestTime
        self.ball.y = self.ball.y + self.ball.dy * remaining * earliestTime

        if collided then
            if normalX ~= 0 then
                self.ball.dx = -self.ball.dx
            end
            if normalY ~= 0 then
                self.ball.dy = -self.ball.dy
            end

            remaining = remaining * (1 - earliestTime)

            if earliestTime <= 0.00001 then
                remaining = 0
            end
        else
            remaining = 0
        end
    end

    -- Scoring
    if self.ball.x < 0 then
        self.score.p2 = self.score.p2 + 1
        self:resetBall(1)
    elseif self.ball.x > Global.VIRTUAL_WIDTH then
        self.score.p1 = self.score.p1 + 1
        self:resetBall(-1)
    end
end

function Global:serialize()
    return string.format(
        "%d|%f|%f|%f|%f|%f|%f|%d|%d|%s|%d",
        self.tick,
        self.players[1].y,
        self.players[2].y,
        self.ball.x,
        self.ball.y,
        self.ball.dx,
        self.ball.dy,
        self.score.p1,
        self.score.p2,
        self.gameState,
        self.seed
    )
end

function Global:deserialize(data)
    local parts = {}
    for part in data:gmatch("[^|]+") do
        table.insert(parts, part)
    end

    self.tick = tonumber(parts[1])
    self.players[1].y = tonumber(parts[2])
    self.players[2].y = tonumber(parts[3])
    self.ball.x = tonumber(parts[4])
    self.ball.y = tonumber(parts[5])
    self.ball.dx = tonumber(parts[6])
    self.ball.dy = tonumber(parts[7])
    self.score.p1 = tonumber(parts[8])
    self.score.p2 = tonumber(parts[9])
    self.gameState = parts[10]
end

return Global