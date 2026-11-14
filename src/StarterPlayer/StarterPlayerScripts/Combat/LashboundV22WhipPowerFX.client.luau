-- LASHBOUND V22: stronger, animated elemental ability presence, no client-side damage.
-- Brief, pooled-by-lifetime primitives only. Each power has a distinct 3-D silhouette.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local effects=Instance.new("Folder")
effects.Name="LashboundV22PowerVolume"
effects.Parent=workspace
local rng=Random.new()
local function near(p)
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    return root and (root.Position-p).Magnitude<165
end
local function make(name,at,sz,clr,life,material,shape,alpha)
    local p=Instance.new("Part")
    p.Name=name;p.Size=sz;p.CFrame=CFrame.new(at)
    p.Material=material or Enum.Material.Neon
    p.Color=clr;p.Shape=shape or Enum.PartType.Block
    p.Transparency=alpha or .18
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Parent=effects
    Debris:AddItem(p,life+.13)
    return p
end
local function breath(p,color,scale,duration)
    local orb=make("ElementalBreath",p,Vector3.new(1.5,1.5,1.5),color,duration,Enum.Material.Glass,Enum.PartType.Ball,.58)
    Tween:Create(orb,TweenInfo.new(duration,Enum.EasingStyle.Quart),{
        Size=Vector3.new(scale,scale*.7,scale),Transparency=1}):Play()
end
local function strand(a,b,color,life,width)
    local delta=b-a
    if delta.Magnitude<.1 then return end
    local p=make("ElementalStrand",(a+b)*.5,Vector3.new(width or .33,width or .33,delta.Magnitude),color,life)
    p.CFrame=CFrame.lookAt((a+b)*.5,b)
    Tween:Create(p,TweenInfo.new(life),{Transparency=1}):Play()
end
local function circle(at,radius,col,life,height)
    local n=16
    local y=height or 1.2
    local prev=nil
    for i=0,n do
        local a=i*math.pi*2/n
        local q=at+Vector3.new(math.cos(a)*radius,y,math.sin(a)*radius)
        if prev then strand(prev,q,col,life,.28) end
        prev=q
    end
end
local function dust(at,color,lifetime,number)
    local anchor=make("AuraParticleEmitter",at,Vector3.new(.1,.1,.1),color,lifetime,Enum.Material.SmoothPlastic,Enum.PartType.Block,1)
    local em=Instance.new("ParticleEmitter")
    em.Texture="rbxasset://textures/particles/sparkles_main.dds"
    em.Lifetime=NumberRange.new(.25,lifetime)
    em.Rate=0
    em.Speed=NumberRange.new(6,18)
    em.SpreadAngle=Vector2.new(140,140)
    em.Drag=6
    em.LightEmission=.8
    em.Color=ColorSequence.new(color,Color3.new(1,1,1))
    em.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.4),NumberSequenceKeypoint.new(1,0)})
    em.Parent=anchor
    em:Emit(number)
end
-- V26 universal 3D skill impact family: vertical energy columns, raised
-- shockwave perimeter, inner flash sphere and additive particles. All cosmetic;
-- the authoritative hitboxes and status effects remain on the server.
local function skillVolume(p,shock)
    local col=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(240,211,116)
    local dir=typeof(p.direction)=="Vector3" and p.direction or Vector3.new(0,0,-1)
    dir=Vector3.new(dir.X,0,dir.Z)
    if dir.Magnitude<.05 then dir=Vector3.new(0,0,-1) else dir=dir.Unit end
    local origin=p.origin+(shock and Vector3.zero or dir*9)
    local radius=shock and 7.5 or 9
    local life=shock and .34 or .52
    for i=0,11 do
        local a=2*math.pi*i/12
        local q=origin+Vector3.new(math.cos(a)*radius,1,math.sin(a)*radius)
        local nextA=2*math.pi*(i+1)/12
        local nextQ=origin+Vector3.new(math.cos(nextA)*radius,1,math.sin(nextA)*radius)
        strand(q,nextQ,col,life,.38)
        if i%3==0 then
            local ht=shock and 7 or 12
            local pillar=make("SkillEnergyPillar",q+Vector3.new(0,ht*.5,0),Vector3.new(.85,ht,.85),col,life,Enum.Material.Neon,Enum.PartType.Cylinder,.38)
            Tween:Create(pillar,TweenInfo.new(life,Enum.EasingStyle.Quad),{Transparency=1,Size=Vector3.new(.18,ht*1.12,.18)}):Play()
        end
    end
    local flash=make("SkillExpandingCore",origin+Vector3.new(0,3.3,0),Vector3.new(1.8,1.8,1.8),col,life,Enum.Material.Glass,Enum.PartType.Ball,.45)
    Tween:Create(flash,TweenInfo.new(life,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
        Size=Vector3.new(radius*1.55,radius*.86,radius*1.55),Transparency=1}):Play()
    dust(origin+Vector3.new(0,3,0),col,life,shock and 8 or 15)
end

local last={}
local function power(p)
    local point=p.origin
    local id=tostring(p.whipId or "Rope")
    local clr=typeof(p.color)=="Color3" and p.color or Color3.fromRGB(200,216,255)
    local direction=typeof(p.direction)=="Vector3" and p.direction or Vector3.new(0,0,-1)
    local dir=Vector3.new(direction.X,0,direction.Z)
    if dir.Magnitude<.05 then dir=Vector3.new(0,0,-1) else dir=dir.Unit end
    local right=Vector3.new(-dir.Z,0,dir.X)
    local center=point+dir*13
    dust(point+Vector3.new(0,2,0),clr,.65,10)
    if id=="Rope" then
        for k=-1,1 do strand(point+Vector3.new(k*.9,3,0),point+dir*30+Vector3.new(k*1.5,2,0),clr,.42,.37) end
        breath(point+dir*24,clr,7,.43)
    elseif id=="Ember" then
        for i=1,3 do
            task.delay(.11*(i-1),function()
                if effects.Parent then
                    circle(point,8+i*4,clr,.4,1+i*.3)
                    dust(point+Vector3.new(0,1,0),clr,.6,8)
                end
            end)
        end
        breath(point+Vector3.new(0,4,0),Color3.fromRGB(255,117,45),17,.6)
    elseif id=="Frost" then
        for k=-4,4 do
            local origin=center+right*k*2.4
            strand(origin+Vector3.new(0,1,0),origin+Vector3.new(0,12-k%3,0),Color3.fromRGB(218,247,255),.65,.65)
        end
        breath(center,clr,19,.7)
    elseif id=="Volt" or id=="Judgement" then
        for k=-3,3 do
            local q=point+dir*(14+k*2)+right*(k*2.4)
            strand(q+Vector3.new(0,19,0),q+Vector3.new(0,1,0),Color3.fromRGB(255,240,141),.3,.39)
            dust(q+Vector3.new(0,2,0),clr,.38,5)
        end
        breath(center,clr,13,.45)
    elseif id=="Gravity" then
        circle(center,13,clr,.85,1)
        circle(center,8,Color3.fromRGB(221,194,255),.85,4)
        breath(center+Vector3.new(0,5,0),clr,15,.9)
    elseif id=="Echo" then
        circle(point,11,clr,.6,1.7)
        for i=1,7 do
            local a=i*math.pi*2/7
            local orbit=point+Vector3.new(math.cos(a)*7,2,math.sin(a)*7)
            strand(point+Vector3.new(0,2,0),orbit,clr,.43,.32)
            breath(orbit,clr,3.8,.48)
        end
        breath(point+Vector3.new(0,3,0),clr,11,.75)
    elseif id=="Phantom" then
        for k=-2,2 do
            strand(point+right*k*1.4+Vector3.new(0,2,0),point+dir*25+right*k*2.5+Vector3.new(0,3.5,0),clr,.48,.3)
        end
        breath(point+dir*25,clr,11,.5)
    elseif id=="Legend" then
        circle(point+dir*20,10,clr,.76,1.5)
        for i=0,7 do
            local a=2*math.pi*i/8
            local start=point+dir*20+Vector3.new(math.cos(a)*9,1,math.sin(a)*9)
            strand(start,start+Vector3.new(0,13,0),clr,.55,.31)
        end
        breath(point+dir*20,clr,13,.6)
    elseif id=="Owner" then
        circle(point,16,clr,.65,1.4)
        breath(point+dir*22,clr,20,.55)
    end
end
Feedback.OnClientEvent:Connect(function(kind,_,p)
    if kind~="Visual" or type(p)~="table" or typeof(p.origin)~="Vector3" then return end
    if p.kind~="Power" and p.kind~="PowerPulse" then return end
    if not near(p.origin) then return end
    local id=tostring(p.whipId or "Rope")
    local actor=tostring(p.actorUserId or 0)
    local now=os.clock()
    local key=actor..id
    if now-(last[key] or -20)<.22 then return end
    last[key]=now
    if p.kind=="Power" then power(p) end
    skillVolume(p,p.kind=="PowerPulse")
end)
