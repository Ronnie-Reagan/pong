-- main.lua
local MODE = "client"
local Logging = require "logging"
local logger
if not love.graphics then
	MODE = "server"
	logger = Logging:new("server.log")
	print = function(...) logger:print(...) end
else
	logger = Logging:new("client.log")
	print = function(...) love.graphics.print(...) logger:print(...) end
end
print("System Starting.. Running in " .. MODE .. " mode")
local enet   = require "enet"
local Global = require "global"
local Server = require "server"
local Client = require "client"
local Room   = require "room"
local global = Global:new()
local app

function love.load()
	if MODE == "server" then
		app = Server:new(enet, logger)
	else
		love.graphics.setDefaultFilter("nearest", "nearest")
		app = Client:new(global, "love.donreagan.ca:1990")
	end
end

function love.update(dt)
	app:update(dt, global, Room, Global)
	logger:update(dt)
end

if MODE == "client" then
	function love.draw()
		app:draw()
	end
end
