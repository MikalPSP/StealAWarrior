local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Component = require(ReplicatedStorage.Packages.Component)
local Signal = require(ReplicatedStorage.Packages.Signal)

local CharacterFolder = ServerStorage.GameAssets:FindFirstChild("Characters")
local PlotThemes = ServerStorage.GameAssets:FindFirstChild("PlotThemes")

local Utils = require(ReplicatedStorage.GameData).Utils

local SOUNDS = {
     DoorOpen = "rbxassetid://7309104360",
     DoorClose = "rbxassetid://9119630180"
}


local Plot = Component.new({
     Tag = "Plot",
     Ancestors = {workspace.Plots},
})




function Plot:Construct()

     self.CurrentOwner = nil
     self.Locked = true
     self.NextLockTime = 0
     self.NextUnlockTime = 0

     self.BackupModel = self.Instance:Clone()
     self.Gate = self.Instance:FindFirstChild("Gate")
     self.BannerColor = Color3.new(1,1,1)
     self.PlotSign = self.Instance:FindFirstChild("PlotSign",true)
     self.OnSlotCollected = Signal.new()
     self.OnZoneCollected = Signal.new()
     self.OnSlotsUpdated = Signal.new()
     self.CurrentTheme = "Normal"

     self.Connections = {}
     self.Slots = {}

end

function Plot:SetOwner(player, is_update)
     if self.CurrentOwner or not player or not player:IsA("Player") then return end
     self.CurrentOwner = player
     self.Instance:SetAttribute("OwnerId", player.UserId)

     local function onCharacterAdded(character)
          if not character then return end
          local existing = character:FindFirstChild("NOC")
          if existing then existing:Destroy() end
          local folder = Instance.new("Folder")
          folder.Name = "NOC"
          folder.Parent = character

          local function onDescendantAdded(desc)
               if desc:IsA("BasePart") then
                    local noc = Instance.new("NoCollisionConstraint")
                    noc.Part0 = desc
                    noc.Part1 = self.Gate.PrimaryPart
                    noc.Parent = folder
                    desc.CollisionGroup = "Players"
               end
          end

          --character:PivotTo(self.Gate:GetPivot()*CFrame.new(0,0,5))

          for _,x in character:GetDescendants() do onDescendantAdded(x) end
          if self.Connections.onCharacterDescendantAdded then
               self.Connections.onCharacterDescendantAdded:Disconnect()
               self.Connections.onCharacterDescendantAdded = nil
          end
          self.Connections.onCharacterDescendantAdded = character.DescendantAdded:Connect(onDescendantAdded)
     end

     self.Connections.onCharacterAdded = player.CharacterAdded:Connect(onCharacterAdded)
     if not is_update then
          onCharacterAdded(player.Character)
     end

     local spawnLocation = self.Instance:FindFirstChildWhichIsA("SpawnLocation")
     if spawnLocation and not is_update then
          spawnLocation.Enabled = true
          player.RespawnLocation = spawnLocation

          if player.Character then
               player.Character:PivotTo(spawnLocation:GetPivot()*CFrame.new(0,2,0))
          end
     end

     self.PlotSign.OwnerLabel.Text = string.format("%s's Castle",player.DisplayName)
     if is_update then
          self:UnlockGate()
     else
          self:LockGate()
     end
end

function Plot:SetBannerColor(color: Color3)
      if typeof(color)~="Color3" then return end
     local banners =  self.Instance:FindFirstChild("Banners",true)
     if banners then
          for _,banner in banners:GetDescendants() do
               if banner:IsA("BasePart") and banner.Name == "Flag" then
                    banner.Color = color
               end
          end
     end
     self.BannerColor = color
end

function Plot:ApplyModel(style)
     local themeFolder = PlotThemes:FindFirstChild(style)
     local plotTemplate, is_custom = themeFolder and themeFolder:FindFirstChild("Plot") or nil, true
     if not plotTemplate then
          plotTemplate = ServerStorage.GameAssets:FindFirstChild("Plot")
          is_custom = false
     end

     print(plotTemplate, style)
     if plotTemplate then
          local newPlot = plotTemplate:Clone()
          newPlot:SetAttribute("Index", self.Instance:GetAttribute("Index"))
          newPlot:PivotTo(self.Instance:GetPivot())
          newPlot.Parent = workspace.Plots

          self.Instance:Destroy()
          local owner = self.CurrentOwner

          Plot:WaitForInstance(newPlot):andThen(function(comp)
               comp.IsCustomModel = is_custom

               if is_custom then
                    comp.CurrentTheme = style
               else
                    comp:SetBaseTheme(style)
               end

               local profileService = Knit.GetService("ProfileService")
               local data = profileService:GetData(owner)

               comp:SetOwner(owner, true)
               comp:SetFloors(math.ceil(#data.Inventory.Characters/8)-1)
               comp:LoadCharacters(data.Inventory.Characters)
               comp:SetBannerColor(data.Settings["Banner Color"] and Color3.fromHex(data.Settings["Banner Color"]) or Color3.new(1,1,1))

               comp.OnSlotCollected:Connect(function(slotIdx, amount, offlineAmount)

                    profileService:Dispatch(owner,{
                         type = "ADD_COINS", payload = amount + offlineAmount, 
                         logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
                    })

                    profileService:Dispatch(owner, { type = "UPDATE_PROFIT", payload = {
                         slot = slotIdx,
                         amount = -1*math.abs(amount),
                         offlineAmount = -1*math.abs(offlineAmount)
                    }})
               end)
          end)
          -- for _,x in plotTemplate:GetChildren() do
          --      local existing = x:FindFirstChild(x.Name)
          --      if x:IsA("Model") then
          --           local newModel = existing:Clone()
          --           newModel:PivotTo(x:GetPivot())
          --           newModel.Parent = x.Parent

          --      if existing then
                    
          --      end
          -- end
     end
end

function Plot:SetBaseTheme(themeName: string)
     local color = ({
          ["Normal"] = Color3.fromRGB(139, 137, 140),
          ["Gold"] = Color3.fromRGB(239, 184, 56),
          ["Diamond"] = Color3.fromRGB(18, 238, 212),
     })[themeName]

     if themeName == "Volcanic" then
          self:ApplyModel(themeName)
     else
          if self.IsCustomModel then
               self:ApplyModel(themeName)
               return
          end

          if themeName == "Rainbow" and self.CurrentTheme ~= "Rainbow" then
               task.spawn(function()
                    self.CurrentTheme = themeName
                    while self.CurrentTheme == "Rainbow" do
                         for hue=0,1,(1/12) do
                              local tweens = {}
                              for _,part in self.Instance:GetDescendants() do
                                   if part:IsA("BasePart") and part.Name == "ColorPart" then
                                        local tween = TweenService:Create(part,TweenInfo.new(1),{Color = Color3.fromHSV(hue,1,1)})
                                        table.insert(tweens,tween)
                                        tween:Play()
                                   end
                              end
                              self.ActiveRainbowTweens = tweens
                              task.wait(1)
                         end
                    end
               end)
          elseif color then
               self.CurrentTheme = themeName
               if self.ActiveRainbowTweens then
                    for _,tween in self.ActiveRainbowTweens do tween:Cancel() end
                    self.ActiveRainbowTweens = nil
               end

               for _,part in self.Instance:GetDescendants() do
                    if part:IsA("BasePart") then
                         if part.Name == "ColorPart" then part.Color = color
                         elseif part.Name == "ColorPart2" then
                              if themeName == "Normal" then part.Color = Color3.fromRGB(98, 97, 99)
                              else part.Color = color end
                         end
                    end
               end
          
          end
     end
end

function Plot:SetFloors(numFloors)

     local hasFloors = numFloors>0
     for _,x in ipairs(self.Instance:GetChildren()) do
          if x:IsA("Model") and x.Name == "Roof" then
               for _,z in x:GetDescendants() do
                    if z:IsA("BasePart") then
                         z.CanCollide, z.Transparency = not hasFloors, hasFloors and 1 or 0
                         for _,v in z:GetDescendants() do
                              if v:IsA("Texture") then v.Texture = z.Transparency end
                         end
                    end
               end
          elseif x:IsA("Model") and x.Name:match("PlotUpgrade")~=nil then x:Destroy()
          elseif x:IsA("Folder") and x.Name == "Slots" then
               for _,z in ipairs(x:GetChildren()) do
                    local num = tonumber(z.Name:match("%d+"))
                    if num and num>8 then z:Destroy() end
               end
          end
     end

     if hasFloors then 
          local floorTemplate = ServerStorage.GameAssets:FindFirstChild("PlotUpgrade")
          if self.IsCustomModel then
               local themeFolder = PlotThemes:FindFirstChild(self.CurrentTheme)
               local plotTemplate = themeFolder and themeFolder:FindFirstChild("PlotUpgrade")
               if plotTemplate then
                    floorTemplate = plotTemplate
               else
                    warn(`Failed to find PlotUpgrade for {self.CurrentTheme}`)
               end
          end

          for idx=1,numFloors do
               local prevFloor = self.Instance:FindFirstChild("PlotUpgrade_"..(idx-1)) or self.Instance
               local newFloor = floorTemplate:Clone()
               newFloor.Name = string.format("PlotUpgrade_%d",idx)
               newFloor:PivotTo(prevFloor.Roof:GetPivot())

               if idx~=numFloors and newFloor:FindFirstChild("Banners") then
                    newFloor.Banners:Destroy()
               end

               for _,x in newFloor.Slots:GetChildren() do
                    if x:IsA("Model") and x.Name:find("^Slot") then
                         x.Name = x.Name:gsub("%d+",function(i) return i+(idx*8) end)
                         x.Parent = self.Instance:FindFirstChild("Slots")
                    end
               end

               newFloor.Parent = self.Instance
               if prevFloor ~= self.Instance then prevFloor.Roof:Destroy() end
          end
          self:SetBannerColor(self.BannerColor or Color3.new(1,1,1))
          if not self.IsCustomModel then
               self:SetBaseTheme(self.CurrentTheme or "Normal")
          end
     end
     self.NumFloors = numFloors
end


function Plot:LoadCharacters(characters: {Name: string})
     for i,slot in self.Slots do
          local charData = characters[i]
          if charData ~= "Empty" and typeof(charData)=="table" and typeof(charData.Name)=="string"  then
               local modelTemplate = CharacterFolder:FindFirstChild(charData.Name):Clone()
               if modelTemplate and not (slot.CurrentModel and slot.CurrentModel.Name == modelTemplate.Name) then
                    slot:AttachCharacter(modelTemplate, charData.Mutation)
               end
               slot.IsStealable = not charData.Permanent
               slot:SetAmount(charData.Reward, charData.OfflineReward)
               if slot.CurrentModel then
                    slot.CurrentModel:SetAttribute("Tier",charData.Tier)
                    slot.CurrentModel:SetAttribute("IsStealable",not charData.Permanent)
                    slot.CurrentModel:SetAttribute("IsLuckyWarrior",charData.IsLuckyWarrior or nil)
               end
          else
               slot:AttachCharacter(nil)
               slot:SetAmount(0,0)
               slot.IsStealable = false
          end
     end
end

function Plot:GetSlotForInstance(instance)
     for i,slot in self.Slots do
          if slot.Instance == instance then
               return slot, i
          end
     end
end

function Plot:GetCharacters()
     return Sift.Array.map(self.Slots,function(slot)
          if slot.CurrentModel then
               return Sift.Dictionary.merge(slot.CurrentModel:GetAttributes(),{
                    Instance = slot.CurrentModel,
                    Name = slot.CurrentModel,
               })
          end
          return "Empty"
     end)
end

function Plot:Reset()
     local plotTemplate = ServerStorage.GameAssets:FindFirstChild("Plot")
     if plotTemplate then
          local newPlot = plotTemplate:Clone()
          newPlot:SetAttribute("Index", self.Instance:GetAttribute("Index"))
          newPlot:PivotTo(self.Instance:GetPivot())
          newPlot.Parent = workspace.Plots

          self.Instance:Destroy()
     end
end

function Plot:IsOwner(player)
     if player and player:IsA("Player") then
          return self.CurrentOwner and self.CurrentOwner == player
     end
end


function Plot:UpdateSlots()

end

function Plot:Start()

     local slotConnections = {}
     local function updateSlots()
          self.Slots = Sift.Array.sort(Sift.Array.map(self.Instance.Slots:GetChildren(),function(v)
               if v:IsA("Model") and v:HasTag("CharacterSlot") then
                    local ok, ret = Knit.Components.CharacterSlot:WaitForInstance(v):await(5)
                    return ok and ret
               end
          end),function(a,b)
               local function toNum(x) return tonumber(x.Instance.Name:match("%d+$")) end
               return toNum(a)<toNum(b)
          end)

          for _,conn in slotConnections do conn:Disconnect() end
          for i,slot in ipairs(self.Slots) do
               table.insert(slotConnections,slot.OnCollected:Connect(function(amount, offlineAmount)
                    self.OnSlotCollected:Fire(i,amount,offlineAmount)
               end))
          end
     end

     self.Connections.onDescendantAdded = self.Instance.DescendantAdded:Connect(function(child)
          if child:HasTag("CharacterSlot") then updateSlots() end
     end)
     self.Connections.onDescendandRemoved = self.Instance.DescendantRemoving:Connect(function(child)
          if child:HasTag("CharacterSlot") then updateSlots() end
     end)
     updateSlots()

     self.GateButton = Knit.Components.TouchButton:FromInstance(self.Instance:FindFirstChild("Gate Button"))
     if self.GateButton then
          self.GateButton:UpdateUI("TimerLabel",{ Text = "", Visible = false})
          self.GateButton:UpdateUI("MainText", { Text = "LOCK" })

          self.GateButton.Triggered:Connect(function(plr)
               if self:IsOwner(plr) and not self.Locked and tick()>self.NextLockTime then
                    local lockTime = Knit.GetService("ProfileService"):GetStatistics(plr,"LockTime")
                    local is_vip = Knit.GetService("EconomyService"):PlayerHasPass(plr,"VIP")
                    if is_vip then lockTime+=10 end

                    self:LockGate(lockTime)
               end
          end)
     else warn("Failed to find GateButton <TouchButton Component>") end

     self.CollectZone = Knit.Components.TouchButton:FromInstance(self.Instance:FindFirstChild("CollectZone"))
     if self.CollectZone then
          self.CollectZone:Disable()
          self.CollectZone:UpdateUI("MainText",{ Text = "COINS MULTI:\nx1"})
          self.CollectZone.Triggered:Connect(function(plr)
               if self:IsOwner(plr) then self.OnZoneCollected:Fire() end
          end)
     end

     self:UnlockGate()
end

function Plot:LockGate(duration)
     duration = tonumber(duration) or 60

     self.Locked = true
     self.Instance:SetAttribute("Locked",self.Locked)
     self.NextLockTime = tick() + duration

     for _,x in self.Gate:GetDescendants() do
          if x == self.Gate.PrimaryPart then x.CanCollide = true
          elseif x:IsA("BasePart") then x.Transparency = 0
          end
     end

     local sound = Instance.new("Sound")
     sound.Name = "DoorSFX"
     sound.SoundId = SOUNDS.DoorClose
     sound.Parent = self.Gate.PrimaryPart
     sound:Play()
     task.delay(5,function() sound:Destroy() end)

     self.GateButton:UpdateUI("TimerLabel",{ Visible = true, Text = Utils.formatTime(duration) })
     self.GateButton:UpdateUI("MainText",{ Text = "LOCKED" })

     Knit.GetService("GameService"):SendNotification(self.CurrentOwner,`Gate locked for {duration} seconds!`,"Default")
end

function Plot:UnlockGate(duration: number?)
     self.GateButton:UpdateUI("TimerLabel",{ Visible = false})
     self.GateButton:UpdateUI("MainText",{ Text = "LOCK" })

     self.Locked = false
     self.Instance:SetAttribute("Locked",self.Locked)

     for _,x in self.Gate:GetDescendants() do
          if x == self.Gate.PrimaryPart then x.CanCollide = false
          elseif x:IsA("BasePart") then x.Transparency = 1
          end
     end

     local sound = Instance.new("Sound")
     sound.Name = "DoorSFX"
     sound.SoundId = SOUNDS.DoorOpen
     sound.Parent = self.Gate.PrimaryPart
     sound:Play()
     task.delay(5,function() sound:Destroy() end)

     if typeof(duration)=="number" and duration>0 then
          --local timeLeft = (self.NextLockTime - tick())
          self.NextLockTime = tick() + duration
     end
     if self.CurrentOwner then
          if typeof(duration)=="number" and duration>0 then
               Knit.GetService("GameService"):SendNotification(self.CurrentOwner,`Gate unlocked for {duration} seconds!`,"Warning")
          else
               Knit.GetService("GameService"):SendNotification(self.CurrentOwner,"Your gate is unlocking!","Warning")
          end
     end
end

function Plot:SteppedUpdate(dt)
     if not self.CurrentOwner then return end
     local now = tick()

     if not self.lastUpdateTime or (now-self.lastUpdateTime)>=1 then
          self.lastUpdateTime = now
          if self.Locked then
               local timeLeft = self.NextLockTime - now
               if timeLeft > 0 then
                    self.GateButton:UpdateUI("TimerLabel",{ Visible = true, Text = Utils.formatTime(timeLeft) })
               else
                    self:UnlockGate()
               end
          end
     end
end

function Plot:Stop()
     for _,conn in self.Connections do
          conn:Disconnect()
     end
     self.Connections = {}
end


return Plot
