local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")


local Effects = {}

function Effects.lightningStrike(position)
    local EffectsFolder = ServerStorage:WaitForChild("GameAssets"):FindFirstChild("Effects")

    if typeof(position)~="Vector3" then return end
    local effect = EffectsFolder:FindFirstChild("LightningStrike"):Clone()
    effect.CFrame = CFrame.new(position)
    effect.Anchored = true
    effect.Transparency = 1
    effect.Parent = workspace.Terrain


    local lingerTime = 1
    local beams, beamAttach0, beamAttach1 = {}, nil,nil
    for _,x in effect:GetDescendants() do
        if x:IsA("ParticleEmitter") then
            x:AddTag("VFX")
            local emitDelay = x:GetAttribute("EmitDelay")
            local emitCount = math.max(1,tonumber(x:GetAttribute("EmitCount")) or 1)
            if typeof(emitDelay)=="number" and emitDelay>0 then
                task.delay(emitDelay,function() x:Emit(emitCount) end)
                lingerTime = math.max(lingerTime,emitDelay+x.Lifetime.Max)
            else
                x:Emit(emitCount)
                lingerTime = math.max(lingerTime,x.Lifetime.Max)
            end
        elseif x:IsA("Beam") then
            x:AddTag("VFX")
            if not beamAttach0 then beamAttach0 = x.Attachment0 end
            if not beamAttach1 then beamAttach1 = x.Attachment1 end

            table.insert(beams,x)
            x.Enabled = true
        elseif x:IsA("Sound") then
            x:Play()
        end
    end

    if next(beams)~=nil and beamAttach0 and beamAttach1 then
        local tweens = {}
        for _,attach in ({beamAttach0,beamAttach1}) do
            local startPos = attach:GetAttribute("StartPosition") or Vector3.new()
            local endPos = attach:GetAttribute("EndPosition") or startPos
            local tweenTime = attach:GetAttribute("TweenTime") or .1

            if typeof(startPos)~="Vector3" or typeof(endPos)~="Vector3" then continue end

            attach.CFrame = CFrame.new(startPos)
            table.insert(tweens, TweenService:Create(attach,TweenInfo.new(tweenTime),{
                CFrame = CFrame.new(endPos)
            }))

            lingerTime = math.max(lingerTime,tweenTime)
        end



        for _,t in tweens do
            t:Play()
        end

        local stepConn
        local startTime, stepConn = tick() 
        stepConn = RunService.Heartbeat:Connect(function()
            local timeSinceStart = tick() - startTime

            local delayTime = .1
            local alpha = math.clamp((timeSinceStart-delayTime)/(lingerTime-delayTime),0,1)

            for _,b in beams do
                b.Transparency = NumberSequence.new(alpha)
            end

            if timeSinceStart>=lingerTime then
                for _,x in beams do x.Enabled = false end
                stepConn:Disconnect()

            end
        end)
    end

    Debris:AddItem(effect,lingerTime)
    return effect
end

function Effects.playEffect(templateName: string, position, scale)
    local EffectsFolder = ServerStorage:WaitForChild("GameAssets"):FindFirstChild("Effects")

    local template = EffectsFolder:FindFirstChild(templateName)
    if not template or not template:IsA("BasePart") or typeof(position)~="Vector3" then return end
    local effect = template:Clone()
    effect.CFrame = CFrame.new(position)
    effect.CanCollide = false
    effect.Anchored = true
    effect.Transparency = 1

    if typeof(scale)=="number" and scale>0 then
        local model = Instance.new("Model")
        effect.Parent = model
        model:ScaleTo(scale)
        effect.Parent = workspace.Terrain
        model:Destroy()
    else
        effect.Parent = workspace.Terrain
    end

    local lingerTime = 1
    for _,x in effect:GetDescendants() do
        if x:IsA("ParticleEmitter") then
            x.Enabled = false
            x:AddTag("VFX")
            local emitDelay = x:GetAttribute("EmitDelay")
            local emitCount = math.max(1,tonumber(x:GetAttribute("EmitCount")) or x.Rate)
            if typeof(emitDelay)=="number" and emitDelay>0 then
                task.delay(emitDelay,function() x:Emit(emitCount) end)
                lingerTime = math.max(lingerTime,emitDelay+x.Lifetime.Max)
            else
                x:Emit(emitCount)
                lingerTime = math.max(lingerTime,x.Lifetime.Max)
            end
        elseif x:IsA("Sound") then
            x:Play()
            lingerTime = math.max(lingerTime,x.TimeLength)
        end
    end

    Debris:AddItem(effect,lingerTime)

    return effect
end

return Effects