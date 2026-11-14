-- LASHBOUND V10: arena boss with five readable, server-authoritative attacks.
-- Exactly one boss at a time. Its 30-second respawn countdown begins ONLY when defeated.
-- The first boss appears when a player enters an arena; map rotation resets the encounter.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local bossCoins=ServerScriptService:WaitForChild("LashboundBossCoins")
local RNG=Random.new()
local INTERVAL=30
local MAX_HEALTH=800
local PHASE_TWO_HEALTH=800
local REVIVE_TIME=5.1
local PHASE_TWO_WINDUPS={1.7,1.9,1.8,2.0,2.15,1.8,1.85,1.55,1.65,2.4}
local activeArena
local epoch=0
local currentBoss=nil
local defeatedAt=nil
local nextBossAt=nil
local function publishState(state,untilTime)
    RS:SetAttribute("LashboundBossState",state)
    RS:SetAttribute("LashboundBossCountdownEnd",untilTime or 0)
end
publishState("WAITING_FOR_PLAYERS",nil)
local function makePart(model,name,size,col,collision)
    local p=Instance.new("Part")
    p.Name=name;p.Size=size;p.Color=col;p.Material=Enum.Material.Metal
    p.CanCollide=collision==true;p.CanTouch=false;p.Massless=name~="HumanoidRootPart"
    p.Parent=model
    return p
end
local function motor(parent,child,name,c0,c1)
    local m=Instance.new("Motor6D")
    m.Name=name;m.Part0=parent;m.Part1=child;m.C0=c0;m.C1=c1 or CFrame.identity;m.Parent=parent
    return m
end
local function weld(parent,child)
    local c=Instance.new("WeldConstraint");c.Part0=parent;c.Part1=child;c.Parent=child
end
local function playersInArena()
    local a={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("Zone")=="Arena" then
            local c=p.Character
            local h=c and c:FindFirstChildOfClass("Humanoid")
            local r=c and c:FindFirstChild("HumanoidRootPart")
            if h and h.Health>0 and r then table.insert(a,{player=p,root=r,hum=h}) end
        end
    end
    return a
end
local function nearest(pos)
    local closest,best=nil,350
    for _,t in ipairs(playersInArena()) do
        local d=(pos-t.root.Position).Magnitude
        if d<best then closest=t;best=d end
    end
    return closest,best
end
-- Collision and telegraphs use the same circles/lanes as the corresponding animation.
local function visual(source,kind,where,dir,color,step,meta)
    local payload={kind=kind,origin=where,direction=dir,color=color,step=step,whipId="Boss"}
    if meta then
        for key,value in pairs(meta) do payload[key]=value end
    end
    for _,t in ipairs(playersInArena()) do
        if (t.root.Position-where).Magnitude<265 then
            Feedback:FireClient(t.player,"Visual",kind,payload)
        end
    end
end
local function isLive(boss)
    return boss.active and boss.model.Parent and boss.hum.Health>0 and boss.epoch==epoch and activeArena==boss.arena
end
local function canBossHit(t)
    return t.hum.Health>0 and os.clock()>=(t.player:GetAttribute("SafeUntil") or 0)
        and os.clock()>=(t.player:GetAttribute("DodgeUntil") or 0)
end
local function hitPlayer(t,damage,origin,knock,alreadyHit)
    if alreadyHit and alreadyHit[t.player] then return false end
    if not canBossHit(t) then return false end
    if alreadyHit then alreadyHit[t.player]=true end
    t.player:SetAttribute("LastCombatAt",os.clock())
    t.hum:TakeDamage(damage)
    if knock and knock>0 then
        local diff=t.root.Position-origin
        local flat=Vector3.new(diff.X,0,diff.Z)
        if flat.Magnitude>.1 then t.root.AssemblyLinearVelocity=flat.Unit*knock+Vector3.new(0,7,0) end
    end
    Feedback:FireClient(t.player,"Message","COLOSSUS HIT -"..damage)
    return true
end
local function strikeArea(center,radius,damage,origin,knock,alreadyHit)
    for _,t in ipairs(playersInArena()) do
        local delta=t.root.Position-center
        local horizontal=Vector3.new(delta.X,0,delta.Z)
        if horizontal.Magnitude <= radius and math.abs(delta.Y)<=11 then
            hitPlayer(t,damage,origin,knock,alreadyHit)
        end
    end
end
-- Rectangular/swept lanes: no 64-stud auto-hit when a player sidesteps.
local function strikeLane(start,dir,length,halfWidth,damage,knock,alreadyHit)
    local f=Vector3.new(dir.X,0,dir.Z)
    if f.Magnitude<.1 then return end
    f=f.Unit
    for _,t in ipairs(playersInArena()) do
        local delta=t.root.Position-start
        local flat=Vector3.new(delta.X,0,delta.Z)
        local along=flat:Dot(f)
        local sideways=(flat-f*along).Magnitude
        if along>=-2 and along<=length+2 and sideways<=halfWidth and math.abs(delta.Y)<=10 then
            hitPlayer(t,damage,start,knock,alreadyHit)
        end
    end
end
local function tweenPose(motor,base,offset,time)
    if not motor or not motor.Parent then return end
    Tween:Create(motor,TweenInfo.new(time,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{C0=base*offset}):Play()
end
local WINDUP={1.6,1.45,1.85,1.55,1.5}
local poseAngles={
    {CFrame.Angles(math.rad(-100),0,math.rad(100)),CFrame.Angles(math.rad(-100),0,math.rad(-100)),CFrame.Angles(math.rad(-15),0,0)},
    {CFrame.Angles(math.rad(-25),math.rad(-95),math.rad(70)),CFrame.Angles(math.rad(25),math.rad(-20),math.rad(-45)),CFrame.Angles(0,math.rad(30),0)},
    {CFrame.Angles(math.rad(-135),0,math.rad(20)),CFrame.Angles(math.rad(-135),0,math.rad(-20)),CFrame.Angles(math.rad(-14),0,0)},
    {CFrame.Angles(math.rad(-85),math.rad(-35),math.rad(95)),CFrame.Angles(math.rad(-15),0,math.rad(-30)),CFrame.Angles(math.rad(9),math.rad(-20),0)},
    {CFrame.Angles(math.rad(55),0,math.rad(30)),CFrame.Angles(math.rad(55),0,math.rad(-30)),CFrame.Angles(math.rad(22),0,0)},
}
local function prepareAttack(boss,index,dir,windup)
    boss.hum:Move(Vector3.zero,false)
    boss.hum:MoveTo(boss.root.Position)
    local horizontal=Vector3.new(dir.X,0,dir.Z)
    if horizontal.Magnitude>.01 then
        local position=boss.root.Position
        boss.model:PivotTo(CFrame.lookAt(position,position+horizontal.Unit))
    end
    boss.model:SetAttribute("BossInAttack",true)
    boss.model:SetAttribute("BossAttackIndex",index)
    boss.model:SetAttribute("BossAttackStarted",Workspace:GetServerTimeNow())
    boss.model:SetAttribute("BossWindupDuration",windup)
    local pose=poseAngles[index] or {
        CFrame.Angles(math.rad(-105),math.rad((index%2==0) and 35 or -35),math.rad(62)),
        CFrame.Angles(math.rad(-85),0,math.rad(-42)),
        CFrame.Angles(math.rad(-16),math.rad((index%2==0) and 15 or -15),0)
    }
    tweenPose(boss.right,boss.rc0,pose[1],windup*.72)
    tweenPose(boss.left,boss.lc0,pose[2],windup*.72)
    if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,pose[3],windup*.72) end
    -- Last-resort timeout: missing targets and interrupted skills must never
    -- leave the Colossus trapped in BossInAttack forever.
    local serial=(boss.attackSerial or 0)+1
    boss.attackSerial=serial
    task.delay(9.5,function()
        if not isLive(boss) or boss.reviving or boss.attackSerial~=serial then return end
        if boss.model:GetAttribute("BossInAttack")==true then
            warn("[Lashbound Boss] Attack timeout; releasing movement lock",index)
            boss.model:SetAttribute("BossInAttack",false)
            boss.model:SetAttribute("BossAttackImpactTime",0)
            boss.hum.WalkSpeed=boss.phase==2 and 13 or 10
            if boss.root.Anchored then boss.root.Anchored=false end
            tweenPose(boss.right,boss.rc0,CFrame.identity,.22)
            tweenPose(boss.left,boss.lc0,CFrame.identity,.22)
            if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,CFrame.identity,.22) end
        end
    end)
end
local function releaseAttack(boss,index)
    if not isLive(boss) then return end
    local side=index%2==0 and -1 or 1
    tweenPose(boss.right,boss.rc0,CFrame.Angles(math.rad(44),math.rad(105*side),math.rad(-70*side)),.11)
    tweenPose(boss.left,boss.lc0,CFrame.Angles(math.rad(12),math.rad(-30*side),math.rad(18*side)),.13)
    if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,CFrame.Angles(math.rad(-15),0,0),.14) end
    task.delay(.17,function()
        if not boss.model.Parent then return end
        tweenPose(boss.right,boss.rc0,CFrame.identity,.30)
        tweenPose(boss.left,boss.lc0,CFrame.identity,.30)
        if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,CFrame.identity,.30) end
    end)
end
local function finishAttack(boss)
    if not boss.model.Parent then return end
    boss.model:SetAttribute("BossInAttack",false)
    boss.model:SetAttribute("BossAttackImpactTime",0)
    if not boss.reviving then
        if boss.root.Anchored then boss.root.Anchored=false end
        if boss.hum.WalkSpeed<3 then boss.hum.WalkSpeed=boss.phase==2 and 13 or 10 end
    end
end
local function runAttack(boss,index,target)
    if not isLive(boss) or boss.reviving or not target.root.Parent then return end
    local r=boss.root
    local difference=target.root.Position-r.Position
    local flat=Vector3.new(difference.X,0,difference.Z)
    local dir=flat.Magnitude>.1 and flat.Unit or Vector3.new(0,0,-1)
    local origin=r.Position
    local color=boss.color
    local windup=WINDUP[index]
    prepareAttack(boss,index,dir,windup)
    visual(boss,"BossTell",origin,dir,color,index,{duration=windup})
    if index==3 then
        -- Ground-targeted meteors snapshot their actual 10-stud impact areas.
        local marked={}
        for _,p in ipairs(playersInArena()) do
            if (p.root.Position-origin).Magnitude<95 and #marked<4 then
                table.insert(marked,p.root.Position)
            end
        end
        if #marked==0 then table.insert(marked,origin+dir*20) end
        for _,where in ipairs(marked) do
            visual(boss,"BossMark",where,dir,Color3.fromRGB(255,93,65),index,{radius=10,duration=windup})
        end
        task.wait(windup)
        if not isLive(boss) or boss.reviving then return end
        releaseAttack(boss,index)
        for _,where in ipairs(marked) do
            visual(boss,"BossStrike",where,dir,Color3.fromRGB(255,120,66),index,{radius=10})
            strikeArea(where,10,22,where,22)
        end
    elseif index==4 then
        -- This is a locked *directional lane*, NOT a target-locked distance check.
        -- The long rectangle is shown by BossTell; do not mark a misleading
        -- circle on the player's old position. Once telegraphed, the direction
        -- and lane origin remain locked even if the victim moves.
        task.wait(windup)
        if not isLive(boss) or boss.reviving then return end
        releaseAttack(boss,index)
        visual(boss,"BossStrike",origin,dir,color,index,{range=64,halfWidth=5.5})
        strikeLane(origin,dir,64,5.5,16,35)
    elseif index==5 then
        -- One physical-looking, collision-tested 28-stud dash. Damage only
        -- to the corridor actually traveled, followed by an 11-stud slam.
        task.wait(windup)
        if not isLive(boss) or boss.reviving then return end
        releaseAttack(boss,index)
        local position=r.Position
        local traveled=0
        local stepDistance=2
        local ray=RaycastParams.new()
        ray.FilterType=Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances={boss.model}
        ray.RespectCanCollide=true
        for i=1,14 do
            if not isLive(boss) or boss.reviving then return end
            local sweep=Workspace:Blockcast(CFrame.new(r.Position),Vector3.new(5.4,6.5,5.4),dir*stepDistance,ray)
            local d=sweep and math.max(0,sweep.Distance-.4) or stepDistance
            if d<=.1 then break end
            boss.model:PivotTo(boss.model:GetPivot()+dir*d)
            traveled+=d
            if sweep then break end
            task.wait(.027)
        end
        if not isLive(boss) or boss.reviving then return end
        local hitAlready={}
        visual(boss,"BossStrike",r.Position,dir,color,index,{radius=11,range=traveled})
        strikeLane(position,dir,traveled,7.5,16,23,hitAlready)
        strikeArea(r.Position,11,22,r.Position,38,hitAlready)
    elseif index==2 then
        -- Each cyclone sweep lands as the arms snap; its outline matches radius.
        task.wait(windup)
        for pulse=1,3 do
            if not isLive(boss) or boss.reviving then return end
            local radius=15+pulse*2
            releaseAttack(boss,index)
            visual(boss,"BossStrike",origin,dir,color,index,{radius=radius,pulse=pulse})
            strikeArea(origin,radius,6,origin,12)
            if pulse<3 then task.wait(.52) end
        end
    else -- Thunderquake: single readable 26-stud blast at end of windup.
        task.wait(windup)
        if not isLive(boss) or boss.reviving then return end
        releaseAttack(boss,index)
        visual(boss,"BossStrike",origin,dir,color,index,{radius=26})
        strikeArea(origin,26,18,origin,30)
    end
    task.wait(.4)
    finishAttack(boss)
end

-- Phase-two geometry is shared between telegraphs and server damage. Warning
-- shapes never track a player after the windup starts. A dodge can escape them.
local PHASE_NAMES={
    [6]="STAR LANCE", [7]="METEOR BARRAGE", [8]="TRIDENT BOLTS",
    [9]="CRYSTAL RAIN", [10]="VORTEX ORB", [11]="SEISMIC RINGS",
    [12]="TWIN CRESCENTS", [13]="TITAN CRUSH", [14]="BLADE SPIRAL",
    [15]="CATACLYSM"
}
-- V20: Ascended difficulty. Single geometry source for warns AND damage.
-- These numbers are STUDS. Tells do not follow players after they begin.
local P2_AREAS={
    StarLance={range=155,halfWidth=7.5},
    Meteor={radius=15.5,maxReach=175,maxSpots=6},
    Trident={range=133,halfWidth=5.8},
    Crystal={radius=12.5,count=7,start=32,spacing=18,lateral=14,delay=.19},
    Vortex={radius=23.5,maxReach=165},
    Seismic={radii={18,37,59,83},delay=.47},
    Crescents={range=76,dot=.32,delay=.55},
    Titan={radius=27},
    Blade={range=66,halfWidth=8.0,delay=.37},
    Cataclysm={outer=78,inner=32,delay=.65},
}
local function turnFlat(v,radians)
    local c,s=math.cos(radians),math.sin(radians)
    return Vector3.new(v.X*c-v.Z*s,0,v.X*s+v.Z*c)
end
local function strikeRingBand(origin,minRadius,maxRadius,damage,knock)
    for _,t in ipairs(playersInArena()) do
        local delta=t.root.Position-origin
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude>=minRadius and flat.Magnitude<=maxRadius and math.abs(delta.Y)<=11
            and clearBossLine(origin+Vector3.new(0,2,0),t.root.Position+Vector3.new(0,2,0)) then
            hitPlayer(t,damage,origin,knock)
        end
    end
end
local function strikeSector(origin,dir,length,dot,damage,knock)
    for _,t in ipairs(playersInArena()) do
        local delta=t.root.Position-origin
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude>1 and flat.Magnitude<=length and math.abs(delta.Y)<=13
            and flat.Unit:Dot(dir)>=dot
            and clearBossLine(origin+Vector3.new(0,2,0),t.root.Position+Vector3.new(0,2,0)) then
            hitPlayer(t,damage,origin,knock) end
    end
end
local function p2Notice(boss,index,at,dir,shape,meta,warning)
    local fields={name=PHASE_NAMES[index],shape=shape,phase=2,
        duration=warning,impactServerTime=Workspace:GetServerTimeNow()+warning}
    if meta then for k,v in pairs(meta) do fields[k]=v end end
    visual(boss,"BossPhaseTell",at,dir,boss.color,index,fields)
end
local function p2Impact(boss,index,at,dir,shape,meta)
    local fields={name=PHASE_NAMES[index],shape=shape,phase=2,
        impactServerTime=Workspace:GetServerTimeNow()}
    if meta then for k,v in pairs(meta) do fields[k]=v end end
    visual(boss,"BossPhaseStrike",at,dir,boss.color,index,fields)
end
local function p2Wait(boss,t)
    task.wait(t)
    return isLive(boss) and not boss.reviving
end
local function phaseTwoAttack(boss,index,target)
    if not isLive(boss) or boss.reviving or boss.phase~=2 or not target.root.Parent then return end
    local origin=boss.root.Position
    local flat=target.root.Position-origin
    local dir=Vector3.new(flat.X,0,flat.Z)
    dir=dir.Magnitude>.1 and dir.Unit or Vector3.new(0,0,-1)
    local windup=PHASE_TWO_WINDUPS[index-5]
    local base=origin
    prepareAttack(boss,index,dir,windup)
    boss.model:SetAttribute("BossAttackName",PHASE_NAMES[index])
    boss.model:SetAttribute("BossAttackImpactTime",Workspace:GetServerTimeNow()+windup)
    -- 6-10 are five ranged attacks; 11-12 are visible shockwaves.
    if index==6 then -- wider long-distance Star Lance
        local g=P2_AREAS.StarLance
        p2Notice(boss,index,base,dir,"lane",g,windup)
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        p2Impact(boss,index,base,dir,"lane",g)
        strikeLane(base,dir,g.range,g.halfWidth,18,26)
    elseif index==7 then -- six broad meteors; snapshots freeze at warning time
        local g=P2_AREAS.Meteor
        local spots={}
        for _,t in ipairs(playersInArena()) do
            if (t.root.Position-origin).Magnitude<g.maxReach then
                table.insert(spots,t.root.Position)
                if #spots>=3 then break end
            end
        end
        if #spots==0 then spots={origin+dir*65} end
        local anchor=spots[1]
        while #spots<g.maxSpots do
            local a=(#spots-1)*math.pi*2/(g.maxSpots-1)
            local spread=26
            table.insert(spots,anchor+Vector3.new(math.cos(a)*spread,0,math.sin(a)*spread))
        end
        -- Avoid a six-hit burst when overlapping meteor circles strike one target.
        local alreadyHit={}
        for _,point in ipairs(spots) do
            p2Notice(boss,index,point,dir,"circle",{radius=g.radius},windup)
        end
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        for _,point in ipairs(spots) do
            p2Impact(boss,index,point,dir,"circle",{radius=g.radius})
            strikeArea(point,g.radius,17,point,24,alreadyHit)
        end
    elseif index==8 then -- five wide fan lanes for a broad ranged volley
        local g=P2_AREAS.Trident
        local rays={turnFlat(dir,-.48),turnFlat(dir,-.24),dir,turnFlat(dir,.24),turnFlat(dir,.48)}
        for _,r in ipairs(rays) do
            p2Notice(boss,index,origin,r,"lane",g,windup)
        end
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        local seen={}
        for _,r in ipairs(rays) do
            p2Impact(boss,index,origin,r,"lane",g)
            strikeLane(origin,r,g.range,g.halfWidth,14,22,seen)
        end
    elseif index==9 then -- seven 25-stud crystal explosions across the field
        local g=P2_AREAS.Crystal
        local spots={}
        local side=Vector3.new(-dir.Z,0,dir.X)
        for n=1,g.count do
            local point=origin+dir*(g.start+n*g.spacing)+side*((n%2==0 and 1 or -1)*g.lateral)
            table.insert(spots,point)
            p2Notice(boss,index,point,dir,"circle",{radius=g.radius},windup+(n-1)*g.delay)
        end
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        for n,point in ipairs(spots) do
            if not isLive(boss) then return end
            p2Impact(boss,index,point,dir,"circle",{radius=g.radius})
            strikeArea(point,g.radius,13,point,17)
            if n<#spots then task.wait(g.delay) end
        end
    elseif index==10 then -- long-range vortex with a 47-stud diameter
        local g=P2_AREAS.Vortex
        local point=target.root.Position
        if (point-origin).Magnitude>g.maxReach then point=origin+dir*g.maxReach end
        p2Notice(boss,index,point,dir,"circle",{radius=g.radius},windup)
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        p2Impact(boss,index,point,dir,"circle",{radius=g.radius})
        for _,t in ipairs(playersInArena()) do
            local offset=point-t.root.Position
            if Vector3.new(offset.X,0,offset.Z).Magnitude<=g.radius and math.abs(offset.Y)<=12 then
                if hitPlayer(t,17,point,0) and offset.Magnitude>2 then
                    local horizontal=Vector3.new(offset.X,0,offset.Z)
                    if horizontal.Magnitude>.1 then
                        t.root.AssemblyLinearVelocity=horizontal.Unit*42+Vector3.new(0,7,0)
                    end
                end
            end
        end
    elseif index==11 then -- four escalating shockwave bands to 83 studs
        local g=P2_AREAS.Seismic
        local radii=g.radii
        for n,radius in ipairs(radii) do
            p2Notice(boss,index,origin,dir,"ring",{radius=radius,innerRadius=n==1 and 0 or radii[n-1]-1},windup+(n-1)*g.delay)
        end
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        for n,radius in ipairs(radii) do
            if not isLive(boss) then return end
            local low=n==1 and 0 or radii[n-1]-1
            p2Impact(boss,index,origin,dir,"ring",{radius=radius,innerRadius=low})
            strikeRingBand(origin,low,radius,13,30)
            if n<#radii then task.wait(g.delay) end
        end
    elseif index==12 then -- two sweeping cone shockwaves out to 76 studs
        local g=P2_AREAS.Crescents
        local waves={turnFlat(dir,-.42),turnFlat(dir,.42)}
        for n,r in ipairs(waves) do
            p2Notice(boss,index,origin,r,"cone",{range=g.range,dot=g.dot},windup+(n-1)*g.delay)
        end
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        for n,r in ipairs(waves) do
            if not isLive(boss) then return end
            p2Impact(boss,index,origin,r,"cone",{range=g.range,dot=g.dot})
            strikeSector(origin,r,g.range,g.dot,17,29)
            if n<#waves then task.wait(g.delay) end
        end
    elseif index==13 then -- massive but dodgable 27-stud stomp
        local g=P2_AREAS.Titan
        p2Notice(boss,index,origin,dir,"circle",g,windup)
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        p2Impact(boss,index,origin,dir,"circle",g)
        strikeArea(origin,g.radius,24,origin,35)
    elseif index==14 then -- rotating wide blades reach 66 studs
        local g=P2_AREAS.Blade
        local rays={dir,turnFlat(dir,math.pi*.5),turnFlat(dir,math.pi),turnFlat(dir,-math.pi*.5)}
        for n,r in ipairs(rays) do
            p2Notice(boss,index,origin,r,"lane",g,windup+(n-1)*g.delay)
        end
        if not p2Wait(boss,windup) then return end
        for n,r in ipairs(rays) do
            if not isLive(boss) then return end
            releaseAttack(boss,index)
            p2Impact(boss,index,origin,r,"lane",g)
            strikeLane(origin,r,g.range,g.halfWidth,14,25)
            if n<#rays then task.wait(g.delay) end
        end
    else -- 15: huge outer-ring detonation followed by inner aftershock
        local g=P2_AREAS.Cataclysm
        p2Notice(boss,index,origin,dir,"ring",{radius=g.outer,innerRadius=g.inner},windup)
        p2Notice(boss,index,origin,dir,"circle",{radius=g.inner},windup+g.delay)
        if not p2Wait(boss,windup) then return end
        releaseAttack(boss,index)
        p2Impact(boss,index,origin,dir,"ring",{radius=g.outer,innerRadius=g.inner})
        strikeRingBand(origin,g.inner,g.outer,21,39)
        if not p2Wait(boss,g.delay) then return end
        p2Impact(boss,index,origin,dir,"circle",{radius=g.inner})
        strikeArea(origin,g.inner,15,origin,29)
    end
    if p2Wait(boss,.35) then finishAttack(boss) end
end

-- V26: one-knee collapse -> enlarge -> sky ascent -> charged hover ->
-- cinematic ground impact.  The same BossReviveStarted clock drives clients.
local function travelRevive(boss,from,to,duration)
    local start=os.clock()
    while boss.model.Parent and os.clock()-start<duration do
        local p=math.clamp((os.clock()-start)/duration,0,1)
        p=p*p*(3-2*p)
        boss.model:PivotTo(from:Lerp(to,p))
        task.wait(1/30)
    end
    if boss.model.Parent then boss.model:PivotTo(to) end
end
local function superchargeWhip(boss)
    local grip=boss.model:FindFirstChild("ColossusWhipGrip",true)
    if not grip then return end
    for _,piece in ipairs(boss.model:GetDescendants()) do
        if piece:IsA("BasePart") and piece.Name:match("^ColossusLash_") then
            piece.Material=Enum.Material.Neon
            piece.Color=boss.color
        end
    end
    local light=Instance.new("PointLight")
    light.Name="AscendedWhipGlow"
    light.Color=boss.color
    light.Range=23
    light.Brightness=3.2
    light.Shadows=false
    light.Parent=grip
    local charge=Instance.new("ParticleEmitter")
    charge.Name="AscendedWhipSparks"
    charge.Texture="rbxasset://textures/particles/sparkles_main.dds"
    charge.Color=ColorSequence.new(boss.color,Color3.fromRGB(255,255,255))
    charge.Rate=31
    charge.Lifetime=NumberRange.new(.18,.5)
    charge.Speed=NumberRange.new(3,8)
    charge.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.85),NumberSequenceKeypoint.new(1,0)})
    charge.LightEmission=1
    charge.Parent=grip
end
-- Geometry-aware support for oversized R6 bosses, including both feet and ankles.
local function footBottom(model)
    local lowest=math.huge
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA('BasePart') and (part.Name=='Left Foot' or part.Name=='Right Foot') then
            local cf=part.CFrame
            local half=part.Size*.5
            local extent=math.abs(cf.RightVector.Y)*half.X + math.abs(cf.UpVector.Y)*half.Y + math.abs(cf.LookVector.Y)*half.Z
            lowest=math.min(lowest,part.Position.Y-extent)
        end
    end
    return lowest
end
local function floorBelow(model,root)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={model}
    params.RespectCanCollide=true
    local hit=Workspace:Raycast(root.Position+Vector3.new(0,60,0),Vector3.new(0,-160,0),params)
    if hit and hit.Normal.Y>.7 then return hit.Position.Y end
    return nil
end
local function groundBossFeet(boss,extra)
    if not boss.model.Parent or not boss.root.Parent then return end
    local floorY=floorBelow(boss.model,boss.root)
    local lowest=footBottom(boss.model)
    if not floorY or lowest==math.huge then return end
    local clearance=floorY+(extra or .9)-lowest
    -- One-time placement at spawn / phase change: correct floating AND sinking.
    if math.abs(clearance)>.09 and math.abs(clearance)<45 then
        boss.model:PivotTo(boss.model:GetPivot()+Vector3.new(0,clearance,0))
    end
    -- Roblox R6 standing formula: upper leg Y + half root Y + HipHeight.
    -- HipHeight must NOT grow indefinitely from the root's world height.
    local upper=boss.model:FindFirstChild('Right Leg')
    if not upper then return end
    local desiredHip=footSpan+.18-upper.Size.Y-boss.root.Size.Y*.5
    boss.hum.HipHeight=math.clamp(desiredHip,0,28)
end
local function reviveBoss(boss)
    if not isLive(boss) or boss.reviving or boss.phase~=1 or boss.revived then return end
    boss.reviving=true
    boss.revived=true
    boss.model:SetAttribute("BossInvulnerable",true)
    boss.model:SetAttribute("BossReviving",true)
    boss.model:SetAttribute("BossReviveStarted",Workspace:GetServerTimeNow())
    boss.model:SetAttribute("BossReviveDuration",REVIVE_TIME)
    boss.model:SetAttribute("BossMoving",false)
    boss.model:SetAttribute("BossInAttack",false)
    boss.model:SetAttribute("BossAttackName","FALLEN TITAN - AWAKENING")
    boss.hum:Move(Vector3.zero,false)
    boss.hum.WalkSpeed=0
    boss.hum.Health=1
    local pivot=boss.model:GetPivot()
    boss.root.Anchored=true
    -- Revival is cinematic but should not permanently freeze the encounter if
    -- a tween/model operation unexpectedly exits before the landing cleanup.
    local reviveEpoch=boss.epoch
    task.delay(11,function()
        if not boss.model.Parent or not boss.reviving or boss.epoch~=reviveEpoch then return end
        warn("[Lashbound Boss] Revival watchdog restored arena movement")
        boss.phase=2
        boss.model:SetAttribute("BossPhase",2)
        boss.model:SetAttribute("BossHasRevived",true)
        boss.hum.MaxHealth=PHASE_TWO_HEALTH
        boss.hum.Health=PHASE_TWO_HEALTH
        boss.hum.WalkSpeed=13
        boss.root.Anchored=false
        boss.reviving=false
        boss.model:SetAttribute("BossReviving",false)
        boss.model:SetAttribute("BossInvulnerable",false)
        boss.model:SetAttribute("BossInAttack",false)
        groundBossFeet(boss,.28)
        publishState("BOSS_ASCENDED",nil)
    end)
    publishState("REVIVING",nil)
    visual(boss,"BossRevival",boss.root.Position,Vector3.new(0,0,-1),boss.color,0,{duration=REVIVE_TIME,phase=2})
    -- One knee hits the ground while the giant braces with its whip arm.
    tweenPose(boss.right,boss.rc0,CFrame.Angles(math.rad(89),0,math.rad(23)),.45)
    tweenPose(boss.left,boss.lc0,CFrame.Angles(math.rad(32),0,math.rad(-38)),.45)
    if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,CFrame.new(0,-1.45,0)*CFrame.Angles(math.rad(29),0,0),.50) end
    task.wait(1.20)
    if not isLive(boss) then return end
    -- Transform larger while immobilized; all 3D joints scale with Model:ScaleTo.
    local right0,left0,root0=boss.rc0,boss.lc0,boss.rootC0
    boss.model:ScaleTo(2)
    local basePivot=pivot+Vector3.new(0,4,0)
    boss.model:PivotTo(basePivot)
    for _,piece in ipairs(boss.model:GetDescendants()) do
        if piece:IsA("BasePart") and piece.Name~="HumanoidRootPart" then
            if piece.Name=="Torso" or piece.Name=="Head" or piece.Name:find("Arm") or piece.Name:find("Leg") then
                piece.Color=boss.color
                piece.Material=Enum.Material.Metal
            elseif piece.Name=="TitanHeart" or piece.Name=="CyclopsEye" or piece.Name:find("Lash") then
                piece.Color=boss.color
                piece.Material=Enum.Material.Neon
            end
        end
    end
    boss.rc0=CFrame.new(right0.Position*2)*right0.Rotation
    boss.lc0=CFrame.new(left0.Position*2)*left0.Rotation
    boss.rootC0=CFrame.new(root0.Position*2)*root0.Rotation
    tweenPose(boss.right,boss.rc0,CFrame.Angles(math.rad(-130),0,math.rad(14)),.62)
    tweenPose(boss.left,boss.lc0,CFrame.Angles(math.rad(-120),0,math.rad(-14)),.62)
    if boss.rootJoint then tweenPose(boss.rootJoint,boss.rootC0,CFrame.identity,.65) end
    boss.model:SetAttribute("BossAttackName","ASCENDING - TAKE COVER")
    -- Phase two doubles every articulated leg segment. The phase-one spawn
    -- clearance is no longer valid: measure BOTH feet after the scaling and
    -- pose tweens, then lift the entire model so neither foot intersects floor.
    task.wait(.70)
    if not isLive(boss) then return end
    groundBossFeet(boss,.28) -- scale-two footsteps need greater landing clearance
    basePivot=boss.model:GetPivot() -- use the corrected position for the sky return
    local skyPivot=basePivot+Vector3.new(0,25,0)
    travelRevive(boss,basePivot,skyPivot,.80)
    if not isLive(boss) then return end
    -- One second above the ground before the unavoidable-looking, but
    -- telegraphed, landing burst.  Real damage is NOT applied in the lobby.
    boss.model:SetAttribute("BossAttackName","SKYBORNE - IMPACT IMMINENT")
    task.wait(1.12)
    if not isLive(boss) then return end
    travelRevive(boss,skyPivot,basePivot,.66)
    if not isLive(boss) then return end
    boss.phase=2
    boss.model:SetAttribute("BossPhase",2)
    boss.model:SetAttribute("BossHasRevived",true)
    boss.hum.MaxHealth=PHASE_TWO_HEALTH
    boss.hum.Health=PHASE_TWO_HEALTH
    boss.model:SetAttribute("BossAttackName","ASCENDED COLOSSUS")
    superchargeWhip(boss)
    -- Camera vibration, shock ring, energy pillars, volumetric core and audio
    -- are dispatched to every nearby client at the moment of actual landing.
    visual(boss,"BossAscended",boss.root.Position,Vector3.new(0,0,-1),boss.color,0,{phase=2,landing=true,range=52})
    visual(boss,"BossReviveLanding",boss.root.Position,Vector3.new(0,0,-1),boss.color,0,{phase=2,radius=45})
    for _,gui in ipairs(boss.model:GetDescendants()) do
        if gui:IsA("BillboardGui") and gui.Name=="ColossusHealth" then
            gui.StudsOffsetWorldSpace=Vector3.new(0,18,0)
        end
    end
    task.wait(1.32) -- hold the charged landing pose; total revival ~5.1s
    if not isLive(boss) then return end
    groundBossFeet(boss,.28)
    boss.root.Anchored=false
    boss.hum.WalkSpeed=13
    boss.reviving=false
    boss.model:SetAttribute("BossReviving",false)
    boss.model:SetAttribute("BossInvulnerable",false)
    publishState("BOSS_ASCENDED",nil)
end

local function buildBoss(arena,slot)
    local family=RS:GetAttribute("LashboundMapIndex") or 1
    local colors={Color3.fromRGB(135,116,255),Color3.fromRGB(255,119,62),Color3.fromRGB(118,216,243),Color3.fromRGB(117,230,118),Color3.fromRGB(192,123,255)}
    local color=colors[family] or colors[1]
    local folder=arena:FindFirstChild("LashboundBosses")
    if not folder then folder=Instance.new("Folder");folder.Name="LashboundBosses";folder.Parent=arena end
    local model=Instance.new("Model")
    model.Name="COLOSSUS"
    model:SetAttribute("LashboundBoss",true)
    model:SetAttribute("BossPhase",1)
    model:SetAttribute("BossHasRevived",false)
    model:SetAttribute("BossReviving",false)
    model:SetAttribute("BossInvulnerable",false)
    local root=makePart(model,"HumanoidRootPart",Vector3.new(3,4,2),Color3.new(0,0,0),false)
    root.Transparency=1
    local torso=makePart(model,"Torso",Vector3.new(6.5,7,3.6),Color3.fromRGB(55,59,78),true)
    local head=makePart(model,"Head",Vector3.new(5,3,4.6),Color3.fromRGB(81,80,97),false)
    local ra=makePart(model,"Right Arm",Vector3.new(2.9,3.0,3),Color3.fromRGB(71,73,100),false)
    local la=makePart(model,"Left Arm",Vector3.new(2.9,3.0,3),Color3.fromRGB(71,73,100),false)
    local rl=makePart(model,"Right Leg",Vector3.new(2.8,3.15,3),Color3.fromRGB(66,65,87),false)
    local ll=makePart(model,"Left Leg",Vector3.new(2.8,3.15,3),Color3.fromRGB(66,65,87),false)
    local rootJoint=motor(root,torso,"RootJoint",CFrame.identity)
    motor(torso,head,"Neck",CFrame.new(0,3.7,0),CFrame.new(0,-1.5,0))
    local right=motor(torso,ra,"Right Shoulder",CFrame.new(4.5,2.1,0),CFrame.new(0,1.48,0))
    local left=motor(torso,la,"Left Shoulder",CFrame.new(-4.5,2.1,0),CFrame.new(0,1.48,0))
    local rightHip=motor(torso,rl,"Right Hip",CFrame.new(2,-3.3,0),CFrame.new(0,1.54,0))
    local leftHip=motor(torso,ll,"Left Hip",CFrame.new(-2,-3.3,0),CFrame.new(0,1.54,0))
    -- V25: real articulated elbows, wrists, knees, ankles, torso armor and jaw.
    -- Upper R6-named pieces remain compatible with legacy Humanoid scripts.
    local function armChain(upper,side,label)
        local fore=makePart(model,label.." Forearm",Vector3.new(2.7,2.9,2.75),upper.Color,false)
        motor(upper,fore,label.." Elbow",CFrame.new(0,-1.48,0),CFrame.new(0,1.43,0))
        local hand=makePart(model,label.." Hand",Vector3.new(2.32,1.22,2.45),upper.Color,false)
        motor(fore,hand,label.." Wrist",CFrame.new(0,-1.45,0),CFrame.new(0,.55,0))
        local guard=makePart(model,label.." ElbowPlate",Vector3.new(3.18,.66,3.2),color,false)
        guard.Material=Enum.Material.Metal
        guard.CFrame=upper.CFrame*CFrame.new(0,-1.34,0)
        weld(upper,guard)
        return hand
    end
    local function legChain(upper,label)
        local shin=makePart(model,label.." Shin",Vector3.new(2.62,2.85,2.8),upper.Color,false)
        motor(upper,shin,label.." Knee",CFrame.new(0,-1.54,0),CFrame.new(0,1.41,0))
        local foot=makePart(model,label.." Foot",Vector3.new(3.1,.8,4.1),Color3.fromRGB(39,38,56),false)
        motor(shin,foot,label.." Ankle",CFrame.new(0,-1.44,-.55),CFrame.new(0,.33,.67))
        return foot
    end
    local rightHand=armChain(ra,1,"Right")
    armChain(la,-1,"Left")
    legChain(rl,"Right")
    legChain(ll,"Left")
    local chest=makePart(model,"ArticulatedChest",Vector3.new(5.7,3.5,.70),Color3.fromRGB(62,69,91),false)
    motor(torso,chest,"SpineFlex",CFrame.new(0,.8,-2.0),CFrame.identity)
    model:SetAttribute("BossRigVersion",25)
    local eye=makePart(model,"CyclopsEye",Vector3.new(3,.85,.4),color,false)
    eye.Material=Enum.Material.Neon;eye.CFrame=head.CFrame*CFrame.new(0,.2,-2.1);weld(head,eye)
    local core=makePart(model,"TitanHeart",Vector3.new(2.7,2.7,.5),color,false)
    core.Material=Enum.Material.Neon;core.CFrame=torso.CFrame*CFrame.new(0,0,-2);weld(torso,core)
    -- Secure the giant whip to a genuine wrist grip joint, not an offset
    -- loose prop. Model:ScaleTo scales this Motor6D along with the boss.
    local handle=makePart(model,"ColossusWhipGrip",Vector3.new(.7,4.6,.7),Color3.fromRGB(44,40,52),false)
    local wristC0=CFrame.new(0,-rightHand.Size.Y*.48,-rightHand.Size.Z*.19)
        * CFrame.Angles(math.rad(-23),0,math.rad(-8))
    local wristC1=CFrame.new(0,-handle.Size.Y*.30,0)
    handle.CFrame=rightHand.CFrame*wristC0*wristC1:Inverse()
    motor(rightHand,handle,"ColossusWhipHandGrip",wristC0,wristC1)
    for i=1,6 do
        local lash=makePart(model,"ColossusLash_"..i,Vector3.new(math.max(.11,.46-i*.046),math.max(.11,.46-i*.046),2.25),color,false)
        lash.Material=i>=4 and Enum.Material.Neon or Enum.Material.Metal
        -- Side-hang the coiled lash on the right of his wrist, not across his stomach.
        lash.CFrame=rightHand.CFrame*CFrame.new(1.15+i*1.42,-.8-i*.18,-1.5-i*.11)
            * CFrame.Angles(0,math.rad(90),0)
        weld(handle,lash)
    end
    local hum=Instance.new("Humanoid")
    hum.RigType=Enum.HumanoidRigType.R6
    hum.MaxHealth=MAX_HEALTH;hum.Health=MAX_HEALTH;hum.WalkSpeed=10
    hum.JumpPower=0;hum.BreakJointsOnDeath=false
    -- Initial R6 neutral pose: the articulated feet reach ~10 studs below root.
    -- 10.16 desired root height - 3.15 upper-leg Y - 2 root half-height.
    hum.HipHeight=5.01
    hum.Parent=model
    local healthGui=Instance.new("BillboardGui")
    healthGui.Name="ColossusHealth"
    healthGui.Size=UDim2.fromOffset(290,78);healthGui.MaxDistance=170
    healthGui.StudsOffsetWorldSpace=Vector3.new(0,9,0);healthGui.AlwaysOnTop=true;healthGui.Parent=head
    local name=Instance.new("TextLabel")
    name.Size=UDim2.fromOffset(290,36);name.BackgroundTransparency=1
    name.Text="COLOSSUS • "..MAX_HEALTH.." HP";name.TextColor3=color
    name.TextStrokeTransparency=.1;name.TextScaled=true;name.Font=Enum.Font.GothamBlack;name.Parent=healthGui
    local track=Instance.new("Frame");track.Position=UDim2.fromOffset(12,42)
    track.Size=UDim2.fromOffset(266,18);track.BorderSizePixel=0
    track.BackgroundColor3=Color3.fromRGB(23,21,35);track.Parent=healthGui
    local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(1,1)
    fill.BackgroundColor3=color;fill.BorderSizePixel=0;fill.Parent=track
    local previousHealth=hum.Health
    hum.HealthChanged:Connect(function(hp)
        if hp<previousHealth and hp>0 and not model:GetAttribute("BossReviving") then
            model:SetAttribute("BossFlinchAt",Workspace:GetServerTimeNow())
        end
        previousHealth=hp
        local label=model:GetAttribute("BossPhase")==2 and "ASCENDED COLOSSUS" or "COLOSSUS"
        if name.Parent then name.Text=label.."  "..math.ceil(math.max(0,hp)).." / "..math.ceil(hum.MaxHealth) end
        if fill.Parent then fill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,hum.MaxHealth),0,1),1) end
    end)
    model.PrimaryPart=root
    model.Parent=folder
    -- The articulated shin + foot chain extends about 10 studs below the root.
    -- Sample the actual floor; the old fixed root height (9) buried the feet.
    local x,z=slot==1 and -113 or 113,-620+(slot==1 and 95 or -95)
    local groundParams=RaycastParams.new()
    groundParams.FilterType=Enum.RaycastFilterType.Exclude
    groundParams.FilterDescendantsInstances={model}
    groundParams.RespectCanCollide=true
    local ground=Workspace:Raycast(Vector3.new(x,80,z),Vector3.new(0,-150,0),groundParams)
    local floorY=(ground and ground.Normal.Y>.65) and ground.Position.Y or .25
    local spawn=Vector3.new(x,floorY+10.16,z)
    model:PivotTo(CFrame.lookAt(spawn,Vector3.new(0,spawn.Y,-620)))
    pcall(function()root:SetNetworkOwner(nil)end)
    local boss={model=model,hum=hum,root=root,right=right,left=left,rc0=right.C0,lc0=left.C0,
        rightHip=rightHip,leftHip=leftHip,rootJoint=rootJoint,rootC0=rootJoint.C0,
        color=color,arena=arena,epoch=epoch,attackIndex=slot,active=true,slot=slot,
        phase=1,revived=false,reviving=false,lastMoves={},lastGroundFix=0}
    groundBossFeet(boss,.18)
    currentBoss=boss
    model:GetAttributeChangedSignal("ReviveTrigger"):Connect(function()
        if not boss.reviving and boss.phase==1 and not boss.revived then
            task.spawn(reviveBoss,boss)
        end
    end)
    publishState("BOSS_ACTIVE",nil)
    hum.Died:Connect(function()
        if not boss.active then return end
        if boss.phase~=2 then
            warn("[Lashbound Boss] Unexpected phase-one death; finishing encounter safely")
        end
        boss.active=false
        -- The countdown is reset by a VERIFIED boss death, never by a timer tick.
        if currentBoss==boss and boss.epoch==epoch and activeArena==arena then
            currentBoss=nil
            defeatedAt=Workspace:GetServerTimeNow()
            nextBossAt=defeatedAt+INTERVAL
            publishState("RESPAWNING",nextBossAt)
        end
        local killerId=hum:GetAttribute("LastAttackerId")
        local killer=killerId and Players:GetPlayerByUserId(killerId)
        if killer and killer:GetAttribute("Zone")=="Arena" then
            bossCoins:Fire(killer,120)
            Feedback:FireClient(killer,"Message","COLOSSUS DEFEATED! +120 COINS")
        end
        task.delay(4,function()if model.Parent then model:Destroy() end end)
    end)
    task.spawn(function()
        local last=0
        local strafe=1
        local turnAt=0
        local nextDelay=4.5
        while isLive(boss) do
            if not boss.reviving and root.Anchored then
                warn("[Lashbound Boss] Released unexpected rooted physics state")
                root.Anchored=false
            end
            if not boss.reviving and model:GetAttribute("BossInAttack")==true then
                local started=model:GetAttribute("BossAttackStarted") or Workspace:GetServerTimeNow()
                if Workspace:GetServerTimeNow()-started>10 then
                    finishAttack(boss)
                end
            end
            if not boss.reviving and os.clock()-boss.lastGroundFix>.65 then
                boss.lastGroundFix=os.clock()
                local floorY=floorBelow(model,root)
                if floorY and not model:GetAttribute("BossMoving")
                    and not model:GetAttribute("BossInAttack")
                    and math.abs(root.AssemblyLinearVelocity.Y)<2.4 then
                    -- Settling uses HipHeight, never teleports during ordinary movement.
                    local error=footBottom(model)-(floorY+.18)
                    if math.abs(error)>.4 and math.abs(error)<7 then
                        hum.HipHeight=math.clamp(hum.HipHeight-error*.45,0,28)
                    end
                end
            end
            local target,dist=nearest(root.Position)
            if boss.reviving or model:GetAttribute("BossInAttack") then
                hum:Move(Vector3.zero,false)
                model:SetAttribute("BossMoving",false)
            elseif target and target.root.Parent then
                local movement=target.root.Position-root.Position
                local flat=Vector3.new(movement.X,0,movement.Z)
                local preferred=boss.phase==2 and 38 or 17
                if os.clock()>turnAt then
                    strafe=RNG:NextNumber()<.52 and -1 or 1
                    turnAt=os.clock()+RNG:NextNumber(1.1,2.7)
                end
                if dist<(boss.phase==2 and 340 or 155) and flat.Magnitude>.1 then
                    hum.WalkSpeed=math.clamp(6+dist*.065+(boss.phase==2 and 4 or 0),9,boss.phase==2 and 21 or 14)
                    local toward=flat.Unit
                    local lateral=Vector3.new(-toward.Z,0,toward.X)*strafe
                    local move=dist>preferred and (toward*.95+lateral*.3) or (lateral*.9-toward*.22)
                    hum:Move(move.Unit,false)
                    model:SetAttribute("BossMoving",true)
                else
                    hum:Move(Vector3.zero,false)
                    model:SetAttribute("BossMoving",false)
                end
                if dist<(boss.phase==2 and 210 or 102) and os.clock()-last>nextDelay then
                    last=os.clock()
                    nextDelay=RNG:NextNumber(boss.phase==2 and 2.65 or 3.8,boss.phase==2 and 3.9 or 5.6)
                    hum:Move(Vector3.zero,false)
                    model:SetAttribute("BossMoving",false)
                    if boss.phase==2 then
                        local options={6,7,8,9,10,11,12,13,14,15}
                        if dist>75 then options={6,7,8,9,10,11,12,15}
                        elseif dist<28 then options={11,12,13,14,15,7,10} end
                        local chosen=options[RNG:NextInteger(1,#options)]
                        for _=1,5 do
                            if chosen~=boss.lastMoves[1] and chosen~=boss.lastMoves[2] then break end
                            chosen=options[RNG:NextInteger(1,#options)]
                        end
                        table.insert(boss.lastMoves,1,chosen)
                        if #boss.lastMoves>2 then table.remove(boss.lastMoves) end
                        local ok,err=pcall(phaseTwoAttack,boss,chosen,target)
                        if not ok then warn("[Lashbound Boss] Phase two ability failed:",err) end
                    else
                        local chosen=RNG:NextInteger(1,5)
                        if chosen==boss.attackIndex then chosen=chosen%5+1 end
                        boss.attackIndex=chosen
                        local ok,err=pcall(runAttack,boss,chosen,target)
                        if not ok then warn("[Lashbound Boss] Phase one ability failed:",err) end
                    end
                    -- The attack functions have early returns for despawns,
                    -- canceled abilities and lost players; always release their lock.
                    if boss.model.Parent and not boss.reviving then
                        finishAttack(boss)
                    end
                end
            else
                hum:Move(Vector3.zero,false)
                model:SetAttribute("BossMoving",false)
            end
            task.wait(.10)
        end
    end)
    print("[Lashbound Boss] Spawn",model.Name,"HP",MAX_HEALTH)
    return boss
end
local function changeArena(arena)
    epoch+=1
    activeArena=arena
    currentBoss=nil
    defeatedAt=nil
    nextBossAt=nil
    -- A new map is a fresh encounter. Never carry over a respawn countdown
    -- for a boss destroyed because the previous map rotated out.
    publishState("WAITING_FOR_PLAYERS",nil)
end
Workspace.ChildAdded:Connect(function(child)
    if child.Name=="LashboundBattleArena" then changeArena(child) end
end)
changeArena(Workspace:FindFirstChild("LashboundBattleArena"))
while script.Parent do
    task.wait(.5) -- Single inexpensive scheduler; no per-frame busy loop.
    local arena=Workspace:FindFirstChild("LashboundBattleArena")
    if arena~=activeArena then changeArena(arena) end
    if arena then
        -- Never start another countdown while a boss is alive.
        if currentBoss and currentBoss.active and currentBoss.hum.Health>0
            and currentBoss.model.Parent then
            local correct=(currentBoss.reviving and "REVIVING") or (currentBoss.phase==2 and "BOSS_ASCENDED") or "BOSS_ACTIVE"
            if RS:GetAttribute("LashboundBossState")~=correct then
                publishState(correct,nil)
            end
        elseif currentBoss and currentBoss.active and not currentBoss.model.Parent then
            -- External deletion is NOT a defeat: do not reward or run a false timer.
            currentBoss.active=false
            currentBoss=nil
            defeatedAt=nil
            nextBossAt=nil
            publishState("WAITING_FOR_PLAYERS",nil)
        elseif not currentBoss and #playersInArena()>0 then
            if not nextBossAt or Workspace:GetServerTimeNow()>=nextBossAt then
                nextBossAt=nil
                defeatedAt=nil
                buildBoss(arena,1)
            end
        end
    end
end
