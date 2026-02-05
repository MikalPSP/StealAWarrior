local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sift = require(ReplicatedStorage.Packages.Sift)

local Utils = require(script.Parent.Utils)


local function CalculateProfit(rarity, index)

    local rarityCurve = {
    Common     = {a = 1,    b = 1.55},
    Rare       = {a = 15,   b = 1.35},
    Epic       = {a = 75,   b = 1.22},
    Legendary  = {a = 200,  b = 1.45},
    Mythic     = {a = 1900, b = 1.80},
}

    local r = rarityCurve[rarity]
    return math.floor(r.a * (index ^ r.b))
end


local Data = {

    -- Commons (8)
    ["Caveman Warrior"]        = { Index = 1,  Rarity = "Common",    Era = "Prehistoric", Profit = 1,     Price = 25 },
    ["Caveman Elder"]          = { Index = 2,  Rarity = "Common",    Era = "Prehistoric", Profit = 3,     Price = 250 },
    ["Caveman Chieftan"]       = { Index = 3,  Rarity = "Common",    Era = "Prehistoric", Profit = 5,     Price = 500 },
    ["Egyptian Warrior"]       = { Index = 4,  Rarity = "Common",    Era = "Ancient",     Profit = 7,     Price = 750 },
    ["Spartan Warrior"]        = { Index = 5,  Rarity = "Common",    Era = "Ancient",     Profit = 9,     Price = 1000 },
    ["Roman Legionary"]        = { Index = 6,  Rarity = "Common",    Era = "Ancient",     Profit = 10,    Price = 1200 },
    ["Roman Signifer"]         = { Index = 7,  Rarity = "Common",    Era = "Ancient",     Profit = 13,    Price = 1500 },
    ["Persian Warrior"]        = { Index = 8,  Rarity = "Common",    Era = "Ancient",     Profit = 14,    Price = 1750 },



    -- Rare (10)
    ["Skull Hunter"]           = { Index = 1,  Rarity = "Rare",      Era = "Prehistoric", Profit = 15,    Price = 2000 },
    ["Persian Immortal"]       = { Index = 2,  Rarity = "Rare",      Era = "Medieval",    Profit = 20,    Price = 3000 },
    ["Viking Warrior"]         = { Index = 3,  Rarity = "Rare",      Era = "Ancient",     Profit = 30,    Price = 4000 },
    ["Greek Warrior"]          = { Index = 4,  Rarity = "Rare",      Era = "Ancient",     Profit = 35,    Price = 4500 },
    ["Gladiator"]              = { Index = 5,  Rarity = "Rare",      Era = "Ancient",     Profit = 40,    Price = 5000 },
    ["Gallic Warrior"]         = { Index = 6,  Rarity = "Rare",      Era = "Ancient",     Profit = 50,    Price = 6500 },
    ["Germanic Warrior"]       = { Index = 7,  Rarity = "Rare",      Era = "Ancient",     Profit = 55,    Price = 7500 },
    ["Carthaginian Warrior"]   = { Index = 8,  Rarity = "Rare",      Era = "Ancient",     Profit = 65,    Price = 9000 },
    ["Viking Berserker"]       = { Index = 9,  Rarity = "Rare",      Era = "Medieval",    Profit = 70,    Price = 9500 },
    ["Chinese Warrior"]        = { Index = 10, Rarity = "Rare",      Era = "Medieval",    Profit = 75,    Price = 10000 },



    -- Epic (12)
    ["Dinosaur"]               = { Index = 1,  Rarity = "Epic",      Era = "Prehistoric", Profit = 85,    Price = 10000 },
    ["Praetorian Guard"]       = { Index = 2,  Rarity = "Epic",      Era = "Ancient",     Profit = 100,   Price = 15000 },
    ["Roman Centurion"]        = { Index = 3,  Rarity = "Epic",      Era = "Ancient",     Profit = 115,   Price = 17500 },
    ["Byzantine Warrior"]      = { Index = 4,  Rarity = "Epic",      Era = "Ancient",     Profit = 125,   Price = 20000 },
    ["Knight"]                 = { Index = 5,  Rarity = "Epic",      Era = "Medieval",    Profit = 135,   Price = 22500 },
    ["French Knight"]          = { Index = 6,  Rarity = "Epic",      Era = "Medieval",    Profit = 150,   Price = 25000 },
    ["English Knight"]         = { Index = 7,  Rarity = "Epic",      Era = "Medieval",    Profit = 160,   Price = 27500 },
    ["Ninja"]                  = { Index = 8,  Rarity = "Epic",      Era = "Medieval",    Profit = 175,   Price = 30000 },
    ["Crusader"]               = { Index = 9,  Rarity = "Epic",      Era = "Medieval",    Profit = 225,   Price = 35000 },
    ["Dark Knight"]            = { Index = 10, Rarity = "Epic",      Era = "Medieval",    Profit = 250,   Price = 40000 },
    ["Teutonic Knight"]        = { Index = 11, Rarity = "Epic",      Era = "Medieval",    Profit = 275,   Price = 42500 },
    ["Winged Hussar"]          = { Index = 12, Rarity = "Epic",      Era = "Medieval",    Profit = 300,   Price = 45000 },

    -- Legendary (15)
    ["Samurai"]                = { Index = 1,  Rarity = "Legendary", Era = "Medieval",    Profit = 350,   Price = 50000 },
    ["Joan of Arc"]            = { Index = 2,  Rarity = "Legendary", Era = "Medieval",    Profit = 400,   Price = 75000 },
    ["Baldwin IV"]             = { Index = 3,  Rarity = "Legendary", Era = "Medieval",    Profit = 500,   Price = 100000 },
    ["Saladin"]                = { Index = 4,  Rarity = "Legendary", Era = "Medieval",    Profit = 550,   Price = 125000 },
    ["Vlad the Impaler"]       = { Index = 5,  Rarity = "Legendary", Era = "Medieval",    Profit = 600,   Price = 150000 },
    ["Robin Hood"]             = { Index = 6,  Rarity = "Legendary", Era = "Medieval",    Profit = 650,   Price = 175000 },
    ["Cleopatra"]              = { Index = 7,  Rarity = "Legendary", Era = "Ancient",     Profit = 750,   Price = 200000 },
    ["Hannibal Barca"]         = { Index = 8,  Rarity = "Legendary", Era = "Ancient",     Profit = 900,   Price = 225000 },
    ["Julius Caesar"]          = { Index = 9,  Rarity = "Legendary", Era = "Ancient",     Profit = 1000,  Price = 250000 },
    ["Marcus Aurelius"]        = { Index = 10, Rarity = "Legendary", Era = "Ancient",     Profit = 1100,  Price = 275000 },
    ["Tomyris"]                = { Index = 11, Rarity = "Legendary", Era = "Ancient",     Profit = 1250,  Price = 300000 },
    ["Zenobia"]                = { Index = 12, Rarity = "Legendary", Era = "Ancient",     Profit = 1350,  Price = 325000 },
    ["Ragnar Lothbrok"]        = { Index = 13, Rarity = "Legendary", Era = "Medieval",    Profit = 1450,  Price = 340000 },
    ["Richard the Lionheart"]  = { Index = 14, Rarity = "Legendary", Era = "Medieval",    Profit = 1500,  Price = 350000 },
    ["King Arthur"]            = { Index = 15, Rarity = "Legendary", Era = "Medieval",    Profit = 1700,  Price = 375000 },

    -- Mythic (13)
    ["Achilles"]               = { Index = 1,  Rarity = "Mythic", Era = "Ancient",         Profit = 1900,  Price = 350000 }, 
    ["Artemis"]                = { Index = 2,  Rarity = "Mythic", Era = "Ancient",         Profit = 2000,  Price = 400000 },
    ["Athena"]                 = { Index = 3,  Rarity = "Mythic", Era = "Ancient",         Profit = 2100,  Price = 450000 },
    ["Sun Tzu"]                = { Index = 4,  Rarity = "Mythic", Era = "Ancient",         Profit = 2500,  Price = 500000 },
    ["Blackbeard"]             = { Index = 5,  Rarity = "Mythic", Era = "Medieval",        Profit = 3000,  Price = 600000 },
    ["William Wallace"]        = { Index = 6,  Rarity = "Mythic", Era = "Medieval",        Profit = 3500,  Price = 700000 },
    ["Alexander the Great"]    = { Index = 7,  Rarity = "Mythic", Era = "Medieval",        Profit = 4000,  Price = 800000 },
    ["Genghis Khan"]           = { Index = 8,  Rarity = "Mythic", Era = "Medieval",        Profit = 4500,  Price = 900000 },
    ["Polyphemus"]             = { Index = 9,  Rarity = "Mythic", Era = "Ancient",         Profit = 5000,  Price = 1_000_000 },
    ["Ares"]                   = { Index = 10, Rarity = "Mythic", Era = "Ancient",         Profit = 6000,  Price = 2_000_000 },
    ["Poseidon"]               = { Index = 11, Rarity = "Mythic", Era = "Ancient",         Profit = 7000,  Price = 3_000_000 },
    ["Hades"]                  = { Index = 12, Rarity = "Mythic", Era = "Ancient",         Profit = 8000,  Price = 4_000_000 },
    ["Zeus"]                   = { Index = 13, Rarity = "Mythic", Era = "Ancient",         Profit = 9000,  Price = 5_000_000, WeightFactor = 0.75 },

    -- Secret (6)
    ["Skeletino Raptorino"]    = { Index = 1,  Rarity = "Secret", Era = "Prehistoric",     Profit = 5000,  Price = 750000 },
    ["Sabertoothy Chomperino"] = { Index = 2,  Rarity = "Secret", Era = "Prehistoric",     Profit = 6000,  Price = 1_000_000 },
    ["Chariotus Spoketron"]    = { Index = 3,  Rarity = "Secret", Era = "Ancient",         Profit = 8000,  Price = 2_000_000 },
    ["Cerberino Vulcano"]      = { Index = 4,  Rarity = "Secret", Era = "Ancient",         Profit = 10000, Price = 3_500_000, WeightFactor = 2 },
    ["Regalroar Majestico"]    = { Index = 5,  Rarity = "Secret", Era = "Medieval",        Profit = 12500, Price = 5_000_000 },
    ["Samurino Craneo"]        = { Index = 6,  Rarity = "Secret", Era = "Medieval",        Profit = 15000, Price = 7_500_000 },
    --["Napolini Cannonini"]     = { Index = 7,  Rarity = "Secret", Era = "Early Modern",        Profit = 25000, Price = 10_000_000, WeightFactor = 0 },

    ["The Emperor"]            = { Index = 1,  Rarity = "OG", Era = "Ancient",         Profit = 50000, Price = 1_000_000_000, WeightFactor = 0 },

    ["Rare Lucky Warrior"]      = { Index = 1, Rarity = "Rare",      Type = "LuckyWarrior",   Profit = 0, Price = 0, WeightFactor = 0 },
    ["Epic Lucky Warrior"]      = { Index = 2, Rarity = "Epic",      Type = "LuckyWarrior",   Profit = 0, Price = 0, WeightFactor = 0 },
    ["Legendary Lucky Warrior"] = { Index = 3, Rarity = "Legendary", Type = "LuckyWarrior",   Profit = 0, Price = 0, WeightFactor = 0 },
    ["Mythic Lucky Warrior"]    = { Index = 4, Rarity = "Mythic",    Type = "LuckyWarrior",   Profit = 0, Price = 0, WeightFactor = 0 },
    ["Secret Lucky Warrior"]    = { Index = 5, Rarity = "Secret",    Type = "LuckyWarrior",   Profit = 0, Price = 0, WeightFactor = 0 },
}

return Data