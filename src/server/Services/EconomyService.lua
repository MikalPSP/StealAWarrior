local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameData = require(ReplicatedStorage.GameData)

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Signal = require(ReplicatedStorage.Packages.Signal)


local Service = Knit.CreateService({
	Name = "EconomyService",
	Client = {
		GamePasses = Knit.CreateProperty({}),
		ActiveGiftRequest = Knit.CreateProperty({}),
	},

	GamePasses = GameData.GamePasses,
	GiftProducts = {
		--["AdminPanel"] = 0,
		["VIP"] = 3482330738,
		["2X Coins"] = 3482331412,
		["2X Speed"] = 3482331414,
	},
	Products = {

		[3478987137] = {
			Name = "5,000 Coins",
			Icon = "rbxassetid://0",
			Description = "Adds 5,000 coins",
			ProductType = "Coins",
			Callback = { type = "ADD_COINS", payload = 5000 },
		},
		[3478987293] = {
			Name = "25,000 Coins",
			Icon = "rbxassetid://0",
			Description = "Adds 25,000 coins",
			ProductType = "Coins",
			Callback = { type = "ADD_COINS", payload = 25000 },
		},
		[3478987442] = {
			Name = "100,000 Coins",
			Icon = "rbxassetid://0",
			Description = "Adds 100,000 coins",
			ProductType = "Coins",
			Callback = { type = "ADD_COINS", payload = 100000 },
		},
		[3478987554] = {
			Name = "500,000 Coins",
			Icon = "rbxassetid://0",
			Description = "Adds 500,000 coins",
			ProductType = "Coins",
			Callback = { type = "ADD_COINS", payload = 500000 },
		},
		[3478987704] = {
			Name = "1,000,000 Coins",
			Icon = "rbxassetid://0",
			Description = "Adds 1,000,000 coins",
			ProductType = "Coins",
			Callback = { type = "ADD_COINS", payload = 1_000_000 },
		},

		[3447974095] = {
			Name = "Server Luck",
			Icon = "rbxassetid://125763030257805",
			Description = "Boost server luck to 2X for 15 minutes!",
			ProductType = "Boost",
		},
		[3479005436] = {
			Name = "Server Luck II",
			Icon = "rbxassetid://125763030257805",
			Description = "Boost server luck to 4X for 15 minutes!",
			ProductType = "Boost",
		},

		[3504118298] = {
			Name = "1 Spin",
			Icon = "rbxassetid://125763030257805",
			Description = "Awards 1 Wheel Spin",
			ProductType = "Spin",
			Callback = { type = "ADD_SPINS", payload = 1 }
		},

		[3504118590] = {
			Name = "3 Spins",
			Icon = "rbxassetid://125763030257805",
			Description = "Awards 3 Wheel Spins",
			ProductType = "Spin",
			Callback = { type = "ADD_SPINS", payload = 3 }
		},

		[3508235902] = {
			Name = "Rare Lucky Warrior",
			Icon = "rbxassetid://0",
			Description = "Awards A Lucky Warrior Character",
			ProductType = "LuckyWarrior",
		},
		[3508236534] = {
			Name = "Legendary Lucky Warrior",
			Icon = "rbxassetid://0",
			Description = "Awards A Lucky Warrior Character",
			ProductType = "LuckyWarrior",
		},
		[3508236839] = {
			Name = "Mythic Lucky Warrior",
			Icon = "rbxassetid://0",
			Description = "Awards A Lucky Warrior Character",
			ProductType = "LuckyWarrior",
		}


	},
	UGCItems = {}


})

function Service:KnitInit()
	--Create Signals
	self.OnProductGranted = Signal.new()
	self.OnGamePassPurchased = Signal.new()

	self.Client.OnProductGranted = Knit.CreateSignal()

	for name, id in self.GiftProducts do
		self.Products[id] = {
			Name = name,
			ProductType = "GamePassGift",
		}
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
		local activeRequest = self.Client.ActiveGiftRequest:GetFor(player)
		if not wasPurchased and activeRequest and activeRequest.ProductId == productId then
			self.Client.ActiveGiftRequest:ClearFor(player)
		end
	end)

end


function Service:PlayerHasPass(player, passName)
	if not player or not player:IsA("Player") or typeof(passName) ~= "string" then
		return
	end
	if not self.GamePasses[passName] then
		warn(("GamePass Not Found For \"%s\""):format(passName))
		return
	end

	local ownedPasses = self.Client.GamePasses:GetFor(player) or {}
	if ownedPasses[passName] then
		return true
	else
		local passId = self.GamePasses[passName]
		local isDeveloper = false --table.find({8801600,95451097},player.UserId)
		local savedPasses = Knit.GetService("ProfileService"):GetStatus(player, "OwnedGamepasses")

		if isDeveloper or (typeof(savedPasses) == "table" and table.find(savedPasses, passId)) then
			self.Client.GamePasses:SetFor(player, Sift.Dictionary.merge(ownedPasses, { [passName] = true }))
			return true
		end

		local ok, hasPass = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) end)
		if ok then
			self.Client.GamePasses:SetFor(
				player,
				Sift.Dictionary.merge(ownedPasses, { [passName] = hasPass })
			)
			return hasPass
		end
	end
	return false
end

function Service:GetProductName(productId)
	if typeof(productId) ~= "number" then
		warn("EconomyService:GetProductName() number expected, got ", typeof(productId))
		return
	end
	local product = self.Products[productId]
	return product and product.Name or nil
end

function Service:GetGamePassName(passId)
	if typeof(passId) ~= "number" then
		warn("EconomyService:GetGamePassName() number expected, got ", typeof(passId))
		return
	end
	for name,id in self.GamePasses do
		if id == passId then
			return name
		end
	end
end
function Service:GetProductId(productName)
	if typeof(productName) ~= "string" then
		warn("EconomyService:GetProductId() string expected, got ", typeof(productName))
		return
	end
	for id, p in self.Products do
		if p.Name:lower() == productName:lower() then
			return id
		end
	end
end

function Service:GetPurchaseLogs(player)
	local profile = Knit.GetService("ProfileService").Profiles[player]
	if profile then
		return profile:GetMetaTag("PurchaseIds")
	end
end

function Service:GrantProduct(player, productId, receiptInfo)
	--TODO: Handle Receipts

	local product = self.Products[productId]
	if product then
		local callback = product.Callback
		if product.ProductType == "GamePassGift" and typeof(self.GamePasses[product.Name]) == "number" then
			local passName = product.Name

			Knit.GetService("ProfileService"):Dispatch(player, {
				type = "ADD_GAME_PASS",
				payload = self.GamePasses[product.Name],
			})

			local data = self.Client.GamePasses:GetFor(player) or {}

			Knit.GetService("GameService"):SendNotification(player, `You have been gifted {passName} Game Pass.`,Color3.fromRGB(255,215,0))

			self.Client.GamePasses:SetFor(player, Sift.Dictionary.merge(data, { [product.Name] = true }))
			self.OnGamePassPurchased:Fire(player, passName)
		elseif typeof(callback) == "table" and typeof(callback.type) == "string" then
			if callback.type == "ADD_COINS" then
				Knit.GetService("ProfileService"):Dispatch(player, Sift.Dictionary.merge(callback,{
					logEconomy = { transactionType = Enum.AnalyticsEconomyTransactionType.IAP.Name }
				}))	
				self.Server:SendNotification(player, string.format("+%s COIN$ Rewarded",GameData.Utils.formatNumber(callback.payload)), Color3.fromRGB(253, 216, 53))

			else
				Knit.GetService("ProfileService"):Dispatch(player, callback)
			end
		elseif typeof(callback) == "function" then
			task.spawn(callback, player, self.Client)
		end
	end

	self.OnProductGranted:Fire(player, productId, receiptInfo)
end

function Service:KnitStart()
	self.Connections = {}
	local profileService = Knit.GetService("ProfileService")

	local function playerAdded(plr)
		local plrPasses = Sift.Dictionary.map(self.GamePasses, function(id, name)
			if typeof(id) == "number" then
				local ownsPass = self:PlayerHasPass(plr, name)
				return ownsPass, name
			end
		end)

		self.Client.GamePasses:SetFor(plr, plrPasses)
		plr:SetAttribute("IsVIP",self:PlayerHasPass(plr,"VIP"))
	end

	self.Connections.playerDataAdded = profileService.PlayerDataLoaded:Connect(playerAdded)
	self.Connections.playerRemoving = Players.PlayerRemoving:Connect(function(plr) self.Client.GamePasses:ClearFor(plr) end)
	self.Connections.promptGamePassPurchasedFinished = MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(plr, passId, wasPurchased)
			if not wasPurchased then return end
			local data = self.Client.GamePasses:GetFor(plr)
			local passName = self:GetGamePassName(passId)
	

			if data and passName then
				self.Client.GamePasses:SetFor(plr,
					Sift.Dictionary.merge(data, {
						[passName] = true,
					})
				)
				self.OnGamePassPurchased:Fire(plr, passName)
			end
		end
	)

	self.OnGamePassPurchased:Connect(function(plr, passName)
		if passName == "VIP" then plr:SetAttribute("IsVIP",true) end
	end)


	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local purchaseId = receiptInfo.PurchaseId
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if player then
			local profile = Knit.GetService("ProfileService").Profiles[player]
			if profile then
				if not profile or not profile:IsActive() then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				else
					local metaData = profile.MetaData

					local localPurchaseIds = metaData.MetaTags.ProfilePurchaseIds
					if localPurchaseIds == nil then
						localPurchaseIds = {}
						metaData.MetaTags.ProfilePurchaseIds = localPurchaseIds
					end

					-- Granting product if not received:
					if table.find(localPurchaseIds, purchaseId) == nil then
						while #localPurchaseIds >= 30 do
							table.remove(localPurchaseIds, 1)
						end
						table.insert(localPurchaseIds, purchaseId)


						local totalSpent = metaData.MetaTags.TotalCurrencySpent
						metaData.MetaTags.TotalCurrencySpent = (totalSpent or 0) + receiptInfo.CurrencySpent

						local activeRequest = self.Client.ActiveGiftRequest:GetFor(player)
						local productName = self:GetProductName(receiptInfo.ProductId)
						if activeRequest and activeRequest.ProductId == receiptInfo.ProductId and (activeRequest.TargetPlayer and activeRequest.TargetPlayer:IsA("Player")) then
							self:GrantProduct(activeRequest.TargetPlayer, receiptInfo.ProductId, receiptInfo)
							Knit.GetService("GameService"):SendNotification(activeRequest.TargetPlayer,
								`Successfully gifted {productName} to {player.Name}!`
							)
							self.Client.ActiveGiftRequest:ClearFor(player)
						else
							self:GrantProduct(player, receiptInfo.ProductId, receiptInfo)
						end
					end


					-- Waiting until the purchase is confirmed to be saved:
					local result = nil
					local function check_latest_meta_tags()
						local saved_purchase_ids = metaData.MetaTagsLatest.ProfilePurchaseIds
						if saved_purchase_ids ~= nil and table.find(saved_purchase_ids, purchaseId) ~= nil then
							result = Enum.ProductPurchaseDecision.PurchaseGranted
						end
					end

					check_latest_meta_tags()

					local meta_tags_connection = profile.MetaTagsUpdated:Connect(function()
						check_latest_meta_tags()
						-- When MetaTagsUpdated fires after profile release:
						if profile:IsActive() == false and result == nil then
							result = Enum.ProductPurchaseDecision.NotProcessedYet
						end
					end)

					while result == nil do
						task.wait()
					end

					meta_tags_connection:Disconnect()

					return result
				end
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

end


function Service.Client:GetProducts()
	local ugcProducts = Sift.Dictionary.map(self.Server.UGCItems, function(id)
		if typeof(id)~="number" then return end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
		end)
		if ok and info.IsForSale then
			local canBeSold = info.CanBeSoldInThisGame
			if not canBeSold then
				warn(("UGC Item <%d> can not be sold in this game"):format(info.AssetId))
				return
			end
			return {
				Name = info.Name,
				Description = info.Description,
				Price = info.PriceInRobux,
				Icon = string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", info.AssetId),
				ProductType = "UGC",
				ProductInfo = info,
			},info.AssetId
		end
	end)

	local passes = Sift.Dictionary.map(self.Server.GamePasses, function(id, k)
		if typeof(id) ~= "number" then return end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
		end)
		if not ok or typeof(info) ~= "table" then
			info = { Name = k }
		end
		return {
			Name = info.Name,
			Description = info.Description,
			Price = info.PriceInRobux,
			Icon = string.format("rbxthumb://type=GamePass&id=%d&w=150&h=150", id),
			ProductType = "Game Pass",
			ProductInfo = info,
		},id
	end)


	local devProducts = Sift.Dictionary.map(self.Server.Products, function(data,id)
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
		end)

		if ok and typeof(info)=="table" then
			return Sift.Dictionary.merge(data, {Price = info.PriceInRobux })
		end
		return data
	end)

	return Sift.Dictionary.merge(devProducts, ugcProducts, passes)
end

function Service.Client:PlayerHasPass(player, passName)
	return self.Server:PlayerHasPass(player, passName)
end

function Service.Client:PromptGift(player, targetPlayer, productId)
	if typeof(targetPlayer)~="Instance" or not targetPlayer:IsA("Player") then
		return false, "Invalid Recipient"
	end

	local passName = self.Server:GetGamePassName(productId)
	local product = self.Server.Products[productId]
	if passName then
		local giftProductId = self.Server:GetProductId(passName)
		if typeof(giftProductId) ~= "number" then
			warn(`No Gift Productid Found For "{passName or "???"}"`)
			return false
		elseif self.Server:PlayerHasPass(targetPlayer, passName) then
			Knit.GetService("GameService")
				:SendNotification(player, `{targetPlayer.Name} already owns "{passName}"`, "Fail", 5)
			return false, "Already Owned"
		end

		productId = giftProductId
	elseif not self.Server.Products[productId] then
		return false, "Invalid ProductId"
	elseif self.Server.Products[productId].ProductType == "LuckyWarrior" then
		local hasEmptySlot = Knit.GetService("GameService"):HasEmptySlot(targetPlayer)
		if not hasEmptySlot then
			Knit.GetService("GameService")
				:SendNotification(player, `{targetPlayer.Name} has no empty character slots!`, "Fail", 5)
			return false, "No Empty Slot"
		end
	end

	self.Server.Client.ActiveGiftRequest:SetFor(player, {
		TargetPlayer = targetPlayer,
		ProductId = productId,
	})

	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end

function Service.Client:PromptProduct(player, productId)
	local product = self.Server.Products[productId]
	if not product then
		return false, "Invalid ProductId"
	end

	if product.ProductType == "LuckyWarrior" then
		local hasEmptySlot = Knit.GetService("GameService"):HasEmptySlot(player)
		if not hasEmptySlot then
			Knit.GetService("GameService")
				:SendNotification(player, "You have no empty character slots!", "Fail", 5)
			return false, "No Empty Slot"
		end
	end

	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end


return Service
