-- SERVER WITH LOGGING
local Server = {}
Server.__index = Server

function Server:new(enet, logger)
	local s = setmetatable({}, self)
	s.host = enet.host_create("*:1990", 64)
    s.enet = enet
	s.rooms = {}
	s.peerRoom = {}
	s.accumulator = 0
	s.logger = logger or { print = print }
	return s
end

function Server:getOrCreateRoom(RoomSystem, Global)
	for _, room in pairs(self.rooms) do
		if room.state == "waiting" and not room:isFull() then
			self.logger:print("Assigning player to existing room:", room.id)
			return room
		end
	end

	local id = #self.rooms + 1
	local room = RoomSystem:new(id, Global)
	self.rooms[id] = room
	self.logger:print("Created new room:", id)
	return room
end

function Server:broadcastRoom(room, message)
	for i = 1, 2 do
		local peer = room.players[i].peer
		if peer then
			peer:send(message)
		end
	end
end

function Server:checkRoomStart(room)
	if room:bothReady() then
		room.state = "playing"
		room.global:resetBall(1)
		self:broadcastRoom(room, "start")
		self.logger:print("Room", room.id, "started match. Both players ready.")
	end
end

function Server:handleNetwork(RoomSystem, Global)
	if not self.host then self.host = self.enet.host_create("*:1990", 64) end
	local event = self.host:service(0)

	while event do
		-- CONNECT
		if event.type == "connect" then
			local room = self:getOrCreateRoom(RoomSystem, Global)

			local slot
			if not room.players[1].peer then
				slot = 1
			elseif not room.players[2].peer then
				slot = 2
			end

			if slot then
				room.players[slot].peer = event.peer
				self.peerRoom[event.peer] = room
				event.peer:send("id|" .. slot)
				self.logger:print("Player connected:", "Room", room.id, "Slot", slot)
			else
				event.peer:disconnect()
				self.logger:print("Player connection rejected: all slots full in Room", room.id)
			end
		end

		-- DISCONNECT
		if event.type == "disconnect" then
			local room = self.peerRoom[event.peer]
			if room then
				for i = 1, 2 do
					if room.players[i].peer == event.peer then
						room.players[i].peer = nil
						room.players[i].ready = false
						self.logger:print("Player disconnected from Room", room.id, "Slot", i)
					end
				end
				room.state = "waiting"
				room:resetReady()
				self.logger:print("Room", room.id, "reset to waiting state due to disconnect")
			end
			self.peerRoom[event.peer] = nil
		end

		-- RECEIVE
		if event.type == "receive" then
			local room = self.peerRoom[event.peer]
			if not room then
				event = self.host:service(0)
				goto continue
			end

			-- READY
			if event.data:sub(1, 6) == "ready|" then
				local id = tonumber(event.data:sub(7))
				if id and room.players[id] then
					room.players[id].ready = true
					self.logger:print("Player", id, "ready in Room", room.id)
					self:checkRoomStart(room)
				end
			else
				-- INPUT
				local id, input = event.data:match("(%d)|(.+)")
				id = tonumber(id)
				if id and room.state == "playing" then
					room.global.playerInputs[id] = input
				end
			end
		end

		::continue::
		event = self.host:service(0)
	end
end

function Server:update(dt, Global, RoomSystem, global)
	self.accumulator = self.accumulator + dt

	self:handleNetwork(RoomSystem, global)

	while self.accumulator >= Global.TICKTIME do
		for _, room in pairs(self.rooms) do
			if room.state == "playing" then
				room.global.tick = room.global.tick + 1
				room.global:update(Global.TICKTIME)
			end
		end
		self.accumulator = self.accumulator - Global.TICKTIME
	end

	for _, room in pairs(self.rooms) do
		if room.state == "playing" then
			self:broadcastRoom(room, room.global:serialize())
		end
	end
end

return Server