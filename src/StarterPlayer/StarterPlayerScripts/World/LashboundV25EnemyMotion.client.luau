-- LASHBOUND V25: distance-budgeted full-body Sentinel procedural animation.
-- 12 enemy style variations x 8 movement/action states x 16 poses = 1,536
-- baked procedural pose samples, blended smoothly. These are NOT 1,536
-- uploaded Animation assets or 1,536 animation tracks running together.
-- Server alone owns NPC combat, navigation, hitboxes, health and AI decisions.
local Workspace=game:GetService("Workspace")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local renderables=setmetatable({}, {__mode="k"})
local registering=setmetatable({}, {__mode="k"})
local STYLES=12
local FRAMES=16
local MODES={"Idle","Walk","Strafe","Attack","Dodge","Stun","Flinch","Recover"}
local BONE_NAMES={
    root="RootJoint",neck="Neck",armR="Right Shoulder",armL="Left Shoulder",
    hipR="Right Hip",hipL="Left Hip",elbowR="Right Elbow",elbowL="Left Elbow",
    wristR="Right Wrist",wristL="Left Wrist",kneeR="Right Knee",kneeL="Left Knee",
    ankleR="Right Ankle",ankleL="Left Ankle",spine="SpineFlex",
    grip="BotWhipGrip",
}
local function ease(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function cf(p,y,r) return CFrame.Angles(p or 0,y or 0,r or 0) end
local function makePose(style,mode,t)
    local phase=t*math.pi*2
    local gait=math.sin(phase)
    local body=math.sin(phase*2+.2*style)
    local styleVar=1+(style%4)*.045
    local side=(style%2==0) and -1 or 1
    local stride=0;local bend=0;local attack=0;local flinch=0;local dodge=0
    local crouch=0;local twist=0;local head=0
    if mode=="Idle" then
        stride=.025; crouch=.018*body; head=math.sin(phase*.55+style)*.05
    elseif mode=="Walk" then
        stride=.78; crouch=.075*math.abs(body);twist=.082*gait
    elseif mode=="Strafe" then
        stride=.52; crouch=.085*math.abs(body);twist=.15*side
    elseif mode=="Attack" then
        attack=math.sin(math.pi*ease(t))
        local release=ease((t-.58)/.20)
        twist=side*(.40*attack-.68*release)
        crouch=-.17*attack+.06*release
        stride=.1
        bend=release*.40
    elseif mode=="Dodge" then
        dodge=math.sin(math.pi*t)
        twist=side*.36*dodge
        crouch=-.18*dodge
        stride=.32*dodge
    elseif mode=="Stun" then
        crouch=-.22;head=-.17+.08*body;twist=.12*body
    elseif mode=="Flinch" then
        flinch=math.sin(math.pi*ease(t))
        crouch=-.12*flinch;twist=-side*.33*flinch;head=.2*flinch
    else
        bend=.08*math.sin(math.pi*t)
        head=.07*body
    end
    local legR=stride*gait*styleVar
    local legL=-legR
    local armR=-legR*.38
    local armL=-legL*.42
    if mode=="Attack" then
        local raise=ease(t/.36)
        local snap=ease((t-.58)/.17)
        local recover=ease((t-.82)/.18)
        armR=-1.20*raise+2.1*snap-1.0*recover
        armL=-.26*raise+.18*snap
    elseif mode=="Flinch" then
        armR=-.42*flinch;armL=-.35*flinch
    elseif mode=="Dodge" then
        armR=-.32*dodge;armL=-.28*dodge
    end
    local elbowR=(mode=="Attack" and (.78*attack+.23*bend)) or .12+.1*math.abs(gait)
    local elbowL=(mode=="Attack" and (.35*attack)) or .09+.1*math.abs(gait)
    return {
        root=CFrame.new(0,crouch,0)*cf(.065*body+flinch*.17,twist,.11*side*dodge),
        neck=cf(head,-twist*.30,.045*body),
        spine=cf(-.06*attack+.04*body,twist*.23,0),
        armR=cf(armR,twist*.35,side*(.16*attack+.10*dodge)),
        armL=cf(armL,-twist*.32,-side*(.12*attack+.1*dodge)),
        elbowR=cf(-elbowR,side*.08*attack,0),elbowL=cf(-elbowL,0,0),
        wristR=cf(.20*attack+.07*gait,0,-side*.32*attack),wristL=cf(.02+.1*flinch,0,0),
        hipR=cf(legR+.22*dodge,0,.045*body),hipL=cf(legL+.22*dodge,0,-.045*body),
        kneeR=cf(-.18-math.max(0,legR)*.75-.45*dodge,0,0),
        kneeL=cf(-.18-math.max(0,legL)*.75-.45*dodge,0,0),
        ankleR=cf(.06+math.max(0,legR)*.24,0,0),ankleL=cf(.06+math.max(0,legL)*.24,0,0),
        grip=cf(.12*attack+.05*body,0,side*.07*attack),
    }
end
local library={}
local keyCount=0
for style=1,STYLES do
    library[style]={}
    for _,mode in ipairs(MODES) do
        local samples={}
        for frame=1,FRAMES do
            samples[frame]=makePose(style,mode,(frame-1)/(FRAMES-1))
            keyCount+=1
        end
        library[style][mode]=samples
    end
end
assert(keyCount==1536,"Sentinel animation library must contain exactly 1536 pose samples")
local function sample(style,mode,t)
    local poses=library[style][mode]
    local v=math.clamp(t,0,1)*(FRAMES-1)
    local idx=math.floor(v)+1
    local a,b=poses[idx],poses[math.min(idx+1,FRAMES)]
    local alpha=ease(v-math.floor(v))
    local out={}
    for bone,transform in pairs(a) do out[bone]=transform:Lerp(b[bone],alpha) end
    return out
end
local function register(model)
    if renderables[model] or not model:IsA("Model") or model:GetAttribute("LashboundNPC")~=true
        or model:GetAttribute("LashboundDog") then return end
    local root=model:FindFirstChild("HumanoidRootPart")
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or not model:FindFirstChild("Torso") then return end
    local joints={}
    for k,name in pairs(BONE_NAMES) do
        local m=model:FindFirstChild(name,true)
        if not m or not m:IsA("Motor6D") then return end
        joints[k]=m
    end
    local style=(tonumber(model.Name:match("_(%d+)$")) or 1)%STYLES+1
    renderables[model]={root=root,hum=humanoid,joints=joints,style=style,phase=style*.63,
        lastMode="Idle",current={},lastUpdate=0,lastLoc=0,walkBlend=0,attackProgress=0}
end
local function retry(model)
    if renderables[model] or registering[model] then return end
    registering[model]=true
    task.spawn(function()
        for _=1,36 do
            if not model.Parent or renderables[model] then break end
            register(model)
            if renderables[model] then break end
            task.wait(.15)
        end
        registering[model]=nil
    end)
end
for _,m in ipairs(Workspace:GetDescendants()) do
    if m:IsA("Model") and m:GetAttribute("LashboundNPC") and not m:GetAttribute("LashboundDog") then retry(m) end
end
Workspace.DescendantAdded:Connect(function(m)
    if m:IsA("Model") and m:GetAttribute("LashboundNPC") and not m:GetAttribute("LashboundDog") then retry(m) end
end)
local playerRoot=nil
local accumulate=0
RunService.PreSimulation:Connect(function(dt)
    dt=math.min(dt,.075)
    accumulate+=dt
    if accumulate<1/24 then return end
    local tick=accumulate;accumulate=0
    local ch=player.Character
    playerRoot=ch and ch:FindFirstChild("HumanoidRootPart")
    if not playerRoot then return end
    local now=Workspace:GetServerTimeNow()
    for model,st in pairs(renderables) do
        if not model.Parent or st.hum.Health<=0 or not st.root.Parent then
            renderables[model]=nil
        else
            local distance=(playerRoot.Position-st.root.Position).Magnitude
            local budget=distance<95 and (1/24) or distance<175 and .12 or .28
            if distance<260 and now-st.lastUpdate>=budget then
                local elapsed=st.lastUpdate>0 and math.clamp(now-st.lastUpdate,.015,.15) or tick
                st.lastUpdate=now
                local v=st.root.AssemblyLinearVelocity
                local speed=Vector3.new(v.X,0,v.Z).Magnitude
                local goal=math.clamp(speed/10,0,1)
                st.walkBlend+= (goal-st.walkBlend)*(1-math.exp(-elapsed*9))
                st.phase+=elapsed*(6.5+math.min(speed,20)*.34)
                local attackTime=now-(model:GetAttribute("BotAttackStart") or -100)
                local impactAt=model:GetAttribute("BotAttackImpact") or 0
                local dodgeAt=model:GetAttribute("BotDodgeStarted") or -100
                local flinchAt=model:GetAttribute("BotFlinchAt") or -100
                local mode="Idle";local t=(st.phase/(math.pi*2))%1
                if now-flinchAt<.28 then mode="Flinch";t=(now-flinchAt)/.28
                elseif now-dodgeAt<.52 then mode="Dodge";t=(now-dodgeAt)/.52
                elseif attackTime>=0 and now<impactAt+.38 then
                    mode="Attack";t=attackTime/math.max(.1,impactAt-(model:GetAttribute("BotAttackStart") or now)+.38)
                elseif st.hum.Health<st.hum.MaxHealth*.32 and speed>1.8 then mode="Strafe"
                elseif st.walkBlend>.14 then mode=speed>4.5 and "Walk" or "Strafe"
                elseif model:GetAttribute("BotFrozen") then mode="Stun" end
                local pose=sample(st.style,mode,t)
                local timeAlpha=1-math.exp(-elapsed*16)
                if mode~=st.lastMode then timeAlpha=math.min(timeAlpha,.35) end
                st.lastMode=mode
                for name,m in pairs(st.joints) do
                    if m.Parent then
                        local target=pose[name] or CFrame.identity
                        -- Transform is purely cosmetic: joints keep their welded,
                        -- server-authoritative character assembly and hitbox.
                        local from=st.current[name] or CFrame.identity
                        local blended=from:Lerp(target,timeAlpha)
                        st.current[name]=blended
                        m.Transform=blended
                    end
                end
            end
        end
    end
end)
