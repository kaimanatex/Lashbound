-- LASHBOUND V7 | server-only lightweight AI. Six bots per active map.
-- Aggro starts at 36 studs; bot gives up after 52 studs.
-- Defeated NPCs DROP an actual collectible 10-coin orb; they do not pay immediately.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local PathfindingService=game:GetService("PathfindingService")
local Debris=game:GetService("Debris")
local TweenService=game:GetService("TweenService")
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local coinReward=ServerScriptService:WaitForChild("LashboundBotCoins")
local bots={}
local spawnEpoch=0
local MAX_BOTS=6
local AGGRO_RADIUS=36
local DISENGAGE_RADIUS=52
local botColors={Color3.fromRGB(255,102,86),Color3.fromRGB(240,154,71),Color3.fromRGB(203,86,226)}

local function part(model,name,size,color,collide,material)
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.Color=color
    p.Material=material or Enum.Material.Metal
    p.Anchored=false
    p.CanCollide=collide==true
    p.CanTouch=false
    p.Massless=name~="HumanoidRootPart"
    p.Parent=model
    return p
end
local function motor(base,child,name,c0,c1)
    local m=Instance.new("Motor6D")
    m.Name=name
    m.Part0=base; m.Part1=child
    m.C0=c0; m.C1=c1 or CFrame.identity
    m.Parent=base
    return m
end
local function weld(base,child)
    local w=Instance.new("WeldConstraint")
    w.Part0=base; w.Part1=child; w.Parent=child
end
local function flare(origin,to,color)
    if (to-origin).Magnitude<.2 then return end
    local p=Instance.new("Part")
    p.Name="BotWhipFlash";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.Material=Enum.Material.Neon;p.Color=color;p.CastShadow=false
    p.Size=Vector3.new(.23,.23,(to-origin).Magnitude)
    p.CFrame=CFrame.lookAt((origin+to)/2,to)
    p.Parent=Workspace
    Debris:AddItem(p,.15)
    for _,player in ipairs(Players:GetPlayers()) do
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position-origin).Magnitude<95 then
            Feedback:FireClient(player,"Visual","BotAttack",{
                kind="Attack",step=1,origin=origin,direction=to-origin,color=color,whipId="Rope"})
        end
    end
end
local function showBotAttack(state,mode,origin,dir,range,duration)
    local payload={kind=mode,origin=origin,direction=dir,color=botColors[(state.index-1)%#botColors+1],
        step=state.attackIndex,range=range,dot=.54,duration=duration,
        impactServerTime=Workspace:GetServerTimeNow()+duration}
    for _,player in ipairs(Players:GetPlayers()) do
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position-origin).Magnitude<95 then
            Feedback:FireClient(player,"Visual",mode,payload)
        end
    end
end
local function createCoinDrop(arena,pos)
    local reward=Instance.new("Part")
    reward.Name="CoinDrop_10"
    reward.Shape=Enum.PartType.Ball
    reward.Size=Vector3.new(3.2,3.2,3.2)
    reward.CFrame=CFrame.new(pos.X,math.max(2.35,pos.Y-2.5),pos.Z)
    reward.Anchored=true
    reward.CanCollide=false
    reward.CanTouch=true
    reward.CanQuery=false
    reward.Material=Enum.Material.Neon
    reward.Color=Color3.fromRGB(255,205,66)
    reward.Parent=arena
    local light=Instance.new("PointLight")
    light.Color=reward.Color;light.Range=12;light.Brightness=1.0;light.Parent=reward
    local billboard=Instance.new("BillboardGui")
    billboard.Name="CoinLabel";billboard.Size=UDim2.fromOffset(100,30)
    billboard.StudsOffsetWorldSpace=Vector3.new(0,3.3,0);billboard.AlwaysOnTop=true;billboard.Parent=reward
    local label=Instance.new("TextLabel")
    label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
    label.Text="+10 COINS";label.TextColor3=Color3.fromRGB(255,230,97)
    label.TextStrokeTransparency=.1;label.TextScaled=true;label.Font=Enum.Font.GothamBold;label.Parent=billboard
    local claimed=false
    reward.Touched:Connect(function(hit)
        if claimed then return end
        local char=hit:FindFirstAncestorOfClass("Model")
        local player=char and Players:GetPlayerFromCharacter(char)
        if not player or player:GetAttribute("Zone")~="Arena" then return end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then return end
        claimed=true
        coinReward:Fire(player,10)
        reward:Destroy()
    end)
    Debris:AddItem(reward,20)
end
local function spawnBot(arena,marker,index)
    if arena.Parent~=Workspace or arena.Name~="LashboundBattleArena" then return end
    local model=Instance.new("Model")
    model.Name=string.format("Sentinel_%02d",index)
    model:SetAttribute("LashboundNPC",true)
    local accent=botColors[(index-1)%#botColors+1]
    local root=part(model,"HumanoidRootPart",Vector3.new(2,2,1),Color3.new(0,0,0),false)
    root.Transparency=1;root.Massless=false
    local torso=part(model,"Torso",Vector3.new(2,2,1),Color3.fromRGB(59,65,83),true)
    local head=part(model,"Head",Vector3.new(2,1,1),Color3.fromRGB(72,76,94),false)
    head.Shape=Enum.PartType.Ball
    local leftArm=part(model,"Left Arm",Vector3.new(1,1.1,1),Color3.fromRGB(79,83,103),false)
    local rightArm=part(model,"Right Arm",Vector3.new(1,1.1,1),Color3.fromRGB(79,83,103),false)
    local leftLeg=part(model,"Left Leg",Vector3.new(1,1.1,1),Color3.fromRGB(58,63,82),false)
    local rightLeg=part(model,"Right Leg",Vector3.new(1,1.1,1),Color3.fromRGB(58,63,82),false)
    motor(root,torso,"RootJoint",CFrame.identity)
    motor(torso,head,"Neck",CFrame.new(0,1,0),CFrame.new(0,-.5,0))
    motor(torso,rightArm,"Right Shoulder",CFrame.new(1.5,.5,0),CFrame.new(0,.5,0))
    motor(torso,leftArm,"Left Shoulder",CFrame.new(-1.5,.5,0),CFrame.new(0,.5,0))
    motor(torso,rightLeg,"Right Hip",CFrame.new(.5,-1,0),CFrame.new(0,.53,0))
    motor(torso,leftLeg,"Left Hip",CFrame.new(-.5,-1,0),CFrame.new(0,.53,0))
    -- V25 articulated R6-compatible model: upper limbs keep standard names for
    -- Humanoid/legacy scripts, while forearms, hands, shins and feet have real
    -- Motor6D joints. All added limbs are light, non-colliding and server rigged.
    local function armChain(side,upper,label)
        local fore=part(model,label.." Forearm",Vector3.new(.91,1.0,.9),upper.Color,false)
        motor(upper,fore,label.." Elbow",CFrame.new(0,-.53,0),CFrame.new(0,.48,0))
        local hand=part(model,label.." Hand",Vector3.new(.67,.45,.82),upper.Color,false)
        motor(fore,hand,label.." Wrist",CFrame.new(0,-.51,0),CFrame.new(0,.20,0))
        local guard=part(model,label.." ElbowGuard",Vector3.new(1.04,.23,1.08),accent,false,Enum.Material.Metal)
        guard.CFrame=upper.CFrame*CFrame.new(0,-.48,0)
        weld(upper,guard)
        return hand
    end
    local function legChain(upper,label)
        local shin=part(model,label.." Shin",Vector3.new(.98,1.02,1.02),upper.Color,false)
        motor(upper,shin,label.." Knee",CFrame.new(0,-.53,0),CFrame.new(0,.50,0))
        local boot=part(model,label.." Foot",Vector3.new(1.1,.36,1.5),Color3.fromRGB(42,46,60),false)
        motor(shin,boot,label.." Ankle",CFrame.new(0,-.52,-.17),CFrame.new(0,.14,.26))
        return boot
    end
    local rightHand=armChain(1,rightArm,"Right")
    armChain(-1,leftArm,"Left")
    legChain(rightLeg,"Right")
    legChain(leftLeg,"Left")
    local spinePlate=part(model,"ArticulatedChest",Vector3.new(1.66,1.10,.32),Color3.fromRGB(72,80,106),false,Enum.Material.Metal)
    motor(torso,spinePlate,"SpineFlex",CFrame.new(0,.26,-.53),CFrame.identity)
    model:SetAttribute("BotRigVersion",25)
    local visor=part(model,"Visor",Vector3.new(1.6,.22,.24),accent,false,Enum.Material.Neon)
    visor.CFrame=CFrame.new(0,.07,-.51);weld(head,visor)
    local chest=part(model,"ChestCore",Vector3.new(.75,.75,.26),accent,false,Enum.Material.Neon)
    chest.CFrame=CFrame.new(0,.15,-.58);weld(torso,chest)
    -- The handle is held by a dedicated wrist Motor6D. Its grip point lies
    -- inside the right hand rather than hovering beside the arm. This joint
    -- moves with attack animations, and the lash is welded to its handle.
    local whip=part(model,"BotWhipHandle",Vector3.new(.32,2.15,.32),Color3.fromRGB(156,115,75),false)
    local wristC0=CFrame.new(0,-rightHand.Size.Y*.48,-rightHand.Size.Z*.20)
        * CFrame.Angles(math.rad(-28),0,math.rad(-12))
    local wristC1=CFrame.new(0,-whip.Size.Y*.30,0)
    whip.CFrame=rightHand.CFrame*wristC0*wristC1:Inverse()
    motor(rightHand,whip,"BotWhipGrip",wristC0,wristC1)
    for i=1,5 do
        local thickness=math.max(.065,.18-i*.023)
        local lash=part(model,"BotLash_"..i,Vector3.new(thickness,thickness,1.18),accent,false,Enum.Material.Neon)
        lash.CFrame=whip.CFrame*CFrame.new(0,.80,-.40-i*1.1)
        weld(whip,lash)
    end
    local hum=Instance.new("Humanoid")
    hum.Name="Humanoid"
    hum.RigType=Enum.HumanoidRigType.R6
    hum.MaxHealth=95;hum.Health=95;hum.WalkSpeed=14;hum.JumpPower=52
    hum.BreakJointsOnDeath=false
    hum.Parent=model
    model.PrimaryPart=root
    local markerPos=marker.Position
    local folder=arena:FindFirstChild("LashboundBots")
    if not folder then
        folder=Instance.new("Folder");folder.Name="LashboundBots";folder.Parent=arena
    end
    model.Parent=folder
    model:PivotTo(CFrame.new(markerPos+Vector3.new(0,3.3,0)))
    local ui=Instance.new("BillboardGui")
    ui.Name="SentinelHealthBar"
    ui.Size=UDim2.fromOffset(145,55);ui.StudsOffsetWorldSpace=Vector3.new(0,3.2,0)
    ui.AlwaysOnTop=true;ui.MaxDistance=145;ui.Parent=head
    local text=Instance.new("TextLabel")
    text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1)
    text.Text="SENTINEL | 95 HP"
    text.TextScaled=true;text.Font=Enum.Font.GothamBold
    text.Size=UDim2.new(1,0,0,29)
    text.TextColor3=accent;text.TextStrokeTransparency=.15;text.Parent=ui
    local bar=Instance.new("Frame");bar.Size=UDim2.new(1,-8,0,12)
    bar.Position=UDim2.fromOffset(4,35);bar.BorderSizePixel=0
    bar.BackgroundColor3=Color3.fromRGB(19,20,29);bar.Parent=ui
    local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(1,1)
    fill.BorderSizePixel=0;fill.BackgroundColor3=accent;fill.Parent=bar
    local prevHealth=hum.Health
    hum.HealthChanged:Connect(function(hp)
        if hp<prevHealth and hp>0 then
            model:SetAttribute("BotFlinchAt",Workspace:GetServerTimeNow())
        end
        prevHealth=hp
        if text.Parent then text.Text="SENTINEL | "..math.ceil(math.max(0,hp)).." HP" end
        if fill.Parent then fill.Size=UDim2.fromScale(math.clamp(hp/hum.MaxHealth,0,1),1) end
    end)
    local state={model=model,hum=hum,root=root,arena=arena,marker=marker,index=index,
        origin=markerPos,lastAttack=-10,lastPath=0,route=nil,wp=2,target=nil,
        leftHip=torso:FindFirstChild("Left Hip"),rightHip=torso:FindFirstChild("Right Hip"),
        leftShoulder=torso:FindFirstChild("Left Shoulder"),
        dodgeAt=-10,lastReactAt=-100, strafeDirection=index%2==0 and 1 or -1,
        style=index%3+1, lastFeint=-10, burstUntil=-10, attackIndex=0,
        strafeUntil=0, thinkingUntil=0, pendingAttack=false,
        rng=Random.new(9173+index*1091)}
    -- Server owns NPC simulation; avoids client hand-offs that cause stutters.
    pcall(function() root:SetNetworkOwner(nil) end)
    table.insert(bots,state)
    hum.Died:Connect(function()
        if state.dead then return end
        state.dead=true
        if hum:GetAttribute("PlayerHitAt") and os.clock()-hum:GetAttribute("PlayerHitAt")<12 then
            createCoinDrop(arena,root.Position)
        end
        task.delay(2.0,function() if model.Parent then model:Destroy() end end)
        task.delay(10,function()
            if arena.Parent==Workspace and arena.Name=="LashboundBattleArena" then
                spawnBot(arena,marker,index)
            end
        end)
    end)
    return state
end

local function spawnAll(arena)
    -- A map can be discovered by both ChildAdded and the startup lookup.
    if arena:GetAttribute("SentinelsSpawned") then return end
    arena:SetAttribute("SentinelsSpawned",true)
    spawnEpoch+=1
    local spawns=arena:FindFirstChild("BotSpawns")
    if not spawns then warn("[Lashbound AI] BotSpawns not found") return end
    local list=spawns:GetChildren()
    table.sort(list,function(a,b)return a.Name<b.Name end)
    for i=1,math.min(MAX_BOTS,#list) do
        if list[i]:IsA("BasePart") then spawnBot(arena,list[i],i) end
    end
    print("[Lashbound AI] Spawned", math.min(MAX_BOTS,#list), "sentinels in",arena.Name)
end
local function findNearest(state)
    -- Sticky targets disengage at 52 studs; new targets must come within 36.
    local current=state.target
    if current then
        local player=current.player
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if player and player:GetAttribute("Zone")=="Arena" and hum and hum.Health>0 and root then
            local distance=(root.Position-state.root.Position).Magnitude
            if distance<DISENGAGE_RADIUS then
                return {player=player,root=root,hum=hum},distance
            end
        end
        state.target=nil
    end
    local nearest=nil
    local best=AGGRO_RADIUS
    for _,player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Zone")=="Arena" then
            local char=player.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            local r=char and char:FindFirstChild("HumanoidRootPart")
            if h and h.Health>0 and r then
                local distance=(r.Position-state.root.Position).Magnitude
                if distance<best then nearest={player=player,root=r,hum=h};best=distance end
            end
        end
    end
    state.target=nearest
    return nearest,best
end
local function hasSight(state,target)
    local direction=target.root.Position-state.root.Position
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={state.model}
    local result=Workspace:Raycast(state.root.Position,direction,params)
    return result==nil or result.Instance:IsDescendantOf(target.player.Character)
end
local function getPath(state,target)
    if state.calculating then return end
    state.calculating=true
    task.spawn(function()
        if not state.root.Parent or not target.root.Parent then state.calculating=false;return end
        local path=PathfindingService:CreatePath({AgentRadius=2.8,AgentHeight=5.5,AgentCanJump=true,WaypointSpacing=7})
        local ok=pcall(function()path:ComputeAsync(state.root.Position,target.root.Position) end)
        if ok and path.Status==Enum.PathStatus.Success and state.model.Parent then
            state.route=path:GetWaypoints();state.wp=2
        else
            state.route=nil
        end
        state.calculating=false
    end)
end
-- Whip attack poses have a visible wind-up so nearby players can dodge.
local function attack(state,target)
    local now=os.clock()
    if now<(state.model:GetAttribute("BotFrozenUntil") or 0) or state.pendingAttack or now-state.lastAttack<state.rng:NextNumber(1.0,1.9) or not hasSight(state,target) then return end
    state.lastAttack=now
    state.attackIndex=(state.attackIndex%3)+1
    local typeIndex=state.rng:NextInteger(1,3)
    local isFeint=(now-state.lastFeint>7 and state.rng:NextNumber()<.19)
    if isFeint then state.lastFeint=now end
    local swingDelay=typeIndex==3 and .55 or typeIndex==2 and .34 or .41
    local castOrigin=state.root.Position
    local initial=target.root.Position-castOrigin
    local forward=Vector3.new(initial.X,0,initial.Z)
    if forward.Magnitude<.1 then return end
    forward=forward.Unit
    local reach=typeIndex==3 and 18 or 14
    showBotAttack(state,"BotTell",castOrigin,forward,reach,swingDelay)
    state.model:SetAttribute("BotAttackType",typeIndex)
    state.model:SetAttribute("BotFeint",isFeint)
    state.model:SetAttribute("BotAttackStart",Workspace:GetServerTimeNow())
    state.model:SetAttribute("BotAttackImpact",Workspace:GetServerTimeNow()+swingDelay)
    state.pendingAttack=true
    state.hum:MoveTo(state.root.Position)
    local shoulder=state.model:FindFirstChild("Torso") and state.model.Torso:FindFirstChild("Right Shoulder")
    local default=shoulder and shoulder.C0
    if shoulder then
        TweenService:Create(shoulder,TweenInfo.new(swingDelay*.62),{C0=default*CFrame.Angles(math.rad(typeIndex==3 and -118 or -75),math.rad(typeIndex==2 and -45 or 25),math.rad(typeIndex==3 and 82 or 38))}):Play()
    end
    -- Don't hit immediately; defenders get a brief readable attack tell.
    task.delay(swingDelay,function()
        state.pendingAttack=false
        if isFeint then return end
        if shoulder and shoulder.Parent and default then
            -- Follow-through: arm goes across the body, then rebounds to neutral.
            TweenService:Create(shoulder,TweenInfo.new(.13,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
                C0=default*CFrame.Angles(math.rad(35),math.rad(-65),math.rad(-58))}):Play()
        end
        if state.dead or not state.model.Parent or state.hum.Health<=0 or os.clock()<(state.model:GetAttribute("BotFrozenUntil") or 0) then return end
        local current=target.player.Character
        if not current or not target.root.Parent or target.hum.Health<=0 then return end
        local delta=target.root.Position-state.root.Position
        local dist=delta.Magnitude
        if dist>reach or math.abs(delta.Y)>9 or not hasSight(state,target) then return end
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude<.15 or Vector3.new(flat.X,0,flat.Z).Unit:Dot(forward)<.54 then return end
        local origin=state.root.Position+Vector3.new(0,2,0)
        showBotAttack(state,"BotStrike",castOrigin,forward,reach,0)
        flare(origin,target.root.Position+Vector3.new(0,2,0),botColors[(state.index-1)%#botColors+1])
        if target.player:GetAttribute("Zone")~="Arena" then return end
        if os.clock()<(target.player:GetAttribute("SafeUntil") or 0) or os.clock()<(target.player:GetAttribute("DodgeUntil") or 0) then return end
        local damage=typeIndex==3 and 19 or typeIndex==2 and 7 or 10
        target.player:SetAttribute("LastCombatAt",os.clock())
        target.hum:TakeDamage(damage)
        target.root.AssemblyLinearVelocity=flat.Unit*(typeIndex==3 and 39 or 22)+Vector3.new(0,6,0)
        Feedback:FireClient(target.player,"Message","SENTINEL HIT -"..damage)
    end)
    task.delay(swingDelay+.27,function()
        if shoulder and shoulder.Parent and default then
            TweenService:Create(shoulder,TweenInfo.new(.18),{C0=default}):Play()
        end
    end)
end

local function npcDodge(state,target,now,dist)
    if dist>26 or dist<2 or state.pendingAttack or now-state.dodgeAt<3.1 then return false end
    -- Counter attacks read the real player's attack windup; not omniscient.
    local when=target.player:GetAttribute("WhipWindupAt") or -100
    if now-when>.35 or when<=state.lastReactAt then return false end
    state.lastReactAt=when
    if state.rng:NextNumber()>.56 then return false end
    state.dodgeAt=now
    local flat=target.root.Position-state.root.Position
    local toward=Vector3.new(flat.X,0,flat.Z)
    if toward.Magnitude<1 then return false end
    local side=Vector3.new(-toward.Z,0,toward.X).Unit*state.strafeDirection
    -- Reverse side sometimes; nearby cover can block either escape.
    if state.rng:NextNumber()<.34 then side=-side end
    state.strafeDirection=side:Dot(Vector3.new(-toward.Z,0,toward.X))>0 and 1 or -1
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances={state.model}
    local ray=Workspace:Blockcast(CFrame.new(state.root.Position),Vector3.new(2.5,4.2,2.5),side*8,rayParams)
    if ray and ray.Distance<6 then side=-side end
    state.model:SetAttribute("BotDodgeUntil",now+.42)
    state.model:SetAttribute("BotDodgeStarted",Workspace:GetServerTimeNow())
    state.hum:MoveTo(state.root.Position)
    local a=Instance.new("Attachment")
    a.Parent=state.root
    -- Sweep collision-aware displacement instead of forcing through nearby walls.
    a:Destroy()
    task.spawn(function()
        for _=1,5 do
            if state.dead or not state.root.Parent then break end
            local step=side*1.65
            local hit=Workspace:Blockcast(CFrame.new(state.root.Position),Vector3.new(2.5,4.2,2.5),step,rayParams)
            if hit then break end
            state.model:PivotTo(state.model:GetPivot()+step)
            task.wait(.035)
        end
    end)
    for _,player in ipairs(Players:GetPlayers()) do
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position-state.root.Position).Magnitude<105 then
            Feedback:FireClient(player,"Visual","BotDodge",{
                kind="BotDodge",origin=state.root.Position,direction=side,
                color=botColors[(state.index-1)%#botColors+1],step=1})
        end
    end
    return true
end

-- Server publishes coarse movement state only; the V25 client controller
-- animates all Motor6D joints smoothly at render rate. Avoid server C0 gait
-- edits here because they fight locally interpolated elbow/knee movements.
local function animateGait(state,now)
    if not state.model.Parent then return end
    local v=state.root.AssemblyLinearVelocity
    local speed=Vector3.new(v.X,0,v.Z).Magnitude
    local moving=speed>2 and now>=(state.model:GetAttribute("BotFrozenUntil") or 0)
    if state.model:GetAttribute("BotMoving")~=moving then
        state.model:SetAttribute("BotMoving",moving)
    end
end

local function circlePosition(state,target,distance,now)
    local relative=target.root.Position-state.root.Position
    local flat=Vector3.new(relative.X,0,relative.Z)
    if flat.Magnitude<.1 then return target.root.Position end
    local to=flat.Unit
    local side=Vector3.new(-to.Z,0,to.X)*state.strafeDirection
    if now>state.strafeUntil then
        state.strafeUntil=now+state.rng:NextNumber(1.5,3.4)
        if state.rng:NextNumber()<.35 then state.strafeDirection=-state.strafeDirection end
    end
    local retreat=state.hum.Health<state.hum.MaxHealth*.33
    local preferred=retreat and 18 or state.style==1 and 9 or state.style==2 and 13 or 10.5
    if now>state.burstUntil and state.rng:NextNumber()<.025 then
        state.burstUntil=now+state.rng:NextNumber(.4,.9)
        state.strafeDirection=-state.strafeDirection
    end
    local radial=(distance<preferred and -to*(preferred-distance+2) or to*math.min(3,distance-preferred))
    -- Strafing around the player is less robotic than direct MoveTo each tick.
    return state.root.Position+side*(now<state.burstUntil and 17 or state.style==2 and 11 or 7)+radial
end

Workspace.ChildAdded:Connect(function(child)
    if child.Name=="LashboundBattleArena" then task.defer(spawnAll,child) end
end)
local first=Workspace:FindFirstChild("LashboundBattleArena")
if first then task.defer(spawnAll,first) end
-- One scheduler for all six NPCs. No RunService-per-bot listeners.
while script.Parent do
    local now=os.clock()
    for i=#bots,1,-1 do
        local bot=bots[i]
        if bot.dead or not bot.model.Parent or not bot.arena.Parent or bot.hum.Health<=0 then
            table.remove(bots,i)
        else
            animateGait(bot,now)
            local target,dist=findNearest(bot)
            if now<(bot.model:GetAttribute("BotFrozenUntil") or 0) then
                bot.hum:MoveTo(bot.root.Position)
            elseif target and dist<DISENGAGE_RADIUS then
                local dodged=npcDodge(bot,target,now,dist)
                if not dodged and now>=(bot.model:GetAttribute("BotDodgeUntil") or 0) and not bot.pendingAttack then
                    local sight=hasSight(bot,target)
                    if sight then
                        bot.route=nil
                        if dist<14 then
                            bot.hum:MoveTo(circlePosition(bot,target,dist,now))
                            if dist<12.7 then attack(bot,target) end
                        elseif dist<27 then
                            bot.hum:MoveTo(circlePosition(bot,target,dist,now))
                            -- Occasional jump/cut to avoid predictable loops.
                            if now>bot.thinkingUntil and bot.rng:NextNumber()<.13 then
                                bot.hum.Jump=true
                                bot.thinkingUntil=now+2.2
                            end
                        else
                            bot.hum:MoveTo(target.root.Position)
                        end
                    else
                        -- Pathfinding only when line of sight is obstructed; maximum every 3s.
                        if now-bot.lastPath>3 then
                            bot.lastPath=now
                            getPath(bot,target)
                        end
                        local wp=bot.route and bot.route[bot.wp]
                        if wp then
                            if (bot.root.Position-wp.Position).Magnitude<5 then
                                bot.wp+=1; wp=bot.route[bot.wp]
                            end
                            if wp then
                                if wp.Action==Enum.PathWaypointAction.Jump then bot.hum.Jump=true end
                                bot.hum:MoveTo(wp.Position)
                            else bot.hum:MoveTo(target.root.Position) end
                        else bot.hum:MoveTo(target.root.Position) end
                    end
                end
            else
                bot.route=nil
                bot.hum:MoveTo(bot.root.Position)
            end
        end
    end
    task.wait(.2)
end
