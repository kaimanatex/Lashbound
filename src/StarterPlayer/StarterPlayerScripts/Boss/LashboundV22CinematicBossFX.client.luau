-- V22 supplemental 3-D effects. Server still owns hitboxes, timing and damage.
-- Uses Roblox-stock particle textures; uploaded audio assets are optional.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local RunService=game:GetService("RunService")
local HapticService=game:GetService("HapticService")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local SoundIds=require(RS:WaitForChild("LashboundSoundIds"))
local fx=Instance.new("Folder")
fx.Name="LashboundV22CinematicFX";fx.Parent=Workspace
local rng=Random.new()
local PARTICLE="rbxasset://textures/particles/sparkles_main.dds"
local SMOKE="rbxasset://textures/particles/smoke_main.dds"
local soundPalette={
    [1]={"rbxasset://sounds/impact_generic.mp3",.7},
    [2]={"rbxasset://sounds/impact_water.mp3",.8},
    [3]={"rbxasset://sounds/swordlunge.wav",.62},
    [4]={"rbxasset://sounds/electronicpingshort.wav",.5},
    [5]={"rbxasset://sounds/impact_generic.mp3",.62},
    [6]={"rbxasset://sounds/swordlunge.wav",1.25},
    [7]={"rbxasset://sounds/impact_generic.mp3",.84},
    [8]={"rbxasset://sounds/electronicpingshort.wav",1.65},
    [9]={"rbxasset://sounds/impact_water.mp3",1.05},
    [10]={"rbxasset://sounds/impact_generic.mp3",.55},
    [11]={"rbxasset://sounds/impact_generic.mp3",.9},
    [12]={"rbxasset://sounds/swordslash.wav",.75},
    [13]={"rbxasset://sounds/impact_generic.mp3",.64},
    [14]={"rbxasset://sounds/swordlunge.wav",1.3},
    [15]={"rbxasset://sounds/impact_water.mp3",.58},
}
local names={
    [6]="BossStarLance",[7]="BossMeteor",[8]="BossTrident",[9]="BossCrystal",
    [10]="BossVortex",[11]="BossSeismic",[12]="BossCrescents",[13]="BossTitan",
    [14]="BossBlade",[15]="BossCataclysm"
}
local function near(p)
    local c=player.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    return r and (r.Position-p).Magnitude<360
end
local function simple(name,pos,sz,color,mat,alpha,shape)
    local p=Instance.new("Part")
    p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Material=mat or Enum.Material.Neon;p.Color=color
    p.Transparency=alpha or 0;p.Size=sz;p.CFrame=CFrame.new(pos)
    if shape then p.Shape=shape end
    p.Parent=fx
    return p
end
local function burst(p,color,count,speed,lifetime,smoke)
    local holder=simple("BossTextureAnchor",p,Vector3.new(.2,.2,.2),color,Enum.Material.Neon,1)
    local emitter=Instance.new("ParticleEmitter")
    emitter.Texture=smoke and SMOKE or PARTICLE
    emitter.Rate=0;emitter.Lifetime=NumberRange.new(lifetime*.45,lifetime)
    emitter.Speed=NumberRange.new(speed*.5,speed)
    emitter.SpreadAngle=Vector2.new(150,150)
    emitter.Drag=4
    emitter.LightEmission=smoke and .15 or .85
    emitter.Color=ColorSequence.new(color,Color3.new(1,1,1))
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,smoke and 5 or 1.8),
        NumberSequenceKeypoint.new(1,0)})
    emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
    emitter.Parent=holder;emitter:Emit(count)
    Debris:AddItem(holder,lifetime+1)
end
local function disc(center,radius,color,life)
    local cyl=simple("CinematicShockDisc",center,Vector3.new(.35,1.4,1.4),color,Enum.Material.Neon,.58,Enum.PartType.Cylinder)
    cyl.CFrame=CFrame.new(center)*CFrame.Angles(0,0,math.pi/2)
    Tween:Create(cyl,TweenInfo.new(life,Enum.EasingStyle.Quad),{
        Size=Vector3.new(.2,radius*2,radius*2),Transparency=1}):Play()
    Debris:AddItem(cyl,life+.05)
end
local function shaft(origin,direction,length,color,life,width)
    local d=direction.Magnitude>.01 and direction.Unit or Vector3.new(0,0,-1)
    local center=origin+d*length*.5
    local part=simple("VolumetricBossBeam",center,Vector3.new(width,width,length),color,Enum.Material.Neon,.32)
    part.CFrame=CFrame.lookAt(center,origin+d*length)
    Tween:Create(part,TweenInfo.new(life,Enum.EasingStyle.Quad),{
        Size=Vector3.new(.12,.12,length),Transparency=1}):Play()
    Debris:AddItem(part,life+.08)
    burst(center,color,10,13,.7)
end
local function pillars(origin,color,count,height,spread,life)
    for i=1,count do
        local a=math.pi*2*i/count
        local r=spread*(.65+.35*(i%3)/2)
        local p=origin+Vector3.new(math.cos(a)*r,height*.5,math.sin(a)*r)
        local pillar=simple("AscensionLightningPillar",p,Vector3.new(.8,height,.8),color,Enum.Material.Neon,.22)
        pillar.CFrame=pillar.CFrame*CFrame.Angles(0,0,(i%2==0 and 1 or -1)*.1)
        Tween:Create(pillar,TweenInfo.new(life),{Transparency=1,Size=Vector3.new(.12,height,.12)}):Play()
        Debris:AddItem(pillar,life+.1)
    end
end
local function soundAt(index,pos)
    local soundSpec=soundPalette[index] or soundPalette[1]
    local customKey=names[index]
    local asset=customKey and SoundIds[customKey]
    local s=Instance.new("Sound")
    s.Name="ColossusDistinct_"..tostring(index)
    s.SoundId=type(asset)=="number" and asset>0 and "rbxassetid://"..asset or soundSpec[1]
    s.Volume=.82;s.PlaybackSpeed=soundSpec[2]
    s.RollOffMaxDistance=300
    local emitter=simple("BossAudioPoint",pos,Vector3.new(.1,.1,.1),Color3.new(1,1,1),Enum.Material.SmoothPlastic,1)
    s.Parent=emitter;s:Play()
    Debris:AddItem(emitter,3)
end
-- Every 3D effect below is generated from the same metadata the server uses
-- for its strike. It is purely cosmetic and cannot expand a damage zone.
local function connectPoints(a,b,color,life,thick,alpha)
    local d=b-a
    if d.Magnitude<.1 then return end
    local beam=simple("BossVolumetricRib",(a+b)*.5,Vector3.new(thick or .45,thick or .45,d.Magnitude),color,Enum.Material.Neon,alpha or .24)
    beam.CFrame=CFrame.lookAt((a+b)*.5,b)
    Tween:Create(beam,TweenInfo.new(life),{Transparency=1,Size=Vector3.new(.06,.06,d.Magnitude)}):Play()
    Debris:AddItem(beam,life+.08)
end
local function ring3d(origin,inner,outer,color,life)
    local slices=20
    local low=math.max(0,inner or 0)
    for j=0,slices-1 do
        local a=j*math.pi*2/slices
        local b=(j+1)*math.pi*2/slices
        for _,radius in ipairs({outer}) do
            local first=origin+Vector3.new(math.cos(a)*radius,2.3,math.sin(a)*radius)
            local last=origin+Vector3.new(math.cos(b)*radius,2.3,math.sin(b)*radius)
            connectPoints(first,last,color,life,.6,.25)
        end
        if j%2==0 and low>0 then
            local pa=origin+Vector3.new(math.cos(a)*low,2.3,math.sin(a)*low)
            local pb=origin+Vector3.new(math.cos(a)*outer,2.3,math.sin(a)*outer)
            connectPoints(pa,pb,color,life,.22,.64)
        end
    end
    -- Volumetric wave fronts rise above the floor instead of lying flat.
    -- They use the same inner/outer radii as the authoritative ring strike.
    for j=0,slices-1,2 do
        local a=j*math.pi*2/slices
        local q=origin+Vector3.new(math.cos(a)*outer,2.3,math.sin(a)*outer)
        connectPoints(q,q+Vector3.new(0,5.0,0),color,life,.40,.56)
        if low>0 then
            local innerQ=origin+Vector3.new(math.cos(a)*low,2.3,math.sin(a)*low)
            connectPoints(innerQ,innerQ+Vector3.new(0,2.0,0),color,life,.20,.68)
        end
    end
    if low>0 then
        for j=0,slices-1,2 do
            local a=j*math.pi*2/slices
            local b=(j+2)*math.pi*2/slices
            connectPoints(origin+Vector3.new(math.cos(a)*low,1.9,math.sin(a)*low),
                origin+Vector3.new(math.cos(b)*low,1.9,math.sin(b)*low),color,life,.25,.45)
        end
    end
end
local function lane3d(origin,direction,length,halfWidth,color,life)
    local d=Vector3.new(direction.X,0,direction.Z)
    if d.Magnitude<.01 then return end
    d=d.Unit
    local right=Vector3.new(-d.Z,0,d.X)
    local lengthSafe=math.clamp(length,1,180)
    local widthSafe=math.clamp(halfWidth,1,20)
    -- Twin lane walls span precisely the server's +/- halfWidth.
    for _,sgn in ipairs({-1,1}) do
        local mid=origin+d*lengthSafe*.5+right*sgn*widthSafe+Vector3.new(0,3.5,0)
        local wall=simple("BossDamageLaneBoundary",mid,Vector3.new(.25,6.5,lengthSafe),color,Enum.Material.Neon,.63)
        wall.CFrame=CFrame.lookAt(mid,mid+d)
        Tween:Create(wall,TweenInfo.new(life),{Transparency=1}):Play()
        Debris:AddItem(wall,life+.06)
    end
    shaft(origin+Vector3.new(0,3.2,0),d,lengthSafe,color,life,math.min(widthSafe*1.4,12))
    for k=1,5 do
        local pos=origin+d*(lengthSafe*k/6)+Vector3.new(0,3.1,0)
        burst(pos,color,4,12,.45)
    end
end
local function cone3d(origin,direction,length,dot,color,life)
    local d=Vector3.new(direction.X,0,direction.Z)
    if d.Magnitude<.01 then return end
    d=d.Unit
    local side=Vector3.new(-d.Z,0,d.X)
    local angle=math.acos(math.clamp(dot,-1,1))
    local radius=math.clamp(length,2,120)
    local prev=nil
    for i=0,16 do
        local a=-angle+(2*angle*i/16)
        local q=origin+(d*math.cos(a)+side*math.sin(a))*radius+Vector3.new(0,2.8,0)
        if prev then connectPoints(prev,q,color,life,.44,.2) end
        if i%4==0 then connectPoints(origin+Vector3.new(0,2.8,0),q,color,life,.30,.6) end
        prev=q
    end
    -- A restrained cone of vertical energy spines follows the visible boundary.
    for k=0,6 do
        local a=-angle+(2*angle*k/6)
        local q=origin+(d*math.cos(a)+side*math.sin(a))*radius+Vector3.new(0,2.8,0)
        connectPoints(q,q+Vector3.new(0,5,0),color,life,.26,.65)
    end
end
local function onStrike(p)
    local origin=p.origin
    local col=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(248,117,92)
    local idx=tonumber(p.step) or 1
    local shape=p.shape
    local life=.55
    if shape=="lane" then
        lane3d(origin,typeof(p.direction)=="Vector3" and p.direction or Vector3.new(0,0,-1),
            tonumber(p.range) or 50,tonumber(p.halfWidth) or 5,col,life)
    elseif shape=="ring" then
        local radius=tonumber(p.radius) or 30
        local inner=tonumber(p.innerRadius) or 0
        ring3d(origin,inner,radius,col,.68)
        -- Never fill the inner safe pocket with a misleading full disc.
    elseif shape=="circle" then
        local radius=tonumber(p.radius) or 18
        ring3d(origin,0,radius,col,life)
        local dome=simple("BossImpactDome",origin+Vector3.new(0,3.5,0),Vector3.new(3,3,3),col,Enum.Material.Glass,.58,Enum.PartType.Ball)
        Tween:Create(dome,TweenInfo.new(.46),{Size=Vector3.new(radius*1.65,math.max(6,radius*.8),radius*1.65),Transparency=1}):Play()
        Debris:AddItem(dome,.5)
    elseif shape=="cone" then
        cone3d(origin,typeof(p.direction)=="Vector3" and p.direction or Vector3.new(0,0,-1),
            tonumber(p.range) or 45,tonumber(p.dot) or .35,col,life)
    else
        ring3d(origin,0,22,col,.4)
    end
    burst(origin+Vector3.new(0,3,0),col,idx>=6 and 18 or 12,22,.75)
    -- Materialized strike core, never collidable and removed before the next attack.
    local core=simple("BossVolumetricImpactCore",origin+Vector3.new(0,3,0),Vector3.new(3,3,3),col,Enum.Material.Glass,.35,Enum.PartType.Ball)
    Tween:Create(core,TweenInfo.new(.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
        Size=Vector3.new(idx>=6 and 13 or 8,idx>=6 and 12 or 7,idx>=6 and 13 or 8),Transparency=1
    }):Play()
    Debris:AddItem(core,.37)
    soundAt(idx,origin)
end
-- All devices receive restrained camera vibration; supported controllers also
-- rumble via HapticService. Server-impact events trigger both, not warnings.
local impactShakeToken=0
local rumbleToken=0
local function vibrate(origin,power,duration)
    local c=player.Character
    local hum=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if not r or not hum then return end
    local distance=(r.Position-origin).Magnitude
    local intensity=math.clamp(power*(1-distance/270),0,.90)
    if intensity<.035 then return end
    impactShakeToken+=1
    rumbleToken+=1
    local shakeID=impactShakeToken
    local rumbleID=rumbleToken
    local base=hum.CameraOffset
    local window=math.clamp(duration,.12,.8)
    task.spawn(function()
        local start=os.clock()
        while os.clock()-start<window and shakeID==impactShakeToken and hum.Parent do
            local fraction=1-(os.clock()-start)/window
            local amount=intensity*fraction*.72
            hum.CameraOffset=base+Vector3.new(rng:NextNumber(-amount,amount),rng:NextNumber(-amount,amount),0)
            RunService.RenderStepped:Wait()
        end
        if shakeID==impactShakeToken and hum.Parent then hum.CameraOffset=base end
    end)
    local gamepad=Enum.UserInputType.Gamepad1
    local large=Enum.VibrationMotor.Large
    local small=Enum.VibrationMotor.Small
    local supported=false
    pcall(function()
        supported=HapticService:IsVibrationSupported(gamepad) and HapticService:IsMotorSupported(gamepad,large)
        if supported then
            HapticService:SetMotor(gamepad,large,intensity)
            if HapticService:IsMotorSupported(gamepad,small) then
                HapticService:SetMotor(gamepad,small,math.min(1,intensity*.75))
            end
        end
    end)
    if supported then
        task.delay(window,function()
            if rumbleID~=rumbleToken then return end
            pcall(function()
                HapticService:SetMotor(gamepad,large,0)
                if HapticService:IsMotorSupported(gamepad,small) then HapticService:SetMotor(gamepad,small,0) end
            end)
        end)
    end
end

local shakeToken=0
local function revive(p)
    shakeToken+=1
    local token=shakeToken
    local origin=p.origin
    local color=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(250,173,137)
    local tint=Instance.new("ColorCorrectionEffect")
    tint.Name="V22BossReviveFlash"
    tint.TintColor=Color3.new(1,1,1)
    tint.Contrast=0;tint.Saturation=0
    tint.Parent=Lighting
    Tween:Create(tint,TweenInfo.new(.45),{TintColor=color,Contrast=.35,Saturation=-.3}):Play()
    task.delay(2.4,function()
        if tint.Parent then Tween:Create(tint,TweenInfo.new(1.1),{TintColor=Color3.new(1,1,1),Contrast=0,Saturation=0}):Play() end
    end)
    Debris:AddItem(tint,(tonumber(p.duration) or 5.1)+.2)
    burst(origin+Vector3.new(0,7,0),color,58,28,2.7)
    burst(origin+Vector3.new(0,7,0),Color3.fromRGB(65,57,68),26,12,2.9,true)
    pillars(origin,color,11,35,18,2.7)
    for i=1,9 do
        task.delay((i-1)*.41,function()
            if token~=shakeToken then return end
            disc(origin+Vector3.new(0,i*.65,0),13+i*8,color,1.4)
        end)
    end
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local offset=hum and hum.CameraOffset or Vector3.zero
    task.spawn(function()
        for i=1,45 do
            if token~=shakeToken or not hum or not hum.Parent then break end
            local scale=(1-i/46)*.24
            hum.CameraOffset=offset+Vector3.new(rng:NextNumber(-scale,scale),rng:NextNumber(-scale,scale),0)
            task.wait(.065)
        end
        if hum and hum.Parent then hum.CameraOffset=offset end
    end)
    soundAt(15,origin)
    -- Camera already shakes during revival; rumble on supported controllers.
    local gp=Enum.UserInputType.Gamepad1
    pcall(function()
        if HapticService:IsVibrationSupported(gp) and HapticService:IsMotorSupported(gp,Enum.VibrationMotor.Large) then
            HapticService:SetMotor(gp,Enum.VibrationMotor.Large,.85)
            task.delay(.8,function()pcall(function()HapticService:SetMotor(gp,Enum.VibrationMotor.Large,0)end)end)
        end
    end)
end
feedback.OnClientEvent:Connect(function(kind,_,p)
    if kind~="Visual" or type(p)~="table" or typeof(p.origin)~="Vector3" or not near(p.origin) then return end
    local mode=p.kind
    if mode=="BossRevival" then revive(p)
    elseif mode=="BossReviveLanding" then
        local color=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(252,211,133)
        disc(p.origin+Vector3.new(0,2,0),90,color,.80)
        pillars(p.origin,color,18,55,30,1.0)
        burst(p.origin+Vector3.new(0,9,0),color,85,43,1.25)
        vibrate(p.origin,.98,.87)
        soundAt(15,p.origin)
    elseif mode=="BossAscended" then
        local col=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(255,205,128)
        pillars(p.origin,col,14,48,26,1.4)
        disc(p.origin+Vector3.new(0,2,0),65,col,.9)
        burst(p.origin+Vector3.new(0,14,0),col,78,36,1.5)
        soundAt(6,p.origin)
        vibrate(p.origin,.8,.60)
    elseif mode=="BossPhaseStrike" or mode=="BossStrike" then
        onStrike(p)
        local step=tonumber(p.step) or 1
        vibrate(p.origin,step>=6 and .72 or .52,step>=11 and .42 or .26)
    end
end)
