local GameData = {}

GameData.GamePasses = require(script.GamePass)
GameData.CharacterData = require(script.CharacterData)
GameData.ToolData = require(script.ToolData)
GameData.RebirthData = require(script.RebirthData)

GameData.Mutations = {
    Gold = 1.25,
    Diamond = 1.5,
    --Shocked = 4,
    --Fire = 6,
    Rainbow = 10
}





GameData.Utils = require(script.Utils)
GameData.Effects = require(script.Effects)


GameData.calculateProfit = function(profit: number, stars: number, slotTier: number, mutation: string)
    if typeof(profit)~="number" or profit<=0 then return end

    if typeof(mutation)=="string" and GameData.Mutations[mutation] then
        profit*=GameData.Mutations[mutation]
    end

    if typeof(stars)=="number" and stars>1 and stars<=5 then
        profit = profit*(2^(stars-1))
    end

    if typeof(slotTier)=="number" and slotTier>1 then
        local factor = 1+(.2*(slotTier-1))
        profit*=factor
    end

    return profit
end

return GameData