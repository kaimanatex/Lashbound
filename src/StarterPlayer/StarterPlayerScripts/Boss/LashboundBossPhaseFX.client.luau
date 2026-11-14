-- V18 second-phase combat effects. Every telegraph uses the SAME locked geometry
-- the server later tests for damage. No touch parts, no client-side hit detection.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local Feedback=ReplicatedStorage:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local folder=Instance.new("Folder")
folder.Name="V18BossPhaseFX"
folder.Parent=Workspace
local rng=Random.new()
local colors={danger=Color3.fromRGB(255,77,83),light=Color3.fromRGB(255,245,228)}
local function near(origin)
    local c=player.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    return r and (r.Position-origin).Magnitude<270
end
local function floorPoint(position)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    local ignore={folder}
    if player.Character then table.insert(ignore,player.Character) end
    params.FilterDescendantsInstances=ignore
    params.RespectCanCollide=true
    local hit=Workspace:Raycast(position+Vector3.new(0,14,0),Vector3.new(0,-50,0),params)
    return hit and hit.Position+Vector3.new(0,.25,0) or Vector3.new(position.X,position.Y-2.5,position.Z)
end
local function line(a,b,color,life,width,alpha)
    local delta=b-a
    if delta.Magnitude<.1 then return end
    local p=Instance.new("Part")
    p.Name="BossPhaseTelegraph"
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Material=Enum.Material.Neon
    p.Color=color;p.Transparency=alpha or .13
    p.Size=Vector3.new(width or .55,.12,delta.Magnitude)
    p.CFrame=CFrame.lookAt((a+b)*.5,b)
    p.Parent=folder
    TweenService:Create(p,TweenInfo.new(life,Enum.EasingStyle.Linear),{Transparency=1}):Play()
    Debris:AddItem(p,life+.08)
end
local function orb(at,color,life,scale)
    local p=Instance.new("Part")
    p.Name="PhaseImpact"
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.Shape=Enum.PartType.Ball;p.CastShadow=false
    p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=.15
    p.Size=Vector3.new(1.5,1.5,1.5);p.CFrame=CFrame.new(at)
    p.Parent=folder
    TweenService:Create(p,TweenInfo.new(life,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
        Transparency=1,Size=Vector3.new(scale,scale,scale)
    }):Play()
    Debris:AddItem(p,life+.1)
end
local function ring(center,radius,color,duration,width,alpha)
    local n=math.clamp(math.ceil(radius*.44),20,40)
    for i=1,n do
        local a=math.pi*2*(i-1)/n
        local b=math.pi*2*i/n
        local start=floorPoint(center+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius))
        local finish=floorPoint(center+Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius))
        line(start,finish,color,duration,width or .6,alpha or .17)
    end
end
local function lane(origin,direction,length,width,color,duration)
    local d=Vector3.new(direction.X,0,direction.Z)
    if d.Magnitude<.1 then return end
    d=d.Unit
    local s=Vector3.new(-d.Z,0,d.X)
    local p1=floorPoint(origin+s*width)
    local p2=floorPoint(origin-s*width)
    local p3=floorPoint(origin+s*width+d*length)
    local p4=floorPoint(origin-s*width+d*length)
    line(p1,p3,color,duration,.64,.12)
    line(p2,p4,color,duration,.64,.12)
    line(p3,p4,color,duration,.8,.12)
    for i=1,4 do
        local amount=i/5
        line(p1:Lerp(p3,amount),p2:Lerp(p4,amount),color,duration,.3,.67)
    end
end
local function cone(origin,direction,length,dot,color,duration)
    local d=Vector3.new(direction.X,0,direction.Z)
    if d.Magnitude<.1 then return end
    d=d.Unit
    local side=Vector3.new(-d.Z,0,d.X)
    local half=math.acos(math.clamp(dot,-1,1))
    local center=floorPoint(origin)
    local prev=nil
    for i=0,14 do
        local a=-half+i*half*2/14
        local pt=floorPoint(origin+(d*math.cos(a)+side*math.sin(a))*length)
        if prev then line(prev,pt,color,duration,.64,.13) end
        if i==0 or i==14 or i==7 then line(center,pt,color,duration,.35,.50) end
        prev=pt
    end
end
local function displayWarning(p,duration)
    local shape=p.shape
    local clr=colors.danger
    if shape=="circle" then
        local r=tonumber(p.radius) or 12
        ring(p.origin,r,clr,duration)
        -- Interior outlines indicate this is a filled danger zone, not only an edge.
        if r>=18 then
            ring(p.origin,r*.42,clr,duration,.24,.67)
            ring(p.origin,r*.72,clr,duration,.24,.67)
        end
    elseif shape=="ring" then
        local r=tonumber(p.radius) or 20
        local inside=tonumber(p.innerRadius) or 0
        ring(p.origin,r,clr,duration,.85,.13)
        if inside>0 then ring(p.origin,inside,clr,duration,.55,.27) end
        -- Radial hatching makes the actual annular hit band visible.
        for k=0,7 do
            local a=k*math.pi/4
            local v=Vector3.new(math.cos(a),0,math.sin(a))
            local a0=floorPoint(p.origin+v*math.max(inside,1))
            local a1=floorPoint(p.origin+v*r)
            line(a0,a1,clr,duration,.22,.72)
        end
    elseif shape=="lane" then
        lane(p.origin,p.direction,tonumber(p.range) or 50,tonumber(p.halfWidth) or 5,clr,duration)
    elseif shape=="cone" then
        cone(p.origin,p.direction,tonumber(p.range) or 40,tonumber(p.dot) or .55,clr,duration)
    end
    local pole=Instance.new("Part")
    pole.Name="PhaseAttackWarningAnchor"
    pole.Anchored=true;pole.CanCollide=false;pole.CanQuery=false;pole.CanTouch=false
    pole.Transparency=1;pole.Size=Vector3.one
    pole.Position=p.origin+Vector3.new(0,9,0);pole.Parent=folder
    local billboard=Instance.new("BillboardGui")
    billboard.AlwaysOnTop=true;billboard.MaxDistance=270
    billboard.Size=UDim2.fromOffset(210,46);billboard.Parent=pole
    local text=Instance.new("TextLabel")
    text.BackgroundColor3=Color3.fromRGB(65,18,29)
    text.BackgroundTransparency=.16
    text.TextColor3=Color3.fromRGB(255,218,171)
    text.Font=Enum.Font.GothamBlack;text.TextScaled=true
    text.TextStrokeTransparency=.25
    text.Text="⚠ "..tostring(p.name or "COLOSSUS ATTACK")
    text.Size=UDim2.fromScale(1,1);text.Parent=billboard
    Debris:AddItem(pole,duration+.1)
end
local lastImpactSound=-100
local function playImpact(at,special)
    local now=os.clock()
    if now-lastImpactSound<.11 then return end
    lastImpactSound=now
    local sound=Instance.new("Sound")
    sound.Name="BossPhaseImpactAudio"
    sound.SoundId=(special==11 or special==12) and "rbxasset://sounds/impact_generic.mp3" or "rbxasset://sounds/swordlunge.wav"
    sound.Volume=.9;sound.PlaybackSpeed=.72+rng:NextNumber(0,.22)
    sound.Parent=SoundService;sound:Play()
    Debris:AddItem(sound,2.3)
end
local function announce(text,color,duration)
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local gui=Instance.new("ScreenGui")
    gui.Name="BossV18Announcement";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false
    gui.DisplayOrder=35;gui.Parent=pg
    local title=Instance.new("TextLabel")
    title.Name="BossCinematicTitle"
    title.Size=UDim2.new(.88,0,0,85)
    title.Position=UDim2.new(.06,0,.16,0)
    title.BackgroundTransparency=1
    title.TextColor3=color;title.TextStrokeColor3=Color3.new(0,0,0)
    title.TextStrokeTransparency=.05
    title.Font=Enum.Font.GothamBlack
    title.TextScaled=true;title.Text=text
    title.Parent=gui
    TweenService:Create(title,TweenInfo.new(duration*.55,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
        Position=UDim2.new(.06,0,.11,0)
    }):Play()
    task.delay(duration*.6,function()
        if title.Parent then TweenService:Create(title,TweenInfo.new(duration*.35),{TextTransparency=1,TextStrokeTransparency=1}):Play() end
    end)
    Debris:AddItem(gui,duration+.15)
end
Feedback.OnClientEvent:Connect(function(kind,_,payload)
    if kind~="Visual" or type(payload)~="table" then return end
    local mode=payload.kind
    if mode~="BossPhaseTell" and mode~="BossPhaseStrike" and mode~="BossRevival"
        and mode~="BossAscended" and mode~="BotTell" and mode~="BotStrike" then return end
    if typeof(payload.origin)~="Vector3" or not near(payload.origin) then return end
    local col=typeof(payload.color)=="Color3" and payload.color or Color3.fromRGB(239,135,249)
    if mode=="BotTell" then
        cone(payload.origin,payload.direction,tonumber(payload.range) or 14,
            tonumber(payload.dot) or .54,colors.danger,
            math.max(.1,tonumber(payload.duration) or .4))
    elseif mode=="BotStrike" then
        orb(payload.origin+Vector3.new(0,2,0),col,.2,6)
        cone(payload.origin,payload.direction,tonumber(payload.range) or 14,
            tonumber(payload.dot) or .54,col,.17)
    elseif mode=="BossRevival" then
        announce("COLOSSUS FALLEN — SECOND WIND",col,3.3)
        ring(payload.origin,12,col,2.4,1.2,.09)
        ring(payload.origin,25,colors.danger,3,1.4,.07)
        orb(payload.origin+Vector3.new(0,8,0),col,3.1,26)
    elseif mode=="BossAscended" then
        announce("ASCENDED COLOSSUS • PHASE II",col,3.0)
        ring(payload.origin,32,col,.55,1.7,.02)
        orb(payload.origin+Vector3.new(0,12,0),col,.9,43)
        playImpact(payload.origin,15)
    elseif mode=="BossPhaseTell" then
        local duration=math.clamp((tonumber(payload.impactServerTime) or Workspace:GetServerTimeNow()+1.4)-Workspace:GetServerTimeNow(),.12,4.2)
        displayWarning(payload,duration)
    elseif mode=="BossPhaseStrike" then
        -- Server issues the strike message immediately before applying damage.
        -- These impact flashes and audio therefore share the authoritative hit moment.
        local shape=payload.shape
        local radius=shape=="ring" and (tonumber(payload.radius) or 22)
            or shape=="circle" and (tonumber(payload.radius) or 13) or 11
        if shape=="lane" then
            lane(payload.origin,payload.direction,tonumber(payload.range) or 60,
                tonumber(payload.halfWidth) or 5,col,.34)
            orb(payload.origin+payload.direction.Unit*math.min(38,tonumber(payload.range) or 38)+Vector3.new(0,2,0),col,.3,7)
        elseif shape=="cone" then
            cone(payload.origin,payload.direction,tonumber(payload.range) or 40,tonumber(payload.dot) or .5,col,.34)
            orb(payload.origin+payload.direction.Unit*22+Vector3.new(0,2,0),col,.3,9)
        else
            ring(payload.origin,radius,col,.48,1.1,.02)
            orb(payload.origin+Vector3.new(0,1.5,0),col,.42,math.min(70,radius*1.05))
        end
        playImpact(payload.origin,tonumber(payload.step) or 6)
    end
end)
