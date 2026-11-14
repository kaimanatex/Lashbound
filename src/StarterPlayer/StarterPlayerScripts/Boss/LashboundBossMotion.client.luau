-- LASHBOUND V25 - 1,344 blended procedural Colossus motion samples.
-- 15 attacks x 64 pose samples = 960; 8 locomotion types x 40 = 320;
-- 64 dramatic revival poses = 1,344. No uploaded animation clips needed.
-- Enemy motion is cosmetic; server validates boss positions and damage timing.
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local active=setmetatable({}, {__mode="k"})
local pending=setmetatable({}, {__mode="k"})
local ATTACK_FRAMES=64
local MOVE_FRAMES=40
local REBIRTH_FRAMES=64
local MOVES={"Idle","March","Sprint","Circle","Stalk","Recoil","Guard","Enrage"}
local BONES={
    hipR="Right Hip",hipL="Left Hip",root="RootJoint",neck="Neck",
    armR="Right Shoulder",armL="Left Shoulder",
    elbowR="Right Elbow",elbowL="Left Elbow",
    wristR="Right Wrist",wristL="Left Wrist",
    kneeR="Right Knee",kneeL="Left Knee",ankleR="Right Ankle",ankleL="Left Ankle",
    spine="SpineFlex",grip="ColossusWhipHandGrip",
}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function wave(t) return math.sin(t*math.pi*2) end
local function pose(kind,id,t)
    local gait=wave(t)
    local foot=math.sin(t*math.pi*4)
    local breath=math.sin(t*math.pi*2+.25)
    local direction=(id%2==0) and -1 or 1
    local attack=0;local release=0;local recoil=0;local stomp=0
    local stride=0;local twist=0;local crouch=0;local handRaise=0
    local guard=0;local roar=0;local head=-.05*breath
    local ranged=id>=6 and id<=10
    local shock=id==11 or id==12
    if kind=="attack" then
        local windup=smooth(t/.64)
        release=smooth((t-.68)/.13)
        recoil=smooth((t-.84)/.16)
        attack=math.sin(math.pi*math.clamp(t/.86,0,1))
        handRaise=(ranged and 1.10 or shock and .86 or 1.35)*windup
        twist=direction*(.33*windup-.62*release+.22*recoil)
        crouch=-.17*windup+.10*release
        stomp=attack*.24+release*.27
        roar=attack*(shock and .23 or .13)
    elseif kind=="revive" then
        -- Timeline synced to 5.1-second server revival: knee fall, ascent,
        -- held overhead hover, fast landing and short recovery.
        local kneel=smooth(t/.23)
        local rise=smooth((t-.24)/.17)
        local dive=smooth((t-.68)/.16)
        local slam=math.sin(math.pi*math.clamp((t-.77)/.15,0,1))
        crouch=-.86*kneel*(1-rise)+.35*rise-.67*slam
        twist=math.sin(t*14*math.pi)*.08*rise*(1-dive)
        handRaise=-.7*kneel*(1-rise)+1.65*rise*(1-dive)+.6*dive
        stomp=.76*kneel*(1-rise)+1.05*slam
        roar=.12*kneel+.6*rise+.25*slam
        guard=.22*rise
        head=-.35*kneel*(1-rise)+.3*rise-.45*slam
        stride=.08*dive
    else
        stride=kind=="March" and .51 or kind=="Sprint" and .76 or kind=="Circle" and .37 or kind=="Stalk" and .25 or 0
        guard=kind=="Guard" and .40 or kind=="Enrage" and .70 or 0
        stomp=kind=="Recoil" and .25*math.sin(math.pi*t) or .05*math.abs(foot)
        twist=kind=="Circle" and .17*direction or .06*gait
        crouch=kind=="Stalk" and -.18 or kind=="Guard" and -.21 or kind=="Enrage" and .14 or 0
        roar=kind=="Enrage" and .3*math.sin(math.pi*t) or .04*breath
        handRaise=guard*.53
    end
    local rleg=stride*gait+stomp
    local lleg=-stride*gait+stomp
    local armRight=handRaise*-1+.78*release-.12*recoil-.36*rleg
    local armLeft=handRaise*-.72+.22*release-.30*lleg
    return {
        root=CFrame.new(0,crouch+math.abs(foot)*stride*.13,0)*CFrame.Angles(-.085*stride+.14*release,twist,.06*guard*direction),
        neck=CFrame.Angles(head+roar*.28,-twist*.28,.04*breath),
        spine=CFrame.Angles(-.1*handRaise+.05*breath,twist*.22,.09*guard*direction),
        armR=CFrame.Angles(armRight,twist*.43,.22*direction*handRaise),
        armL=CFrame.Angles(armLeft,-twist*.43,-.2*direction*handRaise),
        elbowR=CFrame.Angles(-.18-.78*attack-.32*guard+.36*release,0,.1*direction*release),
        elbowL=CFrame.Angles(-.18-.46*attack-.30*guard,0,-.07*direction*release),
        wristR=CFrame.Angles(.28*release+.12*breath,.06*twist,-.31*direction*release),
        wristL=CFrame.Angles(-.08*guard+.1*breath,0,0),
        hipR=CFrame.Angles(rleg+(kind=="revive" and 1.12*smooth(t/.22)*(1-smooth((t-.24)/.17)) or 0),0,.055*twist),
        hipL=CFrame.Angles(lleg+(kind=="revive" and -.48*smooth(t/.22)*(1-smooth((t-.24)/.17)) or 0),0,-.055*twist),
        kneeR=CFrame.Angles(-.12-.65*math.max(0,rleg)-.24*stomp-(kind=="revive" and 1.18*smooth(t/.22)*(1-smooth((t-.24)/.17)) or 0),0,0),
        kneeL=CFrame.Angles(-.12-.65*math.max(0,lleg)-.24*stomp,0,0),
        ankleR=CFrame.Angles(.11+.23*math.max(0,rleg),0,0),
        ankleL=CFrame.Angles(.11+.23*math.max(0,lleg),0,0),
        grip=CFrame.Angles(.19*release,0,.10*direction*attack),
    }
end
local attacks={};local moves={};local revival={}
local sampleCount=0
for id=1,15 do
    attacks[id]={}
    for f=1,ATTACK_FRAMES do
        attacks[id][f]=pose("attack",id,(f-1)/(ATTACK_FRAMES-1))
        sampleCount+=1
    end
end
for i,name in ipairs(MOVES) do
    moves[name]={}
    for f=1,MOVE_FRAMES do
        moves[name][f]=pose(name,i,(f-1)/(MOVE_FRAMES-1))
        sampleCount+=1
    end
end
for f=1,REBIRTH_FRAMES do
    revival[f]=pose("revive",5,(f-1)/(REBIRTH_FRAMES-1))
    sampleCount+=1
end
assert(sampleCount==1344,"Colossus motion library size")
local function poseAt(frames,t)
    local v=math.clamp(t,0,1)*(#frames-1)
    local a=math.floor(v)+1
    local f=smooth(v-math.floor(v))
    local out={}
    for name,cf in pairs(frames[a]) do out[name]=cf:Lerp(frames[math.min(a+1,#frames)][name],f) end
    return out
end
local function register(model)
    if active[model] or not model:IsA("Model") or model:GetAttribute("LashboundBoss")~=true then return end
    local root=model:FindFirstChild("HumanoidRootPart")
    local hum=model:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local joints={}
    for key,n in pairs(BONES) do
        local joint=model:FindFirstChild(n,true)
        if not joint or not joint:IsA("Motor6D") then return end
        joints[key]=joint
    end
    active[model]={root=root,hum=hum,joints=joints,walkBlend=0,phase=0,current={},lastUpdate=0,lastMode="Idle", style=math.random(1,8)}
end
local function retry(model)
    if active[model] or pending[model] then return end
    pending[model]=true
    task.spawn(function()
        for _=1,40 do
            if not model.Parent or active[model] then break end
            register(model)
            if active[model] then break end
            task.wait(.15)
        end
        pending[model]=nil
    end)
end
for _,m in ipairs(Workspace:GetDescendants()) do
    if m:IsA("Model") and m:GetAttribute("LashboundBoss")==true then retry(m) end
end
Workspace.DescendantAdded:Connect(function(m)
    if m:IsA("Model") and m:GetAttribute("LashboundBoss")==true then retry(m) end
end)
local updateTime=0
RunService.PreSimulation:Connect(function(dt)
    dt=math.min(dt,.075)
    updateTime+=dt
    if updateTime<1/30 then return end
    local tick=updateTime
    updateTime=0
    local character=player.Character
    local myRoot=character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local now=Workspace:GetServerTimeNow()
    for model,state in pairs(active) do
        if not model.Parent or state.hum.Health<=0 or not state.root.Parent then
            active[model]=nil
        else
            local distance=(state.root.Position-myRoot.Position).Magnitude
            local interval=distance<150 and 1/30 or distance<300 and .09 or .3
            if distance<370 and now-state.lastUpdate>=interval then
                local elapsed=state.lastUpdate>0 and math.clamp(now-state.lastUpdate,.012,.15) or tick
                state.lastUpdate=now
                local v=state.root.AssemblyLinearVelocity
                local speed=Vector3.new(v.X,0,v.Z).Magnitude
                local moving=model:GetAttribute("BossMoving") and speed>1.0
                local targetBlend=moving and math.clamp(speed/11,0,1) or 0
                state.walkBlend+=(targetBlend-state.walkBlend)*(1-math.exp(-elapsed*7.5))
                state.phase+=elapsed*(4.6+state.walkBlend*3.0)
                local progress=(state.phase/(2*math.pi))%1
                local mode="Idle";local frames=moves.Idle
                local reviving=model:GetAttribute("BossReviving")==true
                local attacking=model:GetAttribute("BossInAttack")==true
                if reviving then
                    mode="Revive"
                    progress=math.clamp((now-(model:GetAttribute("BossReviveStarted") or now))/(model:GetAttribute("BossReviveDuration") or 5.1),0,1)
                    frames=revival
                elseif attacking then
                    local index=math.clamp(math.floor(model:GetAttribute("BossAttackIndex") or 1),1,15)
                    mode="Attack"..index
                    local duration=math.max(.2,model:GetAttribute("BossWindupDuration") or 1.5)
                    progress=math.clamp((now-(model:GetAttribute("BossAttackStarted") or now))/(duration+.43),0,1)
                    frames=attacks[index]
                elseif state.walkBlend>.15 then
                    local selected=state.walkBlend>.82 and "Sprint" or state.walkBlend>.40 and "March" or "Stalk"
                    if model:GetAttribute("BossPhase")==2 and selected=="March" then selected="Circle" end
                    mode=selected;frames=moves[selected]
                elseif (now-(model:GetAttribute("BossFlinchAt") or -99))<.24 then
                    mode="Recoil"; frames=moves.Recoil
                    progress=(now-(model:GetAttribute("BossFlinchAt") or now))/.24
                elseif model:GetAttribute("BossPhase")==2 then
                    mode="Enrage";frames=moves.Enrage
                end
                local poseData=poseAt(frames,progress)
                local blend=1-math.exp(-elapsed*17)
                if mode~=state.lastMode then blend=math.min(blend,.40) end
                state.lastMode=mode
                for key,motor in pairs(state.joints) do
                    if motor.Parent then
                        local goal=poseData[key] or CFrame.identity
                        local previous=state.current[key] or CFrame.identity
                        local nextPose=previous:Lerp(goal,blend)
                        state.current[key]=nextPose
                        motor.Transform=nextPose
                    end
                end
            end
        end
    end
end)
