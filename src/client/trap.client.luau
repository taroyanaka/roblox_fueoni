local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local remotes = ReplicatedStorage:WaitForChild("OniGameRemotes")
local PlaceTrapEvent = remotes:WaitForChild("PlaceTrapRequest")

local placing = false

local function beginPlace(position)
    if placing then return end
    placing = true
    -- move player to the position and freeze for 2 seconds
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
    end
    local oldWalk = humanoid.WalkSpeed
    local oldJump = humanoid.JumpPower
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    wait(2)
    -- send request to server to create trap
    PlaceTrapEvent:FireServer(position)
    humanoid.WalkSpeed = oldWalk
    humanoid.JumpPower = oldJump
    placing = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        -- place trap at mouse hit point
        local mouse = player:GetMouse()
        local hit = mouse.Hit
        if hit then
            local pos = hit.Position
            beginPlace(pos)
        end
    end
end)

print("Trap client loaded")

return {}
