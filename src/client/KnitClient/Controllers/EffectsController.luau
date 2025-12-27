local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local EffectsController = Knit.CreateController({
    Name = "EffectsController",
    Enabled = true
})

function EffectsController:KnitInit()
    
end

function EffectsController:SetEnabled(on)
    if self.Enabled == on then return end
    self.Enabled = on

    for _,x in workspace:GetDescendants() do
        if x:IsA("ParticleEmitter") and (table.find({"Fire","Specks","Smoke"},x.Name)~=nil or x:HasTag("VFX")) then
            x.Enabled = self.Enabled
            x:Clear()
        end
    end

    if self.Enabled then

    else

    end
end


function EffectsController:KnitStart()
    Knit.GetService("ProfileService").Data:Observe(function(data)
        self:SetEnabled(data.Settings["VFX"])
    end)
end




return EffectsController
