local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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
