local Room   = {}
Room.__index = Room

function Room:new(id, Global)
	local r = setmetatable({}, self)
	r.id = id
	r.global = Global:new()
	r.state = "waiting" -- waiting | playing

	r.players = {
		[1] = { peer = nil, ready = false },
		[2] = { peer = nil, ready = false }
	}

	return r
end

function Room:isFull()
	return self.players[1].peer and self.players[2].peer
end

function Room:bothReady()
	return self.players[1].ready and self.players[2].ready
end

function Room:resetReady()
	self.players[1].ready = false
	self.players[2].ready = false
end

return Room