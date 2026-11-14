-- V11 raid weather and countdown. Client-only (zero replicated particle spam).
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="LashboundDogRaidHUD"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=15
gui.Parent=player:WaitForChild("PlayerGui")
local banner=Instance.new("Frame")
banner.Name="RaidBanner";banner.AnchorPoint=Vector2.new(.5,0)
banner.Position=UDim2.new(.5,0,0,166)
banner.Size=UDim2.fromOffset(410,70)
banner.BackgroundColor3=Color3.fromRGB(42,36,47)
banner.BackgroundTransparency=.08
banner.BorderSizePixel=0;banner.Visible=false;banner.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,12);corner.Parent=banner
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(255,136,104);stroke.Thickness=2;stroke.Parent=banner
local title=Instance.new("TextLabel")
title.Name="RaidText";title.BackgroundTransparency=1
title.Size=UDim2.new(1,-20,0,39);title.Position=UDim2.fromOffset(10,4)
title.TextScaled=true;title.TextColor3=Color3.fromRGB(255,190,135)
title.TextStrokeTransparency=.35;title.Font=Enum.Font.GothamBlack;title.Parent=banner
local hint=Instance.new("TextLabel")
hint.BackgroundTransparency=1;hint.Size=UDim2.new(1,-20,0,22)
hint.Position=UDim2.fromOffset(10,43);hint.TextScaled=true
hint.TextColor3=Color3.fromRGB(240,231,224);hint.Font=Enum.Font.GothamBold;hint.Parent=banner
local original={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,FogColor=Lighting.FogColor}
local correction=Instance.new("ColorCorrectionEffect")
correction.Name="LashboundRaidCloudTint";correction.Enabled=true
correction.Saturation=0;correction.Contrast=0;correction.Brightness=0
correction.TintColor=Color3.new(1,1,1);correction.Parent=Lighting
local clouds=Instance.new("Clouds")
clouds.Name="LashboundRaidClouds";clouds.Cover=0;clouds.Density=.55
clouds.Color=Color3.fromRGB(156,163,180)
local terrain=workspace:FindFirstChildOfClass("Terrain")
if terrain then clouds.Parent=terrain else clouds:Destroy();clouds=nil end
local weatherOn=false
local function weather(active)
    if active==weatherOn then return end
    weatherOn=active
    if active then
        Tween:Create(Lighting,TweenInfo.new(1.4),{
            Brightness=math.max(.85,original.Brightness*.54),ClockTime=16.8,
            FogStart=70,FogEnd=400,FogColor=Color3.fromRGB(116,126,142)}):Play()
        Tween:Create(correction,TweenInfo.new(1.4),{
            Saturation=-.43,Contrast=.09,Brightness=-.06,TintColor=Color3.fromRGB(181,195,213)}):Play()
        if clouds then Tween:Create(clouds,TweenInfo.new(1.8),{Cover=.85,Density=.85}):Play() end
    else
        Tween:Create(Lighting,TweenInfo.new(1.8),original):Play()
        Tween:Create(correction,TweenInfo.new(1.8),{
            Saturation=0,Contrast=0,Brightness=0,TintColor=Color3.new(1,1,1)}):Play()
        if clouds then Tween:Create(clouds,TweenInfo.new(1.6),{Cover=0,Density=.55}):Play() end
    end
end
local previousState="WAITING"
local function alertSound()
    local sound=Instance.new("Sound")
    sound.Name="RaidWarningCue"
    sound.SoundId="rbxasset://sounds/electronicpingshort.wav"
    sound.Volume=.75;sound.PlaybackSpeed=.64;sound.Parent=gui
    sound:Play()
    task.delay(2,function()sound:Destroy()end)
end
while gui.Parent do
    task.wait(.35)
    local state=RS:GetAttribute("LashboundDogRaidState") or "WAITING"
    local zone=player:GetAttribute("Zone") or "Lobby"
    local nextTime=RS:GetAttribute("LashboundNextMapTime")
    local duration=RS:GetAttribute("LashboundMapDuration") or 300
    local elapsed=type(nextTime)=="number" and math.max(0,workspace:GetServerTimeNow()-(nextTime-duration)) or 0
    if zone=="Arena" and state=="WARNING" and previousState~="WARNING" then alertSound() end
    previousState=state
    local shown=(zone=="Arena") and (state=="WARNING" or state=="SPAWNING" or state=="ACTIVE")
    banner.Visible=shown
    weather(shown)
    if shown then
        if state=="WARNING" then
            local remain=math.max(0,math.ceil(120-elapsed))
            title.Text="⚠ HOUND RAID IN "..remain.."s"
            hint.Text="30 hostile hounds are approaching. Get ready!"
        elseif state=="SPAWNING" then
            title.Text="⚠ THE HOUNDS ARE HERE"
            hint.Text=tostring(RS:GetAttribute("LashboundDogRaidSpawned") or 0).." / 30 hounds spawned"
        else
            title.Text="HOUND RAID • "..tostring(RS:GetAttribute("LashboundDogRaidAlive") or 0).." LEFT"
            hint.Text="Survive the pack • Defeat a dog for +1 saved coin"
        end
    end
end
weather(false)
if clouds then clouds:Destroy() end
correction:Destroy()
