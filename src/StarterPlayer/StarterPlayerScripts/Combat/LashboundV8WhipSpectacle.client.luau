-- LASHBOUND V8 / spectacle FX. Purely visual: server is the authority for hit detection.
-- Renders a flexible, tapering lash *from the equipped physical handle*.
-- Uses small per-action jobs, not a global animation loop or per-frame remotes.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local Config=require(RS:WaitForChild("WhipConfig"))
local SoundIds=require(RS:WaitForChild("LashboundSoundIds"))
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local fx=Instance.new("Folder")
fx.Name="LashboundV8SpectacleFX"
fx.Parent=workspace
local current=setmetatable({}, {__mode="k"})
local rand=Random.new()

local function cameraRoot()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function nearby(point)
    local root=cameraRoot()
    return root and (root.Position-point).Magnitude<160
end
local function noPhysics(obj)
    obj.Anchored=true; obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false
    obj.CastShadow=false
end
local function orb(pos,size,color,duration,scale,alpha,material)
    local p=Instance.new("Part")
    p.Shape=Enum.PartType.Ball
    p.Size=Vector3.new(size,size,size)
    p.CFrame=CFrame.new(pos)
    p.Material=material or Enum.Material.Neon
    p.Color=color;p.Transparency=alpha or .25
    noPhysics(p)
    p.Parent=fx
    Tween:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        Transparency=1,Size=Vector3.new(scale,scale,scale)
    }):Play()
    Debris:AddItem(p,duration+.05)
    return p
end
local function streak(a,b,color,width,time)
    local delta=b-a
    if delta.Magnitude<.1 then return end
    local p=Instance.new("Part")
    p.Name="EnergyStreak"
    p.Size=Vector3.new(width,width,delta.Magnitude)
    p.CFrame=CFrame.lookAt((a+b)/2,b)
    p.Material=Enum.Material.Neon
    p.Color=color; p.Transparency=.13
    noPhysics(p)
    p.Parent=fx
    Tween:Create(p,TweenInfo.new(time),{Transparency=1,Size=Vector3.new(.04,.04,delta.Magnitude)}):Play()
    Debris:AddItem(p,time+.06)
end
local function ring(origin,color,radius,lifetime,segments,height)
    segments=segments or 14
    height=height or .5
    for i=0,segments-1 do
        local a=math.pi*2*i/segments
        local b=math.pi*2*(i+1)/segments
        streak(origin+Vector3.new(math.cos(a)*radius,height,math.sin(a)*radius),
            origin+Vector3.new(math.cos(b)*radius,height,math.sin(b)*radius),color,.30,lifetime)
    end
end
local function playSound(key,dist)
    local id=SoundIds[key]
    local fallback={
        WhipCrack1="rbxasset://sounds/swordslash.wav",
        WhipCrack2="rbxasset://sounds/swordslash.wav",
        WhipCrack3="rbxasset://sounds/swordlunge.wav",
        WhipCrackPower="rbxasset://sounds/swordlunge.wav",
        WhipCrackHeavy="rbxasset://sounds/swordlunge.wav",
        DodgeWhoosh="rbxasset://sounds/action_jump.mp3",
        BossTremor="rbxasset://sounds/impact_generic.mp3",
        BossCyclone="rbxasset://sounds/impact_water.mp3",
        BossMeteor="rbxasset://sounds/impact_generic.mp3",
        BossChain="rbxasset://sounds/electronicpingshort.wav",
        BossCharge="rbxasset://sounds/impact_generic.mp3",
    }
    local asset=(type(id)=="number" and id>0) and ("rbxassetid://"..id) or fallback[key]
    if not asset then return end
    local sound=Instance.new("Sound")
    sound.Name="LashboundV8_"..key
    sound.SoundId=asset
    sound.Volume=(key=="WhipCrack3" and .98 or .78)*math.clamp(1-(dist or 0)/160,.22,1)
    sound.PlaybackSpeed=key=="WhipCrack2" and 1.28 or key=="WhipCrack3" and .92 or 1
    sound.Parent=SoundService
    sound:Play()
    -- Stock swish has an audible snap layer; uploaded custom .wav replaces it.
    if not (type(id)=="number" and id>0) and string.find(key,"WhipCrack") then
        local snap=Instance.new("Sound")
        snap.Name="LashboundCrackTransient"
        snap.SoundId="rbxasset://sounds/impact_generic.mp3"
        snap.Volume=.5*math.clamp(1-(dist or 0)/160,.2,1)
        snap.PlaybackSpeed=1.35
        snap.Parent=SoundService
        snap:Play()
        Debris:AddItem(snap,1.5)
    end
    Debris:AddItem(sound,2)
end
local function getCaster(payload)
    local id=payload.actorUserId
    if type(id)=="number" then
        local actor=Players:GetPlayerByUserId(id)
        local ch=actor and actor.Character
        local tool=ch and (ch:FindFirstChild("FounderTempest") or ch:FindFirstChild("LashboundWhip"))
        return ch,tool,tool and tool:FindFirstChild("Handle")
    end
    return nil,nil,nil
end

local function whipSwing(payload)
    local origin=payload.origin
    local color=typeof(payload.color)=="Color3" and payload.color or Color3.new(1,1,1)
    local direction=Vector3.new(payload.direction.X,0,payload.direction.Z)
    if direction.Magnitude<.1 or not nearby(origin) then return end
    direction=direction.Unit
    local side=Vector3.new(-direction.Z,0,direction.X)
    local ch,tool,handle=getCaster(payload)
    local step=math.clamp(tonumber(payload.step) or 1,1,3)
    local power=payload.kind=="Power"
    local heavy=payload.kind=="Heavy"
    local duration=heavy and .9 or power and .84 or step==3 and .88 or .78
    local range=tonumber(payload.range) or (heavy and 33 or power and 27 or step==3 and 25 or 19)
    local polarity=(step==2) and -1 or 1
    local holder=Instance.new("Folder")
    holder.Name="FlexibleWhipVisual"
    holder.Parent=fx
    local nodes={}
    local attachments={}
    local viewerDistance=(cameraRoot() and (cameraRoot().Position-origin).Magnitude) or 140
    -- Nearby attacks have 100 independently positioned visual links.  Longer
    -- distances use LOD for multiplayer, while damage is always checked by
    -- the identical 100-segment server geometry.
    local links=viewerDistance<75 and 100 or viewerDistance<130 and 50 or 25
    for i=1,links+1 do
        local node=Instance.new("Part")
        node.Name="CurvePoint"..i
        node.Size=Vector3.new(.08,.08,.08)
        node.Transparency=1
        noPhysics(node)
        node.Parent=holder
        local att=Instance.new("Attachment")
        att.Parent=node
        nodes[i]=node; attachments[i]=att
        if i>1 then
            local beam=Instance.new("Beam")
            beam.Attachment0=attachments[i-1]
            beam.Attachment1=attachments[i]
            beam.Width0=.38*(1-(i-2)/links)+.035
            beam.Width1=.38*(1-(i-1)/links)+.025
            beam.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,color),ColorSequenceKeypoint.new(1,i>=9 and Color3.new(1,1,1) or color)})
            beam.Transparency=NumberSequence.new(.02)
            beam.Segments=1
            beam.LightEmission=.9
            beam.LightInfluence=0
            beam.FaceCamera=true
            beam.Parent=holder
        end
    end
    local base=handle and handle.CFrame.Position+handle.CFrame.UpVector*.85 or origin+Vector3.new(0,2.3,0)
    local myRoot=cameraRoot()
    local distance=myRoot and (myRoot.Position-origin).Magnitude or 110
    -- Hide the rigid coiled prop only for the duration of this actual whip snap.
    local token=tool and ((current[tool] or 0)+1) or 0
    local rootBurstDone=false
    if tool then
        current[tool]=token
        for _,segment in ipairs(tool:GetChildren()) do
            if segment:IsA("BasePart") and (segment.Name:match("^Lash_") or segment.Name=="LashTip") then
                segment.LocalTransparencyModifier=1
            end
        end
    end
    local t0=os.clock()
    local startedAt=tonumber(payload.startedAt)
    local function elapsed()
        return startedAt and math.max(0,workspace:GetServerTimeNow()-startedAt) or (os.clock()-t0)
    end
    local snapped=false
    while holder.Parent and elapsed()<duration do
        local progress=math.clamp(elapsed()/duration,0,1)
        if handle and handle.Parent then
            base=handle.Position+handle.CFrame.UpVector*.85
        end
        -- Curl, physically travel from handle to tip, and snap at the exact
        -- SERVER impact moment. The tip overtakes the thicker base at release.
        local snapSeconds=heavy and .33 or power and .37 or .29
        local elapsedTime=elapsed()
        local launch=math.clamp((elapsedTime-.055)/(snapSeconds-.055),0,1)
        local recoil=math.clamp((elapsedTime-(snapSeconds+.075))/.33,0,1)
        for i,node in ipairs(nodes) do
            local f=(i-1)/(#nodes-1)
            local delayed=math.clamp((launch-.16*f)/(1-.16*f),0,1)
            local smooth=delayed*delayed*(3-2*delayed)
            local extend=(1.6+(range-1.6)*smooth)*f*(1-recoil*.83)
            local curl=(1-smooth)*(2.6+f*5.0)*math.sin(f*math.pi*.86)
            local coiledBack=(1-smooth)*f*4.3
            local wave=math.sin(3*f*math.pi-launch*math.pi*1.8)*(.82-smooth*.5)
            local sideOffset=polarity*(curl+wave)*math.sin(f*math.pi*.99)
            local lift=(1-smooth)*math.sin(f*math.pi)*3.7 + f*.6
            node.CFrame=CFrame.new(base+direction*(extend-coiledBack)+side*sideOffset+Vector3.new(0,lift,0))
        end
        if not snapped and elapsedTime>=snapSeconds then
            snapped=true
            local tip=nodes[#nodes].Position
            orb(tip,1.5,color,.22,6.5,.06)
            orb(tip,0.8,Color3.new(1,1,1),.18,3.2,.12)
            ring(tip,color,2.8,.19,10,0)
            ring(tip,Color3.new(1,1,1),1.6,.13,8,.2)
            for s=1,6 do
                local ang=(s/6)*math.pi*2
                streak(tip,tip+Vector3.new(math.cos(ang)*3.6,math.sin(ang*.5)*1.2,math.sin(ang)*3.6),color,.16,.16)
            end
            -- Dedicated WhipAudio client owns whip sounds even if this FX script fails.
        end
        if not rootBurstDone and progress>.12 then
            rootBurstDone=true
            orb(base,.55,color,.16,2.2,.22)
        end
        RunService.RenderStepped:Wait()
    end
    if tool and current[tool]==token then
        for _,segment in ipairs(tool:GetChildren()) do
            if segment:IsA("BasePart") and (segment.Name:match("^Lash_") or segment.Name=="LashTip") then
                segment.LocalTransparencyModifier=0
            end
        end
    end
    holder:Destroy()
end

local function abilitySpectacle(payload)
    local p=payload.origin
    if not nearby(p) then return end
    local color=typeof(payload.color)=="Color3" and payload.color or Color3.new(1,1,1)
    local dir=Vector3.new(payload.direction.X,0,payload.direction.Z)
    if dir.Magnitude<.1 then dir=Vector3.new(0,0,-1) else dir=dir.Unit end
    local side=Vector3.new(-dir.Z,0,dir.X)
    local id=payload.whipId
    local pulse=payload.kind=="PowerPulse"
    if id=="Rope" then
        if pulse then return end
        for i=-1,1 do
            streak(p+Vector3.new(0,2,0)+side*i,p+dir*31+Vector3.new(0,2,0)+side*i*2,color,.43,.52)
        end
        ring(p+dir*25,color,8,.35,14)
    elseif id=="Ember" then
        local radius=pulse and (12+(tonumber(payload.step) or 1)*3) or 12
        ring(p,color,radius,.43,12)
        for i=1,10 do
            local ang=i*math.pi*2/10
            local where=p+Vector3.new(math.cos(ang)*radius,1,math.sin(ang)*radius)
            streak(where,where+Vector3.new(0,rand:NextNumber(4,10),0),color,.65,.4)
        end
        orb(p+Vector3.new(0,1,0),2.8,color,.42,6,.35)
    elseif id=="Frost" then
        if pulse then return end
        local center=p+dir*17
        ring(center,color,13,.52,16)
        for i=1,10 do
            local spread=(i-5.5)*2.6
            local at=center+side*spread+dir*rand:NextNumber(-3,4)
            streak(at+Vector3.new(0,.3,0),at+Vector3.new(0,rand:NextNumber(5,14),0),color,.8,.75)
            orb(at+Vector3.new(0,5,0),1.3,Color3.fromRGB(207,248,255),.54,.3,.18,Enum.Material.Glass)
        end
    elseif id=="Volt" then
        if pulse then return end
        for branch=1,4 do
            local start=p+Vector3.new(0,2,0)
            local far=start+dir*(13+branch*5)+side*((branch-2.5)*6)
            local prev=start
            for j=1,6 do
                local t=j/6
                local nextPos=start:Lerp(far,t)+Vector3.new(rand:NextNumber(-2,2),rand:NextNumber(-2,2),rand:NextNumber(-2,2))
                streak(prev,nextPos,color,branch==1 and .56 or .36,.36)
                prev=nextPos
            end
            orb(far,1,color,.34,3,.15)
        end
    elseif id=="Gravity" then
        local center=pulse and p or p+dir*19
        local radius=pulse and (22-(tonumber(payload.step) or 1)*2) or 22
        ring(center,color,radius,.58,18)
        orb(center+Vector3.new(0,5,0),pulse and 7 or 5,Color3.fromRGB(30,15,64),.64,pulse and 3 or 13,.05,Enum.Material.SmoothPlastic)
        for axis=1,(pulse and tonumber(payload.step)~=5) and 0 or 2 do
            local phase=axis==1 and .6 or -1.1
            for i=0,9 do
                local a=i/10*math.pi*2+phase
                local b=(i+1)/10*math.pi*2+phase
                local ra=math.max(4,radius*.6)
                local pa=center+Vector3.new(math.cos(a)*ra,4+math.sin(a*2)*2,math.sin(a)*ra)
                local pb=center+Vector3.new(math.cos(b)*ra,4+math.sin(b*2)*2,math.sin(b)*ra)
                streak(pa,pb,color,.38,.7)
            end
        end
    elseif id=="Legend" then
        local center=pulse and p or p+dir*30
        ring(center,color,pulse and 7 or 13,.63,18)
        orb(center+Vector3.new(0,2.2,0),pulse and 5 or 3.3,color,.7,pulse and 11 or 6,.40)
        for i=1,6 do
            local a=i*math.pi*2/6
            local offset=Vector3.new(math.cos(a)*6,3+math.sin(i)*1.8,math.sin(a)*6)
            streak(p+Vector3.new(0,2.1,0),center+offset,color,.53,.47)
        end
        streak(p+Vector3.new(0,2.5,0),center+Vector3.new(0,2.5,0),Color3.fromRGB(255,245,192),1.05,.36)
    elseif id=="Echo" then
        ring(p,color,12,.5,14)
        orb(p+dir*5+Vector3.new(0,3,0),5,color,.60,10,.44)
    elseif id=="Phantom" then
        local landing=p+dir*19
        ring(p,color,5,.34,12)
        ring(landing,color,8,.55,16)
        for i=-1,1 do
            streak(p+Vector3.new(i*1.2,2,0),landing+Vector3.new(i*1.4,2.5,0),color,.27,.36)
        end
        orb(landing+Vector3.new(0,2,0),5,color,.48,12,.68)
    end
end

local function dodgeVisual(payload)
    local p=payload.origin
    if not nearby(p) then return end
    local color=typeof(payload.color)=="Color3" and payload.color or Color3.new(1,1,1)
    local v=payload.direction
    local dir=Vector3.new(v.X,0,v.Z)
    if dir.Magnitude<.15 then return end
    dir=dir.Unit
    local side=Vector3.new(-dir.Z,0,dir.X)
    for i=-1,1,2 do
        streak(p+side*i*1.5+Vector3.new(0,.6,0),p-dir*10+side*i*1.5+Vector3.new(0,.6,0),color,.45,.4)
    end
    for i=1,3 do
        orb(p-dir*i*2.4+Vector3.new(0,2,0),1.5,color,.25+i*.05,3,.72)
    end
    if payload.kind=="BotDodge" then return end
    local dist=cameraRoot() and (cameraRoot().Position-p).Magnitude or 100
    playSound("DodgeWhoosh",dist)
end

-- Five distinct, deliberately capped boss attack visuals. This is local-only
-- so a single Colossus will not generate hundreds of replicated physics parts.
local BOSS_SOUND={"BossTremor","BossCyclone","BossMeteor","BossChain","BossCharge"}
local BOSS_NAMES={"SHOCKWAVE","CYCLONE SWEEPS","METEOR STRIKE","CHAIN GRAB","CHARGE SLAM"}
local BOSS_WARN_TIME={1.6,1.4,1.85,1.5,1.45}
local function bossWarning(origin,step,warningTime)
    local marker=Instance.new("Part")
    marker.Name="BossAttackWarning";marker.Anchored=true;marker.CanCollide=false
    marker.CanTouch=false;marker.CanQuery=false;marker.Transparency=1
    marker.Size=Vector3.new(1,1,1);marker.Position=origin+Vector3.new(0,12,0);marker.Parent=fx
    local bb=Instance.new("BillboardGui")
    bb.Name="BossTelegraph";bb.AlwaysOnTop=true;bb.Size=UDim2.fromOffset(245,73)
    bb.MaxDistance=190;bb.Parent=marker
    local txt=Instance.new("TextLabel")
    txt.Size=UDim2.new(1,0,.68,0);txt.BackgroundTransparency=.17
    txt.BackgroundColor3=Color3.fromRGB(61,16,25)
    txt.TextColor3=Color3.fromRGB(255,232,172)
    txt.Font=Enum.Font.GothamBlack;txt.TextScaled=true
    txt.TextStrokeTransparency=.17;txt.Text="⚠ "..BOSS_NAMES[step].."!";txt.Parent=bb
    local track=Instance.new("Frame")
    track.Position=UDim2.fromScale(.03,.75);track.Size=UDim2.fromScale(.94,.19)
    track.BackgroundColor3=Color3.fromRGB(50,15,24);track.Parent=bb
    local fill=Instance.new("Frame")
    fill.Size=UDim2.fromScale(1,1);fill.BackgroundColor3=Color3.fromRGB(255,83,71)
    fill.BorderSizePixel=0;fill.Parent=track
    local t=math.clamp(tonumber(warningTime) or BOSS_WARN_TIME[step],.5,3)
    Tween:Create(fill,TweenInfo.new(t,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(0,1)}):Play()
    Debris:AddItem(marker,t+.15)
end
local function bossVisual(payload)
    local center=payload.origin
    if not nearby(center) then return end
    local col=typeof(payload.color)=="Color3" and payload.color or Color3.fromRGB(237,135,246)
    local step=math.clamp(tonumber(payload.step) or 1,1,5)
    local v=payload.direction
    local flat=Vector3.new(v.X,0,v.Z)
    if flat.Magnitude<.1 then flat=Vector3.new(0,0,-1) end
    local dir=flat.Unit
    local side=Vector3.new(-dir.Z,0,dir.X)
    local mode=payload.kind
    if mode=="BossTell" then
        bossWarning(center,step,payload.duration)
        -- Distinct telegraphs: radial shock, cyclone, meteors, hook and lane charge.
        if step==1 then
            ring(center,Color3.fromRGB(255,112,112),26,payload.duration or 1.60,20,.38)
            orb(center+Vector3.new(0,5,0),5,col,1.55,10,.45)
        elseif step==2 then
            for j=1,3 do ring(center,col,15+j*2,payload.duration or 1.45,14,1.1+j*.5) end
        elseif step==3 then
            ring(center,col,10,payload.duration or 1.85,14,2)
            for j=1,5 do
                local a=j*math.pi*2/5
                streak(center+Vector3.new(0,5,0),center+Vector3.new(math.cos(a)*12,23,math.sin(a)*12),col,.4,1.6)
            end
        elseif step==4 then
            for i=-1,1 do
                streak(center+side*i*5.5+Vector3.new(0,1,0),center+dir*64+side*i*5.5+Vector3.new(0,1,0),Color3.fromRGB(255,182,66),.3,payload.duration or 1.55)
            end
        else
            for i=-1,1 do
                streak(center+side*i*7.5+Vector3.new(0,.8,0),center+dir*28+side*i*7.5+Vector3.new(0,.8,0),Color3.fromRGB(255,82,82),.33,payload.duration or 1.5)
            end
            ring(center+dir*28,Color3.fromRGB(255,82,82),11,payload.duration or 1.5,16,.4)
            -- Warn both the swept dash corridor and final slam.
        end
    elseif mode=="BossMark" then
        ring(center,Color3.fromRGB(255,80,78),payload.radius or (step==3 and 10 or 5.5),payload.duration or (step==3 and 1.85 or 1.55),18,.4)
        orb(center+Vector3.new(0,.7,0),1,col,.75,3,.7)
    elseif mode=="BossStrike" then
        local dist=cameraRoot() and (cameraRoot().Position-center).Magnitude or 100
        playSound(BOSS_SOUND[step],dist)
        if step==1 then
            ring(center,col,26,.45,22,.5)
            ring(center,Color3.fromRGB(255,225,255),19,.32,18,1)
            orb(center+Vector3.new(0,4,0),10,col,.42,30,.78)
        elseif step==2 then
            for layer=1,3 do
                local radius=payload.radius or (layer*6+6)
                ring(center,col,radius,.45,14,layer*2.2)
                for k=1,6 do
                    local a=k*math.pi/3+layer*.4
                    streak(center+Vector3.new(math.cos(a)*radius,1,math.sin(a)*radius),
                        center+Vector3.new(math.cos(a+1)*radius,9,math.sin(a+1)*radius),col,.35,.42)
                end
            end
        elseif step==3 then
            orb(center+Vector3.new(0,2,0),4,Color3.fromRGB(255,180,65),.5,20,.28)
            ring(center,Color3.fromRGB(255,96,59),payload.radius or 10,.5,16,.4)
            for j=1,9 do
                local a=j*math.pi*2/9
                streak(center+Vector3.new(0,18,0),center+Vector3.new(math.cos(a)*7,0,math.sin(a)*7),Color3.fromRGB(255,212,102),.5,.5)
            end
        elseif step==4 then
            for i=0,10 do
                local where=center+dir*i*6
                orb(where+Vector3.new(0,2,0),1.5,col,.27,3,.3)
                if i<10 then streak(where+Vector3.new(0,3,0),where+dir*6+Vector3.new(0,2,0),col,.8,.38) end
            end
        else
            ring(center,col,payload.radius or 11,.6,20,.65)
            for j=-3,3 do
                streak(center+side*j*1.8+Vector3.new(0,1,0),center-dir*23+side*j*3.1+Vector3.new(0,2,0),col,.56,.45)
            end
            orb(center+Vector3.new(0,1,0),8,col,.48,20,.7)
        end
    end
end

Feedback.OnClientEvent:Connect(function(kind,_,payload)
    if kind~="Visual" or type(payload)~="table" then return end
    if typeof(payload.origin)~="Vector3" or typeof(payload.direction)~="Vector3" then return end
    local mode=payload.kind
    if mode=="Attack" or mode=="Power" or mode=="Heavy" then
        task.spawn(whipSwing,payload)
        if mode=="Power" then
            task.delay(math.max(0,(payload.impactServerTime or (workspace:GetServerTimeNow()+.37))-workspace:GetServerTimeNow()),function()
                if fx.Parent then abilitySpectacle(payload) end
            end)
        end
        if mode=="Heavy" and nearby(payload.origin) then
            local at=payload.origin+payload.direction.Unit*15
            ring(at,payload.color,10,.45,14,1.8)
            orb(at+Vector3.new(0,2,0),4,payload.color,.48,12,.48)
        end
    elseif mode=="PowerPulse" then
        abilitySpectacle(payload)
    elseif mode=="Dodge" or mode=="BotDodge" then
        dodgeVisual(payload)
    elseif mode=="BossTell" or mode=="BossMark" or mode=="BossStrike" then
        bossVisual(payload)
    elseif mode=="Impact" and nearby(payload.origin) then
        local color=typeof(payload.color)=="Color3" and payload.color or Color3.fromRGB(255,255,255)
        orb(payload.origin+Vector3.new(0,1.2,0),1.3,color,.24,6,.12)
        for i=1,7 do
            local ang=i*math.pi*2/7
            local direct=Vector3.new(math.cos(ang),rand:NextNumber(-.2,1),math.sin(ang))
            streak(payload.origin+Vector3.new(0,1,0),payload.origin+Vector3.new(0,1,0)+direct*rand:NextNumber(3,7),color,.32,.24)
        end
    end
end)
