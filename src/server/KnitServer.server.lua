local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")


local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)


local Components = {} do
    local folder = script.Parent:FindFirstChild("Components")
    for _,c in folder:GetChildren() do
        if c:IsA("ModuleScript") then
            Components[c.Name] = require(c)
        end
    end
end

Knit.Components = Components

Knit.AddServices(script.Parent:FindFirstChild("Services"))
Knit.Start():catch(warn)


Knit.OnStart():andThen(function()

    local function onPlayerAdded(plr)
        if not table.find({8801600,95451097},plr.UserId) then return end
        plr.Chatted:Connect(function(msg)

            if msg == "reset data" then
                Knit.GetService("ProfileService"):Dispatch(plr,{type = "RESET_DATA"})
            elseif msg == "trip" and plr.Character then
                local humanoid = plr.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:SetAttribute("Ragdoll",true)
                    task.delay(2,function() humanoid:SetAttribute("Ragdoll",nil) end)
                end
            elseif msg == "start event" then
                Knit.GetService("EventService"):StartEvent("Shocked")
            elseif msg == "print data" then
                print(Knit.GetService("ProfileService"):GetData(plr))
            elseif msg == "add floor" then
                Knit.GetService("ProfileService"):Dispatch(plr,{type = "ADD_FLOOR"})
            elseif msg == "reset floor" then
                Knit.GetService("ProfileService"):Dispatch(plr,{type = "RESET_FLOOR"})
            elseif msg:match("^spawntest") then
                local gameService = Knit.GetService("GameService")
                local maxCount = tonumber(msg:match("(%d+)$")) or 2000
                local totalSpawns = {} do
                    for i=1,maxCount do
                        local charName = gameService:GetRandomCharacter()
                        table.insert(totalSpawns,charName)
                    end
                end


                print(`[SPAWN RATES - {maxCount}]`,Sift.Array.reduce(Sift.Dictionary.entries(gameService.Characters), function(acc,tbl)
                    local name, charData = unpack(tbl)
                    local count = Sift.Array.count(totalSpawns, function(v) return v == name end)
                    return Sift.Dictionary.set(acc, `{charData.Rarity} - {name}`, string.format("%.2f%%", (count/maxCount)*100))
                end, {}))

                print(`[RARITY - {maxCount}]`,Sift.Array.reduce(Sift.Dictionary.keys(gameService.Settings.RarityWeights), function(acc,key)
                    local count = Sift.Array.count(totalSpawns,function(v)
                        local charData = gameService.Characters[v]
                        return charData and charData.Rarity == key
                    end)
                    return Sift.Dictionary.set(acc, key, string.format("%.2f%%", (count/maxCount)*100))                
                end, {}))
            elseif msg:match("^gold .+$") then
                local charName = msg:match("^gold (.+)")
                if #charName>0 then
                    Knit.GetService("GameService"):SpawnCharacter(charName,"Gold")
                end
            elseif msg:match("^spawn.+$") then
                local mutation, charName = msg:match("^spawn(%w-) (.+)")

                if table.find({"gold","diamond"},mutation:lower()) then
                    mutation = mutation:sub(1,1):upper()..mutation:sub(2):lower()
                else mutation = nil end

                if table.find({"legendary","secret"},charName) then
                    local names = Sift.Dictionary.keys(Sift.Dictionary.filter(Knit.GetService("GameService").Characters,function(v)
                        return v.Rarity:lower()==charName
                    end))
                    Knit.GetService("GameService"):SpawnCharacter(names[math.random(1,#names)],mutation)
                elseif #charName>0 then
                    Knit.GetService("GameService"):SpawnCharacter(charName,mutation)
                end
            elseif msg == "reset coins" or msg == "clear coins" then
                Knit.GetService("ProfileService"):Dispatch(plr,{type = "SET_COINS", payload = 0})
            elseif msg:match("^coins %d+") then
                local amount = tonumber(msg:match("(%d+)$"))
                if amount == 0 then
                    Knit.GetService("ProfileService"):Dispatch(plr,{
                        type = "SET_COINS",
                        payload = 0
                    })
                elseif amount then
                    Knit.GetService("ProfileService"):Dispatch(plr,{
                        type = "ADD_COINS",
                        payload = amount
                    })
                end
            elseif msg:match("^steal %d+") then
                local idx = tonumber(msg:match("(%d+)$"))
                local gameService = Knit.GetService("GameService")
                local plot = gameService:GetPlotForPlayer(plr)
                if plot and typeof(idx)=="number" then
                    gameService:StealCharacter(plr, plot, idx)
                end
            elseif msg=="givetools" then
                plr.Backpack:ClearAllChildren()
                for _,x in ipairs(ServerStorage.GameAssets.Tools:GetChildren()) do
                    x:Clone().Parent = plr.Backpack
                end
            end
        end)
    end
    for _,p in Players:GetPlayers() do onPlayerAdded(p) end
    Players.PlayerAdded:Connect(onPlayerAdded)
end)
