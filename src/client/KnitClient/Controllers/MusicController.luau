local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Sift = require(ReplicatedStorage.Packages.Sift)

local SOUND_GROUP_NAME = "BackgroundMusic"


local MusicController = Knit.CreateController({
    Name = "MusicController",
    Tracks = {},
    PlayingTracks = {},
    ActiveTrack = nil,
    Settings = {
        FadeInTime = 1,
        FadeOutTime = 1,
        MusicVolume = 1
    },

    onMutedChanged = Signal.new(),

    MusicList = {
        Normal = {
            --["Zenhiser - TRANCEAFTERBURN"] = "rbxassetid://73731605864817",
            --["Zenhiser - SKYDANCER"] = "rbxassetid://132688754697351",
            --["Zenhiser - MAJESTIC"] = "rbxassetid://124400669675204",
            ["Fury of the Northmen"] = "rbxassetid://91284201329036",
            ["Voodoo Warrior"] = "rbxassetid://9046952451",
            ["The Warrior King's Lament"] = "rbxassetid://92188346907148", --Divine Maybe?
            ["La Cumbia Warrior"] = "rbxassetid://97152892719906",
            ["Odin's Oath"] = "rbxassetid://130800347561846",
            ["Warrior's Honor"] = "rbxassetid://139658293130549",



        },

        EventBased = {
            --Galaxy Maybe?
            ["Clair De Lune"] = "rbxassetid://1838457617",

            -- Maybe For Volcanic Event?
            ["Volcanoes On Mars"] = "rbxassetid://9045937563",
            ["Battle of the Warriors"] = "rbxassetid://1838685303",
        }
    }
})

function MusicController:KnitInit()

    local soundGroup = Instance.new("SoundGroup")
    soundGroup.Name = SOUND_GROUP_NAME
    soundGroup.Volume = 0
    soundGroup.Parent = SoundService

    self.CurrentPlayingGroup = nil
    self.IsPlaying = false
    self.IsMuted = false
    self.Volume = 0
    self.Tracks = {}
    self.PlayingTracks = {}
    self.SoundGroup = soundGroup

    for group,list in self.MusicList do
        local subFolder = Instance.new("Folder")
        subFolder.Name = group.."Tracks"
        for name,soundId in pairs(list) do

            local sound = Instance.new("Sound")
            sound.Name = name
            sound.Volume = 1
            sound.SoundId = soundId
            sound.Parent = subFolder
            sound.SoundGroup = soundGroup

            if not self.Tracks[group] then
                self.Tracks[group] = {}
            end
            table.insert(self.Tracks[group],sound)
        end

        subFolder.Parent = soundGroup
    end
end


function MusicController:SetVolume(volume)
    if not volume or typeof(volume) ~= "number" then
        return
    end

    volume = math.clamp(volume,0,1)
    local willMute = volume == 0

    if willMute ~= self.IsMuted then
        self.onMutedChanged:Fire(willMute)
    end

    self.Volume = volume
    self.IsMuted = willMute

    TweenService:Create(self.SoundGroup,TweenInfo.new(self:GetSetting("FadeInTime",.1)),{Volume = volume}):Play()
end

function MusicController:GetSetting(key,defaultValue)
    local val = self.Settings[key]
    if val ~= nil then
        return val
    end
    return defaultValue
end

function MusicController:SetPlaying(name)
    if not self.Tracks[name] then
        warn(string.format("MusicController:SetPlayingGroup() No TrackGroup Named \"%s\" Found.",name))
        return
    elseif self.CurrentPlayingGroup == name then
        return
    end

    self.CurrentPlayingGroup = name
    self.IsPlaying = name ~= nil

    local tweens = {}
    for group,list in self.Tracks do
        for _,s in list do
            if s:IsA("Sound") then
                table.insert(tweens,TweenService:Create(s,TweenInfo.new(.1),{
                    Volume = (name and group==name) and self:GetSetting("MusicVolume",1) or 0
                }))
            end
        end
    end

    for _,t in tweens do
        t:Play()
    end
end


function MusicController:KnitStart()
    self:SetPlaying("Normal")

    for group,list in self.Tracks do
        local shuffledList = Sift.Array.shuffle(Sift.Dictionary.values(list))
        if #list>0 then
            task.spawn(function()
                for _,s in shuffledList do
                    if s.IsPlaying then s:Stop() end
                end
    
                while true do
                    repeat task.wait() until self.CurrentPlayingGroup == group

                    for _,s in list do
                        if s.IsPlaying then s:Stop() end
                        s.Volume = 1 s:Play()

                        self.ActiveTrack = s
                        repeat task.wait() until (not s.IsPlaying)
                        self.ActiveTrack = nil

                        repeat task.wait() until (self.CurrentPlayingGroup == group)

                        s:Stop()
                    end
                end
            end)
            
        end
    end

    Knit.GetService("ProfileService").Data:Observe(function(data)
        self:SetVolume(data.Settings["Music Volume"])
    end)
end





return MusicController
