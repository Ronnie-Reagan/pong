-- logging.lua
local LOGGING = {}
LOGGING.__index = LOGGING

-- Create logger
function LOGGING:new(filename)
    local t = setmetatable({}, self)
    t.filename = filename or "server.log"
    t.queue = {}
    t.locked = false
    t.flushInterval = 1 -- seconds
    t.accumulator = 0
    return t
end

-- Queue a message
function LOGGING:print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        table.insert(parts, tostring(v))
    end
    local line = table.concat(parts, "\t")
    if not self.queue then self.queue = {} end
    table.insert(self.queue, line)
end

-- Flush queued messages to file
function LOGGING:update(dt)
    self.accumulator = self.accumulator + dt
    if self.accumulator < self.flushInterval then return end
    self.accumulator = 0

    if #self.queue == 0 or self.locked then return end

    self.locked = true
    local f, err = io.open(self.filename, "a")
    if f then
        for _, line in ipairs(self.queue) do
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. line .. "\n")
        end
        f:close()
        self.queue = {}
    else
        -- Could not open file, keep messages queued
        print("Logger error:", err)
    end
    self.locked = false
end

-- Flush immediately
function LOGGING:flush()
    if #self.queue == 0 then return end
    local f, err = io.open(self.filename, "a")
    if f then
        for _, line in ipairs(self.queue) do
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. table.remove(self.queue, _) .. "\n")
        end
        f:close()
        self.queue = {}
    else
        print("Logger flush error:", err)
    end
end

return LOGGING