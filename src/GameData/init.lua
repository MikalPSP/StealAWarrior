local GameData = {}

GameData.GamePasses = require(script.GamePass)
GameData.CharacterData = require(script.CharacterData)
GameData.ToolData = require(script.ToolData)
GameData.RebirthData = require(script.RebirthData)

GameData.Mutations = {
    Gold = 1.25,
    Diamond = 1.5,
    Volcanic = 2,
    Acid = 3,
    Shocked = 4,
    Divine = 5,
    Galaxy = 6,
    Rainbow = 10
}

GameData.SpinData = {
    { Reward = "Event",      Name = "Event", Weight = 0.5, Icon = "rbxassetid://77017545557069", Color = Color3.fromRGB(0, 255, 255) },

    -- Gold Event
    --{ Reward = "Event",      Name = "Event", Weight = 0.5, Icon = "rbxassetid://85833128748640", Color = Color3.fromRGB(0, 255, 255) },
    { Reward = "ServerLuck", Name = "2x Server Luck\n(15m)", Weight = 2, Icon = "rbxassetid://125659671905342", Color = Color3.fromRGB(0,255,0) },
    { Reward = "Coins_25K",  Name = "$25K", Weight = 55,  Icon = "rbxassetid://118183690055706", Color = Color3.fromRGB(255,255,0) },
    { Reward = "Character",  Name = "Raptorino", Weight = 1.0, Icon = "rbxassetid://140327277396024", Color = Color3.fromRGB(255, 0, 255) },
    { Reward = "Coins_100K", Name = "$100K", Weight = 34, Icon = "rbxassetid://86195196207111", Color = Color3.fromRGB(255,255,0) },
    { Reward = "Coins_1M",   Name = "$1M", Weight = 7.5, Icon = "rbxassetid://122774277931768", Color = Color3.fromRGB(255, 128, 0) },
}




GameData.Utils = require(script.Utils)
GameData.Effects = require(script.Effects)


GameData.calculateProfit = function(profit: number, stars: number, slotTier: number, mutation: string)
    if typeof(profit)~="number" or profit<=0 then return 0 end

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