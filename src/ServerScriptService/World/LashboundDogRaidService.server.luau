-- LASHBOUND V11: at 1:50 show an incoming raid warning; at 2:00 spawn 30 hounds.
-- The raid is once per map, resets on rotation; dogs use cheap anchored/pivot movement
-- rather than 30 Humanoid pathfinding agents. Server owns hit detection and currency.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local ServerScriptService=game:GetService("ServerScriptService")
local award=ServerScriptService:WaitForChild("LashboundBotCoins")
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local RNG=Random.new()
local RAID_AT=120
local WARN_AT=110
local DOG_COUNT=30
local TICK=.08
local CENTER=Vector3.new(0,0,-620)
local currentArena=nil
local epoch=0
local dogList={}
local aliveCount=0
local function announce(state,arenaIndex)
    RS:SetAttribute("LashboundDogRaidState",state)
    RS:SetAttribute("LashboundDogRaidMapIndex",arenaIndex or 0)
    RS:SetAttribute("LashboundDogRaidAlive",aliveCount)
end
announce("WAITING",0)
local function rootPart(model,name,size,color)
    local p=Instance.new("Part")
    p.Name=name;p.Size=size;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.CastShadow=false;p.Parent=model
    return p
end
local function nearPlayer(pos)
    local best=math.huge
    local target=nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("Zone")=="Arena" then
            local c=p.Character
            local h=c and c:FindFirstChildOfClass("Humanoid")
            local r=c and c:FindFirstChild("HumanoidRootPart")
            if h and h.Health>0 and r then
                local delta=r.Position-pos
                local d=Vector3.new(delta.X,0,delta.Z).Magnitude
                if d<best then best=d;target={player=p,hum=h,root=r} end
            end
        end
    end
    return target,best
end
local function chooseSpawn(arena,folder,index)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.RespectCanCollide=true
    -- Exclude the dog folder from the downcast by making all dog pieces non-queryable.
    params.FilterDescendantsInstances={arena}
    local fighters={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("Zone")=="Arena" then
            local c=p.Character
            local r=c and c:FindFirstChild("HumanoidRootPart")
            local h=c and c:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health>0 then table.insert(fighters,r.Position) end
        end
    end
    local base=#fighters>0 and fighters[(index-1)%#fighters+1] or CENTER
    for attempt=1,48 do
        local angle=RNG:NextNumber(0,math.pi*2)
        local radius=RNG:NextNumber(42,114)
        local x=math.clamp(base.X+math.cos(angle)*radius,-206,206)
        local z=math.clamp(base.Z+math.sin(angle)*radius,-826,-414)
        local hit=Workspace:Raycast(Vector3.new(x,120,z),Vector3.new(0,-150,0),params)
        if hit and hit.Normal.Y>.65 and hit.Position.Y<16
            and not string.find(hit.Instance.Name,"Hazard_")
            and not string.find(hit.Instance.Name,"Marker") then
            return Vector3.new(x,hit.Position.Y+1.92,z)
        end
    end
    return Vector3.new(RNG:NextNumber(-75,75),2.05,-620+RNG:NextNumber(-75,75))
end
local function createDog(arena,folder,index,createdEpoch)
    local pos=chooseSpawn(arena,folder,index)
    local model=Instance.new("Model")
    model.Name=string.format("RaidHound_%02d",index)
    model:SetAttribute("LashboundNPC",true) -- existing whip system can damage it
    model:SetAttribute("LashboundDog",true)
    local root=rootPart(model,"HumanoidRootPart",Vector3.new(1.8,1.9,2.8),Color3.new(0,0,0))
    root.Transparency=1
    local palette={Color3.fromRGB(70,57,59),Color3.fromRGB(78,79,89),Color3.fromRGB(97,69,53),Color3.fromRGB(47,50,56)}
    local fur=palette[(index-1)%#palette+1]
    local body=rootPart(model,"Body",Vector3.new(2.65,2.0,4.45),fur)
    body.Shape=Enum.PartType.Ball
    body.Material=Enum.Material.Fabric
    local head=rootPart(model,"Head",Vector3.new(2.0,1.7,1.9),fur)
    head.Shape=Enum.PartType.Ball
    head.Material=Enum.Material.Fabric
    local snout=rootPart(model,"Muzzle",Vector3.new(1.1,.65,1),Color3.fromRGB(193,173,138))
    local eyeL=rootPart(model,"EyeL",Vector3.new(.27,.27,.2),Color3.fromRGB(255,98,79))
    local eyeR=rootPart(model,"EyeR",Vector3.new(.27,.27,.2),Color3.fromRGB(255,98,79))
    eyeL.Material=Enum.Material.Neon;eyeR.Material=Enum.Material.Neon
    local legs={}
    for i=1,4 do legs[i]=rootPart(model,"Leg_"..i,Vector3.new(.65,1.35,.72),fur) end
    local tail=rootPart(model,"Tail",Vector3.new(.48,.5,1.65),fur)
    tail.Shape=Enum.PartType.Ball
    -- V25 animal silhouette: articulated-looking upper/lower legs + paws,
    -- upright ears, muzzle/black nose, chest/haunch fur, flexible tail tip.
    -- All ornaments are non-queryable and client-posed; the anchored invisible
    -- root alone remains the server-controlled health/attack target.
    local cosmetics={}
    local function animal(name,size,color,shape,mat)
        local p=rootPart(model,name,size,color)
        if shape then p.Shape=shape end
        p.Material=mat or Enum.Material.Fabric
        cosmetics[name]=p
        return p
    end
    animal("Ruff",Vector3.new(2.75,1.6,1.25),Color3.fromRGB(116,101,89),Enum.PartType.Ball)
    animal("Haunches",Vector3.new(2.5,1.7,1.45),fur,Enum.PartType.Ball)
    animal("Belly",Vector3.new(1.65,.75,2.55),Color3.fromRGB(114,100,86),Enum.PartType.Ball)
    animal("Left Ear",Vector3.new(.49,1.1,.52),fur,nil)
    animal("Right Ear",Vector3.new(.49,1.1,.52),fur,nil)
    animal("Nose",Vector3.new(.52,.31,.34),Color3.fromRGB(30,27,30),Enum.PartType.Ball,Enum.Material.SmoothPlastic)
    animal("Jaw",Vector3.new(1.06,.27,.82),Color3.fromRGB(113,85,73),nil)
    animal("Tongue",Vector3.new(.34,.11,.45),Color3.fromRGB(204,82,91),nil,Enum.Material.SmoothPlastic)
    animal("TailTip",Vector3.new(.47,.47,.94),fur,Enum.PartType.Ball)
    animal("Collar",Vector3.new(1.85,.29,1.4),Color3.fromRGB(98,44,41),nil,Enum.Material.SmoothPlastic)
    for i=1,4 do
        animal("LowerLeg_"..i,Vector3.new(.57,.85,.58),fur,nil)
        animal("Paw_"..i,Vector3.new(.72,.29,.93),Color3.fromRGB(62,54,53),nil,Enum.Material.SmoothPlastic)
    end
    model:SetAttribute("DogRigVersion",25)
    model:SetAttribute("DogRunning",false)
    local hum=Instance.new("Humanoid")
    hum.Name="Humanoid";hum.RequiresNeck=false;hum.BreakJointsOnDeath=false
    hum.MaxHealth=48;hum.Health=48;hum.WalkSpeed=0
    hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    hum.Parent=model
    model.PrimaryPart=root
    model.Parent=folder
    local offsets={
        [root]=CFrame.new(), [body]=CFrame.new(0,.12,0),[head]=CFrame.new(0,.43,-2.20),
        [snout]=CFrame.new(0,.03,-3.11),
        [eyeL]=CFrame.new(-.55,.76,-2.94),[eyeR]=CFrame.new(.55,.76,-2.94),
        [tail]=CFrame.new(0,.60,2.6)*CFrame.Angles(math.rad(-19),0,0),
        [legs[1]]=CFrame.new(-.83,-1.14,-1.15),[legs[2]]=CFrame.new(.83,-1.14,-1.15),
        [legs[3]]=CFrame.new(-.83,-1.14,1.18),[legs[4]]=CFrame.new(.83,-1.14,1.18)
    }
    local state={model=model,hum=hum,root=root,pos=pos,dir=Vector3.new(0,0,-1),
        lastHit=-10,windup=false,epoch=createdEpoch,index=index,speed=RNG:NextNumber(14,19),
        wobble=RNG:NextNumber(0,7),alive=true,style=RNG:NextNumber(.4,1.5)}
    local health=Instance.new("BillboardGui")
    health.Name="DogHealth";health.Size=UDim2.fromOffset(110,40)
    health.StudsOffsetWorldSpace=Vector3.new(0,2.1,0)
    health.AlwaysOnTop=true;health.MaxDistance=85;health.Parent=head
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.fromScale(1,.65);lbl.BackgroundTransparency=1;lbl.TextColor3=Color3.fromRGB(255,176,130)
    lbl.Font=Enum.Font.GothamBold;lbl.TextScaled=true;lbl.TextStrokeTransparency=.1;lbl.Parent=health
    local track=Instance.new("Frame")
    track.Position=UDim2.fromScale(.08,.71);track.Size=UDim2.fromScale(.84,.18)
    track.BackgroundColor3=Color3.fromRGB(42,21,29);track.BorderSizePixel=0;track.Parent=health
    local fill=Instance.new("Frame")
    fill.Size=UDim2.fromScale(1,1);fill.BorderSizePixel=0;fill.BackgroundColor3=Color3.fromRGB(252,128,92);fill.Parent=track
    hum.HealthChanged:Connect(function(n)
        if lbl.Parent then lbl.Text="RAID HOUND  "..math.ceil(math.max(0,n)) end
        if fill.Parent then fill.Size=UDim2.fromScale(math.clamp(n/hum.MaxHealth,0,1),1) end
    end)
    lbl.Text="RAID HOUND 48"
    local initial=CFrame.lookAt(pos,pos+state.dir)
    for obj,offset in pairs(offsets) do obj.CFrame=initial*offset end
    -- Initialize every extra part at its actual local pose: this avoids a
    -- one-frame spawn flash at the map origin while the client rig loads.
    local init={
        Ruff=CFrame.new(0,.20,-1.35),Haunches=CFrame.new(0,.12,1.4),
        Belly=CFrame.new(0,-.69,.10),["Left Ear"]=CFrame.new(-.68,1.49,-2.22),
        ["Right Ear"]=CFrame.new(.68,1.49,-2.22),
        Nose=CFrame.new(0,.17,-3.62),Jaw=CFrame.new(0,-.23,-3.0),
        Tongue=CFrame.new(0,-.4,-3.13),TailTip=CFrame.new(0,.77,3.52),
        Collar=CFrame.new(0,.35,-1.86),
    }
    for i=1,4 do
        local x=(i%2==1) and -.83 or .83
        local z=i<3 and -1.16 or 1.2
        init["LowerLeg_"..i]=CFrame.new(x,-1.47,z)
        init["Paw_"..i]=CFrame.new(x,-1.76,z-.19)
    end
    for name,offset in pairs(init) do
        local piece=cosmetics[name]
        if piece then piece.CFrame=initial*offset end
    end
    -- Server updates the invisible collision/health root only. Clients animate
    -- the individual paws and body each frame using root's replicated CFrame.
    state.draw=function()
        if state.alive and root.Parent then
            local lifted=Vector3.zero
            local startAt=state.model:GetAttribute("JudgementLiftStart") or 0
            local untilAt=state.model:GetAttribute("JudgementLiftUntil") or 0
            if startAt>0 and os.clock()<untilAt then
                local phase=math.clamp((os.clock()-startAt)/math.max(.1,untilAt-startAt),0,1)
                lifted=Vector3.new(0,math.sin(phase*math.pi)*14,0)
            end
            local place=state.pos+lifted
            root.CFrame=CFrame.lookAt(place,place+state.dir)
        end
    end
    hum.Died:Connect(function()
        if not state.alive then return end
        state.alive=false
        if state.epoch==epoch and arena==currentArena then
            aliveCount=math.max(0,aliveCount-1)
            RS:SetAttribute("LashboundDogRaidAlive",aliveCount)
            local killerId=hum:GetAttribute("LastAttackerId")
            local killer=killerId and Players:GetPlayerByUserId(killerId)
            if killer and killer:GetAttribute("Zone")=="Arena"
                and os.clock()-(hum:GetAttribute("PlayerHitAt") or -100)>-1
                and os.clock()-(hum:GetAttribute("PlayerHitAt") or -100)<12 then
                award:Fire(killer,1) -- exactly ONE coin, uses persistent wallet
                Feedback:FireClient(killer,"Message","RAID HOUND DEFEATED! +1 COIN")
            end
            if aliveCount==0 then announce("CLEARED",RS:GetAttribute("LashboundMapIndex")) end
        end
        task.delay(.6,function()if model.Parent then model:Destroy() end end)
    end)
    table.insert(dogList,state)
end
local function startRaid(arena,mapIndex,myEpoch)
    if arena~=currentArena or epoch~=myEpoch then return end
    local folder=arena:FindFirstChild("LashboundBots") or Instance.new("Folder")
    folder.Name="LashboundBots";folder.Parent=arena
    aliveCount=0
    for i=1,DOG_COUNT do
        if epoch~=myEpoch or arena~=currentArena then return end
        -- A single malformed spawn should not silently cancel the other hounds.
        local ok,err=pcall(createDog,arena,folder,i,myEpoch)
        if ok then
            aliveCount+=1
        else
            warn("[Lashbound Hounds] Spawn failed",i,err)
        end
        RS:SetAttribute("LashboundDogRaidSpawned",i)
        RS:SetAttribute("LashboundDogRaidAlive",aliveCount)
        if i%6==0 then task.wait(.04) end
    end
    announce("ACTIVE",mapIndex)
    print("[Lashbound Raid] dogs spawned:",aliveCount,"out of",DOG_COUNT,"map",mapIndex)
end
local function reset(arena)
    epoch+=1
    currentArena=arena
    dogList={}
    aliveCount=0
    RS:SetAttribute("LashboundDogRaidSpawned",0)
    announce("WAITING",RS:GetAttribute("LashboundMapIndex") or 0)
end
local function stepDog(state,dt,now)
    if not state.alive or not state.model.Parent or not state.root.Parent then return end
    local status=state.model:GetAttribute("LashboundStatus")
    if now<(state.model:GetAttribute("BotFrozenUntil") or 0)
        or status=="Freeze" or status=="Shock" then
        state.draw(now)
        return
    end
    local target,distance=nearPlayer(state.pos)
    local direction=state.dir
    -- Sentinel-style awareness: patrol when players are distant, chase when near.
    if distance>125 then target=nil end
    if not target then
        local wanderAt=state.wanderAt or 0
        if now>=wanderAt then
            local angle=now*.17+state.index*2.399
            state.patrol=Vector3.new(math.cos(angle),0,math.sin(angle))
            state.wanderAt=now+3+(state.index%4)
        end
        direction=state.patrol or direction
    end
    if target then
        local delta=target.root.Position-state.pos
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude>1 then direction=flat.Unit end
        -- In combat these hounds circle and burst forward rather than simply beeline.
        if distance<14 then
            local side=Vector3.new(-direction.Z,0,direction.X)
            direction=(direction*.45+side*math.sin(now*1.6+state.index)*.72).Unit
        end
        local speed=state.speed * (distance<6 and .35 or 1) * (status=="Slow" and .52 or 1)
        local step=direction*math.min(speed*dt,math.max(.0,distance-3.9))
        if step.Magnitude>.01 then
            local params=RaycastParams.new()
            params.FilterType=Enum.RaycastFilterType.Exclude
            local excluded={state.model,state.model.Parent}
            for _,otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer.Character then table.insert(excluded,otherPlayer.Character) end
            end
            params.FilterDescendantsInstances=excluded
            params.RespectCanCollide=true
            -- Swept collision prevents hounds running through walls/rock geometry.
            local hit=Workspace:Blockcast(CFrame.new(state.pos),Vector3.new(2,2,2.8),step,params)
            if hit and hit.Distance < step.Magnitude then
                local tangent=Vector3.new(-direction.Z,0,direction.X)
                step=tangent*math.min(2.8,speed*dt)
                if Workspace:Blockcast(CFrame.new(state.pos),Vector3.new(2,2,2.8),step,params) then step=Vector3.zero end
            end
            local nextPos=state.pos+step
            -- Ground-check every tick, even at rest. Do not let dogs stand on
            -- the tops of tall props, avatar heads, or fall back to their old
            -- high Y position. Characters and hound body parts are excluded.
            local ground=Workspace:Raycast(Vector3.new(nextPos.X,18,nextPos.Z),Vector3.new(0,-48,0),params)
            if ground and ground.Normal.Y>.60 and ground.Position.Y<11
                and not string.find(ground.Instance.Name,"Hazard_") then
                local desiredY=ground.Position.Y+1.92
                local corrected=math.abs(desiredY-nextPos.Y)>4 and desiredY or nextPos.Y+(desiredY-nextPos.Y)*math.min(1,dt*18)
                nextPos=Vector3.new(nextPos.X,corrected,nextPos.Z)
            else
                nextPos=state.pos -- stay on a valid surface
            end
            state.pos=nextPos
        end
        if distance<7 and not state.windup and now-state.lastHit>RNG:NextNumber(1.3,2.2) then
            state.windup=true
            state.model:SetAttribute("DogBiteAt",Workspace:GetServerTimeNow())
            state.lastHit=now
            local attacker=target
            local token=state.epoch
            task.delay(.40,function()
                state.windup=false
                if not state.alive or token~=epoch or not state.model.Parent then return end
                local player=attacker.player
                if player:GetAttribute("Zone")~="Arena" or not attacker.root.Parent or attacker.hum.Health<=0 then return end
                if (attacker.root.Position-state.pos).Magnitude>8 then return end
                if os.clock()<(player:GetAttribute("DodgeUntil") or 0)
                    or os.clock()<(player:GetAttribute("SafeUntil") or 0) then return end
                local damage=6
                attacker.hum:TakeDamage(damage)
                player:SetAttribute("LastCombatAt",os.clock())
                Feedback:FireClient(player,"Message","HOUND BITE -6")
            end)
        end
    else
        -- Idle patrol uses a lightweight swept obstacle check, not 30 pathfinders.
        local step=direction*state.speed*.27*dt
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={state.model,state.model.Parent}
        params.RespectCanCollide=true
        local nextPos=state.pos+step
        local blocked=Workspace:Blockcast(CFrame.new(state.pos),Vector3.new(2,2,2.8),step,params)
        local ground=Workspace:Raycast(Vector3.new(nextPos.X,18,nextPos.Z),Vector3.new(0,-48,0),params)
        if blocked or not ground or ground.Normal.Y<.65 or ground.Position.Y>11
            or math.abs(nextPos.X)>205 or math.abs(nextPos.Z+620)>205 then
            state.patrol=-direction
            state.wanderAt=now+1.4
        else
            state.pos=Vector3.new(nextPos.X,ground.Position.Y+1.92,nextPos.Z)
        end
    end
    -- Recheck ground even without an aggro target; no suspended idle hounds.
    if currentArena and (state.pos.Y>3 or math.floor(now*5+state.index)%3==0) then
        local p=RaycastParams.new()
        p.FilterType=Enum.RaycastFilterType.Include
        p.FilterDescendantsInstances={currentArena}
        p.RespectCanCollide=true
        local hit=Workspace:Raycast(Vector3.new(state.pos.X,18,state.pos.Z),Vector3.new(0,-48,0),p)
        if hit and hit.Normal.Y>.6 and hit.Position.Y<11 then
            state.pos=Vector3.new(state.pos.X,hit.Position.Y+1.92,state.pos.Z)
        end
    end
    state.dir=direction
    state.draw(now)
end
local sweep=0
while script.Parent do
    task.wait(TICK)
    sweep+=1
    local arena=Workspace:FindFirstChild("LashboundBattleArena")
    if arena~=currentArena then reset(arena) end
    if arena then
        local nextTime=RS:GetAttribute("LashboundNextMapTime")
        local dur=RS:GetAttribute("LashboundMapDuration")
        local index=RS:GetAttribute("LashboundMapIndex") or 0
        if type(nextTime)=="number" and type(dur)=="number" then
            local elapsed=math.max(0,Workspace:GetServerTimeNow()-(nextTime-dur))
            local state=RS:GetAttribute("LashboundDogRaidState")
            if elapsed>=WARN_AT and elapsed<RAID_AT and state=="WAITING" then
                announce("WARNING",index)
            elseif elapsed>=RAID_AT and (state=="WAITING" or state=="WARNING") then
                announce("SPAWNING",index)
                local myEpoch=epoch
                task.spawn(startRaid,arena,index,myEpoch)
            end
        end
        for i=#dogList,1,-1 do
            local dog=dogList[i]
            if not dog.alive or not dog.model.Parent then
                table.remove(dogList,i)
            elseif i%2==sweep%2 then
                -- Each hound updates 5x/sec on the server, locally interpolated at 30fps.
                stepDog(dog,TICK*2,os.clock())
            end
        end
    end
end
