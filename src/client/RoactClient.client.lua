
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local LocalPlayer = game:GetService("Players").LocalPlayer
local UI = ReplicatedStorage:WaitForChild("UI")
local App = require(UI.App)

Roact.setGlobalConfig({
    elementTracing = true,
})

local tree = Roact.mount(Roact.createElement(App), LocalPlayer:WaitForChild("PlayerGui"),"App")
