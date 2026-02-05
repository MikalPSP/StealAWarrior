local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local UIAssets = game:GetService("ServerStorage"):FindFirstChild("GameAssets"):FindFirstChild("UI")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Component = require(ReplicatedStorage.Packages.Component)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Utils = require(ReplicatedStorage.GameData).Utils


local CharacterSlot = Component.new({
     Tag = "CharacterSlot",
     Ancestors = {workspace.Plots}
})

function CharacterSlot:Construct()

    self.Slot = self.Instance:FindFirstChild("Slot")
    self.IsStolen = false
    self.IsMoving = false
    self.IsStealable = true
    self.CurrentAmount = 0
    self.OfflineAmount = 0
    self.OnCollected = Signal.new()
    self.OnAmountChanged = Signal.new()
    self.OnRetired = Signal.new()

    local uiTemplate = UIAssets:FindFirstChild("CollectUI")
    if uiTemplate then
        local collectUi = uiTemplate:Clone()
        collectUi.Parent = self.Instance
        collectUi.Enabled = false
        collectUi.Adornee = self.Instance:FindFirstChild("Button").PrimaryPart
        self.CollectUI = collectUi
    end
end

function CharacterSlot:SetAmount(amount, offlineAmount)
    amount = math.max(0,tonumber(amount) or 0)

    if typeof(amount)=="number" and amount>=0 then
        self.CurrentAmount = amount
        local amountLabel = self.CollectUI:FindFirstChild("Amount")
        if amountLabel then
            amountLabel.Text = "$"..Utils.formatNumber(amount)
        end
    end

    if typeof(offlineAmount)=="number" and offlineAmount>=0 then
        self.OfflineAmount = offlineAmount
        local offlineLabel = self.CollectUI:FindFirstChild("Offline")
        if offlineLabel then
            offlineLabel.RichText = true
            offlineLabel.Text = `Offline Reward: <font color="#{Color3.fromRGB(255,255,0):ToHex()}">${Utils.formatNumber(offlineAmount)}</font>`
            offlineLabel.Visible = offlineAmount>0
        end
    end

end


function CharacterSlot:Start()

    self.CollectButton = Knit.Components.TouchButton:FromInstance(self.Instance:FindFirstChild("Button"))
    self.CollectButton:SetEnabled(false)

    self.CollectButton.Triggered:Connect(function(player)
        if self:IsOwner(player) and (self.CurrentAmount + self.OfflineAmount)>0 then
            self.OnCollected:Fire(self.CurrentAmount,self.OfflineAmount)
            self:SetAmount(0,0)
    
            local sfx = Instance.new("Sound")
            sfx.Name = "CollectSFX"
            sfx.SoundId = "rbxassetid://87681552750899"
            sfx.Parent = self.CollectButton.Base
            sfx.RollOffMaxDistance = 100
            sfx.SoundGroup = game:GetService("SoundService"):FindFirstChild("SFX")
            sfx.Volume = .5
            sfx:Play()
            task.delay(5,function() sfx:Destroy() end)
        end

    end)
    --[[
    local canTouch = true
    self.Button.PrimaryPart.Touched:Connect(function(hitPart)
        local player = Players:GetPlayerFromCharacter(hitPart.Parent)
        if canTouch and self:IsOwner(player) then
            canTouch = false
            self.OnClaim:Fire()
            task.delay(2,function() canTouch = true end)
        end
    end)
    --]]
end


function CharacterSlot:IsOwner(player)
    local plot = self.Instance:FindFirstAncestor("Plot")
    if plot and player then
        local ownerId = plot:GetAttribute("OwnerId")
        return player and player.UserId == ownerId
    end
end

function CharacterSlot:GetPlot()
    local plotInstance = self.Instance:FindFirstAncestor("Plot")
    if plotInstance then
        return Knit.Components.Plot:FromInstance(plotInstance)
    end
end


function CharacterSlot:AttachCharacter(characterTemplate: Model|nil, mutation)
    if self.CurrentModel then
        self.CurrentModel:Destroy()
        self.CurrentModel = nil
    end

    local hasMutationVariant = false
    if typeof(mutation)=="string" and mutation ~= "Base" then
        local variantFolder = ServerStorage.GameAssets.MutationVariants:FindFirstChild(mutation)
        if variantFolder and variantFolder:FindFirstChild(characterTemplate.Name) then
            local variantModel = variantFolder[characterTemplate.Name]:Clone()
            for k,v in characterTemplate:GetAttributes() do if k~="RBX_ReimportId" then variantModel:SetAttribute(k,v) end end
            characterTemplate = variantModel

            hasMutationVariant = true
        end
    end
    if characterTemplate and characterTemplate:IsA("Model") then
        local characterModel = characterTemplate:Clone()
        characterModel:AddTag("Character")
        characterModel.Parent = self.Instance

        local effectTemplate = mutation and ServerStorage.GameAssets.Effects.Mutations:FindFirstChild(mutation)
        if not hasMutationVariant then
        
            if effectTemplate then
                local eff = effectTemplate:Clone()
                eff.Name = "VFX"
                eff.CanCollide, eff.Anchored = false, false

                local weld = Instance.new("Weld")
                weld.Part0 = characterModel.PrimaryPart
                weld.Part1 = eff
                weld.Parent = eff

                eff.Parent = characterModel.PrimaryPart

                for _,x in eff:GetDescendants() do
                    if x:IsA("ParticleEmitter") then x:AddTag("VFX") end
                end

                local mainBone = characterModel.Name:find("Lucky Warrior$") and characterModel.PrimaryPart:FindFirstChildWhichIsA("Bone") or nil
                if mainBone then
                    for _,x in eff:GetChildren() do x.Parent = mainBone end
                end
            end

            local pbrTemplate = mutation and ServerStorage.GameAssets.Effects.Mutations:FindFirstChild(mutation.."_Appearance")
            if pbrTemplate then
                for _,x in characterModel:GetDescendants() do
                    if x:IsA("MeshPart") then
                        if pbrTemplate:IsA("Texture") then
                            for _,e in Enum.NormalId:GetEnumItems() do
                                local texture = pbrTemplate:Clone()
                                texture.Face = e
                                texture.Parent = x
                            end
                        else
                            pbrTemplate:Clone().Parent = x
                        end
                    end
                end
            end
        end

        characterModel:SetAttribute("Mutation",mutation)
        for _,x in characterModel:GetDescendants() do
            if x:IsA("BasePart") then x.CollisionGroup = "Characters" end
        end

        if characterModel:GetAttribute("Scale") then
            characterModel:ScaleTo(characterModel:GetAttribute("Scale"))
        end

        characterModel.PrimaryPart.Anchored = true

        if characterModel:FindFirstChildWhichIsA("Humanoid") then
            local humanoid = characterModel:FindFirstChildWhichIsA("Humanoid")
            local animTrack = (function()
                local idleObj = characterModel:FindFirstChild("Animate") and characterModel:FindFirstChild("Animate"):FindFirstChild("idle")
                if idleObj then
                    local anim = idleObj:FindFirstChild("Animation1") or idleObj:FindFirstChildOfClass("Animation",true)
                    if anim then return humanoid:LoadAnimation(anim) end
                end
            end)()

            if animTrack then
                animTrack.Looped = true
                animTrack:Play()
            end
            -- task.delay(1,function()
            --     if characterModel.PrimaryPart then characterModel.PrimaryPart.Anchored = false end
            -- end)
        end

        characterModel:PivotTo(self.Slot:GetPivot())

        self.CurrentModel = characterModel
        self.CollectUI.Enabled = true
        self.CollectButton:SetEnabled(true)
    else
        self.CurrentModel = nil
        self.CollectUI.Enabled = false
        self.CollectButton:SetEnabled(false)
    end
    self:SetStolen(false)
end

function CharacterSlot:Animate()

end

function CharacterSlot:SetStolen(active)
    if self.IsStolen == active then return end
    self.IsStolen = active

    if self.CurrentModel then
        --self.CurrentModel:PivotTo(self.Slot:GetPivot()*CFrame.new(0,active and -100 or 0,0))
        for _,x in self.CurrentModel:GetDescendants() do
            if x:IsA("Decal") or x:IsA("BasePart") and x.Name ~= "HumanoidRootPart" and x.Name ~= "VFX" then
                local origTransparency = x:GetAttribute("OriginalTransparency")
                if not origTransparency then
                    x:SetAttribute("OriginalTransparency",x.Transparency)
                    origTransparency = x.Transparency
                end

                x.Transparency = active and 0.5 or origTransparency
            end
        end

        self.CurrentModel:SetAttribute("IsStolen",active)

        --[[
        local uiTemplate = ServerStorage.GameAssets.UI:FindFirstChild("StolenUI")
        if active and uiTemplate then
            local ui = uiTemplate:Clone()
            ui.Parent = self.Instance
            ui.Adornee = self.Slot.PrimaryPart
            ui.StudsOffsetWorldSpace = Vector3.new(0,6,0)
        end
        --]]
    end
end

function CharacterSlot:SetMoving(active)
    if self.IsMoving == active then return end
    self.IsMoving = active

    if self.CurrentModel then
        self.CurrentModel:PivotTo(self.Slot:GetPivot()*CFrame.new(0,active and -100 or 0,0))
        self.CurrentModel:SetAttribute("IsMoving",active)
        if self.CurrentModel:FindFirstChildWhichIsA("Humanoid") then
            self.CurrentModel.PrimaryPart.Anchored = active
        end
    end
end


function CharacterSlot:GetCharacter()
    return self.CurrentModel
end

function CharacterSlot:SetSlotColor(color: Color3)
    if typeof(color)~="Color3" then return end

    for _,x in self.Slot:GetDescendants() do
        if x:IsA("BasePart") and x.Name == "Base" then
            x.Color = color
        elseif x:IsA("ParticleEmitter") then
            x.Color = ColorSequence.new(color)
        end
    end
end

function CharacterSlot:SteppedUpdate(dt)
     local now = tick()
     if not self.lastUpdateTime or (now-self.lastUpdateTime)>1 then
          self.lastUpdateTime = now
     end
end




return CharacterSlot
