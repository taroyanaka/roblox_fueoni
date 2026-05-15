local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents
local RemoteFolder = ReplicatedStorage:FindFirstChild("OniGameRemotes") or Instance.new("Folder", ReplicatedStorage)
RemoteFolder.Name = "OniGameRemotes"
local PlaceTrapEvent = RemoteFolder:FindFirstChild("PlaceTrapRequest") or Instance.new("RemoteEvent", RemoteFolder)
PlaceTrapEvent.Name = "PlaceTrapRequest"

local TrapModule = require(script.Parent.Parent.shared:WaitForChild("trap_module"))

local playerHP = {}
local ghosts = {}

local GAME_DURATION = 30
local gameStartTime = tick()
local gameEnded = false

local function ensureCharacter(player)
    return player.Character or player.CharacterAdded:Wait()
end

local function setPlayerHP(player, hp)
    playerHP[player.UserId] = hp
    -- could fire client HUD update
end

local function playerLose(player)
    if gameEnded then return end
    gameEnded = true
    warn(player.Name .. " lost the game")
    -- notify players
end

local function findNearestPlayer(pos)
    local nearest, ndist
    for _, p in pairs(Players:GetPlayers()) do
        local ch = p.Character
        if ch and ch:FindFirstChild("HumanoidRootPart") then
            local d = (ch.HumanoidRootPart.Position - pos).Magnitude
            if not ndist or d < ndist then
                ndist = d; nearest = p
            end
        end
    end
    return nearest
end

local function nearestToPlayer(pos)
    return findNearestPlayer(pos)
end

local function spawnGhostAbove(position)
    local oni = Instance.new("Part")
    oni.Name = "Oni"
    oni.Size = Vector3.new(2,2,2)
    oni.Position = position + Vector3.new(0,50,0)
    oni.Anchored = false
    oni.CanCollide = true
    oni.Parent = workspace

    local meta = {part = oni, stun = 0}
    table.insert(ghosts, meta)

    oni.Touched:Connect(function(hit)
        if gameEnded then return end
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player and playerHP[player.UserId] then
            if meta.stun <= 0 then
                playerHP[player.UserId] = playerHP[player.UserId] - 1
                meta.stun = 1 -- 1 second stop
                if playerHP[player.UserId] <= 0 then
                    playerLose(player)
                end
            end
        end
        -- trap interaction handled by TrapModule
    end)
end

-- Place trap remote handling
PlaceTrapEvent.OnServerEvent:Connect(function(player, position)
    -- validate
    if not position then return end
    TrapModule.placeTrapForPlayer(player, position)
end)

-- Player management
Players.PlayerAdded:Connect(function(player)
    setPlayerHP(player, 10)
    player.CharacterAdded:Connect(function(char)
        -- nothing for now
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerHP[player.UserId] = nil
    TrapModule.removeTrapForPlayer(player)
end)

-- Main loops: spawn and move ghosts
local spawnBase = 1 -- base ghosts per second
local lastSpawnTick = tick()

RunService.Heartbeat:Connect(function(dt)
    if gameEnded then return end
    local elapsed = tick() - gameStartTime
    if elapsed >= GAME_DURATION then
        gameEnded = true
        warn("Players survived and win!")
        return
    end

    -- spawn logic: spawn count triples each second
    local seconds = math.floor(elapsed)
    local spawnCount = math.max(1, math.floor(spawnBase * (3 ^ seconds)))
    if tick() - lastSpawnTick >= 1 then
        -- spawn near the farthest player
        local farthest, fdist
        for _, p in pairs(Players:GetPlayers()) do
            local ch = p.Character
            if ch and ch:FindFirstChild("HumanoidRootPart") then
                local d = (ch.HumanoidRootPart.Position - workspace:GetModelBounds().Position).Magnitude
                if not fdist or d > fdist then
                    fdist = d; farthest = p
                end
            end
        end
        local basePos = Vector3.new(0,0,0)
        if farthest and farthest.Character and farthest.Character:FindFirstChild("HumanoidRootPart") then
            basePos = farthest.Character.HumanoidRootPart.Position
        end
        for i=1, spawnCount do
            local offset = Vector3.new((math.random()-0.5)*20,0,(math.random()-0.5)*20)
            spawnGhostAbove(basePos + offset)
        end
        lastSpawnTick = tick()
    end

    -- move ghosts toward nearest player
    for i=#ghosts,1,-1 do
        local g = ghosts[i]
        if not g.part or not g.part.Parent then
            table.remove(ghosts, i)
        else
            if g.stun > 0 then g.stun = math.max(0, g.stun - dt) end
            if g.stun <= 0 then
                local target = findNearestPlayer(g.part.Position)
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tgtpos = target.Character.HumanoidRootPart.Position
                    local dir = (tgtpos - g.part.Position)
                    if dir.Magnitude > 1 then
                        local speed = (16/10) -- player speed /10
                        g.part.Velocity = dir.Unit * speed
                    end
                end
            else
                g.part.Velocity = Vector3.new(0,0,0)
            end
        end
    end
end)

return {
    start = function() end
}
