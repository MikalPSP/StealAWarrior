local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.OnStart():andThen(function()
    local economyService = Knit.GetService("EconomyService")
    TextChatService.OnChatWindowAdded = function(textChatMessage)
        local textSource = textChatMessage.TextSource
        local player = textSource and Players:GetPlayerByUserId(textSource.UserId)

        if player then
            local overrideProperties = TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties()
            overrideProperties.PrefixText = textChatMessage.PrefixText
            overrideProperties.Text = textChatMessage.Text

            if economyService:PlayerHasPass(player,"VIP") then
                overrideProperties.PrefixText = `<font color='#{Color3.fromRGB(239, 184, 56):ToHex()}'>[VIP]</font> {overrideProperties.PrefixText}`
            end

            return overrideProperties
        end
    end
end)