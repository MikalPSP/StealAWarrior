
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule"))

if game:GetService("RunService"):IsStudio() then
    ContextActionService:BindAction("SprintAction",function(_,inputState)
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            local normalSpeed = game.StarterPlayer.CharacterWalkSpeed
            if humanoid.Parent:FindFirstChild("CharacterWeld") then
                humanoid.WalkSpeed = normalSpeed*.5
            else
                humanoid.WalkSpeed = inputState == Enum.UserInputState.Begin and normalSpeed*1.5 or normalSpeed
            end
            return Enum.ContextActionResult.Sink
        end
    end,true,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
end

LocalPlayer:SetAttribute("InvertedControls",false)
LocalPlayer:GetAttributeChangedSignal("InvertedControls"):Connect(function()
    local is_inverted = LocalPlayer:GetAttribute("InvertedControls")
    local controls = PlayerModule:GetControls()
    if is_inverted then
        controls.moveFunction = function(_,moveVec,rel)
            LocalPlayer:Move(moveVec*Vector3.new(-1,0,-1),rel)
        end
    else
        controls.moveFunction = LocalPlayer.Move
    end
end)