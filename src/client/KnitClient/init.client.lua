local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TopBar = require(ReplicatedStorage.Packages.Topbar)

Knit.GetIcon = function(iconName: string)
    local icon = TopBar.getIcon(iconName)
    if not icon then
        icon = TopBar.new():setName(iconName)
    end
    return icon
end

Knit.AddControllers(script:FindFirstChild("Controllers"))

Knit.Start():catch(warn)