local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local UIAssets = game:GetService("ServerStorage"):FindFirstChild("GameAssets"):FindFirstChild("UI")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Component = require(ReplicatedStorage.Packages.Component)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Utils = require(ReplicatedStorage.GameData).Utils

--[[
    Overview
    CharacterSlot Component
        - Manages a character slot in a plot
        - Handles character attachment, stealing, moving, and collection of rewards
--]]

local CharacterSlot = Component.new({
     Tag = "CharacterSlot",
     Ancestors = {workspace.Plots}
})

function CharacterSlot:Construct()

    self.Slot = self.Instance:FindFirstChild("Slot")
    self.IsStolen = false
    self.IsMoving = false
    self.IsStealable = true --Used by other systems and set by other systems
    self.CurrentAmount = 0
    self.OfflineAmount = 0
    self.OnCollected = Signal.new()

    --A UI to show collection info
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

    -- This function sets the current and offline amounts displayed in the CollectUI
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
            --Geen text was added to the money amount so it stands out and that is done via RichText manipulation
            --Instead of using string.format, we use an f-string for clarity
            offlineLabel.Text = `Offline Reward: <font color="#{Color3.fromRGB(255,255,0):ToHex()}">${Utils.formatNumber(offlineAmount)}</font>`
            offlineLabel.Visible = offlineAmount>0
        end
    end

end


function CharacterSlot:Start()

    -- This function initializes the CollectButton and its behavior by connecting to the Triggered event
    -- The Triggered Event is a event configured in the CollectButton Component that fires when the button is pressed
    --[[
        ...
        self.Base.Touched:Connect(function(hitPart)
            local player = game.Players:GetPlayerFromCharacter(hitPart.Parent) --Make sure it's a player touching
            if self.Enabled and canTouch and player and self:IsOwner(player) then --Check ownership of the button and if it's enabled
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
    --]]
    self.CollectButton = Knit.Components.TouchButton:FromInstance(self.Instance:FindFirstChild("Button"))
    self.CollectButton:SetEnabled(false)

    self.CollectButton.Triggered:Connect(function(player)
        if self:IsOwner(player) and (self.CurrentAmount + self.OfflineAmount)>0 then
            self.OnCollected:Fire(self.CurrentAmount,self.OfflineAmount)
            self:SetAmount(0,0)
    
            -- This plays a sfx and sets it soundgroup accordingly so it can be controlled via player settings
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
end


function CharacterSlot:IsOwner(player)
    --This component instance is nested under the Plot instance, so we can find the plot by searching ancestors and then pulling the OwnerId attribute
    local plot = self.Instance:FindFirstAncestor("Plot")
    if plot and player then
        local ownerId = plot:GetAttribute("OwnerId")
        return player and player.UserId == ownerId
    end
end

function CharacterSlot:GetPlot()
    --This is a faster way to get the Plot which could be used in :IsOwner() but kept separate for clarity
    local plotInstance = self.Instance:FindFirstAncestor("Plot")
    if plotInstance then
        return Knit.Components.Plot:FromInstance(plotInstance)
    end
end


function CharacterSlot:AttachCharacter(characterTemplate: Model|nil, mutation)
    --This attaches the character model to the slot, applying any mutation variants or effects as needed
    if self.CurrentModel then
        self.CurrentModel:Destroy()
        self.CurrentModel = nil
    end

    -- To account for how the game has the mutation variants set up, we first check if there's a variant for the given mutation
    local hasMutationVariant = false
    if typeof(mutation)=="string" and mutation ~= "Base" then
        local variantFolder = ServerStorage.GameAssets.MutationVariants:FindFirstChild(mutation)
        if variantFolder and variantFolder:FindFirstChild(characterTemplate.Name) then
            --If it does find a variant it replicates any attributes that could be missing into it's variantModel
            local variantModel = variantFolder[characterTemplate.Name]:Clone()
            for k,v in characterTemplate:GetAttributes() do if k~="RBX_ReimportId" then variantModel:SetAttribute(k,v) end end
            characterTemplate = variantModel

            --We have to set this to true so the rest of the code knows it's using a variant
            hasMutationVariant = true
        end
    end
    -- Sanity checks to ensure nothing crazy is going on
    if characterTemplate and characterTemplate:IsA("Model") then
        local characterModel = characterTemplate:Clone()
        characterModel:AddTag("Character")
        characterModel.Parent = self.Instance

        --We clone effects into the character but ONLY if it's not using a variant because they already have effects in them
        local effectTemplate = mutation and ServerStorage.GameAssets.Effects.Mutations:FindFirstChild(mutation)
        if not hasMutationVariant then
        
            -- We take effects from a template and weld them to the character's primary part
            if effectTemplate then
                local eff = effectTemplate:Clone()
                eff.Name = "VFX"
                eff.CanCollide, eff.Anchored = false, false

                local weld = Instance.new("Weld")
                weld.Part0 = characterModel.PrimaryPart
                weld.Part1 = eff
                weld.Parent = eff

                eff.Parent = characterModel.PrimaryPart

                --We need to tag this as a VFX so the settings system can manage it properly
                for _,x in eff:GetDescendants() do
                    if x:IsA("ParticleEmitter") then x:AddTag("VFX") end
                end

                -- Due to the Lucky Warrior model's unique structure, we need to parent the effects differently (They have bones)
                local mainBone = characterModel.Name:find("Lucky Warrior$") and characterModel.PrimaryPart:FindFirstChildWhichIsA("Bone") or nil
                if mainBone then
                    for _,x in eff:GetChildren() do x.Parent = mainBone end
                end
            end

            -- This is a faster way to make mutatino variants that have different appearances by applying PBR textures/materials
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

        --We have to set the Mutation attribute for other UI systems to read
        characterModel:SetAttribute("Mutation",mutation)
        for _,x in characterModel:GetDescendants() do
            if x:IsA("BasePart") then x.CollisionGroup = "Characters" end
        end

        --Some characters are simply too big for the slot so we have to scale them accordingly via a pre-determined Scale attribute
        if characterModel:GetAttribute("Scale") then
            characterModel:ScaleTo(characterModel:GetAttribute("Scale"))
        end

        --The character MUST be anchored or there's a chance it could be moved
        characterModel.PrimaryPart.Anchored = true

        --Now for this, we try to play the idle animation if it exists because sometimes with the default Animate script it doesn't play automtaically if the character is anchored
        if characterModel:FindFirstChildWhichIsA("Humanoid") then
            local humanoid = characterModel:FindFirstChildWhichIsA("Humanoid")

            --I decided to nest this all into one little function that fires and returns the value because it looks cleaner
            local animTrack = (function()
                local idleObj = characterModel:FindFirstChild("Animate") and characterModel:FindFirstChild("Animate"):FindFirstChild("idle")
                if idleObj then
                    local anim = idleObj:FindFirstChild("Animation1") or idleObj:FindFirstChildOfClass("Animation",true)
                    --Instead of returning the animation object, we return the loaded animation track
                    if anim then return humanoid:LoadAnimation(anim) end
                end
            end)()
            

            -- Loop and play it
            if animTrack then
                animTrack.Looped = true
                animTrack:Play()
            end

            -- This is a deprecated fallback I was using to try and force the idle animation to play by unachoring after a delay
            -- task.delay(1,function()
            --     if characterModel.PrimaryPart then characterModel.PrimaryPart.Anchored = false end
            -- end)
        end

        --We have to move the charater to the slot position and we use pivot to ensure proper orientation
        characterModel:PivotTo(self.Slot:GetPivot())

        --We store the current model for later reference
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
    --This function was going to be used to add the idle animation but ended up being integrated into :AttachCharacter() instead
end

function CharacterSlot:SetStolen(active)
    if self.IsStolen == active then return end
    self.IsStolen = active

    --Whenever the character is stolen we apply a transparency effect so we need to ensure IsStolen state is reflected visually
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

        --Again the attributes are used for UI reference
        self.CurrentModel:SetAttribute("IsStolen",active)

        --Instead of setting up the StolenUI here, we do all our UI management via Roact in the client (hence the attributes)
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

    --Similar to SetStolen, we visually indicate movement by shifting the character model's position
    --We could set it's transparency or some other effect but this is more noticeable as the model appears to be gone

    if self.CurrentModel then
        self.CurrentModel:PivotTo(self.Slot:GetPivot()*CFrame.new(0,active and -100 or 0,0))
        self.CurrentModel:SetAttribute("IsMoving",active)
        if self.CurrentModel:FindFirstChildWhichIsA("Humanoid") then
            self.CurrentModel.PrimaryPart.Anchored = active
        end
    end
end


function CharacterSlot:GetCharacter()
    --Little function to quickly grab the Character Model
    return self.CurrentModel
end

function CharacterSlot:SetSlotColor(color: Color3)
    if typeof(color)~="Color3" then return end

    --This function isn't used much but it was added incase we wanted to add visual changes to the Slot color based on character rarity
    for _,x in self.Slot:GetDescendants() do
        if x:IsA("BasePart") and x.Name == "Base" then
            x.Color = color
        elseif x:IsA("ParticleEmitter") then
            x.Color = ColorSequence.new(color)
        end
    end
end
--This was going to be for updating how much money the character has generated by instead of using several Stepped connections we just use a single timer in GameService
--[[
function CharacterSlot:SteppedUpdate(dt)
     local now = tick()
     if not self.lastUpdateTime or (now-self.lastUpdateTime)>1 then
          self.lastUpdateTime = now
     end
end
--]]




return CharacterSlot
