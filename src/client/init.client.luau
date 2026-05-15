local success, err = pcall(function()
	local trapClient = require(script.Parent:FindFirstChild("trap.client") or script.Parent:WaitForChild("trap.client"))
end)
if not success then
	warn("trap client failed to load:", err)
end
