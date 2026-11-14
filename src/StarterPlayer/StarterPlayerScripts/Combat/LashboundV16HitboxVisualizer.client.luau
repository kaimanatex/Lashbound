-- LASHBOUND V16: visible attack reach and ability hit areas.
-- The server is the ONLY hit/damage authority; these temporary ground markers
-- are cosmetic previews using shape, size, direction and timing sent by it.
-- All parts are local, anchored, non-collidable, and automatically cleaned up.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local localPlayer=Players.LocalPlayer
local feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")

local fx=Instance.new("Folder")
fx.Name="LashboundV16HitboxHints"
fx.Parent=Workspace
local groundParams=RaycastParams.new()
groundParams.FilterType=Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater=true
-- Markers never collide and raycasts ignore other cosmetic markers and our rig.
groundParams.RespectCanCollide=true
local function refreshRaycastFilter()
    local ignored={fx}
    if localPlayer.Character then table.insert(ignored,localPlayer.Character) end
    groundParams.FilterDescendantsInstances=ignored
end
localPlayer.CharacterAdded:Connect(refreshRaycastFilter)
refreshRaycastFilter()

local function nearby(origin)
    local char=localPlayer.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    return root and (root.Position-origin).Magnitude<=150
end

local function unitFlat(v)
    if typeof(v)~="Vector3" then return Vector3.new(0,0,-1) end
    local flat=Vector3.new(v.X,0,v.Z)
    if flat.Magnitude<.1 then return Vector3.new(0,0,-1) end
    return flat.Unit
end

local function floorHeight(x,z,referenceY)
    -- Track terraces and natural map elevation so markers aren't buried in floors.
    local origin=Vector3.new(x,referenceY+10,z)
    local hit=Workspace:Raycast(origin,Vector3.new(0,-45,0),groundParams)
    return hit and (hit.Position.Y+.22) or (referenceY-2.6)
end

local function floorPoint(x,z,referenceY)
    return Vector3.new(x,floorHeight(x,z,referenceY),z)
end

local function partBase(name,color,alpha)
    local p=Instance.new("Part")
    p.Name=name
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false
    p.Material=Enum.Material.Neon
    p.Color=color
    p.Transparency=alpha
    p.Parent=fx
    return p
end

local function markerLine(a,b,color,width,lifetime,alpha)
    local delta=b-a
    if delta.Magnitude<.2 then return end
    local p=partBase("CombatReachOutline",color,alpha or .17)
    p.Size=Vector3.new(width,.13,delta.Magnitude)
    p.CFrame=CFrame.lookAt((a+b)*.5,b)
    TweenService:Create(p,TweenInfo.new(lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
        Transparency=1,
    }):Play()
    Debris:AddItem(p,lifetime+.07)
end

local function cone(origin,dir,range,dot,color,life)
    local angle=math.acos(math.clamp(dot,-1,1))
    local cross=Vector3.new(-dir.Z,0,dir.X)
    local count=10
    local center=floorPoint(origin.X,origin.Z,origin.Y)
    local curve={}
    for i=0,count do
        local a=-angle+(2*angle*i/count)
        local h=dir*math.cos(a)+cross*math.sin(a)
        local pt=origin+h*range
        curve[i+1]=floorPoint(pt.X,pt.Z,origin.Y)
    end
    for i=1,count do
        markerLine(curve[i],curve[i+1],color,.65,life,.12)
    end
    markerLine(center,curve[1],color,.55,life,.15)
    markerLine(center,curve[#curve],color,.55,life,.15)
    -- Sparse translucent spokes fill the wedge without hundreds of particles.
    for i=3,count-1,2 do
        markerLine(center,curve[i],color,1.2,life,.77)
    end
    local middle=origin+dir*range*.56
    local spot=floorPoint(middle.X,middle.Z,origin.Y)
    markerLine(center,spot,Color3.new(1,1,1),.28,life,.35)
end

local function ring(origin,radius,color,life)
    local count=18
    local perimeter={}
    for i=0,count do
        local a=2*math.pi*i/count
        local x=origin.X+radius*math.cos(a)
        local z=origin.Z+radius*math.sin(a)
        perimeter[i+1]=floorPoint(x,z,origin.Y)
    end
    for i=1,count do
        markerLine(perimeter[i],perimeter[i+1],color,.73,life,.15)
    end
    local center=floorPoint(origin.X,origin.Z,origin.Y)
    for i=1,count,3 do
        markerLine(center,perimeter[i],color,.35,life,.79)
    end
    local pulse=partBase("CombatReachCenter",color,.4)
    pulse.Shape=Enum.PartType.Ball
    pulse.Size=Vector3.new(.9,.24,.9)
    pulse.Position=center
    TweenService:Create(pulse,TweenInfo.new(life),{Transparency=1,Size=Vector3.new(4,.1,4)}):Play()
    Debris:AddItem(pulse,life+.07)
end

local function lane(origin,dir,range,halfWidth,color,life)
    local side=Vector3.new(-dir.Z,0,dir.X)
    local a=origin+side*halfWidth
    local b=origin-side*halfWidth
    local c=origin+dir*range+side*halfWidth
    local d=origin+dir*range-side*halfWidth
    local points={a,b,c,d}
    for i,v in ipairs(points) do points[i]=floorPoint(v.X,v.Z,origin.Y) end
    a,b,c,d=table.unpack(points)
    markerLine(a,c,color,.72,life,.1)
    markerLine(b,d,color,.72,life,.1)
    markerLine(c,d,color,.72,life,.1)
    markerLine(a,b,color,.4,life,.45)
    for i=1,3 do
        local amount=i/4
        markerLine(a:Lerp(c,amount),b:Lerp(d,amount),color,.5,life,.66)
    end
    -- A transparent strip indicates the dangerous corridor even from overhead.
    local mid=origin+dir*range*.5
    local base=floorPoint(mid.X,mid.Z,origin.Y)
    local tint=partBase("CombatReachLane",color,.89)
    tint.Size=Vector3.new(halfWidth*2,.05,range)
    tint.CFrame=CFrame.lookAt(base,base+dir)
    TweenService:Create(tint,TweenInfo.new(life),{Transparency=1}):Play()
    Debris:AddItem(tint,life+.07)
end

feedback.OnClientEvent:Connect(function(kind,_,payload)
    if kind~="Visual" or type(payload)~="table" then return end
    if payload.kind=="Attack" or payload.kind=="Heavy" then return end
    local box=payload.hitbox
    if type(box)~="table" or typeof(payload.origin)~="Vector3" or not nearby(payload.origin) then return end
    local shape=box.shape
    if shape~="cone" and shape~="ring" and shape~="lane" then return end
    local duration=math.clamp(tonumber(box.duration) or .48,.15,2)
    local dir=unitFlat(payload.direction)
    local center=payload.origin+dir*math.clamp(tonumber(box.centerOffset) or 0,0,80)
    local color=typeof(payload.color)=="Color3" and payload.color or Color3.fromRGB(255,218,95)
    if shape=="cone" then
        local range=math.clamp(tonumber(box.range) or 20,2,55)
        cone(center,dir,range,math.clamp(tonumber(box.dot) or .65,-1,1),color,duration)
    elseif shape=="ring" then
        ring(center,math.clamp(tonumber(box.radius) or 20,2,48),color,duration)
    else
        lane(center,dir,math.clamp(tonumber(box.range) or 30,2,55),
            math.clamp(tonumber(box.halfWidth) or 8,1,25),color,duration)
    end
end)
