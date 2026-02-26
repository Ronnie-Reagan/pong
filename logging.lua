local LOGGING = {}
LOGGING.__index = LOGGING

function LOGGING:new(filename)
    local t = setmetatable({}, self)
    t.filename = filename or "server.log"
    t.queue = {}
    t.locked = false
    t.flushInterval = 1
    t.accumulator = 0
    return t
end

function LOGGING:print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        table.insert(parts, tostring(v))
    end
    local line = table.concat(parts, "\t")
    table.insert(self.queue, line)
end

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
        error("Logger error:" .. err)
    end
    self.locked = false
end

function LOGGING:flush()
    if #self.queue == 0 then return end
    local f, err = io.open(self.filename, "a")
    if f then
        for _, line in ipairs(self.queue) do
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. line .. "\n")
        end
        f:close()
        self.queue = {}
    else
        error("Logger flush error:" .. err)
    end
end

return LOGGING