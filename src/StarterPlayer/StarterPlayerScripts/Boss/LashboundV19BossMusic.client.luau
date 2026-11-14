-- Plays original optional phase-two music; built-in ominous stinger fallback.
-- To hear full score upload audio/BossRevivalTheme.wav and set its ID in LashboundSoundIds.
local RS=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local ids=require(RS:WaitForChild("LashboundSoundIds"))
local sound=Instance.new("Sound")
sound.Name="LashboundBossPhaseTwoMusic"
sound.SoundId=type(ids.BossRevivalTheme)=="number" and ids.BossRevivalTheme>0
    and "rbxassetid://"..ids.BossRevivalTheme or ""
sound.Volume=.52
sound.Looped=true
sound.Parent=SoundService
local stinger=Instance.new("Sound")
stinger.Name="ColossusAwakeningRumble"
stinger.SoundId="rbxasset://sounds/impact_generic.mp3"
stinger.Volume=.8
stinger.PlaybackSpeed=.65
stinger.Parent=SoundService
local chime=Instance.new("Sound")
chime.Name="ColossusAwakeningChime"
chime.SoundId="rbxasset://sounds/electronicpingshort.wav"
chime.Volume=.5
chime.Parent=SoundService
local state=RS:GetAttribute("LashboundBossState")
local token=0
local function update()
    local new=RS:GetAttribute("LashboundBossState")
    local active=new=="REVIVING" or new=="BOSS_ASCENDED"
    if active and not (state=="REVIVING" or state=="BOSS_ASCENDED") then
        token+=1
        local mine=token
        stinger:Play()
        if sound.SoundId~="" then sound:Play() else
            -- Fallback atmospheric motif, not the full original music track.
            task.spawn(function()
                for i=1,8 do
                    if mine~=token then return end
                    chime.PlaybackSpeed=({.7,.82,.62,1.1})[(i-1)%4+1]
                    chime:Play()
                    task.wait(.43)
                end
            end)
        end
    elseif not active and (state=="REVIVING" or state=="BOSS_ASCENDED") then
        token+=1
        sound:Stop()
    end
    state=new
end
RS:GetAttributeChangedSignal("LashboundBossState"):Connect(update)
update()
