local Rebirths = {

    ["Rebirth 1"] = {
        Requirements = {
            Characters = {"Caveman Chieftan", "Egyptian Warrior"},
            Coins = 1_000_000, -- 1M
        },
        Rewards = {
            IncomeMultiplier = 0.5,
            LockTime = 30,
            Coins = 2000,
            Tools = {"Club","Gravity Coil","Iron Slap"},
        }
    },

    ["Rebirth 2"] = {
        Requirements = {
            Characters = {"Gladiator", "Roman Legionary"},
            Coins = 25_000_000, -- 25M
        },
        Rewards = {
            IncomeMultiplier = 0.5,
            LockTime = 30,
            Coins = 5000,
            Tools = {"Bee Launcher","Coil Combo","Volcanic Slap"},
        }
    },

    ["Rebirth 3"] = {
        Requirements = {
            Characters = {"Knight", "French Knight", "English Knight"},
            Coins = 100_000_000, -- 100M
        },
        Rewards = {
            IncomeMultiplier = 1,
            Coins = 10000,
            Tools = {"Raig Table","Acid Slap"},
            Floor = 2,
        }
    },

    ["Rebirth 4"] = {
        Requirements = {
            Characters = {"Crusader", "Dark Knight", "Teutonic Knight"},
            Coins = 250_000_000, -- 250M
        },
        Rewards = {
            IncomeMultiplier = 0.5,
            LockTime = 30,
            Coins = 25000,
            Tools = {"Gold Slap","Dance Grenade"},
        }
    },

    ["Rebirth 5"] = {
        Requirements = {
            Characters = {"Joan Of Arc", "Baldwin IV", "Richard The Lionheart"},
            Coins = 1_000_000_000, -- 1B
        },
        Rewards = {
            IncomeMultiplier = 0.5,
            Coins = 50000,
            Tools = {"Zeus's Hand"},
            Floor = 3,
        }
    },

}
return Rebirths
