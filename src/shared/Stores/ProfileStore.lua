local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Array, Dictionary = Sift.Array, Sift.Dictionary


local inventoryReducer = function(state, action)
    local initialState = {
        Coins = 25,
        Tiers = Array.create(8,{
            Level = 1,
            NextUpgradeTime = nil
        }),
        Collection = {},
        IndexRewards = {},
        Characters = Array.create(8,"Empty")
    }
    state = state or initialState

    local payload = action.payload or {}
    if action.type == "ADD_COINS" and typeof(payload)=="number" then
        return Dictionary.update(state,"Coins",function(old)
            return math.max((tonumber(old) or 0)+ payload,0)
        end)
    elseif action.type == "SET_COINS" and typeof(payload)=="number" then
        return Dictionary.set(state,"Coins",math.max(payload,0))
    elseif action.type == "ADD_CHARACTER" then
        local slot = payload.slot or Array.findWhere(state.Characters,function(v) return v == "Empty" end)
        local mutation = payload.mutation or "Base"

        if typeof(slot)=="number" and state.Characters[slot] then
            return Dictionary.merge(state,{
                Characters = Array.set(state.Characters,slot,{
                    Name = payload.name,
                    Mutation = mutation,
                    Tier = payload.tier or 1,
                    Reward = 0,
                    Permanent = payload.permanent or false,
                    OfflineReward = 0,
                    IsLuckyWarrior = payload.charType == "LuckyWarrior",
                }),
                Collection = Dictionary.merge(state.Collection,{
                    [payload.name] = Dictionary.update(state.Collection[payload.name] or {},mutation,function(old)
                        return Dictionary.merge(old,{
                            TimesObtained = tonumber(old.TimesObtained or 0) + 1
                        })
                    end,function()
                        if not table.find({"Base","Gold","Diamond","Rainbow","Volcanic"},mutation) then
                            return { IsNew = false, TimesObtained = 1 }
                        end
                        return { IsNew = payload.charType ~= "LuckyWarrior", TimesObtained = 1 }
                    end)
                }),
            })
        end
    elseif action.type == "ADD_INDEX_REWARD" and typeof(payload)=="string" then
        return Dictionary.update(state,"IndexRewards",function(set)
            return Sift.Set.add(set,payload)
        end)
    elseif action.type == "VIEW_CHARACTER" then
        local name, mutation = payload.name, payload.mutation or "Base"

        if typeof(payload.name)=="string" then
            return Dictionary.merge(state,{
                Collection = Dictionary.update(state.Collection,name,function(charData)
                    return Dictionary.merge(charData or {},{
                        [mutation] = Dictionary.merge(charData and charData[mutation] or {},{
                            IsNew = false
                        })
                    })
                end)
            })
        else
            return Dictionary.merge(state,{
                Collection = Dictionary.map(state.Collection,function(v,k)
                    return Dictionary.map(v,function(v2)
                        return Dictionary.merge(v2,{
                            IsNew = false
                        })
                    end)
                end)
            })
        end
    elseif action.type == "UPDATE_PROFIT" and typeof(payload.slot)=="number" then
        local profit = tonumber(payload.amount) or 0
        local offline = tonumber(payload.offlineAmount) or 0

        return Dictionary.update(state,"Characters",function(list)
            return Array.update(list,payload.slot,function(chr)
                if chr and chr ~= "Empty" then
                    local new = Dictionary.merge(chr,{
                        Reward = math.max(0, (chr.Reward or 0) + profit),
                        OfflineReward = math.max(0, (chr.OfflineReward or 0) + offline)
                    })
                    return new
                end
                return chr
            end)
        end)
    elseif action.type == "MERGE_CHARACTER" and typeof(payload.slot)=="number" then
        return Dictionary.update(state,"Characters",function(list)
            local chr = list[payload.slot]
            if chr and chr~="Empty" then
                local idx = Array.findWhere(list,function(v,i)
                    return (v.Name == chr.Name and v.Tier == chr.Tier and v.Mutation == chr.Mutation) and payload.slot ~= i
                end)

                if idx then
                    list[idx] = "Empty"
                    list[payload.slot] = Dictionary.merge(chr,{
                        Tier = chr.Tier + 1
                    })
                end
            end
            return list
        end)
    elseif action.type == "SET_STOLEN" and typeof(payload.slot)=="number" then
        return Dictionary.merge(state,{
            Characters = Array.update(state.Characters,payload.slot,function(old)
                return Dictionary.merge(old,{ IsStolen = payload.active or Sift.None })
            end)
        })
    elseif action.type == "SET_CARRIED" and typeof(payload.slot)=="number" then
        return Dictionary.merge(state,{
            Characters = Array.update(state.Characters,payload.slot,function(old)
                return Dictionary.merge(old,{ IsCarried = payload.active or Sift.None })
            end)
        })
    elseif action.type == "MOVE_CHARACTER" and typeof(payload.slot)=="number" and typeof(payload.target)=="number" then
        return Dictionary.update(state,"Characters",function(list)
            local chr = list[payload.slot]
            local target = list[payload.target]
            if (chr and chr~="Empty") and target then
                return Dictionary.merge(list,{
                    [payload.slot] = (typeof(target)=="table" and next(target)~=nil) and target or "Empty",
                    [payload.target] = chr
                })
            end
            return list
        end)
    elseif action.type == "CLEAR_COLLECTION" then
        return Dictionary.merge(state,{
            Collection = {}
        })
    elseif action.type == "REMOVE_CHARACTER" then
        return Dictionary.merge(state,{
            Characters = Array.update(state.Characters,payload.slot,function() return "Empty" end)
        })
    elseif action.type == "CLEAR_CHARACTERS" then
        return Dictionary.merge(state,{
            Characters = Array.map(state.Characters,function(v)
                if v~="Empty" and (payload.excludePermanent and v.Permanent) then
                    return v
                else return "Empty" end
            end)
        })
    elseif action.type == "ADD_FLOOR" then
        return Dictionary.merge(state,{
            Characters = Array.concat(state.Characters,Array.create(8,"Empty")),
            Tiers = Array.concat(state.Tiers,Array.create(8,{ Level = 1 }))
        })
    elseif action.type == "REMOVE_TOOL" and typeof(payload.name)=="string" then
        return Dictionary.merge(state,{
            Tools = Array.filter(state.Tools,function(v)
                return v ~= payload.name
            end)
        })
    end

    return state
end

local statusReducer = function(state,action)
    state = state or {
        TutorialCompleted = false,
        OwnedGamepasses = {},
        IsVIP = false,
        AutoBuyItems = {},
        Spins = 0,
        NextSpinTime = os.time(),
    }

    local payload = action.payload
    if action.type == "SET_TUTORIAL_COMPLETED" then
        return Dictionary.merge(state,{ TutorialCompleted = true })
	elseif action.type == "ADD_GAME_PASS" and typeof(payload) == "number" then
		return Dictionary.update(state, "OwnedGamepasses", function(arr)
			return Sift.Set.toArray(Sift.Set.add(Sift.Array.toSet(arr), payload))
		end)
    elseif action.type == "SET_AUTO_BUY" and typeof(payload)=="table" then
        return Dictionary.update(state,"AutoBuyItems",function(set)
            if payload.active then
                return Sift.Set.add(set,payload.key)
            else
                return Sift.Set.delete(set,payload.key)
            end
        end)
    elseif action.type == "ADD_SPINS" then
        return Dictionary.update(state,"Spins",function(old)
            return math.max(old + math.max(1,tonumber(payload) or 0))
        end)
    elseif action.type == "USE_SPINS" then
        return Dictionary.update(state,"Spins",function(old)
            return math.max(old-1,0)
        end)
    elseif action.type == "CLAIM_SPIN" then
        local waitTime = tonumber(payload) or 7200
        return Dictionary.merge(state,{
            Spins = state.Spins + 1,
            NextSpinTime = os.time() + waitTime
        })
    end
    return state
end

local statisticReducer = function(state, action)
    local initialState ={
        Rebirths = 0,
        Steals = 0,
        IncomeRate = 0,
        IncomeMultiplier = 1,
        TierLimit = 5,
        LockTime = 30,
    }

    state = state or initialState

    local payload = action.payload or {}
    if action.type == "ADD_REBIRTH" then
        return Dictionary.update(state,"Rebirths",function(rebirths)
            return math.max((tonumber(rebirths) or 0)+1,0)
        end)

    elseif action.type == "ADD_STEALS" then
        return Dictionary.update(state,"Steals",function(steals)
            return math.max((tonumber(steals) or 0)+1,0)
        end)
    elseif action.type == "ADD_MULTIPLIER" and typeof(payload)=="number" then
        return Dictionary.update(state,"IncomeMultiplier",function(multi)
            return math.max((tonumber(multi) or 1)+ payload,1)
        end)
    elseif action.type == "ADD_LOCK_TIME" and typeof(payload)=="number" then
        return Dictionary.update(state,"LockTime",function(lockTime)
            return math.max((tonumber(lockTime) or 30)+ payload,0)
        end)
    elseif action.type == "SET_INCOME_RATE" and typeof(payload)=="number" then
        return Dictionary.merge(state,{ IncomeRate = math.max(payload,0) })
    elseif action.type == "SET_TIER_LIMIT" and typeof(payload)=="number" then
        return Dictionary.merge(state,{ TierLimit = math.max(payload,5) })
    elseif action.type == "RESET_STATS" then
       return initialState
    end
    return state
end

local settingsReducer = function(state,action)
    local initialSettings = {
        ["Music Volume"] = 1,
        ["Sound Effects"] = 1,
        ["VFX"] = true,
        ["Chat Tips"] = true,
        ["Banner Color"] = Color3.new(1,1,1):ToHex(),
        ["Base Theme"] = "Normal",
        ["Arrow Indicators"] = true,
    }
    state = state or initialSettings

    if action.type == "ADJUST_SETTING" then
        local payload = action.payload

        if Dictionary.has(state,payload.key) then
            local key = payload.key
            if key == "Banner Color" then
                return Dictionary.merge(state,{
                    [payload.key] = typeof(payload.value)=="Color3" and payload.value:ToHex()
                })
            elseif key:find("Volume$") then
                return Dictionary.merge(state,{
                    [payload.key] = typeof(payload.value)=="number" and math.clamp(payload.value,0,1)
                })
            else
                return Dictionary.merge(state,{
                    [payload.key] = payload.value or false
                })
            end
        end
    elseif action.type == "RESET_SETTINGS" then
        return initialSettings
    end

    return Sift.Dictionary.withKeys(state,unpack(Sift.Dictionary.keys(initialSettings)))
end






local rootReducer = Rodux.combineReducers({
    Inventory = inventoryReducer,
    Statistics = statisticReducer,
    Settings = settingsReducer,
    Status = statusReducer
})

return {
    new = function(initialState, middlewares)
        local reducer = function(state,action)
            if action.type == "SET_DATA" then
                return action.payload
            elseif action.type == "RESET_DATA" then
                return rootReducer(nil,{})
            end
            return rootReducer(state,action)
        end
        return Rodux.Store.new(reducer,initialState, middlewares)
    end,
    __template = rootReducer(nil,{})
}