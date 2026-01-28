local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)

local Service = Knit.CreateService({
	Name = "LeaderboardService",
	Client = {
		TopSteals = Knit.CreateProperty({}),
        TopEarning = Knit.CreateProperty({}),

	},

    Stores = {
        Steals = DataStoreService:GetOrderedDataStore("Steals"),
        Earning = DataStoreService:GetOrderedDataStore("Earning"),
    },

	Settings = {
		PageSize = 25,
		RefreshTime = 60,
	},
	Connections = {},
	LastRefresh = os.time(),

})

function Service:KnitStart()

	task.delay(5,function()
		while true do
            self.Client.TopSteals:Set(self:GetOrderedStore("Steals",100))
            self.Client.TopEarning:Set(self:GetOrderedStore("Earning",100))
			task.wait(self.Settings.RefreshTime)
		end
	end)


	local profileService = Knit.GetService("ProfileService")
	profileService.PlayerDataLoaded:Connect(function(player,data)
        local plrStats = data.Statistics

        if plrStats then
            self:AppendStore("Steals",player.UserId,plrStats.Steals)
            self:AppendStore("Earning",player.UserId,plrStats.IncomeRate)
        end
	end)

    profileService.PlayerDataChanged:Connect(function(player, state, lastState)
        if typeof(state)~="table" or typeof(lastState)~="table" then return end

        local plrStats = state and state.Statistics or nil
        if plrStats then
            if plrStats.Steals ~= lastState.Statistics.Steals then
                self:AppendStore("Steals",player.UserId,plrStats.Steals)
            end

            if plrStats.IncomeRate ~= lastState.Statistics.IncomeRate then
                self:AppendStore("Earning",player.UserId,plrStats.IncomeRate)
            end
        end
    end)
end

function Service:GetBudget()
	return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)
end

function Service:GetOrderedStore(storeName, maxCount: number?)
    if not self.Stores[storeName] then
        warn(("LeaderboardService:GetOrderedStore() \"%s\" OrderStore Doesn't Exit"):format(storeName))
        return
    end


	local list = {}
	local success, pages = pcall(function()
		return self.Stores[storeName]:GetSortedAsync(false,self.Settings.PageSize,1,nil)
	end)

	if not success then 
		warn("LeaderboardService:GetOrderedStore() Failed to GetSortedAsync ",pages)
		return
	end

	while true do
		for _, entry in (pages:GetCurrentPage()) do
			table.insert(list,entry)
			if typeof(maxCount)=="number" and #list>=maxCount then break end
		end
		repeat task.wait() until self:GetBudget()>=self.Settings.PageSize
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	end

	return Sift.Array.map(list,function(v)
		local userId = tonumber(v.key:match("(%d+)"))
		local ok,name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		return {
			UserId = userId,
			Name = ok and name,
			Value = v.value
		}
	end)
end

function Service:GetStoreAsync(storeName, userId: number)
	if not self.Stores[storeName] then
        warn(("LeaderboardService:GetStoreAsync() \"%s\" OrderedStore Doesn't Exist"):format(storeName))
        return
    elseif typeof(userId)~="number" then return end
	local dsSuccess, dsRet = pcall(function()
		return self.Stores[storeName]:GetAsync(string.format("User_%d",userId))
	end)

	return dsSuccess and dsRet or nil
end

function Service:AppendStore(storeName, userId: number, value: number, increment: boolean?)
    if not self.Stores[storeName] then
        warn(("LeaderboardService:AppendStore() \"%s\" OrderedStore Doesn't Exist"):format(storeName))
        return
	elseif typeof(userId)~="number" or typeof(value)~="number" or (increment and value<=0) then warn("BAD!") return end

	local dsSuccess, dsRet = pcall(function()
        local key = string.format("User_%d",userId)
        if increment then
            return self.Stores[storeName]:IncrementAsync(key, value)
        else
		    return self.Stores[storeName]:SetAsync(key,value>0 and value or nil)
        end
	end)

	return dsSuccess and dsRet or nil
end

return Service
