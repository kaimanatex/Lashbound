-- LASHBOUND V25: expressive four-legged hound motion, lightweight at raid scale.
-- The server moves an invisible root and owns hit detection. Clients interpolate
-- anchored cosmetic pieces with a diagonal trot, bent knees, paw placement,
-- spine/shoulder flex, head tracking, ears, tail and bite-lunge animation.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local me=Players.LocalPlayer
local animals=setmetatable({}, {__mode="k"})
local accumulated=0
local TWO_PI=math.pi*2
local function smooth(t) t=math.clamp(t,0,1); return t*t*(3-2*t) end
local function findState(model)
    local s=animals[model]
    if s then return s end
    local root=model:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    s={root=root,pos=root.Position,oldRoot=root.Position,
        look=Vector3.new(0,0,-1),phase=math.random()*TWO_PI,
        stride=0,lastMotion=-100,updated=0,parts={},seed=math.random()*11}
    animals[model]=s
    return s
end
local function p(model,s,name)
    local cached=s.parts[name]
    if cached and cached.Parent then return cached end
    local found=model:FindFirstChild(name)
    s.parts[name]=found
    return found
end
local function place(model,s,name,cf)
    local part=p(model,s,name)
    if part then part.CFrame=cf end
end
local function poseDog(model,s,dt,now,dist)
    local root=s.root
    local rootPos=root.Position
    local displacement=(rootPos-s.oldRoot).Magnitude
    if displacement>.12 then s.lastMotion=now end
    if displacement>60 then s.pos=rootPos;s.look=root.CFrame.LookVector end
    s.oldRoot=rootPos
    local speedGoal=(now-s.lastMotion<.27) and 1 or 0
    s.stride+=(speedGoal-s.stride)*(1-math.exp(-dt*(speedGoal>0 and 11 or 5)))
    local heading=root.CFrame.LookVector
    heading=Vector3.new(heading.X,0,heading.Z)
    if heading.Magnitude>.05 then
        s.look=s.look:Lerp(heading.Unit,1-math.exp(-dt*9))
    end
    local forward=Vector3.new(s.look.X,0,s.look.Z)
    if forward.Magnitude<.05 then forward=Vector3.new(0,0,-1) end
    s.pos=s.pos:Lerp(rootPos,1-math.exp(-dt*12))
    local cadence=10+7.0*s.stride
    s.phase+=dt*cadence
    local gait=s.phase+s.seed
    local trot=math.sin(gait)
    local bob=s.stride*.13*math.abs(math.sin(gait))
    local breathing=math.sin(now*2.2+s.seed)*.035
    local biteElapsed=now-(model:GetAttribute("DogBiteAt") or -100)
    local biting=biteElapsed>=0 and biteElapsed<.65
    local lunge=biting and math.sin(math.pi*smooth(biteElapsed/.65)) or 0
    local base=CFrame.lookAt(s.pos,s.pos+forward.Unit)
    local chassis=base*CFrame.new(0,bob+breathing+.24*lunge,0)
        *CFrame.Angles(-.065*s.stride*trot-.18*lunge,0,.045*s.stride*math.cos(gait))
    place(model,s,"Body",chassis*CFrame.new(0,.12,0))
    place(model,s,"Ruff",chassis*CFrame.new(0,.21,-1.28))
    place(model,s,"Haunches",chassis*CFrame.new(0,.12,1.4))
    place(model,s,"Belly",chassis*CFrame.new(0,-.69,.07))
    local head=chassis*CFrame.new(0,.43,-2.18)
        *CFrame.Angles(.07*math.sin(now*4+s.seed)-.30*lunge,math.sin(now*1.5+s.seed)*.07,0)
    place(model,s,"Head",head)
    place(model,s,"Muzzle",head*CFrame.new(0,-.4,-.92))
    place(model,s,"Nose",head*CFrame.new(0,-.26,-1.43))
    place(model,s,"Jaw",head*CFrame.new(0,-.67,-.93)*CFrame.Angles(.20*lunge,0,0))
    place(model,s,"Tongue",head*CFrame.new(0,-.86,-1.10)*CFrame.Angles(.16*lunge,0,0))
    place(model,s,"EyeL",head*CFrame.new(-.55,.33,-.72))
    place(model,s,"EyeR",head*CFrame.new(.55,.33,-.72))
    local earWiggle=math.sin(now*6.3+s.seed)*.085
    place(model,s,"Left Ear",head*CFrame.new(-.67,.91,-.14)*CFrame.Angles(earWiggle,0,-.14))
    place(model,s,"Right Ear",head*CFrame.new(.67,.91,-.14)*CFrame.Angles(-earWiggle,0,.14))
    place(model,s,"Collar",head*CFrame.new(0,-.35,.35)*CFrame.Angles(math.rad(35),0,0))
    local tailYaw=math.sin(now*5.4+s.seed)*.26
    local tail=chassis*CFrame.new(0,.60,2.55)*CFrame.Angles(-.26+math.sin(now*3)*.08,tailYaw,0)
    place(model,s,"Tail",tail*CFrame.new(0,0,.65))
    place(model,s,"TailTip",tail*CFrame.new(0,.18,1.54)*CFrame.Angles(.12,tailYaw*.45,0))
    -- Opposite diagonal legs work together (front-left + back-right).
    -- Each leg has a hip, bent knee and foot, with stance planting/swing lift.
    for i=1,4 do
        local left=i%2==1
        local front=i<=2
        local side=left and -1 or 1
        local z=front and -1.15 or 1.18
        local shift=(i==1 or i==4) and 0 or math.pi
        local cyc=gait+shift
        local forwardStep=math.sin(cyc)*.45*s.stride
        local lift=math.max(0,math.cos(cyc))*.23*s.stride
        local hip=chassis*CFrame.new(side*.83,-.55,z)
            *CFrame.Angles(forwardStep*(front and 1 or -.76),0,side*.025*s.stride)
        local upper=hip*CFrame.new(0,-.4,0)
        place(model,s,"Leg_"..i,upper)
        local bent=.12+lift*.8+(front and .08 or .16)*s.stride
        local knee=hip*CFrame.new(0,-.72,0)*CFrame.Angles(bent,0,0)
        place(model,s,"LowerLeg_"..i,knee*CFrame.new(0,-.20,0))
        local paw=knee*CFrame.new(0,-.49,-.26)*CFrame.Angles(-bent*.54,0,0)
        place(model,s,"Paw_"..i,paw)
    end
end
RunService.RenderStepped:Connect(function(dt)
    accumulated+=dt
    if accumulated<1/30 then return end
    local step=math.min(accumulated,.09)
    accumulated=0
    local char=me.Character
    local view=char and char:FindFirstChild("HumanoidRootPart")
    if not view then return end
    local arena=Workspace:FindFirstChild("LashboundBattleArena")
    local folder=arena and arena:FindFirstChild("LashboundBots")
    if not folder then return end
    local now=Workspace:GetServerTimeNow()
    for _,dog in ipairs(folder:GetChildren()) do
        if dog:IsA("Model") and dog:GetAttribute("LashboundDog") then
            local s=findState(dog)
            if s and s.root.Parent then
                local dist=(view.Position-s.root.Position).Magnitude
                local interval=dist<120 and 1/30 or dist<200 and .12 or .5
                if dist<240 and now-s.updated>=interval then
                    local elapsed=math.min(now-s.updated,.12)
                    s.updated=now
                    poseDog(dog,s,elapsed,now,dist)
                end
            end
        end
    end
end)
