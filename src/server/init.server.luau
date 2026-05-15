local success, err = pcall(function()
	local gameServer = require(script.Parent:FindFirstChild("game.server") or script.Parent:FindFirstChild("game_server") )
	if type(gameServer) == "table" and type(gameServer.start) == "function" then
		gameServer.start()
	end
end)
if not success then
	warn("game server failed to start:", err)
end
