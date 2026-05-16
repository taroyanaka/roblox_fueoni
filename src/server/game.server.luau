local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents
local RemoteFolder = ReplicatedStorage:FindFirstChild("OniGameRemotes") or Instance.new("Folder", ReplicatedStorage)
RemoteFolder.Name = "OniGameRemotes"
local PlaceTrapEvent = RemoteFolder:FindFirstChild("PlaceTrapRequest") or Instance.new("RemoteEvent", RemoteFolder)
PlaceTrapEvent.Name = "PlaceTrapRequest"

-- Robustly locate and require the shared trap module from common locations.
local TrapModule
do
    local found
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    -- Check common locations in order
    if ReplicatedStorage:FindFirstChild("trap_module") then
        found = ReplicatedStorage:FindFirstChild("trap_module")
    elseif script:FindFirstChild("trap_module") then
        found = script:FindFirstChild("trap_module")
    elseif script.Parent and script.Parent:FindFirstChild("trap_module") then
        found = script.Parent:FindFirstChild("trap_module")
    elseif script.Parent and script.Parent.Parent and script.Parent.Parent:FindFirstChild("shared") and script.Parent.Parent.shared:FindFirstChild("trap_module") then
        found = script.Parent.Parent.shared:FindFirstChild("trap_module")
    end

    if found then
        local ok, mod = pcall(require, found)
        if ok then
            TrapModule = mod
        else
            warn("Failed to require trap_module:", mod)
        end
    else
        warn("trap_module not found in ReplicatedStorage or script ancestors; using noop fallback")
    end

    -- Fallback to noop module to avoid nil errors
    if not TrapModule then
        TrapModule = {}
        TrapModule.placeTrapForPlayer = function() end
        TrapModule.removeTrapForPlayer = function() end
    end
end

local playerHP = {}
local ghosts = {}

local GAME_DURATION = 30
local gameStartTime = tick()
local gameEnded = false

-- Spawn area radius (map random spawn will be within +/- this on X/Z from map center)
local spawnRange = 100

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
    oni.Shape = Enum.PartType.Ball
    oni.Position = position + Vector3.new(0,50,0)
    oni.Anchored = false
    oni.CanCollide = true
    oni.Parent = workspace

    -- ghost meta: hp, stun, landed state
    local meta = {part = oni, stun = 0, hp = 1, landed = false}
    table.insert(ghosts, meta)
    warn("Spawned Oni part at " .. tostring(oni.Position))

    -- Landing detection: when touching non-player part first time, mark as landed
    local landConn
    landConn = oni.Touched:Connect(function(hit)
        if meta.landed then return end
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player then
            meta.landed = true
            warn("Oni landed at " .. tostring(oni.Position))
            if landConn then landConn:Disconnect() end
        end
    end)

    -- Damage and trap handling (only apply damage after landing)
    oni.Touched:Connect(function(hit)
        if gameEnded then return end
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player and playerHP[player.UserId] then
            if meta.landed and meta.stun <= 0 then
                playerHP[player.UserId] = playerHP[player.UserId] - 1
                meta.stun = 1 -- 1 second stop
                if playerHP[player.UserId] <= 0 then
                    playerLose(player)
                end
            end
        end
        -- trap interaction handled by TrapModule (trap_module listens for Oni touching trap parts)
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

    -- spawn logic: spawn count increases by +1 each second (additive)
    local seconds = math.floor(elapsed)
    local spawnCount = math.max(1, math.floor(spawnBase + seconds))
    if tick() - lastSpawnTick >= 1 then
        -- spawn at random map positions (map center if available)
        local mapCenter = Vector3.new(0,0,0)
        local Map = workspace:FindFirstChild("Map")
        if Map and Map.PrimaryPart then
            mapCenter = Map.PrimaryPart.Position
        end
        local basePos = mapCenter
        for i=1, spawnCount do
            -- choose a random X/Z within spawnRange around map center
            local rx = math.random(-spawnRange, spawnRange)
            local rz = math.random(-spawnRange, spawnRange)
            local spawnPos = basePos + Vector3.new(rx, 0, rz)
            warn("Spawning Oni at " .. tostring(spawnPos))
            spawnGhostAbove(spawnPos)
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
            if g.stun <= 0 and g.landed then
                local target = findNearestPlayer(g.part.Position)
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tgtpos = target.Character.HumanoidRootPart.Position
                    local dir = (tgtpos - g.part.Position)
                    if dir.Magnitude > 1 then
                        -- Ghost speed is player speed / 10
                        local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
                        local playerSpeed = (humanoid and humanoid.WalkSpeed) or 16
                        local speed = playerSpeed / 10
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
