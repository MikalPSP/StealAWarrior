local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)


--// SERVICE
local Service = Knit.CreateService({
    Name = "BadgeService",
    Badges = {
        Welcome = 2740968212029559,

        Coins_1M = 4166401402106855,
        Coins_10M = 4500032886690967,
        Coins_100M = 967116281320296,
        Coins_1B = 2590323135433149,


        Steals_Bronze = 2863045125845285,
        Steals_Silver = 2919862006077815,
        Steals_Gold = 3673646118285616,
        Steals_Winged = 2855485226100898,
        Steals_Master = 3018496140057955,

        Base_Gold = 4276894511972267,
        Base_Diamond = 2231302135289247,
        Base_Rainbow = 2603077178423679,
    }
})


function Service:KnitStart()
    Players.PlayerAdded:Connect(function(player: Player) self:AwardBadge(player, "Welcome") end)
    for _,plr in Players:GetPlayers() do self:AwardBadge(plr, "Welcome") end

    local profileService = Knit.GetService("ProfileService")
    profileService.PlayerDataLoaded:Connect(function(player: Player, state)
        if typeof(state)~="table" then return end

        local coins = state.Inventory.Coins
        if coins then
            if coins >= 1_000_000 then self:AwardBadge(player, "Coins_1M") end
            if coins >= 10_000_000 then self:AwardBadge(player, "Coins_10M") end
            if coins >= 100_000_000 then self:AwardBadge(player, "Coins_100M") end
            if coins >= 1_000_000_000 then self:AwardBadge(player, "Coins_1B") end
        end

        local steals = state.Statistics.Steals
        if steals then
            if steals >= 50 then self:AwardBadge(player, "Steals_Bronze") end
            if steals >= 150 then self:AwardBadge(player, "Steals_Silver") end
            if steals >= 300 then self:AwardBadge(player, "Steals_Gold") end
            if steals >= 800 then self:AwardBadge(player, "Steals_Winged") end
            if steals >= 1000 then self:AwardBadge(player, "Steals_Master") end
        end

        local indexRewards = state.Inventory.IndexRewards
        if indexRewards then
            if Sift.Set.has(indexRewards,"Gold") then
                self:AwardBadge(player, "Base_Gold")
            elseif Sift.Set.has(indexRewards,"Diamond") then
                self:AwardBadge(player, "Base_Diamond")
            elseif Sift.Set.has(indexRewards,"Rainbow") then
                self:AwardBadge(player, "Base_Rainbow")
            end
        end
    end)

    profileService.PlayerDataChanged:Connect(function(player, state, lastState)
        if typeof(state)~="table" or typeof(lastState)~="table" then return end

        local coins = state.Inventory.Coins
        if coins and coins > lastState.Inventory.Coins then
            if coins >= 1_000_000 and lastState.Inventory.Coins < 1_000_000 then self:AwardBadge(player, "Coins_1M") end
            if coins >= 10_000_000 and lastState.Inventory.Coins < 10_000_000 then self:AwardBadge(player, "Coins_10M") end
            if coins >= 100_000_000 and lastState.Inventory.Coins < 100_000_000 then self:AwardBadge(player, "Coins_100M") end
            if coins >= 1_000_000_000 and lastState.Inventory.Coins < 1_000_000_000 then self:AwardBadge(player, "Coins_1B") end
        end

        local steals = state.Statistics.Steals
        if steals and steals > lastState.Statistics.Steals then
            if steals >= 50 and lastState.Statistics.Steals < 50 then self:AwardBadge(player, "Steals_Bronze") end
            if steals >= 150 and lastState.Statistics.Steals < 150 then self:AwardBadge(player, "Steals_Silver") end
            if steals >= 300 and lastState.Statistics.Steals < 300 then self:AwardBadge(player, "Steals_Gold") end
            if steals >= 800 and lastState.Statistics.Steals < 800 then self:AwardBadge(player, "Steals_Winged") end
            if steals >= 1000 and lastState.Statistics.Steals < 1000 then self:AwardBadge(player, "Steals_Master") end
        end

        local indexRewards = state.Inventory.IndexRewards
        if indexRewards ~= lastState.Inventory.IndexRewards then
            if Sift.Set.has(indexRewards,"Gold") then
                self:AwardBadge(player, "Base_Gold")
            elseif Sift.Set.has(indexRewards,"Diamond") then
                self:AwardBadge(player, "Base_Diamond")
            elseif Sift.Set.has(indexRewards,"Rainbow") then
                self:AwardBadge(player, "Base_Rainbow")
            end
        end
    end)

end

function Service:AwardBadge(recipient: Player, badge: string)
    local badgeId = self.Badges[badge]
    if not badgeId or typeof(badgeId)~="number" or badgeId<=0 or typeof(recipient)~="Instance" or not recipient:IsA("Player") then return end

    local ok,hasBadge = pcall(function() return BadgeService:UserHasBadgeAsync(recipient.UserId,badgeId) end)
    if ok and not hasBadge then
        local didAward, result = pcall(BadgeService.AwardBadgeAsync, BadgeService, recipient.UserId, badgeId)
        if not didAward then
            warn(("Failed To Award Badge <%s> To <%d>: %s"):format(badge, recipient.UserId, tostring(result)))
            return false
        end
        return true
    end
end

return Service