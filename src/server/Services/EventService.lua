local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)
local GameData = require(ReplicatedStorage.GameData)

local localRandom = Random.new(tick())

local EventLightingFolder = Lighting:FindFirstChild("EventLighting")

local EventService = Knit.CreateService({
    Name = "EventService",
    Client = {
        OnEventChanged = Knit.CreateSignal(),
        OnServerLuckChanged = Knit.CreateSignal()
    },

    ServerLuck = {
        CurrentLevel = 1,
        Timestamp = nil
    },

    CurrentEvent = nil,

    Settings = {
        EventWeights = { Shocked = 3, Galactic = 1, Volcanic = 8, Acid = 6, Divine = 2 },
        EventInterval = 3600
    },

    AvailableEvents = {
        ["Shocked"] = {
            Duration = 300,
            MutationType = "Shocked",
            Description = "Warriors get shocked when they touch the ground!",
        },

        ["Galactic"] = {
            Duration = 300,
            MutationType = "Galaxy",
            Description = "Warriors get transformed by deep space events!",
        },

        ["Fire"] = {
            Duration = 300,
            MutationType = "Fire",
            Description = "Warriors are ignited with flames!",
        },

        ["Acid"] = {
            Duration = 300,
            MutationType = "Acid",
            Description = "Warriors are covered in acid!",
        },

        ["Gold"] = {
            Duration = 300,
            MutationType = "Gold",
            Description = "All warriors turn to gold!"
        },

        ["Divine"] = {
            Duration = 300,
            MutationType = "Divine",
            Description = "Warriors are blessed by the gods!"
        },
    }
})

function EventService:KnitInit()

end



function EventService:KnitStart()
    local economyService = Knit.GetService("EconomyService")
    economyService.OnProductGranted:Connect(function(player, productId)
        local productName = economyService:GetProductName(productId)
        if productName == "Server Luck" then
            self:SetServerLuck(2,15*60)
        elseif productName == "Server Luck II" then
            self:SetServerLuck(4,15*60)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(1)

            local now = os.time()
            if self.ServerLuck.Timestamp and now >= self.ServerLuck.Timestamp then
                self.ServerLuck = {
                    CurrentLevel = 1,
                    Timestamp = nil
                }
                self.Client.OnServerLuckChanged:FireAll(self.ServerLuck.CurrentLevel)
            end
           
            if self.CurrentEvent then
                if self.CurrentEvent.Name == "Shocked" then
                    local timeSinceLastStrike = tick()-(self._lastLightningStrike or 0)
                    if (timeSinceLastStrike>2) and math.random() < 0.5 then
                        local pos = localRandom:NextUnitVector()*Vector3.new(250,0,200)
                        local params = RaycastParams.new()
                        params.FilterType = Enum.RaycastFilterType.Whitelist
                        params.FilterDescendantsInstances = {workspace.Map}

                        local result = workspace:Raycast(pos+Vector3.yAxis*500, Vector3.yAxis*-100, params)
                        if result then pos = result.Position end

                        GameData.Effects.lightningStrike(pos)
                        self._lastLightningStrike = tick()
                    end
                end

                if now >= self.CurrentEvent.Timestamp then
                    self:EndEvent()
                end
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(self.Settings.EventInterval)

            if not self.CurrentEvent then
                local options = self.Settings.EventWeights
                local eventName = GameData.Utils.weightedChoice(Sift.Dictionary.keys(options),Sift.Dictionary.values(options),localRandom)
                if eventName then
                    self:StartEvent(eventName)
                end
            end
        end
    end)
end


function EventService:StartEvent(eventName)
    local eventData = self.AvailableEvents[eventName]
    if not eventData then warn("Event not found: " .. eventName) return end

    self.CurrentEvent = {
        Name = eventName,
        Description = eventData.Description,
        MutationType = eventData.MutationType,
        Timestamp = os.time() + eventData.Duration,
    }

    local lightingFolder = EventLightingFolder:FindFirstChild(eventName)
    if lightingFolder then
        for _,x in lightingFolder:GetChildren() do
            if x:IsA("Folder") and x.Name == "EventVFX" then
                local existing = workspace:FindFirstChild("EventVFX")
                if existing then existing:Destroy() end
                x:Clone().Parent = workspace
            elseif x:IsA("Atmosphere") or x:IsA("Sky") or x:IsA("ColorCorrectionEffect") then
                local existing = Lighting:FindFirstChildWhichIsA(x.ClassName)
                if existing then existing:Destroy() end
                x:Clone().Parent = Lighting
            end
        end
        Lighting.Brightness = lightingFolder:GetAttribute("Brightness") or 1
    end

    if eventName == "Shocked" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Lightning Event Has Started!", Color3.fromRGB(0, 170, 255))
    elseif eventName == "Galactic" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Galactic Event Has Started!", Color3.fromRGB(170, 0, 255)) 
    elseif eventName == "Fire" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Volcanic Event Has Started!", Color3.fromRGB(255, 85, 0))
    elseif eventName == "Acid" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Acidic Event Has Started!", Color3.fromRGB(0, 255, 0))  
    elseif eventName == "Gold" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Midas Touch Event Has Started!", Color3.fromRGB(255, 215, 0))
    elseif eventName == "Divine" then
        Knit.GetService("GameService").Client.OnNotify:FireAll("Divine Event Has Started!", Color3.fromRGB(255, 175, 100))
    end

    self.Client.OnEventChanged:FireAll(self.CurrentEvent)
end

function EventService:EndEvent()

    local lightingFolder = EventLightingFolder:FindFirstChild("Default")
    if lightingFolder then
        local vfxFolder = workspace:FindFirstChild("EventVFX")
        if vfxFolder then vfxFolder:Destroy() end
        for _,x in lightingFolder:GetChildren() do
            local existing = Lighting:FindFirstChildWhichIsA(x.ClassName)
            if existing then existing:Destroy() end
            x:Clone().Parent = Lighting
        end
        Lighting.Brightness = 4
    end

    Knit.GetService("GameService").Client.OnNotify:FireAll("The Event Has Ended!")

    self.CurrentEvent = nil
    self.Client.OnEventChanged:FireAll(self.CurrentEvent)
end

function EventService:SetServerLuck(level, duration)
    if self.ServerLuck.CurrentLevel ~= level then
        self.ServerLuck = {
            CurrentLevel = level,
            Timestamp = os.time() + duration
        }
    else
        self.ServerLuck = {
            CurrentLevel = level,
            Timestamp = (self.ServerLuck.Timestamp or os.time())+duration
        }
    end

    self.Client.OnServerLuckChanged:FireAll(self.ServerLuck.CurrentLevel)
    Knit.GetService("GameService").Client.OnNotify:FireAll(`{self.ServerLuck.CurrentLevel}X Server Luck For {duration//60} Minutes!`, Color3.fromRGB(255, 215, 0))
end


function EventService.Client:GetServerLuck()
    return self.Server.ServerLuck
end

function EventService.Client:GetCurrentEvent()
    return self.Server.CurrentEvent
end

return EventService

