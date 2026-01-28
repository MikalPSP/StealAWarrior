local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerChannel = TextChatService:WaitForChild("TextChannels"):FindFirstChild("RBXGeneral")

local TIP_INTERVAL = 300
local CAN_ANNOUNCE = true

Knit.OnStart():andThen(function()
    Knit.GetService("ProfileService").Data:Observe(function(data)
        CAN_ANNOUNCE = data.Settings and data.Settings["Chat Tips"] or false
    end)
end)


TextChatService.OnChatWindowAdded = function(textChatMessage)
    local textSource = textChatMessage.TextSource
    local player = textSource and Players:GetPlayerByUserId(textSource.UserId)

    if player then
        local overrideProperties = TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties()
        overrideProperties.Text = textChatMessage.Text

        if player:GetAttribute("IsVIP") then
            overrideProperties.PrefixText = `<font color='#{Color3.fromRGB(239, 184, 56):ToHex()}'>[VIP]</font> {textChatMessage.PrefixText}`
        end

        return overrideProperties

    end
end


task.spawn(function()
    local messages = {
        {"[TIP] Try your luck at the wheel spin. You can get a free spin every 2 hours!", Color3.fromRGB(85, 170, 0)},
        {"[TIP] Your warriors earn coins offline when you leave the game!", Color3.fromRGB(85, 170, 0)},
        {"[TIP] Invite friends to team up and steal warriors together!", Color3.fromRGB(255, 204, 0)},
        {"[TIP] Rebirthing unlocks new upgrades, tools, and bonuses!", Color3.fromRGB(85, 170, 0)},
    }

    while true do
        for _,msgData in messages do
            task.wait(TIP_INTERVAL)
            local message, color = unpack(msgData)
            if typeof(color)=="Color3" then
                message = `<font color='#{color:ToHex()}'>{message}</font>`
            end

            if CAN_ANNOUNCE then
                ServerChannel:DisplaySystemMessage(message, "Server")
            end
        end
    end
end)

