-- THUNDER VERDICT: lock-on reticle, ascending tether and instantaneous bolt
-- synchronized to the server's actual stun/damage event.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Debris=game:GetService("Debris")
local Tween=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local ids=require(RS:WaitForChild("LashboundSoundIds"))
local rng=Random.new()
local me=Players.LocalPlayer
local fx=Instance.new("Folder")
fx.Name="ThunderVerdictFX";fx.Parent=workspace
local function makePart(pos,color,size,alpha)
    local p=Instance.new("Part")
    p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
    p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=alpha or .1
    p.Size=size;p.CFrame=CFrame.new(pos);p.Parent=fx
    return p
end
local function line(a,b,color,duration,width)
    local d=b-a
    if d.Magnitude<.1 then return end
    local p=makePart((a+b)*.5,color,Vector3.new(width or .35,width or .35,d.Magnitude),.02)
    p.CFrame=CFrame.lookAt((a+b)*.5,b)
    Tween:Create(p,TweenInfo.new(duration),{Transparency=1}):Play()
    Debris:AddItem(p,duration+.1)
end
local function ring(pos,color,size,duration)
    local last=nil
    for j=0,12 do
        local a=math.pi*2*j/12
        local point=pos+Vector3.new(math.cos(a)*size,.55,math.sin(a)*size)
        if last then line(last,point,color,duration,.28) end
        last=point
    end
end
local function sound()
    local s=Instance.new("Sound")
    local asset=ids.ThunderVerdict
    s.SoundId=(type(asset)=="number" and asset>0) and ("rbxassetid://"..asset)
        or "rbxasset://sounds/electronicpingshort.wav"
    s.Volume=1.2;s.PlaybackSpeed=.85
    s.Parent=SoundService;s:Play();Debris:AddItem(s,3)
    local bass=Instance.new("Sound")
    bass.SoundId="rbxasset://sounds/impact_generic.mp3"
    bass.Volume=.65;bass.PlaybackSpeed=.75;bass.Parent=SoundService
    bass:Play();Debris:AddItem(bass,2)
end
local function nearby(pos)
    local root=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    return root and (root.Position-pos).Magnitude<175
end
Feedback.OnClientEvent:Connect(function(kind,_,payload)
    if kind~="Visual" or type(payload)~="table" then return end
    if payload.kind~="JudgementLock" and payload.kind~="JudgementStrike" then return end
    local pos=payload.origin
    if typeof(pos)~="Vector3" or not nearby(pos) then return end
    local gold=Color3.fromRGB(255,241,112)
    local cyan=Color3.fromRGB(122,227,255)
    if payload.kind=="JudgementLock" then
        for i=1,3 do
            ring(pos,gold,3.4+i*.65,1.03)
            ring(pos,cyan,1.5+i*.6,1.03)
        end
        local start=pos+Vector3.new(0,1.5,0)
        line(start,start+Vector3.new(0,15,0),cyan,.8,.2)
    else
        sound()
        local start=pos+Vector3.new(0,34,0)
        local prev=start
        for i=1,13 do
            local fraction=i/13
            local nextPoint=pos+Vector3.new((i==13 and 0 or rng:NextNumber(-2.8,2.8)),34*(1-fraction),
                (i==13 and 0 or rng:NextNumber(-2.8,2.8)))
            line(prev,nextPoint,i%3==0 and cyan or gold,.35,i%3==0 and .65 or .44)
            prev=nextPoint
        end
        local flash=makePart(pos+Vector3.new(0,3,0),gold,Vector3.new(2,2,2),.02)
        flash.Shape=Enum.PartType.Ball
        Tween:Create(flash,TweenInfo.new(.38,Enum.EasingStyle.Quart),{Size=Vector3.new(12,12,12),Transparency=1}):Play()
        Debris:AddItem(flash,.42)
        ring(pos,gold,9,.43)
        ring(pos,cyan,5,.27)
    end
end)
