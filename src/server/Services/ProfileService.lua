local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PS = require(ReplicatedStorage.Packages.ProfileService)
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)

local Signal = require(ReplicatedStorage.Packages.Signal)

local ProfileRoduxStore = require(ReplicatedStorage.Shared.Stores.ProfileStore)



local ProfileTemplate = ProfileRoduxStore.__template

local ProfileStore = PS.GetProfileStore("PlayerData",ProfileTemplate)
local IS_DEBUG = false

if RunService:IsStudio() and IS_DEBUG then
	ProfileStore = ProfileStore.Mock
end


local ProfileService = Knit.CreateService {
    Name = "ProfileService",
    Client = {
       -- ProfileNetworkHandler = Knit.CreateSignal(),

		OnCreditsChanged = Knit.CreateSignal(),
		OnLevelChanged = Knit.CreateSignal(),
		OnXPChanged = Knit.CreateSignal(),
        Data = Knit.CreateProperty(ProfileTemplate)
    },
    Profiles = {},
	Stores = {},
	Middlewares = {},
	Connections = {},
	AllowedClientActions = {
		"ADJUST_SETTING","VIEW_CHARACTER","SET_TUTORIAL_COMPLETED",
		"SET_AUTO_BUY","USE_SPINS"
	},

	Settings = {
		LogEconomyEvents = true,
		DataVersion = "BETA_BUILD",
		SavePlayTime = true
	},
	JoinTimes = {}

}


function ProfileService:KnitInit()
	self.ProfileStore = ProfileStore
	self.PlayerDataLoaded = Signal.new()
	self.PlayerDataChanged = Signal.new()


	self.PlayerDataChanged:Connect(function(plr,state,lastState)
		if typeof(state)~="table" or typeof(lastState)~="table" then return end
		
		--local new, old = Dictionary.flatten(state,1), Dictionary.flatten(lastState,1)
	end)


end

function ProfileService:KnitStart()
	for _,plr in ipairs(Players:GetPlayers()) do
		self:LoadProfile(plr)
	end

	Players.PlayerAdded:Connect(function(plr) self:LoadProfile(plr) end)
	Players.PlayerRemoving:Connect(function(plr) self:ReleaseProfile(plr) end)
end


function ProfileService:GetProfile(player)
	local profile = self.Profiles[player]
	return profile
end

function ProfileService:ViewProfile(userId: number, vers: string?)
	if typeof(userId)~="number" then
		warn("ProfileService:ViewProfile() number expected for userId, got ",typeof(userId))
		return
	end
	local profile = ProfileStore:ViewProfileAsync(("User_%d"):format(userId),vers)
	if not profile then
		warn(("ProfileService:ViewProfile() Profile for \"User_%d\" does not exist."):format(userId))
	end
	return profile
end

function ProfileService:WipeProfile(userId: number)
	if typeof(userId)~="number" then
		warn("ProfileService:WipeProfile() number expected for userId, got ",typeof(userId))
		return
	end
	return ProfileStore.Mock:WipeProfileAsync(("User_%d"):format(userId)) :: boolean
end


function ProfileService:LoadProfile(player)
	if self.Profiles[player] then return self.Profiles[player] end

	local profile = self.ProfileStore:LoadProfileAsync("User_"..player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			self.Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick("Failed to load data.")
		end)


		if player:IsDescendantOf(Players) == true then
			self.Profiles[player] = profile

			
			if self.Settings.SavePlayTime then
				self.JoinTimes[player] = DateTime.now()
			end

			local store = self.Stores[player]
			if not store then
				local middlewares = next(self.Middlewares)~=nil and self.Middlewares or nil
				store = ProfileRoduxStore.new(profile.Data, middlewares)
				store.changed:connect(function(state,lastState)

					self:Update(player,state)
					self.PlayerDataChanged:Fire(player, state, lastState)
				end)
				self.Stores[player] = store
			end

			local profile_version = profile:GetMetaTag("DataVersion")
			if typeof(profile_version)=="string" and profile_version ~= self.Settings.DataVersion then


				if true or table.find({"DEV_BUILD","ALPHA_BUILD","BETA_BUILD"},profile_version) then
					warn(string.format("[ProfileService] Mismatched DataVersion Found For <User_%d>. Resetting Data",player.UserId))
					self:GlobalDispatch(player.UserId,{ type = "RESET_DATA"})
				end
			end

			profile:SetMetaTag("DataVersion",self.Settings.DataVersion)

			local function processGlobalUpdate(id,data)
				if typeof(data)=="table" and data.type then store:dispatch(data) end
				profile.GlobalUpdates:ClearLockedUpdate(id)
			end

			for _,update in ipairs(profile.GlobalUpdates:GetLockedUpdates()) do
				processGlobalUpdate(unpack(update))
			end
			profile.GlobalUpdates:ListenToNewLockedUpdate(processGlobalUpdate)


			for _,update in ipairs(profile.GlobalUpdates:GetActiveUpdates()) do
				profile.GlobalUpdates:LockActiveUpdate(update[1])
			end
			profile.GlobalUpdates:ListenToNewActiveUpdate(function(id,data)
				profile.GlobalUpdates:LockActiveUpdate(id)
			end)

			self.PlayerDataLoaded:Fire(player, profile.Data)
			self.PlayerDataChanged:Fire(player, profile.Data)
			self.Client.Data:SetFor(player, profile.Data)
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load data")
	end
	return profile
end

function ProfileService:ReleaseProfile(player)
    local profile = self.Profiles[player]
	local store = self.Stores[player]

    if profile ~= nil then
		if store then
			store:flush()
			--self.Stores[player] = nil   --Maybe add this line back?
			
		end

		local leaveTime = DateTime.now()
		local joinTime = self.JoinTimes[player]
		if joinTime then
			if self.Settings.SavePlayTime then
				local duration = (leaveTime.UnixTimestamp-joinTime.UnixTimestamp)
				profile:SetMetaTag("PlayTime",math.max(0,(profile:GetMetaTag("PlayTime") or 0)+duration ))
			end
			self.JoinTimes[player] = nil
		end

		profile:SetMetaTag("LastOnlineTime",leaveTime.UnixTimestamp)

        profile:Release()
		self.Profiles[player] = nil
		self.Client.Data:ClearFor(player)

        --print(("Saving PlayerData for %s <%d>"):format(player.Name,player.UserId))
    end
end

function ProfileService:Dispatch(player: Players|number, action)
	if not player then return end
	if typeof(player)=="number" then return self:GlobalDispatch(player,action) end
	local store = self.Stores[player]
	if not store then
		warn("No store found for "..player.Name)
		return
	end

	if typeof(action)=="table" and typeof(action.logEconomy)=="table" and self.Settings.LogEconomyEvents then
		local amount, logEconomy = action.payload, action.logEconomy

		if action.type == "ADD_COINS" and typeof(amount)=="number" and math.abs(amount)>0 and logEconomy.transactionType then
			local flowType = amount>0 and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
			local endingBalance = store:getState().Inventory.Coins + amount
			
			local ok,ret = pcall(function()
				return AnalyticsService:LogEconomyEvent(player,flowType,"Coins",math.abs(amount),math.max(0,endingBalance),
					logEconomy.transactionType,
					logEconomy.itemSku,
					logEconomy.customFields
				)
			end)

			if not ok then
				warn("An error occured during LogEconomyEvent: ",ret)
			end
		end
	end

	store:dispatch(action)
	return store:getState()
end

function ProfileService:GlobalDispatch(userId, action)
	if typeof(action)~="table" or not action.type then warn("ProfileService:GlobalDispatch() Action must be a table with a \"type\" parameter") return
	elseif typeof(userId)~="number" then warn("ProfileService:GlobalDispatch() Number expected for UserId") return end

	local existingPlayer = Players:GetPlayerByUserId(userId)
	if existingPlayer and self:GetProfile(existingPlayer) then
		--warn(string.format("ProfileService:GlobalDispatch() Player <%d> is already in-game. Sending normal dispatch",userId))
		return self:Dispatch(existingPlayer,action)
	end

	ProfileStore:GlobalUpdateProfileAsync("User_"..userId,function(handler)
		handler:AddActiveUpdate(action)
	end)
end

function ProfileService:Update(player,data)
	if typeof(data)~="table" then return end
	local profile = self.Profiles[player]
	if profile then
		profile.Data = data
		self.Client.Data:SetFor(player, data)
	end
end

function ProfileService:GetData(player)
	local profile = self.Profiles[player]
	if profile then
		return profile.Data
	end
end


function ProfileService:GetInventory(player,key: string?)
	local data = self:GetData(player)
	if data then
		if typeof(key)=="string" and data.Inventory then
			return data.Inventory[key]
		end
		return data.Inventory
	end
end

function ProfileService:GetCoins(player)
	return self:GetInventory(player,"Coins")
end

function ProfileService:GetStatistics(player,key: string?)
	local data = self:GetData(player)
	if data then
		if typeof(key)=="string" and data.Statistics then
			return data.Statistics[key]
		end
		return data.Statistics
	end
end

function ProfileService:GetStatus(player,key: string?)
	local data = self:GetData(player)
	if data then
		if typeof(key)=="string" and data.Status then
			return data.Status[key]
		end
		return data.Status
	end
end

function ProfileService:GetSettings(player,key: string?)
	local data = self:GetData(player)
	if data then
		if typeof(key)=="string" and data.Settings then
			return data.Settings[key]
		end
		return data.Settings
	end
end

function ProfileService:GetMetaTag(player,tag)
	local profile = self.Profiles[player]
	if profile and typeof(tag)=="string" then
		return profile:GetMetaTag(tag)
	end
end

function ProfileService:SetMetaTag(player,tag,data)
	local profile = self.Profiles[player]
	if profile and profile:IsActive() and typeof(tag)=="string" then
		profile:SetMetaTag(tag,data)
	end
end

function ProfileService.Client:Dispatch(player,action)
	if typeof(action)~="table" or not action.type then return end

	local isAllowed = (function(list)
		for _,a in list do
			if action.type == a then return true end
		end
		return false
	end)(self.Server.AllowedClientActions)

	if isAllowed then			
		self.Server:Dispatch(player,action)
	else
		warn(string.format("%s <%d> Attempted to dispatch a forbidden action through the ProfileData RoduxStore",player.Name,player.UserId))
		return
	end
end

function ProfileService.Client:GetProfileInfo(player, userId)
	local profile = self.Server:ViewProfile(userId)
	if profile then
		local metadata = profile.MetaData

		--Maybe send the entire MetaData table?
		return {
			Level = profile.Data.Statistics.Level or 1,
			JoinTime = metadata.ProfileCreateTime,
			PlayTime = metadata.MetaTags.PlayTime or 0,
			LastOnline = metadata.MetaTags.LastOnlineTime or 0,
		}
	end
end

function ProfileService.Client:GetJoinTime(player)
	local joinTime = self.Server.JoinTimes[player]

	if joinTime then
		local playTime = self.Server:GetMetaTag(player,"PlayTime") or 0
		return joinTime.UnixTimestamp - playTime, playTime
	end
end

function ProfileService.Client:GetData()
	return self.Data:Get()
end

return ProfileService
