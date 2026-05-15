local Players = game:GetService("Players")

local traps = {} -- traps[player.UserId] = {part = Part}

local function makeTrapPart(position)
    local part = Instance.new("Part")
    part.Name = "OniTrap"
    part.Size = Vector3.new(5, 0.2, 5)
    part.Position = Vector3.new(position.X, position.Y + 0.1, position.Z)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Parent = workspace
    return part
end

local function onTrapTouched(part, other)
    if other and other.Name == "Oni" then
        -- destroy the ghost
        other:Destroy()
    end
end

local module = {}

function module.placeTrapForPlayer(player, position)
    -- remove existing
    module.removeTrapForPlayer(player)
    local trapPart = makeTrapPart(position)
    local conn
    conn = trapPart.Touched:Connect(function(hit)
        if hit and hit.Name == "Oni" then
            hit:Destroy()
        end
    end)
    traps[player.UserId] = {part = trapPart, conn = conn}
end

function module.removeTrapForPlayer(player)
    local t = traps[player.UserId]
    if t then
        if t.conn then t.conn:Disconnect() end
        if t.part and t.part.Parent then t.part:Destroy() end
        traps[player.UserId] = nil
    end
end

return module
