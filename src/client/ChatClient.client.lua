local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ServerChannel = TextChatService:WaitForChild("TextChannels"):FindFirstChild("RBXGeneral")

local function Announce(message, color)
    if typeof(message)~="string" then return end
    if typeof(color)=="Color3" then
        message = `<font color='#{color:ToHex()}'>{message}</font>`
    end
    ServerChannel:DisplaySystemMessage(message, "Server")
end

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
    local interval = 300
    while true do
        task.wait(interval)
        Announce("[TIP] Your warriors earn coins offline when you leave the game!", Color3.fromRGB(85, 170, 0))
        task.wait(interval)
        Announce("[TIP] Invite friends to team up and steal warriors together!", Color3.fromRGB(255, 204, 0))
        task.wait(interval)
        Announce("[TIP] Rebirthing unlocks new upgrades, tools, and bonuses!", Color3.fromRGB(85, 170, 0))
    end
end)

