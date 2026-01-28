local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local ServerStorage = game:GetService("ServerStorage")
local GroupService = game:GetService("GroupService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ConfigService = game:GetService("ConfigService")


local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)


local GameData = require(ReplicatedStorage.GameData)

local RarityColors = require(ReplicatedStorage.UI.Theme).Rarity

local localRandom = Random.new(tick())

local GameService = Knit.CreateService({
    Name = "GameService",
    Client = {
        StolenCharacter = Knit.CreateProperty(),
        MovingCharacter = Knit.CreateProperty(),
        Plot = Knit.CreateProperty({}),
        PendingCharacters = Knit.CreateProperty(0),
        PendingGateUnlock = Knit.CreateProperty(nil),
        OnNotify = Knit.CreateSignal(),
        IncomeRate = Knit.CreateProperty(0),
        FriendBoost = Knit.CreateProperty(0),

        GameVotes = Knit.CreateProperty()
    },

    Settings = {

        SpawnPosition = CFrame.new(-303,10,8),
        SpawnInterval = 4,
        SpawnLifetime = 120,
        RarityWeights = {
            Common = 135,
            Rare = 70,
            Epic = 20,
            Legendary = 2.5,
            Mythic = 1,
            Secret = .25,
            OG = .1
        },
        MutationWeights = { Base = 85, Gold = 25, Diamond = 10, Rainbow = 1 },

        GuaranteeTimes = { Legendary = 600, Mythic = 1800 },
        OfflineProfitFactor = 0.1,
    },
    Characters = {},
    GameVotes = {}

})



function GameService:KnitStart()

    self.Plots = Knit.Components.Plot:GetAll()

    for _,x in ServerStorage.GameAssets.LuckyWarriors:GetChildren() do
        if x:IsA("Model") then x.Parent = ServerStorage.GameAssets.Characters end
    end
    ServerStorage.GameAssets.LuckyWarriors:Destroy()

    self.Characters = Sift.Dictionary.map(GameData.CharacterData,function(charData,name)
        local instance = ServerStorage.GameAssets.Characters:FindFirstChild(name)
        if not instance then
            instance = ServerStorage.GameAssets.CharacterTemplate:Clone()
            instance.Name = name
            instance.Parent = ServerStorage.GameAssets.Characters
            warn("No character instance found for",name)
        elseif instance.PrimaryPart then
            instance.PrimaryPart.Anchored = true
        end

        for k,v in charData do instance:SetAttribute(k,v) end

        self:BuildViewportItem(instance)
        return Sift.Dictionary.merge(charData,{
            Name = instance.Name,
            Instance = instance
        }), instance.Name
    end)

    local function updateLeaderStats(player, data)
        local folder = player:FindFirstChild("leaderstats")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "leaderstats"
            folder.Parent = player
        end

        for _,name in ipairs({"Coins","Steals","Rebirths"}) do
            local stat = folder:FindFirstChild(name)
            if not stat then
                if name == "Coins" then
                    stat = Instance.new("StringValue")
                else
                    stat = Instance.new("IntValue")
                end

                stat.Name = name
                stat.Parent = folder
            end

            local newValue = data[name] or 0
            if stat:IsA("StringValue") then
                newValue = GameData.Utils.formatNumber(newValue)
            end
            if stat.Value ~= newValue then
                stat.Value = newValue
            end
        end
    end

    local profileService = Knit.GetService("ProfileService")
    local economyService = Knit.GetService("EconomyService")


    Players.PlayerAdded:Connect(function(player)
        local newPlot = self:GetAvailablePlot()
        if newPlot then
            newPlot:SetOwner(player)
        else 
            warn("No available plots for player:",player.Name)
        end
    end)

    profileService.PlayerDataLoaded:Connect(function(player, data)
        local newPlot = self:GetPlotForPlayer(player)
        repeat task.wait(1) newPlot = self:GetPlotForPlayer(player) until newPlot

        local isVIP, isDouble = economyService:PlayerHasPass(player,"VIP"), economyService:PlayerHasPass(player,"2X Coins")
        local isGroup = player:IsInGroup(6124305)
        local multiplier = data.Statistics.IncomeMultiplier or 1
        if isVIP then multiplier+=.5 end
        if isDouble then multiplier+=2 end
        if isGroup then multiplier+=.5 end
        if newPlot then
            local inventoryData = data.Inventory
            local lastLoginTime = profileService:GetProfile(player):GetMetaTag("LastOnlineTime")
            local offlineTime = typeof(lastLoginTime)=="number" and math.floor(os.time() - lastLoginTime) or 0
            if offlineTime > 0 then

                offlineTime = math.min(offlineTime, 3*86400) --3 Day Maximum Offline Time
                local tierUpgrades = inventoryData.Tiers
                local totalOffline = 0
                for i,chr in inventoryData.Characters do
                    if chr and chr ~= "Empty" then
                        if chr.IsStolen then
                            profileService:Dispatch(player,{
                                type = "REMOVE_CHARACTER",
                                payload = { slot = i }
                            })
                        else
                            local chrData = self.Characters[chr.Name]
                            if not chrData then continue end
                            local baseProfit = GameData.calculateProfit(chrData.Profit, chr.Tier, tierUpgrades and tierUpgrades[i].Level or 1, chrData.Mutation)
                            local profit = math.floor(self.Settings.OfflineProfitFactor * (offlineTime * baseProfit * multiplier))
                            profileService:Dispatch(player,{ type = "UPDATE_PROFIT", payload = {
                                slot = i,
                                offlineAmount = profit
                            }})

                            totalOffline += profit
                        end
                    end
                end
            end

            newPlot:SetOwner(player)
            newPlot:SetFloors(math.ceil(#data.Inventory.Characters/8)-1)
            newPlot:LoadCharacters(data.Inventory.Characters)
            newPlot:SetBannerColor(data.Settings["Banner Color"] and Color3.fromHex(data.Settings["Banner Color"]) or Color3.new(1,1,1))
            newPlot:SetBaseTheme(data.Settings["Base Theme"] or "Normal")

            newPlot.CollectZone:UpdateUI("MainText",{ Text = string.format("COINS MULTI:\nx%.1f",multiplier) })
            newPlot.OnSlotCollected:Connect(function(slotIdx, amount, offlineAmount)

                profileService:Dispatch(player,{
                    type = "ADD_COINS", payload = amount + offlineAmount, 
                    logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
                })

                profileService:Dispatch(player, { type = "UPDATE_PROFIT", payload = {
                    slot = slotIdx,
                    amount = -1*math.abs(amount),
                    offlineAmount = -1*math.abs(offlineAmount)
                }})
            end)
        end


        local autoBuyItems = data.Status.AutoBuyItems
        if next(autoBuyItems)~=nil then
            for n,_ in autoBuyItems do self.Client:BuyTool(player, n) end
        end

        updateLeaderStats(player,{
            Coins = data.Inventory.Coins, Rebirths = data.Statistics.Rebirths,
            Steals = data.Statistics.Steals
        })
    end)

    profileService.PlayerDataChanged:Connect(function(player, state, lastState)
        if typeof(state)~="table" or typeof(lastState)~="table" then return end

        local plot = self:GetPlotForPlayer(player)
        if plot then
            local characters = state.Inventory.Characters
            if characters ~= lastState.Inventory.Characters then
                plot:LoadCharacters(characters)
            end

            if #characters ~= #lastState.Inventory.Characters then
                local floors = math.ceil(#characters/8)-1
                plot:SetFloors(floors)
            end

            local multiplier = state.Statistics.IncomeMultiplier or 1
            if multiplier ~= lastState.Statistics.IncomeMultiplier then
                local isVIP, isDouble = economyService:PlayerHasPass(player,"VIP"), economyService:PlayerHasPass(player,"2X Coins")
                local isGroup = player:IsInGroup(6124305)
                if isVIP then multiplier+=.5 end
                if isDouble then multiplier+=2 end
                if isGroup then multiplier+=.5 end
                plot.CollectZone:UpdateUI("MainText",{ Text = string.format("COINS MULTI:\nx%.1f",multiplier) })
            end

            for i,slot in ipairs(plot.Slots) do
                local chr = characters[i]
                if chr and chr ~= "Empty" and typeof(chr.Tier)=="number" and slot.CurrentModel then
                    local hasDupes = Sift.Array.count(characters,function(v,idx)
                        return v.Name == chr.Name and v.Tier == chr.Tier and v.Mutation == chr.Mutation
                    end)>=2

                    slot:SetStolen(chr.IsStolen)
                    slot.CurrentModel:SetAttribute("CanMerge", hasDupes and chr.Tier<5)

                    if slot.CurrentAmount ~= chr.Reward or slot.OfflineAmount ~= chr.OfflineReward then
                        slot:SetAmount(chr.Reward, chr.OfflineReward)
                    end
                end
            end

            if state.Settings["Banner Color"] ~= lastState.Settings["Banner Color"] then
                plot:SetBannerColor(state.Settings["Banner Color"] and Color3.fromHex(state.Settings["Banner Color"]) or Color3.new(1,1,1))
            end

            if state.Settings["Base Theme"] ~= lastState.Settings["Base Theme"] then
                plot:SetBaseTheme(state.Settings["Base Theme"])
            end

        end

        -- local autoBuyItems = Sift.Set.difference(state.Status.AutoBuyItems,lastState.Status.AutoBuyItems)
        -- if next(autoBuyItems)~=nil then
        --     for n,_ in autoBuyItems do self.Client:BuyTool(player, n) end
        -- end

        if state.Inventory ~= lastState.Inventory or state.Statistics ~= lastState.Statistics then
            updateLeaderStats(player,{
                Coins = state.Inventory.Coins, Rebirths = state.Statistics.Rebirths,
                Steals = state.Statistics.Steals
            })

            local collected = state.Inventory.Collection or {}
            local totalCharacters = Sift.Dictionary.count(GameData.CharacterData)
            local mutationOwned = Sift.Dictionary.map(Sift.Array.concat(Sift.Dictionary.keys(GameData.Mutations),{"Normal"}),function(mutation)
                return Sift.Dictionary.count(collected,function(chr)
                    if mutation == "Normal" then
                        return chr.Base ~= nil
                    end
                    return chr[mutation] ~= nil
                end),mutation
            end)

            for name,amount in mutationOwned do
                local ratio = (amount / totalCharacters)
                local hasReward = state.Inventory.IndexRewards and state.Inventory.IndexRewards[name]
                if ratio >= .75 and not hasReward then
                    self:SendNotification(player, `Congratulations! You have collected all {name} characters!`)
                    profileService:Dispatch(player,{
                        type = "ADD_INDEX_REWARD",
                        payload = name
                    })
                    profileService:Dispatch(player,{
                        type = "ADD_MULTIPLIER",
                        payload = 0.5
                    })
                end
            end



        end
    end)


    economyService.OnProductGranted:Connect(function(player, productId)
        local product = economyService.Products[productId]
        if product and product.ProductType == "LuckyWarrior" then
            local charData = self.Characters[product.Name]
            if charData then
                self:GiveCharacter(player, charData, true)
                self:SendNotification(player, `You have received a {charData.Name}!`, Color3.fromRGB(255,215,0))
            end
        elseif product and product.Name == "Unlock Gate" then
            local pendingGateUnlock = self.Client.PendingGateUnlock:GetFor(player)
            if pendingGateUnlock then
                self.Client.PendingGateUnlock:SetFor(player, nil)
                local plot = self:GetPlotForPlayer(pendingGateUnlock)
                if plot then
                    local numFloors = plot.NumFloors or 0
                    plot:UnlockGate(15+(10*numFloors))
                end
            end

            -- if not didUnlock then
            --     self:SendNotification(player, "Failed to unlock gate. You have been compensated $5,000", "Warning")
            --     profileService:Dispatch(player,{
            --         type = "ADD_COINS",
            --         payload = 5000,
            --         logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
            --     })
            -- end
        end
    end)

    --game.StarterPlayer.CharacterWalkSpeed = 50

    Players.PlayerRemoving:Connect(function(plr)
        for _,p in self.Plots do
            if p:IsOwner(plr) then p:Reset() end
        end
    end)

    --Handle Character Spawning
    task.spawn(function()

        local checkNewPlayers = setmetatable({},{
            __call = function(self,interval)
                local now = tick()            
                local num_players = Sift.Array.count(Players:GetPlayers(),function(p)
                    local inventoryData = profileService:GetInventory(p)
                    if inventoryData then
                        local empty_characters = Sift.Array.every(inventoryData.Characters,function(c)
                            return c == "Empty"
                        end)
                        return empty_characters and inventoryData.Coins<=25
                    end
                end)

                if num_players>0 then
                    interval = math.max(1,interval or 10)//(num_players/#Players:GetPlayers())
                    if not self.lastCheckTime or (now-self.lastCheckTime) >= interval then
                        self.lastCheckTime = now
                        return true
                    end
                end
            end
        })

    
        local timestamps = {}
        local signUI = workspace.Map.StartGate:FindFirstChild("SignUI")

        while true do
            task.wait(1)

            local now = tick()
            local charName, mutation, guarantee
            local canSpawn = now - (timestamps.Default or 0) >= self.Settings.SpawnInterval

            if self.GameVotes.GoalReached and not self.GameVotes.DidSpawn then
                if canSpawn and game.PrivateServerOwnerId == 0 then
                    guarantee = "Secret"
                    self.GameVotes.DidSpawn = true
                    --TODO: Maybe Automate To New Like Goal
                end
            end

            for rarity, duration in self.Settings.GuaranteeTimes do
                if not timestamps[rarity] then timestamps[rarity] = now end
                local timeLeft = math.max(0,duration - math.max(0,now-timestamps[rarity]))
                local textLabel = signUI:FindFirstChild(rarity.."Text")
                if textLabel then
                    textLabel.Text = textLabel.Text:gsub("[%d:]+$",GameData.Utils.formatTime(timeLeft))
                end

                if canSpawn and timeLeft<=0 and not guarantee then
                    guarantee = rarity
                    timestamps[rarity] = now
                end
            end

            if canSpawn then
                charName, mutation = self:GetRandomCharacter(guarantee)
                timestamps.Default = now

                if not guarantee and checkNewPlayers(10) then
                    self:SpawnCharacter("Caveman Warrior","Base")
                else
                    self:SpawnCharacter(charName, mutation)
                end
            end
        end
    end)

    --Handle Income
    task.spawn(function()
        while true do
            task.wait(1)

            for _,plr in Players:GetPlayers() do
                local plot = self:GetPlotForPlayer(plr)
                local inventoryData = profileService:GetInventory(plr)
                if inventoryData then
                    local tierUpgrades = inventoryData.Tiers
                    local friendBoost = Sift.Array.count(Players:GetPlayers(),function(other) return other~=plr and other:IsFriendsWith(plr.UserId) end)*.1
                    self.Client.FriendBoost:SetFor(plr,friendBoost)

                    local isVIP, isDouble = economyService:PlayerHasPass(plr,"VIP"), economyService:PlayerHasPass(plr,"2X Coins")
                    local isGroup = (plr and plr.Parent~=nil) and plr:IsInGroup(6124305) or false
                    local totalProfit = 0
                    for i,chr in ipairs(inventoryData.Characters) do
                        if chr and chr ~= "Empty" and not chr.IsStolen and self.Characters[chr.Name]  then
                            local baseProfit = GameData.calculateProfit(self.Characters[chr.Name].Profit, chr.Tier, tierUpgrades and tierUpgrades[i].Level or 1, chr.Mutation)
                            local multiplier = profileService:GetStatistics(plr,"IncomeMultiplier") or 1
                            if isVIP then multiplier+=.5 end
                            if isDouble then multiplier+=2 end
                            if isGroup then multiplier+=.5 end

                            local profit = math.floor(baseProfit  * multiplier) -- * math.max(1,1+friendBoost))

                            local curModel = (plot and plot.Slots[i]) and plot.Slots[i].CurrentModel or nil
                            if curModel then curModel:SetAttribute("Profit", profit) end
                            profileService:Dispatch(plr,{ type = "UPDATE_PROFIT", payload = {
                                slot = i,
                                amount = math.floor(profit * math.max(1,1+friendBoost))
                            }})

                            totalProfit+=profit
                        end
                    end

                    profileService:Dispatch(plr, { type = "SET_INCOME_RATE", payload = totalProfit })
                    self.Client.IncomeRate:SetFor(plr,totalProfit)
                end

                local spinTime = profileService:GetStatus(plr,"NextSpinTime")
                if spinTime and os.time() >= spinTime then
                    profileService:Dispatch(plr,{ type = "CLAIM_SPIN" })
                    if spinTime>0 then self:SendNotification(plr, "You have received a free spin!") end
                end
            end
        end
    end)

    -- Handle Game Info Updates
    task.spawn(function()
        local config = ConfigService:GetConfigAsync()
        config.UpdateAvailable:Connect(function() config:Refresh() end)

        while true do
            local votes = self:GetGameVotes()
            local curGoal = math.max(1000,config:GetValue("current_like_goal"))
            if votes then
                if not self.GameVotes.GoalReached and typeof(self.GameVotes.Likes)=="number" and self.GameVotes.Likes < curGoal and votes.Likes >= curGoal then
                    self.Client.OnNotify:FireAll(`{GameData.Utils.formatNumber(curGoal)} Likes Reached!`,Color3.fromRGB(0,255,0))
                    self.GameVotes.GoalReached = true
                end

                self.GameVotes.Likes = votes.Likes
                self.Client.GameVotes:Set(Sift.Dictionary.merge(self.GameVotes,{Goal = curGoal}))
            end
            task.wait(RunService:IsStudio() and 1 or 60)
        end
    end)

end

function GameService:GetGameVotes()

    if RunService:IsStudio() then
        local likes = ServerStorage:GetAttribute("Likes")
        if not likes then likes = 0 ServerStorage:SetAttribute("Likes",likes) end
        return { Likes = likes, Dislikes = 0 }
    end

    local ok, data = pcall(function()
        local ret = HttpService:GetAsync("https://games.rotunnel.com/v1/games/votes?universeIds=8662373722")
        return HttpService:JSONDecode(ret).data[1]
    end)

    if ok and data then
        return { Likes = data.upVotes, Dislikes = data.downVotes }
    else warn("Failed to fetch game votes") end
end

function GameService:BuildViewportItem(instance)
	local viewportItems = ReplicatedStorage.UI:FindFirstChild("ViewportItems")
	if not viewportItems or not instance or viewportItems:FindFirstChild(instance.Name) then
		return
	end

	local template = nil
	if instance:IsA("Tool") then
		local model = nil
		do
			for _, x in ipairs(instance:GetChildren()) do
				if x:IsA("Model") and (x:FindFirstChildWhichIsA("Attachment", true) or x.Name:find("Weapon")) then
					model = x break
				end
			end
			if not model then
				model = instance:FindFirstChildWhichIsA("Model")
			end
		end
		if not model then
			local handle = instance:FindFirstChild("Handle")
			if handle then
				model = Instance.new("Model")

				local p = handle:Clone()
				p.Parent = model
				model.PrimaryPart = p
            else return end
		end

		template = model:Clone()
		template.Name = instance.Name
	elseif instance:IsA("Model") then
		template = instance:Clone()
        if template.PrimaryPart then
            template.PrimaryPart.Anchored = true
        end
	end

	if template and template:IsA("Model") then
		local base = template.PrimaryPart
		for _, x in ipairs(template:GetDescendants()) do
			if x:IsA("BasePart") then
				if not base then base = x end
				if x ~= base then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = base
					weld.Part1 = x
					weld.Parent = x
				end
                x.Anchored = true
			elseif x:IsA("Script") then
				x:Destroy()
			end
		end

		template.Parent = viewportItems
		return template
	end
end

function GameService:GiveTool(player, toolName)
    if not player or not player:IsA("Player") then return end
    local toolTemplate = ServerStorage.GameAssets.Tools:FindFirstChild(toolName)
    if toolTemplate then
        for _,container in ({player.Backpack, player.StarterGear}) do
            if container:FindFirstChild(toolName) then continue end
            local tool = toolTemplate:Clone()
            tool.CanBeDropped = false
            tool.Parent = container
        end
    end
end

function GameService:GetRandomCharacter(rarity)

    local serverLuck = math.max(1, Knit.GetService("EventService").ServerLuck.CurrentLevel or 0)

    local mutationData = self.Settings.MutationWeights
    local data = Sift.Dictionary.map(self.Characters,function(v)
        if typeof(rarity)=="string" and v.Rarity ~= rarity or v.Type == "LuckyWarrior" then return end

        local weight = self.Settings.RarityWeights[v.Rarity] or 0
        if typeof(v.WeightFactor)=="number" then
            weight = weight*v.WeightFactor
        end

        if serverLuck > 1 then
            --[[
            if v.Rarity == "Epic" then
                weight = weight * (serverLuck*1.50)
            elseif v.Rarity == "Legendary" then
                weight = weight * (serverLuck*1.00)
            elseif v.Rarity == "Mythic" then
                weight = weight * (serverLuck*0.50)
            end
            --]]
            weight =  weight ^ (1/(serverLuck))
        end
        return weight
    end)

    local currentEvent = Knit.GetService("EventService").CurrentEvent
    if currentEvent then
        local mutationType = currentEvent.MutationType
        mutationData = Sift.Dictionary.merge(mutationData, {
            [mutationType] = 70,
            --[mutationType] = mutationData.Base//2,
        })
    end

    local charName = GameData.Utils.weightedChoice(Sift.Dictionary.keys(data),Sift.Dictionary.values(data), localRandom)
    local mutation = GameData.Utils.weightedChoice(Sift.Dictionary.keys(mutationData),Sift.Dictionary.values(mutationData), localRandom)

    return charName, mutation or "Base"
end

function GameService:GetAvailablePlot()
    local sortedPlots = Sift.Array.sort(self.Plots,function(a,b)
        return a.Instance:GetAttribute("Index") < b.Instance:GetAttribute("Index")
    end)

    for _,plot in ipairs(sortedPlots) do
        if not plot.CurrentOwner then return plot end
    end
end

function GameService:GetSpawnedCharacters()
    return Sift.Array.map(workspace.SpawnedCharacters:GetChildren(),function(c)
        if c:IsA("Model") and c:HasTag("Character") then
            return Sift.Dictionary.merge(self.Characters[c.Name],{
                Mutation = c:GetAttribute("Mutation") or "Base",
                Instance = Sift.None
            })
        end
    end)
end

function GameService:SpawnCharacter(name, mutation)
    local charData = self.Characters[name] and Sift.Dictionary.copyDeep(self.Characters[name]) or nil
    if charData and charData.Instance then
        if charData.Rarity == "OG" or charData.Type == "LuckyWarrior" then
            self.Client.OnNotify:FireAll(`{charData.Name} Spawned!`,"Rainbow")
        elseif table.find({"Epic","Legendary","Mythic","Secret"},charData.Rarity) then
            self.Client.OnNotify:FireAll(`{charData.Rarity} Spawned!`,RarityColors[charData.Rarity])
        end
        local profileService = Knit.GetService("ProfileService")
        local charModel = charData.Instance:Clone()
        local charHumanoid = charModel:FindFirstChild("Humanoid")
        local didHit, didClaim = false, false

        local hasMutationVariant
        if typeof(mutation)=="string" and mutation ~= "Base" then
            local variantFolder = ServerStorage.GameAssets.MutationVariants:FindFirstChild(mutation)
            if variantFolder and variantFolder:FindFirstChild(charModel.Name) then
                local mutatedModel = variantFolder[charModel.Name]:Clone()
                for k,v in charData do if typeof(v)~="Instance" then mutatedModel:SetAttribute(k,v) end end
                charModel = mutatedModel
                charHumanoid = charModel:FindFirstChild("Humanoid")
                hasMutationVariant = true
            end
        end



        for _,x in charModel:GetDescendants() do
            if x:IsA("BasePart") then
                x.CollisionGroup = "Characters"
            elseif x:IsA("Sound") then
                x.SoundGroup = SoundService:FindFirstChild("SFX")
            elseif x:IsA("ParticleEmitter") then
                x:AddTag("VFX")
            end
        end

        if typeof(mutation)=="string" and mutation ~= "Base" then
            charData.Mutation = mutation

            local effectTemplate = ServerStorage.GameAssets.Effects.Mutations:FindFirstChild(mutation)
            if not hasMutationVariant and effectTemplate then
                local eff = effectTemplate:Clone()
                eff.CanCollide, eff.Anchored = false, false

                local weld = Instance.new("Weld")
                weld.Part0 = charModel.PrimaryPart
                weld.Part1 = eff
                weld.Parent = eff

                eff.Parent = charModel.PrimaryPart

                for _,x in eff:GetDescendants() do
                    if x:IsA("ParticleEmitter") then x:AddTag("VFX") end
                end

                local mainBone = charData.Type == "LuckyWarrior" and charModel.PrimaryPart:FindFirstChildWhichIsA("Bone") or nil
                if mainBone then
                    for _,x in eff:GetChildren() do x.Parent = mainBone end
                end
            end

            if mutation == "Shocked" then
                task.delay(4,function()
                    GameData.Effects.lightningStrike(charModel.PrimaryPart.Position - Vector3.new(0,5,0))
                end)
            end
        end

        local rootPart = charHumanoid and charHumanoid.RootPart or charModel.PrimaryPart
        rootPart.Anchored = true
        task.delay(1,function()
            rootPart.Anchored = false
            if charHumanoid then
                charHumanoid.WalkSpeed = 12
                charHumanoid.BreakJointsOnDeath = false
                charHumanoid:Move(Vector3.xAxis)
            else
                local controller = charModel:FindFirstChildWhichIsA("ControllerManager")
                if controller then
                    controller.ActiveController = controller:FindFirstChildWhichIsA("GroundController")
                    controller.BaseMoveSpeed = 12
                    controller.FacingDirection, controller.MovingDirection = Vector3.xAxis, Vector3.xAxis
                end
            end
        end)

        charModel:PivotTo(self.Settings.SpawnPosition*CFrame.Angles(0,math.rad(-90),0))
        charModel:SetAttribute("Mutation",mutation)
        charModel:SetAttribute("Profit", GameData.calculateProfit(charData.Profit,nil,nil,mutation))
        charModel:AddTag("Character")
        charModel.Parent = workspace:FindFirstChild("SpawnedCharacters")

        rootPart.Touched:Connect(function(hitPart)
            if not didHit and not didClaim then
                if hitPart.Name == "Base" and hitPart:IsDescendantOf(workspace.Map.EndGate) then
                    didHit = true
                    charModel:Destroy()
                end
            end
        end)

        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "ClaimPrompt"
        prompt.RequiresLineOfSight = false
        prompt.HoldDuration = .5
        prompt.ObjectText = string.format("%s $%d",charData.Name,charData.Price)
        prompt.ActionText = "RECRUIT"
        prompt.MaxActivationDistance = 10
        prompt.Parent = rootPart

        local connections, lastBuyer = {}, nil
        prompt.Triggered:Connect(function(player)
            if lastBuyer and lastBuyer == player then return end
            local price = prompt:GetAttribute("Price") or charData.Price
            local oldAmount = profileService:GetCoins(player)
            local plot = self:GetPlotForPlayer(player)

            local canAfford = typeof(oldAmount)=="number" and oldAmount >= price
            local numPending = self.Client.PendingCharacters:GetFor(player)
            local hasEmptySlot = self:HasEmptySlot(player)


            if not canAfford then
                self:SendNotification(player, "Not enough coins!", "Warning")
            elseif not hasEmptySlot then
                self:SendNotification(player, "Not enough space. Free up a character slot!", "Warning")
            elseif not plot then
                return
            else
                local newPrice = math.floor(price*1.5)
                prompt:SetAttribute("Price",newPrice)
                charModel:SetAttribute("Price",newPrice)
                charModel:SetAttribute("IsBought",true)
                prompt.ObjectText = string.format("%s $%d",charData.Name,newPrice)


                if lastBuyer then
                    local old = self.Client.PendingCharacters:GetFor(lastBuyer)
                    self.Client.PendingCharacters:SetFor(lastBuyer, math.max(0,old - 1))

                    self:SendNotification(lastBuyer, string.format("%s Stole your %s!",player.DisplayName, charData.Name), "Warning")
                end

                local recruitSound = charModel:FindFirstChild("RecruitSound", true)
                if recruitSound then
                    if recruitSound.Playing then recruitSound:Stop() end
                    recruitSound:Play()
                end

                didClaim = true
                lastBuyer = player

                self.Client.PendingCharacters:SetFor(player, numPending + 1)

                profileService:Dispatch(player,{
                    type = "ADD_COINS",
                    payload = -1*price,
                    logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
                })

                local recruitSounds = {
                    Normal = "rbxassetid://87157792904634",
		            Brainrot = "rbxassetid://117798922822996"
                }

                local sfx = Instance.new("Sound")
                sfx.Name = "RecruitSFX"
                sfx.SoundId = recruitSounds[charData.Rarity == "Mythic" and "Brainrot" or "Normal"]
                sfx.Parent = rootPart
                sfx.RollOffMaxDistance = 100
                sfx.Volume = 0.5
                sfx.SoundGroup = SoundService:FindFirstChild("SFX")
                sfx:Play()

                for _,conn in connections do
                    conn:Disconnect()
                end
                connections = {}

                local didFinish, startTime = false, tick()
                connections.onStepped = RunService.Stepped:Connect(function(dt)
                    if not didFinish then

                        if charHumanoid then
                            charHumanoid:MoveTo(plot.Gate:GetPivot().Position)
                        else
                            local controller = charModel:FindFirstChildWhichIsA("ControllerManager")
                            if controller then
                                local dir = ((plot.Gate:GetPivot().Position - charModel:GetPivot().Position)*Vector3.new(1,0,1)).Unit
                                controller.FacingDirection, controller.MovingDirection = dir, dir
                            end
                        end

                        local dist = ((charModel:GetPivot().Position - plot.Gate:GetPivot().Position)*Vector3.new(1,0,1)).Magnitude
                        local timeSinceStart = tick() - startTime

                        didFinish = dist<=5 or timeSinceStart>=60
                    else
                        self.Client.PendingCharacters:SetFor(player, math.max(0,numPending - 1))
                        for _,conn in connections do conn:Disconnect() end
                        connections = {}
                        charModel:Destroy() charData.Tier = 1
                        self:GiveCharacter(player, charData)

                        AnalyticsService:LogCustomEvent(player,"CharacterBought",1,{
                            [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = charData.Name,
                            [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = charData.Rarity,
                            [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = charData.Mutation
                        })
                    end
                end)

                connections.onPlayerLeft = player.Destroying:Once(function()
                    charModel:Destroy()
                    for _,conn in connections do conn:Disconnect() end
                    connections = {}
                end)
            end
        end)

        task.delay(self.Settings.SpawnLifetime,function()
            if not didClaim then charModel:Destroy() end
        end)
    end
end

function GameService:HasEmptySlot(player)
    local profileService = Knit.GetService("ProfileService")
    local plot = self:GetPlotForPlayer(player)

    if plot then
        local currentCharacters = profileService:GetInventory(player, "Characters")
        local emptySlots = Sift.Array.count(currentCharacters,function(v) return v == "Empty" end)
        local numPending = self.Client.PendingCharacters:GetFor(player)
        local stolenCharacter = self.Client.StolenCharacter:GetFor(player)
        if typeof(stolenCharacter)=="table" then numPending +=1 end
        emptySlots = emptySlots - numPending

        return emptySlots>0
    end
end

function GameService:StealCharacter(player, plot, idx)
    if not player or not plot or not plot.CurrentOwner then return end
    local targetUserId = plot.CurrentOwner.UserId

    local targetSlot = plot.Slots[idx]
    local playerPlot = self:GetPlotForPlayer(player)

    local hasEmptySlot = self:HasEmptySlot(player)
    if not playerPlot then
        return
    elseif self.Client.StolenCharacter:GetFor(player) then
        self:SendNotification(player,"You are already stealing!","Warning")
        return
    elseif not hasEmptySlot then
        self:SendNotification(player, "Not enough space. Free up a character slot!", "Warning")
        return
    elseif targetSlot and not targetSlot.IsStealable then
        self:SendNotification(player,"This character can not be stolen!","Warning")
        return
    elseif player.Character and targetSlot and targetSlot.CurrentModel and not targetSlot.IsStolen and not targetSlot.IsMoving then

        local profileService = Knit.GetService("ProfileService")
        local plrCharacter = player.Character

        local charData = self.Characters[targetSlot.CurrentModel.Name]
        local connections = {}
        if charData and charData.Instance then
            local charModel = charData.Instance:Clone()

            if player:DistanceFromCharacter(charModel:GetPivot().Position)>=10 then
                warn(`[POSSIBLE EXPLOIT] {player.Name} <{player.UserId}> was too far from the CharacterSlot when attempting to steal!`)
                return
            end

            local hasMutationVariant = false
            local mutation = targetSlot.CurrentModel:GetAttribute("Mutation") or "Base"
            if typeof(mutation)=="string" and mutation ~= "Base" then
                local variantFolder = ServerStorage.GameAssets.MutationVariants:FindFirstChild(mutation)
                if variantFolder and variantFolder:FindFirstChild(charModel.Name) then
                    local mutatedModel = variantFolder[charModel.Name]:Clone()
                    charModel = mutatedModel
                    hasMutationVariant = true
                end
            end
            for _,x in ipairs(charModel:GetChildren()) do
                if x:IsA("Script") then x:Destroy()
                elseif x:IsA("BasePart") then
                    x.Massless, x.CanCollide = true, false
                    x.Anchored = false

                    local noc = Instance.new("NoCollisionConstraint")
                    noc.Part0 = x
                    noc.Part1 = playerPlot.Gate.PrimaryPart
                    noc.Parent = x
                end
            end

            if charModel:GetAttribute("Scale") then charModel:ScaleTo(charModel:GetAttribute("Scale")) end
            charModel:AddTag("Character")
            charModel:SetAttribute("IsStolen",true)
            charModel.Name = "StolenCharacter"
            charModel.Parent = plrCharacter

            if charModel:FindFirstChild("Humanoid") then
                charModel.Humanoid.EvaluateStateMachine = false
            elseif charModel:FindFirstChildWhichIsA("ControllerManager") then
                local controller = charModel:FindFirstChildWhichIsA("ControllerManager")
                if controller then controller:Destroy() end
            end

            local carryAttach = charModel:FindFirstChild("CarryAttachment",true)

            local weld = Instance.new("Weld")
            weld.Name = "CharacterWeld"
            weld.Part0 = plrCharacter:FindFirstChild("UpperTorso")
            weld.C0 = CFrame.new(0,3.25,0)

            if carryAttach then
                weld.Part1 = carryAttach.Parent
                weld.C1 = carryAttach.CFrame
            else
                weld.Part1 = charModel:FindFirstChild("HumanoidRootPart") or charModel.PrimaryPart
                weld.C1 = CFrame.new(0,0,weld.Part1.Size.Z/-2) * CFrame.Angles(0,math.rad(90),math.rad(-90))
            end

            weld.Parent = plrCharacter
            weld.Part1:SetNetworkOwner(player)

            local anim = Instance.new("Animation")
            anim.Name = "HoldAnim"
            anim.AnimationId = "rbxassetid://105958152938025"

            local animTrack = plrCharacter.Humanoid:LoadAnimation(anim)
            animTrack:Play()
            animTrack:AdjustWeight(1)
            targetSlot:SetStolen(true)
            charData.Tier = tonumber(targetSlot.CurrentModel:GetAttribute("Tier")) or 1
            charData.Mutation = mutation



            self.Client.StolenCharacter:SetFor(player, charData)
            self.Client.OnNotify:Fire(plot.CurrentOwner,`Your {charData.Name} was stolen!`,"Warning")

            profileService:GlobalDispatch(targetUserId,{
                type = "SET_STOLEN",
                payload = { slot = idx, active = true }
            })

            local function cleanup()
                for _,conn in connections do conn:Disconnect() end
                if player then self.Client.StolenCharacter:SetFor(player,nil) end
                if plrCharacter.Humanoid then plrCharacter.Humanoid.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed end

                charModel:Destroy() animTrack:Stop()

                targetSlot:SetStolen(false)
                profileService:GlobalDispatch(targetUserId,{
                    type = "SET_STOLEN",
                    payload = { slot = idx, active = false }
                })
            end

            table.insert(connections,plrCharacter.Humanoid.Died:Once(cleanup))
            table.insert(connections,plrCharacter.Destroying:Once(cleanup))
            table.insert(connections,player.Destroying:Once(cleanup))
            table.insert(connections,charModel.Destroying:Once(cleanup))
            table.insert(connections,plrCharacter.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then plrCharacter.Humanoid:UnequipTools() end
            end))
            table.insert(connections,plrCharacter.Humanoid.StateChanged:Connect(function(old,new)
                if table.find({Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.FallingDown},new) then cleanup() end
            end))

            local didFinish = false

            table.insert(connections,playerPlot.OnZoneCollected:Connect(function() didFinish = true end))
            connections.onStepped = RunService.Stepped:Connect(function(dt)
                if not didFinish then

                    if plrCharacter.Humanoid then
                        plrCharacter.Humanoid.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed*.5
                        plrCharacter.Humanoid:UnequipTools()
                    end
                    local dist = ((charModel:GetPivot().Position - playerPlot.Gate:GetPivot().Position)*Vector3.new(1,0,1)).Magnitude
                    didFinish = dist<=5
                else
                    for _,conn in connections do conn:Disconnect() end
                    self.Client.StolenCharacter:SetFor(player,nil)
                    animTrack:Stop() charModel:Destroy() weld:Destroy()
                    profileService:GlobalDispatch(targetUserId,{
                        type = "REMOVE_CHARACTER",
                        payload = { slot = idx }
                    })

                    profileService:Dispatch(player,{ type = "ADD_STEALS" })

                    self:GiveCharacter(player, charData)

                    AnalyticsService:LogCustomEvent(player,"CharacterStolen",1,{
                        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = charData.Name,
                        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = charData.Rarity,
                        [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = charData.Mutation
                    })

                    if plrCharacter.Humanoid then plrCharacter.Humanoid.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed end
                end
            end)
        end
    end
end

function GameService:GetPlotForPlayer(player)
    for _,p in self.Plots do
        if p.CurrentOwner == player then return p end
    end
end

function GameService:SendNotification(player, nMessage: string, nType: "Default"|"Warning"|"Info"|Color3, duration: number?)
    self.Client.OnNotify:Fire(player, nMessage, nType, duration)
end

function GameService:MoveCharacter(player, slotIdx, is_placing)
    local plot = self:GetPlotForPlayer(player)
    local plrCharacter = player.Character
    local curMoving = self.Client.MovingCharacter:GetFor(player)

    if plrCharacter and plot and typeof(slotIdx)=="number" then
        local profileService = Knit.GetService("ProfileService")

        if not is_placing and not curMoving then
            local slot = plot.Slots[slotIdx]
            local charData = self.Characters[slot.CurrentModel.Name]
            if not charData then return end

            local connections = {}
            local charModel = charData.Instance:Clone()
            for _,x in ipairs(charModel:GetChildren()) do
                if x:IsA("Script") then x:Destroy()
                elseif x:IsA("BasePart") then
                    x.Massless, x.CanCollide = true, false
                    x.Anchored = false

                    local noc = Instance.new("NoCollisionConstraint")
                    noc.Part0 = x
                    noc.Part1 = plot.Gate.PrimaryPart
                    noc.Parent = x
                end
            end

            if charModel:GetAttribute("Scale") then charModel:ScaleTo(charModel:GetAttribute("Scale")) end
            charModel.Name = "MovingCharacter"
            charModel.Parent = plrCharacter

            if charModel:FindFirstChild("Humanoid") then
                charModel.Humanoid.EvaluateStateMachine = false
            elseif charModel:FindFirstChildWhichIsA("ControllerManager") then
                local controller = charModel:FindFirstChildWhichIsA("ControllerManager")
                if controller then controller:Destroy() end
            end
            local carryAttach = charModel:FindFirstChild("CarryAttachment",true)

            local weld = Instance.new("Weld")
            weld.Name = "CharacterWeld"
            weld.Part0 = plrCharacter:FindFirstChild("UpperTorso")
            weld.C0 = CFrame.new(0,3.25,0)

            if carryAttach then
                weld.Part1 = carryAttach.Parent
                weld.C1 = carryAttach.CFrame
            else
                weld.Part1 = charModel:FindFirstChild("HumanoidRootPart") or charModel.PrimaryPart
                weld.C1 = CFrame.new(0,0,weld.Part1.Size.Z/-2) * CFrame.Angles(0,math.rad(90),math.rad(-90))
            end
        
            weld.Parent = plrCharacter
            weld.Part1:SetNetworkOwner(player)

            local anim = Instance.new("Animation")
            anim.Name = "HoldAnim"
            anim.AnimationId = "rbxassetid://105958152938025"

            local animTrack = plrCharacter.Humanoid:LoadAnimation(anim)
            animTrack:Play()
            animTrack:AdjustWeight(1)
            slot:SetMoving(true)

            self.Client.MovingCharacter:SetFor(player, slotIdx)

            local function cleanup()
                for _,conn in connections do conn:Disconnect() end
                if player then self.Client.MovingCharacter:SetFor(player,nil) end
                slot:SetMoving(false)
                animTrack:Stop()

                local movingCharacter = plrCharacter:FindFirstChild("MovingCharacter")
                if movingCharacter then
                    movingCharacter:Destroy()
                end
            end


            table.insert(connections,plrCharacter.Humanoid.Died:Once(cleanup))
            table.insert(connections,plrCharacter.Destroying:Once(cleanup))
            table.insert(connections,player.Destroying:Once(cleanup))
            table.insert(connections,charModel.Destroying:Once(cleanup))
            table.insert(connections,plrCharacter.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then plrCharacter.Humanoid:UnequipTools() end
            end))
            table.insert(connections,plrCharacter.Humanoid.StateChanged:Connect(function(old,new)
                if table.find({Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.FallingDown},new) then cleanup() end
            end))
        elseif is_placing and typeof(curMoving)=="number" then
            local movingSlot = plot.Slots[curMoving]
            movingSlot:SetMoving(false)

            local movingCharacter = plrCharacter:FindFirstChild("MovingCharacter")
            if movingCharacter then
                movingCharacter:Destroy()
            end

            profileService:Dispatch(player,{
                type = "MOVE_CHARACTER",
                payload = { slot = curMoving, target = slotIdx }
            })

        else warn("FAILED TO MOVE") end
    end
end

function GameService:GiveCharacter(player, charData, is_permanent)
    local profileService = Knit.GetService("ProfileService")
    profileService:Dispatch(player, {
        type = "ADD_CHARACTER",
        payload = {
            name = charData.Name, tier = charData.Tier, mutation = charData.Mutation or "Base",
            permanent = is_permanent or false, charType = charData.Type,
        }
    })
end

function GameService.Client:GrantSpinReward(player, rewardType)

    local coinRewards = {
        ["Coins_25K"] = 25000,
        ["Coins_100K"] = 100000,
        ["Coins_1M"] = 1000000
    }

    if rewardType == "ServerLuck" then
        local eventService = Knit.GetService("EventService")
        eventService:SetServerLuck(math.max(2,eventService.CurrentLevel or 1),15*60)

    elseif rewardType == "Character" then
        local charData = self.Server.Characters["Skeletino Raptorino"]
        self.Server:GiveCharacter(player, charData)
        self.Server:SendNotification(player, string.format("You've been awarded \"%s\"",charData.Name), Color3.fromRGB(253, 216, 53))
    elseif rewardType == "Event" then
        Knit.GetService("EventService"):StartEvent("Gold") --Volcanic

    elseif typeof(coinRewards[rewardType])=="number" then
        local amount = coinRewards[rewardType]

        Knit.GetService("ProfileService"):Dispatch(player,{
            type = "ADD_COINS",
            payload = amount,
            logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
        })

        self.Server:SendNotification(player, string.format("+%s COIN$ Rewarded",GameData.Utils.formatNumber(amount)), Color3.fromRGB(253, 216, 53))
    end

    AnalyticsService:LogCustomEvent(player,"WheelSpin",1,{
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = rewardType
    })
end

function GameService.Client:Rebirth(player)
    local profileService = Knit.GetService("ProfileService")
    local nextRebirth = math.max(1, profileService:GetStatistics(player,"Rebirths")+1)
    local inventoryData = profileService:GetInventory(player)
    local rebirthData = GameData.RebirthData[`Rebirth {nextRebirth}`]

    if rebirthData and inventoryData then
        local canRebirth = Sift.Dictionary.every(rebirthData.Requirements, function(value, key)
            if key == "Coins" then
                return inventoryData[key] >= value
            elseif key == "Characters" then
                local currentCharacters = profileService:GetInventory(player, "Characters")
                return Sift.Array.every(value, function(req)
                    return Sift.Array.findWhere(currentCharacters, function(v)
                        return v ~= "Empty" and v.Name == req
                    end) ~= nil
                end)
            end
            return true
        end)

        if canRebirth then

            profileService:Dispatch(player,{type = "SET_COINS", payload = 0})
            profileService:Dispatch(player,{type = "CLEAR_CHARACTERS", payload = { excludePermanent = true }})

            for rewardKey, rewardValue in rebirthData.Rewards do
                if rewardKey == "Coins" then 
                    profileService:Dispatch(player,{
                        type = "ADD_COINS", payload = rewardValue,
                        logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
                    })
                elseif rewardKey == "LockTime" then
                    profileService:Dispatch(player,{ type = "ADD_LOCK_TIME", payload = rewardValue })
                elseif rewardKey == "TierLimit" then
                    profileService:Dispatch(player,{ type = "SET_TIER_LIMIT", payload = rewardValue })
                elseif rewardKey == "IncomeMultiplier" then
                    profileService:Dispatch(player,{ type = "ADD_MULTIPLIER", payload = rewardValue })
                elseif rewardKey == "Floor" then
                    profileService:Dispatch(player, { type = "ADD_FLOOR"})
                end
            end

            profileService:Dispatch(player,{ type = "ADD_REBIRTH" })

            local humanoid = player.Character and player.Character.Humanoid
            if humanoid then humanoid:UnequipTools() end
            for _,x in player.Backpack:GetChildren() do if x:IsA("Tool") and x.Name ~= "Bat" then x:Destroy() end end
            for _,x in player.StarterGear:GetChildren() do if x:IsA("Tool") and x.Name ~= "Bat" then x:Destroy() end end
     

            self.Server:SendNotification(player, `You Have Reached Rebirth {nextRebirth}!`, "Info")
            return true
        else
            self.Server:SendNotification(player, "Rebirth requirements not met!", "Warning")
            return false, "Rebirth Requirements Not Met"
        end
    elseif not rebirthData then
        self.Server:SendNotification(player, "Max Rebirth Reached!", "Warning")
        return false,"Max Rebirth Reached"
    elseif not inventoryData then
        return false,"Profile Data Not Loaded"
    end
end

function GameService.Client:StealCharacter(player, instance)
    if instance and instance.Parent:HasTag("CharacterSlot") then
        for _,plot in self.Server.Plots do
            local slot, idx = plot:GetSlotForInstance(instance.Parent)
            if slot and not slot:IsOwner(player) and not slot.IsStolen then
                self.Server:StealCharacter(player, plot, idx)
                break
            end
        end
    end
end

function GameService.Client:SellCharacter(player, instance)
    local plot = self.Server:GetPlotForPlayer(player)
    if plot and instance.Parent:HasTag("CharacterSlot") then
        local slot, idx = plot:GetSlotForInstance(instance.Parent)
        if slot and slot:IsOwner(player) and not slot.IsStolen then
            local sell_price = instance:GetAttribute("Price")//2
            Knit.GetService("ProfileService"):Dispatch(player,{
                type = "REMOVE_CHARACTER",
                payload = { slot = idx }
            })
            Knit.GetService("ProfileService"):Dispatch(player,{
                type = "ADD_COINS", payload = sell_price,
                logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
            })  
            return true
        end
    end
end

function GameService.Client:PromptUnlockGate(player, targetPlayer)
    if not targetPlayer or not targetPlayer:IsA("Player") then return end
    local plot = self.Server:GetPlotForPlayer(targetPlayer)
    if plot and plot.Locked and plot.CurrentOwner == targetPlayer and player ~= targetPlayer then
        self.Server.Client.PendingGateUnlock:SetFor(player, targetPlayer)
        game:GetService("MarketplaceService"):PromptProductPurchase(player, 3523291022)
    end
end


function GameService.Client:OpenLuckyWarrior(player, instance)
    local plot = self.Server:GetPlotForPlayer(player)
    if plot and instance.Parent:HasTag("CharacterSlot") then
        local slot, idx = plot:GetSlotForInstance(instance.Parent)
        local luckyRarity = instance.Name:match("(%w+) Lucky Warrior") or nil
        if slot and slot:IsOwner(player) and instance:GetAttribute("IsLuckyWarrior") then
            local originalMutation = instance:GetAttribute("Mutation") or "Base"
            local tier = instance:GetAttribute("Tier") or 1
            local name, mutation = self.Server:GetRandomCharacter(luckyRarity)
            local charData = self.Server.Characters[name]
            if charData and charData.Type ~= "LuckyWarrior" then
                GameData.Effects.playEffect("LuckyWarriorOpen", instance.PrimaryPart.Position+Vector3.yAxis*1,2)
                Knit.GetService("ProfileService"):Dispatch(player,{
                    type = "ADD_CHARACTER", payload = {
                        name = charData.Name, tier = tier, mutation = originalMutation=="Base" and mutation or originalMutation,
                        permanent = false, slot = idx
                    }
                })
            end
            return true
        end
    end
end

function GameService.Client:BuyTool(player, toolName)
    local profileService = Knit.GetService("ProfileService")
    local toolData = GameData.ToolData[toolName]
    if toolData and typeof(toolData.Price)=="number" and not player.Backpack:FindFirstChild(toolName) then
        local oldAmount = profileService:GetCoins(player)
        local canAfford = typeof(oldAmount)=="number" and oldAmount >= toolData.Price

        if not canAfford then
            --self.Server:SendNotification(player, "Not enough coins!", "Warning")
            return false
        else
            profileService:Dispatch(player,{
                type = "ADD_COINS",
                payload = -1*toolData.Price,
                logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
            })

            self.Server:GiveTool(player, toolName)
            return true
        end
    end
end

function GameService.Client:MoveCharacter(player, instance, is_placing)
    return self.Server:MoveCharacter(player, instance, is_placing)
end

function GameService.Client:MergeCharacter(player, instance)
    local canMerge = instance:GetAttribute("CanMerge")

    local plot = self.Server:GetPlotForPlayer(player)
    if canMerge and plot and instance.Parent:HasTag("CharacterSlot") then
        local profileService = Knit.GetService("ProfileService")
        local slot, idx = plot:GetSlotForInstance(instance.Parent)
        if slot and slot:IsOwner(player) and not slot.IsStolen then
            local tier = instance:GetAttribute("Tier") or 1
            local merge_price = math.abs(instance:GetAttribute("Price") * 2^(tier-1))//2

            local canAfford = profileService:GetCoins(player)>=merge_price
            if tier>=5 then
                self.Server:SendNotification(player, "Max star rating reached!", "Warning")
                return false
            elseif not canAfford then
                self.Server:SendNotification(player, "Not enough coins!", "Warning")
                return false
            else
                profileService:Dispatch(player,{
                    type = "ADD_COINS", payload = -1*merge_price,
                    logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name }
                })
                profileService:Dispatch(player,{
                    type = "MERGE_CHARACTER",
                    payload = { slot = idx }
                })
            end
            return true
        end
    end
end

return GameService
