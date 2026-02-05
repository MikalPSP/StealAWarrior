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

function Service:GetFunnelSession(player, funnelName)
    if not player or typeof(funnelName)~="string" then return end
    local session = self.Client.FunnelSessions:GetFor(player)[funnelName]
    if session then
        return Sift.Dictionary.merge(session,{
            StartTime = Sift.None,
            Duration = (os.time() - session.StartTime)
        })
    end
end

function Service:LogFunnelStep(player, funnelName, stepName: string, finished: boolean?, customFields: {[number]: string}?)
    if not player or typeof(stepName)~="string" or typeof(funnelName)~="string" then return end
    local session = self.Client.FunnelSessions:GetFor(player)[funnelName]

    if (session and (session.IsFinished or table.find(session.FinishedEvents,stepName))) or (not session and finished) then
        return
    end

    if not session then
        session = {
            Id = HttpService:GenerateGUID(false):sub(1,8):upper(),
            StepName = stepName,
            StepIndex = 0,
            StartTime = os.time(),
            FinishedEvents = {},
        }
    end

    session.StepIndex += 1
    session.StepName = stepName
    session.FinishedEvents = Sift.Array.append(session.FinishedEvents or {},stepName)
    session.IsFinished = finished


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

return Service
