local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sift = require(ReplicatedStorage.Packages.Sift)

local Service = Knit.CreateService({
    Name = "AnalyticsService",
    Client = {
        FunnelSessions = Knit.CreateProperty({})
    },

})


function Service:KnitStart()
    
end

function Service:GetFunnelSession(player, funnelName)
    local session = self.Client.FunnelSessions:GetFor(player)[funnelName]
    if session then
        return Sift.Dictionary.merge(session,{
            StartTime = Sift.None,
            Duration = (os.time() - session.StartTime)
        })
    end
end

function Service:LogFunnelStepEvent(player, funnelName, stepName: string|number, finished: boolean?, customFields: {[number]: string}?)
    local session = self.Client.FunnelSessions:GetFor(player)[funnelName]
    if (session and session.StepName == stepName) or (not session and finished) then
        return
    end
    if not session then
        session = {
            Id = HttpService:GenerateGUID(false):sub(1,8):upper(),
            StepIndex = 1,
            StepName = stepName,
            StartTime = os.time()
        }
    else
        session.StepIndex += 1
        session.StepName = stepName
    end

    if typeof(stepName)=="number" then
        if session.StepIndex == stepName then return end
        session.StepIndex = stepName
        session.StepName = nil
    end


    local is_valid = typeof(customFields)=="table" and Sift.Array.every(customFields, function(v) return typeof(v)=="string" end)

    AnalyticsService:LogFunnelStepEvent(player, funnelName, session.Id, session.StepIndex, session.StepName, is_valid and {
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = customFields[1],
        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = customFields[2],
        [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = customFields[3],
    } or nil)

    self.Client.FunnelSessions:SetFor(player, Sift.Dictionary.merge(self.Client.FunnelSessions:GetFor(player),{
        [funnelName] = finished and Sift.None or session
    }))

end


function Service.Client:LogTutorial(player, stepNum)

    local funnelSession = self.Server:GetFunnelSession("Tutorial") or {}

    local statusData = Knit.GetService("ProfileService"):GetStatus(player)
    if not statusData or not statusData.TutorialCompleted then
        return
    end

    local USE_ONBOARDING = false
    if USE_ONBOARDING then
        if stepNum == 1 then
            AnalyticsService:LogOnboardingFunnelStepEvent(player,1,"Joined Game")
        elseif stepNum == 2 then
            AnalyticsService:LogOnboardingFunnelStepEvent(player,2,"Buy Caveman Warrior")
        elseif stepNum == 3 then
            local joinTime = Knit.GetService("ProfileService").JoinTimes[player]
            local duration = typeof(joinTime)=="number" and os.time() - joinTime or nil
            AnalyticsService:LogOnboardingFunnelStepEvent(player,3,"Earn 500 Coins",{
                [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = duration and math.floor(duration*10)/10 or nil
            })
        end
    else
        if stepNum == 1 then
            self.Server:LogFunnelStepEvent(player, "Tutorial", "Start")
        elseif stepNum == 2 then
            self.Server:LogFunnelStepEvent(player, "Tutorial", "Buy Character")
        elseif stepNum == 3 then
            self.Server:LogFunnelStepEvent(player, "Tutorial", "Earn Coins", true, {funnelSession.Duration})
        end
    end
end



return Service
