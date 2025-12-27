local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require(ReplicatedStorage.Packages.Component)
local Signal = require(ReplicatedStorage.Packages.Signal)

local TouchButton = Component.new({
     Tag = "TouchButton",
     Ancestors = {workspace},
})

function TouchButton:Construct()
    self.Base = self.Instance.PrimaryPart
    self.Enabled = true

    self.Triggered = Signal.new()
    self.OriginalColor = self.Base.Color

    self.UI = self.Instance:FindFirstChildWhichIsA("BillboardGui")
end

function TouchButton:UpdateUI(childName, props)
    local uiElement = self.UI and self.UI:FindFirstChild(childName)
    if uiElement and typeof(props)=="table" then
        for k,v in props do
            uiElement[k] = v
        end
    end
end

function TouchButton:SetEnabled(on)
    if self.Enabled == on then return end
    self.Enabled = on

    for _,x in ipairs(self.Instance:GetDescendants()) do
        if x:IsA("Beam") then
            x.Enabled = self.Enabled
        elseif x == self.Base then
            --x.Color = self.OriginalColor:Lerp(Color3.new(),self.Enabled and 0 or .5)
        end
    end
end

function TouchButton:Enable() self:SetEnabled(true) end
function TouchButton:Disable() self:SetEnabled(false) end

function TouchButton:SetColor(color)
    if typeof(color)~="Color3" then color = self.OriginalColor end
    for _,x in self.Instance:GetDescendants() do
        if x == self.Base then x.Color = color; self.OriginalColor = color
        elseif x:IsA("Beam") then x.Color = ColorSequence.new(color)
        end
    end
end

function TouchButton:IsOwner(player)
    local plot = self.Instance:FindFirstAncestor("Plot")
    if plot and player then
        local ownerId = plot:GetAttribute("OwnerId")
        return player and player.UserId == ownerId
    end
end

function TouchButton:Start()
    local canTouch = true
    local tweenInfo = TweenInfo.new(.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,true)

    local tweenEffects, beams = {}, {} do
        for _,x in self.Instance:GetDescendants() do
            if x:IsA("Decal") and x.Name == "Vignette" then
                table.insert(tweenEffects, TweenService:Create(x,tweenInfo,{ Transparency = .5}))
            elseif x:IsA("Beam") then
                table.insert(tweenEffects, TweenService:Create(x,tweenInfo,{ Brightness = 10}))

                x.Attachment1.CFrame = CFrame.new(0,0,0)
                table.insert(tweenEffects, TweenService:Create(x.Attachment1,TweenInfo.new(.5),{ CFrame = x.Attachment1.CFrame }))
                table.insert(beams, x)
            end
        end
    end


    self.Base.Touched:Connect(function(hitPart)
        local player = game.Players:GetPlayerFromCharacter(hitPart.Parent)
        if self.Enabled and canTouch and player and self:IsOwner(player) then
            canTouch = false
            for _,t in tweenEffects do t:Play() end

            for _,b in beams do
                b.Attachment1.CFrame = CFrame.new(2,0,0)
            end

            self.Triggered:Fire(player)
            task.delay(1,function()
                canTouch = true
            end)
        end
    end)
end

return TouchButton
