-- LASHBOUND V7 | large detailed maps, one-way lobby, held whips, NPC drops, and reliable dodges.
-- Server validates all teleports, purchases, cooldowns, and combat.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(RS:WaitForChild("WhipConfig"))
local AttackTimeline=require(game:GetService("ServerScriptService"):WaitForChild("Combat"):WaitForChild("AttackTimeline"))
local botCoinEvent=game:GetService("ServerScriptService"):WaitForChild("LashboundBotCoins")
local ApplyStatus=game:GetService("ServerScriptService"):WaitForChild("LashboundApplyStatus")
local bossCoinEvent=game:GetService("ServerScriptService"):WaitForChild("LashboundBossCoins")
local Whips = Config.Whips

local remotes = RS:WaitForChild("LashboundV5Remotes")
local Action = remotes:WaitForChild("Action")
local Feedback = remotes:WaitForChild("Feedback")

local lobbySpot = CFrame.lookAt(Vector3.new(0,5,16),Vector3.new(0,5,-40))
-- MapRotation owns the active arena; never cache a map or dummy folder across rotations.
local rng = Random.new()
local data = {}
local cooldowns = {}
local lastHit = {}
local save -- forward-declared to support debounced saves triggered by rewards
local function queueSave(player)
    local d=data[player]
    if not d then return end
    d.Revision=(d.Revision or 0)+1
    d.Dirty=true
    player:SetAttribute("WalletSaveStatus",d.SaveDisabled and "OFFLINE" or "PENDING")
    if d.SaveQueued then return end
    d.SaveQueued=true
    task.delay(18,function()
        if data[player]~=d then return end
        d.SaveQueued=false
        if d.Dirty and d.Loaded and not d.SaveDisabled and save then save(player) end
    end)
end
local impactAt = setmetatable({}, {__mode="k"})
local dummyHealth = setmetatable({}, {__mode="k"})
-- Studio/unpublished places may not have working DataStore access. Never block combat.
local storeOK, datastore = pcall(function()
    return DataStoreService:GetDataStore(RunService:IsStudio() and "LashboundArena_UserProgress_STUDIO_V9" or "LashboundArena_UserProgress_v1")
end)
if not storeOK then datastore = nil end

local function notify(player,kind,msg,payload)
    if player.Parent == Players then Feedback:FireClient(player,kind,msg,payload) end
end
local function charInfo(player)
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health<=0 or not root then return nil end
    return character,humanoid,root
end
local function isArena(player)
    return player:GetAttribute("Zone") == "Arena"
end
local function clearWeaponStyle(tool)
    for _,obj in ipairs(tool:GetChildren()) do
        if obj.Name:match("^Style_") then
            obj:Destroy()
        end
    end
end
local function styleWeld(part0, part1)
    local weld = Instance.new("WeldConstraint")
    weld.Name = "Style_Attached"
    weld.Part0 = part0
    weld.Part1 = part1
    weld.Parent = part1
end
local function stylePart(tool, parentPart, name, size, cf, color, material, shape, trans)
    local p = Instance.new("Part")
    p.Name = "Style_" .. name
    p.Size = size
    p.CFrame = parentPart.CFrame * cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Transparency = trans or 0
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Massless = true
    if shape then p.Shape = shape end
    p.Parent = tool
    styleWeld(parentPart, p)
    return p
end
local function styleWeapon(tool, id)
    if not tool then return end
    clearWeaponStyle(tool)
    local handle = tool:FindFirstChild("Handle")
    local pivot = tool:FindFirstChild("LashPivot") or handle
    if not handle or not pivot then return end
    if id == "Rope" then
        stylePart(tool, handle, "RopeKnotA", Vector3.new(.58,.22,.58), CFrame.new(0,.28,0), Color3.fromRGB(126,88,57), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
        stylePart(tool, handle, "RopeKnotB", Vector3.new(.62,.16,.62), CFrame.new(0,-.18,0), Color3.fromRGB(161,118,76), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
        stylePart(tool, pivot, "RopeTipCharm", Vector3.new(.22,.22,.52), CFrame.new(0,.18,-6.75), Color3.fromRGB(240,220,153), Enum.Material.Neon)
    elseif id == "Ember" then
        stylePart(tool, handle, "EmberGuardL", Vector3.new(.16,.85,.82), CFrame.new(.34,.62,-.12)*CFrame.Angles(math.rad(25),0,math.rad(24)), Color3.fromRGB(255,137,62), Enum.Material.Neon)
        stylePart(tool, handle, "EmberGuardR", Vector3.new(.16,.85,.82), CFrame.new(-.34,.62,-.12)*CFrame.Angles(math.rad(25),0,math.rad(-24)), Color3.fromRGB(255,88,42), Enum.Material.Neon)
        stylePart(tool, handle, "CoalPommel", Vector3.new(.44,.44,.44), CFrame.new(0,-1.05,0), Color3.fromRGB(79,19,12), Enum.Material.Metal, Enum.PartType.Ball)
        stylePart(tool, pivot, "FlameCharm", Vector3.new(.24,.24,.74), CFrame.new(0,.22,-6.62)*CFrame.Angles(math.rad(38),0,0), Color3.fromRGB(255,205,94), Enum.Material.Neon)
    elseif id == "Frost" then
        stylePart(tool, handle, "FrostCrownL", Vector3.new(.16,.72,.72), CFrame.new(.34,.64,-.14)*CFrame.Angles(math.rad(-18),0,math.rad(28)), Color3.fromRGB(205,248,255), Enum.Material.Glass)
        stylePart(tool, handle, "FrostCrownR", Vector3.new(.16,.72,.72), CFrame.new(-.34,.64,-.14)*CFrame.Angles(math.rad(-18),0,math.rad(-28)), Color3.fromRGB(205,248,255), Enum.Material.Glass)
        stylePart(tool, handle, "FrostGem", Vector3.new(.36,.36,.36), CFrame.new(0,-1.02,0), Color3.fromRGB(151,240,255), Enum.Material.Glass, Enum.PartType.Ball, .1)
        stylePart(tool, pivot, "IcicleTip", Vector3.new(.16,.16,.9), CFrame.new(0,.16,-6.74)*CFrame.Angles(math.rad(35),0,0), Color3.fromRGB(235,251,255), Enum.Material.Glass, nil, .12)
    elseif id == "Volt" then
        stylePart(tool, handle, "VoltForkL", Vector3.new(.12,.82,.64), CFrame.new(.28,.66,-.18)*CFrame.Angles(math.rad(8),0,math.rad(40)), Color3.fromRGB(247,230,80), Enum.Material.Metal)
        stylePart(tool, handle, "VoltForkR", Vector3.new(.12,.82,.64), CFrame.new(-.28,.66,-.18)*CFrame.Angles(math.rad(8),0,math.rad(-40)), Color3.fromRGB(247,230,80), Enum.Material.Metal)
        stylePart(tool, handle, "VoltNodeA", Vector3.new(.26,.26,.26), CFrame.new(0,.28,.18), Color3.fromRGB(108,243,255), Enum.Material.Neon, Enum.PartType.Ball)
        stylePart(tool, handle, "VoltNodeB", Vector3.new(.2,.2,.2), CFrame.new(0,-.35,-.15), Color3.fromRGB(255,251,145), Enum.Material.Neon, Enum.PartType.Ball)
    elseif id == "Gravity" then
        stylePart(tool, handle, "GravRing", Vector3.new(.82,.08,.82), CFrame.new(0,.56,0), Color3.fromRGB(194,138,255), Enum.Material.Neon, Enum.PartType.Cylinder, .08)
        stylePart(tool, handle, "GravOrb", Vector3.new(.42,.42,.42), CFrame.new(0,-1.04,0), Color3.fromRGB(88,58,128), Enum.Material.Neon, Enum.PartType.Ball, .08)
        stylePart(tool, pivot, "GravityHalo", Vector3.new(.46,.05,.46), CFrame.new(0,.86,-4.2)*CFrame.Angles(math.rad(90),0,0), Color3.fromRGB(208,175,255), Enum.Material.Neon, Enum.PartType.Cylinder, .22)
    elseif id == "Phantom" then
        stylePart(tool, handle, "PhantomWingL", Vector3.new(.12,.94,.74), CFrame.new(.32,.62,-.16)*CFrame.Angles(math.rad(15),0,math.rad(30)), Color3.fromRGB(255,113,224), Enum.Material.Neon, nil, .18)
        stylePart(tool, handle, "PhantomWingR", Vector3.new(.12,.94,.74), CFrame.new(-.32,.62,-.16)*CFrame.Angles(math.rad(15),0,math.rad(-30)), Color3.fromRGB(188,88,255), Enum.Material.Neon, nil, .18)
        stylePart(tool, handle, "PhantomEye", Vector3.new(.3,.3,.3), CFrame.new(0,-.98,0), Color3.fromRGB(255,189,244), Enum.Material.Neon, Enum.PartType.Ball, .04)
        stylePart(tool, pivot, "PhantomRibbon", Vector3.new(.1,.42,1.18), CFrame.new(0,.72,-5.2)*CFrame.Angles(math.rad(22),0,0), Color3.fromRGB(255,134,242), Enum.Material.Neon, nil, .28)
    elseif id == "Echo" then
        stylePart(tool, handle, "MirrorCore", Vector3.new(.38,.38,.38), CFrame.new(0,-1.05,0), Color3.fromRGB(119,255,241), Enum.Material.Glass, Enum.PartType.Ball, .08)
        stylePart(tool, handle, "MirrorGuardA", Vector3.new(.15,.67,.85), CFrame.new(.34,.65,0)*CFrame.Angles(0,0,math.rad(31)), Color3.fromRGB(119,255,241), Enum.Material.Neon, nil, .19)
        stylePart(tool, handle, "MirrorGuardB", Vector3.new(.15,.67,.85), CFrame.new(-.34,.65,0)*CFrame.Angles(0,0,math.rad(-31)), Color3.fromRGB(119,255,241), Enum.Material.Neon, nil, .19)
    elseif id == "Judgement" then
        stylePart(tool, handle, "StormGuardL", Vector3.new(.18,1.1,.8), CFrame.new(.34,.55,-.15)*CFrame.Angles(math.rad(-20),0,math.rad(32)), Color3.fromRGB(247,218,71), Enum.Material.Neon)
        stylePart(tool, handle, "StormGuardR", Vector3.new(.18,1.1,.8), CFrame.new(-.34,.55,-.15)*CFrame.Angles(math.rad(-20),0,math.rad(-32)), Color3.fromRGB(128,229,255), Enum.Material.Neon)
        stylePart(tool, handle, "StormHeart", Vector3.new(.38,.38,.38), CFrame.new(0,-1.04,0), Color3.fromRGB(234,243,255), Enum.Material.Neon, Enum.PartType.Ball)
        stylePart(tool, pivot, "ThunderTip", Vector3.new(.26,.26,.9), CFrame.new(0,.18,-6.7), Color3.fromRGB(255,251,171), Enum.Material.Neon)
    elseif id == "Legend" then
        stylePart(tool, handle, "RoyalCrossguardL", Vector3.new(.14,.96,.94), CFrame.new(.36,.64,-.1)*CFrame.Angles(math.rad(8),0,math.rad(18)), Color3.fromRGB(255,215,110), Enum.Material.Metal)
        stylePart(tool, handle, "RoyalCrossguardR", Vector3.new(.14,.96,.94), CFrame.new(-.36,.64,-.1)*CFrame.Angles(math.rad(8),0,math.rad(-18)), Color3.fromRGB(255,215,110), Enum.Material.Metal)
        stylePart(tool, handle, "RoyalGem", Vector3.new(.34,.34,.34), CFrame.new(0,-1.02,0), Color3.fromRGB(255,232,133), Enum.Material.Neon, Enum.PartType.Ball)
        stylePart(tool, pivot, "RoyalCrown", Vector3.new(.56,.22,.56), CFrame.new(0,.88,-3.2), Color3.fromRGB(255,204,82), Enum.Material.Neon, Enum.PartType.Cylinder, .06)
        stylePart(tool, pivot, "RoyalTip", Vector3.new(.24,.24,.72), CFrame.new(0,.18,-6.75)*CFrame.Angles(math.rad(32),0,0), Color3.fromRGB(255,244,164), Enum.Material.Neon)
    elseif id == "Owner" then
        stylePart(tool, handle, "FounderSpireL", Vector3.new(.14,1.0,.84), CFrame.new(.36,.62,-.14)*CFrame.Angles(math.rad(18),0,math.rad(20)), Color3.fromRGB(255,241,189), Enum.Material.Neon, nil, .08)
        stylePart(tool, handle, "FounderSpireR", Vector3.new(.14,1.0,.84), CFrame.new(-.36,.62,-.14)*CFrame.Angles(math.rad(18),0,math.rad(-20)), Color3.fromRGB(255,241,189), Enum.Material.Neon, nil, .08)
        stylePart(tool, handle, "FounderCore", Vector3.new(.38,.38,.38), CFrame.new(0,-1.0,0), Color3.fromRGB(255,235,162), Enum.Material.Neon, Enum.PartType.Ball)
        stylePart(tool, pivot, "FounderHalo", Vector3.new(.66,.06,.66), CFrame.new(0,.72,-4.1)*CFrame.Angles(math.rad(90),0,0), Color3.fromRGB(255,241,189), Enum.Material.Neon, Enum.PartType.Cylinder, .08)
    end
end
local function paintWeapon(tool, id)
    if not tool then return end
    local cfg = Whips[id] or Whips.Rope
    tool:SetAttribute("WhipId", id)
    tool.ToolTip = cfg.Name .. " • Q: " .. cfg.PowerName
    for _,piece in ipairs(tool:GetDescendants()) do
        if piece:IsA("BasePart") then
            local lashIndex = tonumber(piece.Name:match("Lash_(%d+)"))
            if piece.Name:match("^Lash_") or piece.Name=="LashTip" or piece.Name=="ColorCollar" then
                piece.Material = Enum.Material.SmoothPlastic
                piece.Transparency = 0
                piece.Color = cfg.Color
                if id=="Ember" then
                    if lashIndex and lashIndex >= 5 or piece.Name=="LashTip" then piece.Color=Color3.fromRGB(255,175,71); piece.Material=Enum.Material.Neon else piece.Color=Color3.fromRGB(119,38,22) end
                elseif id=="Frost" then
                    piece.Color = lashIndex and lashIndex >= 5 and Color3.fromRGB(238,252,255) or Color3.fromRGB(148,238,255)
                    piece.Material = Enum.Material.Glass
                    piece.Transparency = piece.Name=="LashTip" and .08 or .18
                elseif id=="Volt" then
                    if lashIndex and lashIndex % 2 == 0 then piece.Color=Color3.fromRGB(104,244,255) else piece.Color=Color3.fromRGB(255,241,99) end
                    piece.Material = lashIndex and lashIndex >= 5 and Enum.Material.Neon or Enum.Material.Metal
                elseif id=="Gravity" then
                    piece.Color = lashIndex and lashIndex >= 5 and Color3.fromRGB(214,180,255) or Color3.fromRGB(76,59,120)
                    piece.Material = lashIndex and lashIndex >= 4 and Enum.Material.Neon or Enum.Material.SmoothPlastic
                elseif id=="Phantom" then
                    piece.Color = lashIndex and lashIndex >= 5 and Color3.fromRGB(255,176,244) or Color3.fromRGB(206,97,255)
                    piece.Material = Enum.Material.Neon
                    piece.Transparency = piece.Name=="LashTip" and .04 or .14
                elseif id=="Echo" then
                    piece.Color=lashIndex and lashIndex>=5 and Color3.fromRGB(168,255,244) or Color3.fromRGB(69,162,159)
                    piece.Material=Enum.Material.Neon
                    piece.Transparency=piece.Name=="LashTip" and .05 or .13
                elseif id=="Judgement" then
                    piece.Color=lashIndex and lashIndex%2==0 and Color3.fromRGB(115,231,255) or Color3.fromRGB(250,242,102)
                    piece.Material=Enum.Material.Neon
                elseif id=="Legend" then
                    piece.Color = lashIndex and lashIndex >= 5 and Color3.fromRGB(255,240,159) or Color3.fromRGB(255,196,82)
                    piece.Material = Enum.Material.Neon
                elseif id=="Owner" then
                    piece.Color = lashIndex and lashIndex >= 5 and Color3.fromRGB(255,246,203) or Color3.fromRGB(255,228,138)
                    piece.Material = Enum.Material.Neon
                elseif id=="Rope" then
                    if lashIndex then piece.Color = lashIndex>=5 and Color3.fromRGB(210,180,108) or Color3.fromRGB(123,92,61) end
                end
            elseif piece.Name:match("^GripWrap_") then
                piece.Color = (id=="Rope" and Color3.fromRGB(130,94,65)) or (id=="Ember" and Color3.fromRGB(111,42,28)) or (id=="Frost" and Color3.fromRGB(174,230,238)) or (id=="Volt" and Color3.fromRGB(65,98,112)) or (id=="Gravity" and Color3.fromRGB(78,69,120)) or (id=="Phantom" and Color3.fromRGB(94,63,112)) or Color3.fromRGB(145,111,73)
            elseif piece.Name=="Pommel" or piece.Name=="Handle" then
                if id=="Rope" then piece.Color=Color3.fromRGB(73,54,40)
                elseif id=="Ember" then piece.Color=Color3.fromRGB(68,35,28)
                elseif id=="Frost" then piece.Color=Color3.fromRGB(159,194,205)
                elseif id=="Volt" then piece.Color=Color3.fromRGB(78,86,105)
                elseif id=="Gravity" then piece.Color=Color3.fromRGB(54,47,73)
                elseif id=="Phantom" then piece.Color=Color3.fromRGB(67,46,94)
                elseif id=="Echo" then piece.Color=Color3.fromRGB(49,96,93)
                elseif id=="Judgement" then piece.Color=Color3.fromRGB(104,114,135)
                elseif id=="Legend" then piece.Color=Color3.fromRGB(150,103,50)
                elseif id=="Owner" then piece.Color=Color3.fromRGB(181,155,86) end
            end
        end
    end
    styleWeapon(tool,id)
end
local function createEmergencyWeapon()
    -- Backup only. A real physical Tool is also serialized in StarterPack.
    local tool = Instance.new("Tool")
    tool.Name = "LashboundWhip"
    tool.CanBeDropped=false
    tool.RequiresHandle=true
    tool.Grip = CFrame.new(0,-.6,0) * CFrame.Angles(math.rad(-12),0,math.rad(-9))
    local handle = Instance.new("Part")
    handle.Name="Handle"
    handle.Size=Vector3.new(.46,1.8,.46)
    handle.Color=Color3.fromRGB(48,49,67)
    handle.Material=Enum.Material.Metal
    handle.CanCollide=false; handle.CanTouch=false; handle.CanQuery=false
    handle.Massless=true
    handle.Parent=tool
    local pivot=Instance.new("Part")
    pivot.Name="LashPivot"; pivot.Size=Vector3.new(.18,.18,.18)
    pivot.Transparency=1; pivot.CanCollide=false; pivot.CanTouch=false; pivot.CanQuery=false; pivot.Massless=true
    pivot.CFrame=handle.CFrame*CFrame.new(0,.95,0)
    pivot.Parent=tool
    local joint=Instance.new("Motor6D")
    joint.Name="WhipJoint"; joint.Part0=handle; joint.Part1=pivot
    joint.C0=CFrame.new(0,.95,0); joint.Parent=handle
    for i=0,4 do
        local wrap = Instance.new("Part")
        wrap.Name = "GripWrap_"..i
        wrap.Size = Vector3.new(.53,.085,.53)
        wrap.Shape = Enum.PartType.Cylinder
        wrap.Color = Color3.fromRGB(134,101,79)
        wrap.Material = Enum.Material.SmoothPlastic
        wrap.CFrame = handle.CFrame * CFrame.new(0,-.63+.25*i,0)
        wrap.CanCollide=false; wrap.CanTouch=false; wrap.CanQuery=false; wrap.Massless=true
        wrap.Parent=tool
        styleWeld(handle,wrap)
    end
    local collar=Instance.new("Part")
    collar.Name="ColorCollar"; collar.Size=Vector3.new(.64,.20,.64); collar.Shape=Enum.PartType.Cylinder
    collar.Color=Color3.fromRGB(240,212,122); collar.Material=Enum.Material.Neon
    collar.CFrame=handle.CFrame*CFrame.new(0,.85,0)
    collar.CanCollide=false; collar.CanTouch=false; collar.CanQuery=false; collar.Massless=true
    collar.Parent=tool; styleWeld(handle,collar)
    local pommel=Instance.new("Part")
    pommel.Name="Pommel"; pommel.Size=Vector3.new(.66,.46,.66); pommel.Shape=Enum.PartType.Ball
    pommel.Color=Color3.fromRGB(156,127,94); pommel.Material=Enum.Material.Metal
    pommel.CFrame=handle.CFrame*CFrame.new(0,-.95,0)
    pommel.CanCollide=false; pommel.CanTouch=false; pommel.CanQuery=false; pommel.Massless=true
    pommel.Parent=tool; styleWeld(handle,pommel)
    local path={Vector3.new(0,0,0),Vector3.new(0,.45,-.65),Vector3.new(0,.9,-1.5),Vector3.new(0,1.15,-2.5),Vector3.new(0,1.22,-3.5),Vector3.new(0,1,-4.55),Vector3.new(0,.66,-5.55),Vector3.new(0,.24,-6.3)}
    for i=1,#path-1 do
        local a,b=path[i],path[i+1]
        local p=Instance.new("Part")
        p.Name="Lash_"..i
        p.Size=Vector3.new(math.max(.095,.36-i*.035),math.max(.095,.36-i*.035),(b-a).Magnitude*1.08)
        p.CFrame=pivot.CFrame*CFrame.lookAt((a+b)/2,b)
        p.Color=Whips.Rope.Color
        p.Material=(i>=6) and Enum.Material.Neon or Enum.Material.SmoothPlastic
        p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true
        p.Parent=tool
        local weld=Instance.new("WeldConstraint"); weld.Part0=pivot; weld.Part1=p; weld.Parent=p
    end
    local tip=Instance.new("Part")
    tip.Name="LashTip"; tip.Size=Vector3.new(.19,.19,.46)
    tip.Color=Color3.fromRGB(245,246,255); tip.Material=Enum.Material.Neon
    tip.CFrame=pivot.CFrame*CFrame.new(0,1.19,-6.42)
    tip.CanCollide=false; tip.CanTouch=false; tip.CanQuery=false; tip.Massless=true
    tip.Parent=tool; styleWeld(pivot,tip)
    paintWeapon(tool,"Rope")
    return tool
end

local function findWeapon(player)
    local char=player.Character
    local backpack=player:FindFirstChildOfClass("Backpack")
    return (char and char:FindFirstChild("LashboundWhip")) or (backpack and backpack:FindFirstChild("LashboundWhip"))
end

local function attachCombatHealth(model,hum,display,color)
    local head=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    if not head or head:FindFirstChild("LashboundHealthBar") then return end
    local gui=Instance.new("BillboardGui")
    gui.Name="LashboundHealthBar"
    gui.AlwaysOnTop=true;gui.MaxDistance=145
    gui.Size=UDim2.fromOffset(155,41)
    gui.StudsOffsetWorldSpace=Vector3.new(0,3.1,0)
    gui.Parent=head
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(1,0,0,15);bg.Position=UDim2.fromOffset(0,23)
    bg.BackgroundColor3=Color3.fromRGB(19,19,29);bg.BorderSizePixel=0;bg.Parent=gui
    local fill=Instance.new("Frame")
    fill.Name="Fill";fill.BackgroundColor3=color or Color3.fromRGB(90,245,158)
    fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(1,1);fill.Parent=bg
    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,0,0,23);label.BackgroundTransparency=1
    label.TextColor3=Color3.new(1,1,1);label.TextStrokeTransparency=.2
    label.TextScaled=true;label.Font=Enum.Font.GothamBold
    label.Parent=gui
    local function update(hp)
        fill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,hum.MaxHealth),0,1),1)
        label.Text=display.."  "..math.ceil(hp).."/"..math.ceil(hum.MaxHealth)
    end
    hum.HealthChanged:Connect(update)
    update(hum.Health)
end

local function equipWeapon(player,forceNormal)
    local char,hum=charInfo(player)
    if not char then return end
    local bag=player:FindFirstChildOfClass("Backpack")
    if not bag then return end
    local tool=findWeapon(player)
    if not tool then
        tool=createEmergencyWeapon()
        tool.Parent=bag
    end
    -- A founder has TWO separate Tools. Never repaint the ordinary LashboundWhip
    -- as the owner item, and never steal the hotbar selection from FounderTempest.
    if char:FindFirstChild("FounderTempest") and not forceNormal then
        player:SetAttribute("HasWhip",true)
        return
    end
    local regularId=player:GetAttribute("RegularWhip") or "Rope"
    if not Whips[regularId] or Whips[regularId].OwnerOnly then regularId="Rope" end
    paintWeapon(tool,regularId)
    if tool.Parent~=char then hum:EquipTool(tool) end
    if tool.Parent==char then player:SetAttribute("SelectedWhip",regularId) end
    player:SetAttribute("HasWhip", tool.Parent==char)
    notify(player,"Message", tool.Parent==char and "WHIP EQUIPPED" or "WHIP IN BACKPACK - SELECT SLOT 1")
end
local function addCoins(player,amount)
    local d=data[player]
    if not d then return end
    d.Coins=math.max(0,math.floor(d.Coins+amount))
    player:SetAttribute("Coins",d.Coins)
    queueSave(player)
end
botCoinEvent.Event:Connect(function(player,amount)
    -- Server-only BindableEvent, never a client RemoteEvent.
    if player and player.Parent==Players and isArena(player) and (amount==10 or amount==1) then
        addCoins(player,amount)
        if amount==10 then notify(player,"Message","PICKED UP +10 COINS") end
    end
end)
bossCoinEvent.Event:Connect(function(player,amount)
    if player and player.Parent==Players and amount==120 and isArena(player) then
        addCoins(player,amount)
    end
end)
local function setKO(player)
    local d=data[player]
    if not d then return end
    d.KOs+=1
    player:SetAttribute("KOs",d.KOs)
    queueSave(player)
    addCoins(player,Config.PlayerKOReward)
    notify(player,"Message","PLAYER K.O.! +"..Config.PlayerKOReward.." coins")
end
-- Portal transfers are exclusively handled by PortalService; no Return combat action.
-- Low-overhead visuals: one temporary effect per attack, no physics/projectiles/AI loop.
local fxFolder=Instance.new("Folder")
fxFolder.Name="LightweightFX"
fxFolder.Parent=Workspace
local function fxLine(from,to,color,width)
    local delta=to-from
    if delta.Magnitude<.2 then return end
    local p=Instance.new("Part")
    p.Name="WhipFlash"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    p.CastShadow=false; p.Material=Enum.Material.Neon; p.Color=color
    p.Size=Vector3.new(width or .2,width or .2,delta.Magnitude)
    p.CFrame=CFrame.lookAt((from+to)/2,to)
    p.Parent=fxFolder
    Debris:AddItem(p,.14)
end
local function fxPulse(pos,color,radius)
    local part=Instance.new("Part")
    part.Name="PowerPulse"; part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
    part.CastShadow=false; part.Material=Enum.Material.Neon; part.Shape=Enum.PartType.Cylinder
    part.Color=color; part.Size=Vector3.new(radius*2,.12,radius*2); part.Transparency=.77
    part.CFrame=CFrame.new(pos.X,.63,pos.Z)
    part.Parent=fxFolder
    Debris:AddItem(part,.28)
end
-- Lightweight procedural attack and dodge poses; visible to other players.
-- Works on both R6 and R15 without uploaded animation asset IDs.
local baseC0 = setmetatable({}, {__mode = "k"})
local poseToken = setmetatable({}, {__mode = "k"})
local activePoseTween = setmetatable({}, {__mode = "k"})
local function poseMotor(motor, offset, duration, recover, followthrough)
    if not motor or not motor:IsA("Motor6D") then return end
    if not baseC0[motor] then baseC0[motor] = motor.C0 end
    local serial = (poseToken[motor] or 0) + 1
    poseToken[motor] = serial
    if activePoseTween[motor] then activePoseTween[motor]:Cancel() end
    local tween = TweenService:Create(motor, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        C0 = baseC0[motor] * offset
    })
    activePoseTween[motor] = tween
    tween:Play()
    task.delay(duration + .015, function()
        if motor.Parent and poseToken[motor] == serial then
            if activePoseTween[motor] then activePoseTween[motor]:Cancel() end
            if followthrough then
                local snap=TweenService:Create(motor,TweenInfo.new(.13,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
                    C0=baseC0[motor]*followthrough})
                activePoseTween[motor]=snap
                snap:Play()
            end
            task.delay(followthrough and .15 or 0,function()
                if not motor.Parent or poseToken[motor]~=serial then return end
                if activePoseTween[motor] then activePoseTween[motor]:Cancel() end
                local back=TweenService:Create(motor,TweenInfo.new(recover,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                    C0=baseC0[motor]})
                activePoseTween[motor]=back
                back:Play()
            end)
        end
    end)
end
-- Physically readable three-phase combat choreography for R6 and R15.
-- R15 joints are animated through their Motor6D C0 so the motions work without
-- uploaded Animation IDs; the existing rig/Animate script remains responsible
-- for idle locomotion. Each cast pose has wind-up, follow-through and recovery.
local function animateBody(character, mode, step, whipId)
    local upper=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not upper then return end
    local right=upper:FindFirstChild("RightShoulder") or upper:FindFirstChild("Right Shoulder")
    local left=upper:FindFirstChild("LeftShoulder") or upper:FindFirstChild("Left Shoulder")
    local waist=upper:FindFirstChild("Waist")
    local lower=character:FindFirstChild("LowerTorso")
    local rootJoint=(lower and lower:FindFirstChild("Root"))
        or (character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart:FindFirstChild("RootJoint"))
    local torso=waist or rootJoint
    local follow=0.21
    if mode=="Dodge" then
        poseMotor(right,CFrame.Angles(math.rad(42),0,math.rad(24)),.075,.24,
            CFrame.Angles(math.rad(16),0,math.rad(-20)))
        poseMotor(left,CFrame.Angles(math.rad(42),0,math.rad(-24)),.075,.24)
        poseMotor(torso,CFrame.Angles(math.rad(-20),0,math.rad(7)),.08,.24)
    elseif mode=="Heavy" then
        poseMotor(right,CFrame.Angles(math.rad(-125),math.rad(-54),math.rad(86)),.18,.29,
            CFrame.Angles(math.rad(45),math.rad(104),math.rad(-79)))
        poseMotor(left,CFrame.Angles(math.rad(40),math.rad(12),math.rad(-56)),.16,.31,
            CFrame.Angles(math.rad(-20),math.rad(-16),math.rad(18)))
        poseMotor(torso,CFrame.Angles(math.rad(16),math.rad(29),math.rad(-13)),.18,.32,
            CFrame.Angles(math.rad(-19),math.rad(-27),math.rad(12)))
    elseif mode=="Power" then
        -- No ability reuses the ordinary three-hit attack pose.
        if whipId=="Rope" then -- shoulder windup, lunging front thrust
            poseMotor(right,CFrame.Angles(math.rad(-85),math.rad(-58),math.rad(65)),.14,.22,
                CFrame.Angles(math.rad(12),math.rad(112),math.rad(-67)))
            poseMotor(left,CFrame.Angles(math.rad(36),0,math.rad(-25)),.12,.26)
            poseMotor(torso,CFrame.Angles(math.rad(12),math.rad(22),0),.15,.24,
                CFrame.Angles(math.rad(-23),math.rad(-18),0))
        elseif whipId=="Ember" then -- wide circular fiery sweep
            poseMotor(right,CFrame.Angles(math.rad(-88),math.rad(-73),math.rad(70)),.19,.31,
                CFrame.Angles(math.rad(29),math.rad(124),math.rad(-70)))
            poseMotor(left,CFrame.Angles(math.rad(-32),math.rad(38),math.rad(-65)),.17,.30,
                CFrame.Angles(math.rad(15),math.rad(-35),math.rad(52)))
            poseMotor(torso,CFrame.Angles(math.rad(-6),math.rad(-36),0),.20,.30,
                CFrame.Angles(math.rad(5),math.rad(48),0))
        elseif whipId=="Frost" then -- deliberate straight icy lance
            poseMotor(right,CFrame.Angles(math.rad(-100),math.rad(-15),math.rad(16)),.21,.25,
                CFrame.Angles(math.rad(5),math.rad(90),math.rad(-30)))
            poseMotor(left,CFrame.Angles(math.rad(25),math.rad(24),math.rad(-30)),.16,.27)
            poseMotor(torso,CFrame.Angles(math.rad(2),math.rad(14),math.rad(-6)),.18,.27,
                CFrame.Angles(math.rad(-12),math.rad(-11),0))
        elseif whipId=="Judgement" then -- gather both arms, raise whip, cast thunder verdict
            poseMotor(right,CFrame.Angles(math.rad(-165),math.rad(-22),math.rad(28)),.23,.40,
                CFrame.Angles(math.rad(42),math.rad(92),math.rad(-40)))
            poseMotor(left,CFrame.Angles(math.rad(-88),math.rad(23),math.rad(-29)),.20,.33)
            poseMotor(torso,CFrame.Angles(math.rad(17),math.rad(12),0),.21,.34,
                CFrame.Angles(math.rad(-20),math.rad(-18),0))
        elseif whipId=="Volt" then -- high raised arm, downward thunder snap
            poseMotor(right,CFrame.Angles(math.rad(-154),0,math.rad(24)),.19,.29,
                CFrame.Angles(math.rad(40),math.rad(18),math.rad(-35)))
            poseMotor(left,CFrame.Angles(math.rad(-34),0,math.rad(-26)),.17,.25)
            poseMotor(torso,CFrame.Angles(math.rad(11),0,math.rad(-9)),.18,.30,
                CFrame.Angles(math.rad(-18),0,math.rad(9)))
        elseif whipId=="Gravity" then -- hands raise and reel inward
            poseMotor(right,CFrame.Angles(math.rad(-118),math.rad(-35),math.rad(70)),.21,.32,
                CFrame.Angles(math.rad(-34),math.rad(36),math.rad(28)))
            poseMotor(left,CFrame.Angles(math.rad(-100),math.rad(34),math.rad(-73)),.21,.32,
                CFrame.Angles(math.rad(-36),math.rad(-31),math.rad(-25)))
            poseMotor(torso,CFrame.Angles(math.rad(8),0,0),.19,.29,
                CFrame.Angles(math.rad(18),0,0))
        elseif whipId=="Phantom" then -- compact crouch and crossing ambush
            poseMotor(right,CFrame.Angles(math.rad(-70),math.rad(70),math.rad(-55)),.12,.26,
                CFrame.Angles(math.rad(28),math.rad(-103),math.rad(60)))
            poseMotor(left,CFrame.Angles(math.rad(28),math.rad(-35),math.rad(-8)),.13,.23)
            poseMotor(torso,CFrame.Angles(math.rad(-24),math.rad(26),math.rad(14)),.12,.29,
                CFrame.Angles(math.rad(17),math.rad(-28),math.rad(-13)))
        elseif whipId=="Legend" then -- overhead royal grapple
            poseMotor(right,CFrame.Angles(math.rad(-145),math.rad(-35),math.rad(65)),.21,.3,
                CFrame.Angles(math.rad(20),math.rad(120),math.rad(-65)))
            poseMotor(left,CFrame.Angles(math.rad(-45),math.rad(30),math.rad(-52)),.18,.28)
            poseMotor(torso,CFrame.Angles(math.rad(10),math.rad(28),math.rad(-11)),.20,.28,
                CFrame.Angles(math.rad(-14),math.rad(-21),math.rad(10)))
        else
            poseMotor(right,CFrame.Angles(math.rad(-118),0,math.rad(58)),.17,.27,
                CFrame.Angles(math.rad(20),0,math.rad(-38)))
            poseMotor(left,CFrame.Angles(math.rad(-35),0,math.rad(-33)),.14,.23)
            poseMotor(torso,CFrame.Angles(math.rad(8),0,0),.17,.26)
        end
    else
        -- Light attacks alternate left/right, with a visibly larger third finisher.
        local side=(step==2) and -1 or 1
        local power=(step==3) and 1.23 or 1
        poseMotor(right,CFrame.Angles(math.rad(-79*power),math.rad(-44*side),math.rad(62*side)),.11,.26,
            CFrame.Angles(math.rad(39),math.rad(94*side),math.rad(-75*side)))
        poseMotor(left,CFrame.Angles(math.rad(14),math.rad(8*side),math.rad(-17*side)),.1,.2)
        poseMotor(torso,CFrame.Angles(math.rad(-7),math.rad(16*side),math.rad(3*side)),.11,.26,
            CFrame.Angles(math.rad(5),math.rad(-19*side),math.rad(-3*side)))
    end
end
-- Replicate only compact action timestamps, never per-frame body CFrames.
-- All clients evaluate matching attack/dodge poses for newer avatar joints.
local function markWhipMotion(character, mode, step, duration)
    character:SetAttribute("WhipMotion", mode)
    character:SetAttribute("WhipMotionStep", step)
    character:SetAttribute("WhipMotionDuration", duration)
    character:SetAttribute("WhipMotionAt", Workspace:GetServerTimeNow())
    character:SetAttribute("WhipCombatUntil", Workspace:GetServerTimeNow() + duration)
end

local function swingModel(character,step,mode,whipId)
    mode=mode or "Attack"
    animateBody(character,mode,step,whipId)
    local tool=character:FindFirstChild("FounderTempest") or character:FindFirstChild("LashboundWhip")
    if not tool then return end
    local handle=tool:FindFirstChild("Handle")
    local joint=handle and handle:FindFirstChild("WhipJoint")
    if not joint then return end
    local n=(joint:GetAttribute("SwingNo") or 0)+1
    joint:SetAttribute("SwingNo",n)
    local idle=CFrame.new(0,.95,0)
    local side=(step==2) and -1 or 1
    -- Raise the arm, visibly COIL the lash, then snap toward the target.
    -- The lash whip-tip impact timestamps (.29/.33/.37s) stay server-authoritative.
    local windup=mode=="Heavy" and .26 or mode=="Power" and .29 or .21
    local impactAngle=mode=="Heavy" and 148 or mode=="Power" and 132 or step==3 and 124 or 104
    local returnTime=mode=="Heavy" and .38 or mode=="Power" and .32 or .27
    local startYaw=(mode=="Power" and whipId=="Volt") and 20 or 66
    joint.C0=idle*CFrame.Angles(math.rad(-70),math.rad(startYaw*side),math.rad(-35*side))
    local coil=TweenService:Create(joint,TweenInfo.new(windup*.63,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{
        C0=idle*CFrame.Angles(math.rad(-100),math.rad(77*side),math.rad(-55*side))
    })
    coil:Play()
    task.delay(windup*.61,function()
        if not joint.Parent or joint:GetAttribute("SwingNo")~=n then return end
        TweenService:Create(joint,TweenInfo.new(windup*.53,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{
            C0=idle*CFrame.Angles(math.rad(43),math.rad(-impactAngle*side),math.rad(49*side))
        }):Play()
    end)
    task.delay(windup+.09,function()
        if joint.Parent and joint:GetAttribute("SwingNo")==n then
            TweenService:Create(joint,TweenInfo.new(returnTime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                C0=idle
            }):Play()
        end
    end)
end

-- Clients render brief cosmetic arcs locally; no server-spawned particle floods.
local function broadcastAction(origin, kind, direction, color, step, whipId, actorUserId, hitbox, serverStart)
    local payload={kind=kind,origin=origin,direction=direction,color=color,step=step,whipId=whipId,actorUserId=actorUserId,startedAt=serverStart or Workspace:GetServerTimeNow()}
    if kind=="Attack" then payload.impactServerTime=payload.startedAt+.29
    elseif kind=="Heavy" then payload.impactServerTime=payload.startedAt+.33
    elseif kind=="Power" then payload.impactServerTime=payload.startedAt+.37 end
    if hitbox then
        -- Only the server writes combat-range metadata; the client merely draws it.
        payload.hitbox=hitbox
    end
    for _,observer in ipairs(Players:GetPlayers()) do
        local c=observer.Character
        local r=c and c:FindFirstChild("HumanoidRootPart")
        if r and (r.Position-origin).Magnitude < 165 then
            Feedback:FireClient(observer,"Visual",kind,payload)
        end
    end
end
local function vectorFacing(param,root)
    local face=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
    if face.Magnitude<.1 then face=Vector3.new(0,0,-1) end
    if typeof(param)~="Vector3" or param.X~=param.X or param.Z~=param.Z then return face.Unit end
    local flat=Vector3.new(param.X,0,param.Z)
    if flat.Magnitude<.1 or flat.Magnitude>100 then return face.Unit end
    local vec=flat.Unit
    -- Limited client steering; prevents impossible backwards hits without turning.
    if vec:Dot(face.Unit)<-.2 then return face.Unit end
    return vec
end
local function allTargets(attacker)
    local out={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=attacker and isArena(p) then
            local _,h,r=charInfo(p)
            if h and r then table.insert(out,{kind="Player",player=p,root=r,hum=h,pos=r.Position}) end
        end
    end
    local active=Workspace:FindFirstChild("LashboundBattleArena")
    local practice=active and active:FindFirstChild("PracticeTargets")
    for _,target in ipairs(practice and practice:GetChildren() or {}) do
        local core=target:FindFirstChild("Core")
        local hp=dummyHealth[target]
        if core and hp and hp>0 then
            table.insert(out,{kind="Dummy",model=target,root=core,pos=core.Position})
        end
    end
    -- Active sentinels are humanoid NPCs. They are eligible for the same whip
    -- hit checks as players and dummies, but rewards happen on coin pickup.
    local enemies=active and active:FindFirstChild("LashboundBots")
    for _,model in ipairs(enemies and enemies:GetChildren() or {}) do
        if model:IsA("Model") and model:GetAttribute("LashboundNPC")==true then
            local h=model:FindFirstChildOfClass("Humanoid")
            local r=model:FindFirstChild("HumanoidRootPart")
            if h and h.Health>0 and r then
                table.insert(out,{kind="Bot",model=model,root=r,hum=h,pos=r.Position})
            end
        end
    end
    local bosses=active and active:FindFirstChild("LashboundBosses")
    for _,model in ipairs(bosses and bosses:GetChildren() or {}) do
        local h=model:FindFirstChildOfClass("Humanoid")
        local r=model:FindFirstChild("HumanoidRootPart")
        if h and h.Health>0 and r then
            table.insert(out,{kind="Boss",model=model,root=r,hum=h,pos=r.Position})
        end
    end
    return out
end
local function canDamage(victim)
    return os.clock()>=(victim:GetAttribute("SafeUntil") or 0) and os.clock()>=(victim:GetAttribute("DodgeUntil") or 0)
end
local function stunTarget(t,duration)
    duration=math.clamp(duration,.1,2)
    local untilTime=os.clock()+duration
    if (t.kind=="Bot" or t.kind=="Boss") and t.model then
        t.model:SetAttribute("BotFrozenUntil",math.max(untilTime,t.model:GetAttribute("BotFrozenUntil") or 0))
    elseif t.kind=="Player" and t.hum and t.player then
        local player=t.player
        local maxUntil=math.max(untilTime,player:GetAttribute("StunnedUntil") or 0)
        player:SetAttribute("StunnedUntil",maxUntil)
        t.hum.WalkSpeed=0
        t.hum.JumpPower=0
        task.delay(duration+.03,function()
            if t.hum.Parent and os.clock()>=(player:GetAttribute("StunnedUntil") or 0) then
                t.hum.WalkSpeed=18
                t.hum.JumpPower=52
            end
        end)
    end
end
local function tugTarget(t,origin,pullSpeed)
    if t.kind~="Bot" and t.kind~="Player" then return end
    if not t.root or not t.root.Parent then return end
    local diff=origin-t.root.Position
    local flat=Vector3.new(diff.X,0,diff.Z)
    if flat.Magnitude>3 then
        t.root.AssemblyLinearVelocity=flat.Unit*math.clamp(pullSpeed,20,88)+Vector3.new(0,7,0)
    end
end
local function damage(attacker,t,amount,knock,origin,slow)
    if t.kind=="Player" then
        if not canDamage(t.player) or not t.hum or t.hum.Health<=0 then return false end
        local before=t.hum.Health
        lastHit[t.player]={player=attacker,at=os.clock()}
        t.player:SetAttribute("LastCombatAt",os.clock())
        attacker:SetAttribute("LastCombatAt",os.clock())
        t.hum:TakeDamage(amount)
        if knock and knock>0 then
            local v=t.root.Position-origin
            v=Vector3.new(v.X,0,v.Z)
            if v.Magnitude>.1 then t.root.AssemblyLinearVelocity=v.Unit*knock+Vector3.new(0,8,0) end
        end
        if slow then
            local hum=t.hum
            hum.WalkSpeed=9
            local finish=os.clock()+slow
            t.player:SetAttribute("SlowedUntil",finish)
            task.delay(slow,function()
                if hum.Parent and t.player:GetAttribute("SlowedUntil")==finish then hum.WalkSpeed=18 end
            end)
        end
        if before>0 and t.hum.Health<=0 then
            local tag=lastHit[t.player]
            if tag and tag.player==attacker and tag.at>os.clock()-2 then setKO(attacker) end
            lastHit[t.player]=nil
        end
    elseif t.kind=="Bot" or t.kind=="Boss" then
        if not t.hum or t.hum.Health<=0 or (t.kind=="Bot" and os.clock()<(t.model:GetAttribute("BotDodgeUntil") or 0)) then return false end
        if t.kind=="Boss" and t.model:GetAttribute("BossInvulnerable")==true then return false end
        attacker:SetAttribute("LastCombatAt",os.clock())
        t.hum:SetAttribute("PlayerHitAt",os.clock())
        t.hum:SetAttribute("LastAttackerId",attacker.UserId)
        if t.kind=="Boss" and t.model:GetAttribute("BossPhase")==1 and amount>=t.hum.Health then
            -- Phase one cannot enter Humanoid.Died: its first fatal strike triggers
            -- a single cinematic revival; the second phase dies normally.
            t.model:SetAttribute("BossInvulnerable",true)
            amount=math.max(0,t.hum.Health-1) -- report actual damage dealt, not massive overkill
            t.hum.Health=1
            t.model:SetAttribute("ReviveTrigger",Workspace:GetServerTimeNow())
            notify(attacker,"Message","COLOSSUS FALLS... SECOND WIND AWAKENING!")
        else
            t.hum:TakeDamage(amount)
        end
        if t.kind=="Bot" and knock and knock>0 then
            local delta=t.root.Position-origin
            local flat=Vector3.new(delta.X,0,delta.Z)
            if flat.Magnitude>.1 then
                t.root.AssemblyLinearVelocity=flat.Unit*math.min(38,knock)+Vector3.new(0,6,0)
            end
        end
    else
        local hp=dummyHealth[t.model]
        if not hp or hp<=0 then return false end
        hp=math.max(0,hp-amount)
        dummyHealth[t.model]=hp
        t.model:SetAttribute("HP",hp)
        if hp==0 then
            addCoins(attacker,Config.BotReward)
            notify(attacker,"Message","DUMMY DOWN! +"..Config.BotReward.." coins")
            local core=t.model:FindFirstChild("Core")
            if core then core.Transparency=.75 end
            task.delay(3.5,function()
                if t.model.Parent then
                    dummyHealth[t.model]=100
                    t.model:SetAttribute("HP",100)
                    if core then core.Transparency=0 end
                end
            end)
        end
    end
    notify(attacker,"Hit","-"..math.floor(amount),{amount=math.floor(amount),position=t.pos,kind=t.kind,heavy=(attacker.Character and attacker.Character:GetAttribute("WhipMotion")=="Heavy") or false})
    if t.pos then
        local impactKey=t.player or t.model
        local now=os.clock()
        if impactKey and now-(impactAt[impactKey] or -10)>.10 then
            impactAt[impactKey]=now
            local impactDir=t.pos-origin
            if impactDir.Magnitude<.2 then impactDir=Vector3.new(0,0,-1) end
            local whip=Whips[attacker:GetAttribute("SelectedWhip") or "Rope"] or Whips.Rope
            broadcastAction(t.pos,"Impact",impactDir.Unit,whip.Color,1,nil,attacker.UserId)
        end
    end
    return true
end
-- Each freshly cloned arena receives its own HP labels; retired dummies are discarded.
local function setupDummies(active)
    local practice=active and active:FindFirstChild("PracticeTargets")
    if not practice then return end
    for _,model in ipairs(practice:GetChildren()) do
        if model:IsA("Model") then
            dummyHealth[model]=100
            model:SetAttribute("HP",100)
            local core=model:FindFirstChild("Core")
            if core then
                local tag=Instance.new("BillboardGui")
                tag.Name="TargetHP"; tag.Size=UDim2.fromOffset(120,30)
                tag.StudsOffsetWorldSpace=Vector3.new(0,5,0); tag.AlwaysOnTop=true
                tag.Parent=core
                local txt=Instance.new("TextLabel")
                txt.BackgroundTransparency=1; txt.Size=UDim2.fromScale(1,1)
                txt.Font=Enum.Font.GothamBold; txt.TextScaled=true
                txt.TextStrokeTransparency=.2; txt.TextColor3=Color3.fromRGB(255,229,192)
                txt.Parent=tag
                local function update()
                    txt.Text="TRAINING  "..tostring(model:GetAttribute("HP") or 100).." HP"
                end
                model:GetAttributeChangedSignal("HP"):Connect(update)
                update()
            end
        end
    end
end
Workspace.ChildAdded:Connect(function(child)
    if child.Name=="LashboundBattleArena" then setupDummies(child) end
end)
setupDummies(Workspace:FindFirstChild("LashboundBattleArena"))
local function targetsInCone(player,root,dir,range,dot,minY)
    local result={}
    for _,t in ipairs(allTargets(player)) do
        local delta=t.pos-root.Position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude>1 and flat.Magnitude<=range and math.abs(delta.Y)<(minY or 14) and flat.Unit:Dot(dir)>=dot then
            table.insert(result,{t=t,dist=flat.Magnitude})
        end
    end
    table.sort(result,function(a,b)return a.dist<b.dist end)
    return result
end
-- V26: server-authoritative 100-link swept lash contacts.  Damage is never
-- granted merely for being inside a camera-facing cone; the modeled lash must
-- sweep across the target's collision envelope while the hit is active.
-- All link positions are deterministic functions of the attack timeline.
local function pointSegmentDistance(point,a,b)
    local delta=b-a
    local len2=delta:Dot(delta)
    if len2<.0001 then return (point-a).Magnitude end
    local t=math.clamp((point-a):Dot(delta)/len2,0,1)
    return (point-(a+delta*t)).Magnitude
end
local function lashPosition(base,dir,range,step,seconds,f,heavy)
    local snap=heavy and .33 or .29
    local launch=math.clamp((seconds-.055)/(snap-.055),0,1)
    local recoil=math.clamp((seconds-(snap+.075))/.33,0,1)
    local delayed=math.clamp((launch-.16*f)/(1-.16*f),0,1)
    local smooth=delayed*delayed*(3-2*delayed)
    local extend=(1.6+(range-1.6)*smooth)*f*(1-recoil*.83)
    local curl=(1-smooth)*(2.6+f*5.0)*math.sin(f*math.pi*.86)
    local coiledBack=(1-smooth)*f*4.3
    local wave=math.sin(3*f*math.pi-launch*math.pi*1.8)*(.82-smooth*.5)
    local polarity=step==2 and -1 or 1
    local side=Vector3.new(-dir.Z,0,dir.X)
    local sideOffset=polarity*(curl+wave)*math.sin(f*math.pi*.99)
    local lift=(1-smooth)*math.sin(f*math.pi)*3.7+f*.6
    return base+dir*(extend-coiledBack)+side*sideOffset+Vector3.new(0,lift,0)
end
local function lashContacts(player,root,character,dir,reach,step,heavy,maxHits)
    local targets=allTargets(player)
    local result={}
    local start=root.Position+Vector3.new(0,2.35,0)
    local block=RaycastParams.new()
    block.FilterType=Enum.RaycastFilterType.Exclude
    block.FilterDescendantsInstances={character}
    block.RespectCanCollide=true
    for _,target in ipairs(targets) do
        if #result>=maxHits then break end
        local t=target
        local targetRoot=t.root
        if targetRoot and targetRoot.Parent then
            local point=targetRoot.Position+Vector3.new(0,math.min(4.2,math.max(1.4,targetRoot.Size.Y*.6)),0)
            local radial=Vector3.new(point.X-start.X,0,point.Z-start.Z)
            if radial.Magnitude<=reach+5 and math.abs(point.Y-start.Y)<17 then
                local radius=math.clamp(math.max(targetRoot.Size.X,targetRoot.Size.Z)*.62+1.5,2.4,6.8)
                local touched=false
                local frames=heavy and { .15,.19,.23,.27,.30,.33,.36 } or {.13,.16,.19,.22,.25,.27,.29,.31}
                local old=nil
                for _,clock in ipairs(frames) do
                    local base=lashPosition(start,dir,reach,step,clock,0,heavy)
                    local previous=base
                    for joint=1,48 do
                        local pointOnLash=lashPosition(start,dir,reach,step,clock,joint/48,heavy)
                        if pointSegmentDistance(point,previous,pointOnLash)<=radius
                            or (old and old[joint] and pointSegmentDistance(point,old[joint],pointOnLash)<=radius) then
                            touched=true
                            break
                        end
                        previous=pointOnLash
                    end
                    if touched then break end
                    old=old or {}
                    for joint=1,48 do old[joint]=lashPosition(start,dir,reach,step,clock,joint/48,heavy) end
                end
                if touched then
                    local ray=Workspace:Raycast(start,point-start,block)
                    local victimModel=t.model or (t.player and t.player.Character)
                    if not ray or (victimModel and ray.Instance:IsDescendantOf(victimModel)) then
                        table.insert(result,{t=t,dist=radial.Magnitude})
                    end
                end
            end
        end
    end
    return result
end

local function melee(player,root,character,dir,step)
    local attackSerial=(character:GetAttribute("LashAttackSerial") or 0)+1
    character:SetAttribute("LashAttackSerial",attackSerial)
    local timeline=AttackTimeline.begin(.29,.11,.30)
    local serverStart=timeline.startedAt
    local cfg=Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Whips.Rope
    markWhipMotion(character,"Attack",step,step==3 and .85 or .7)
    swingModel(character,step,"Attack")
    local visualRange=cfg.Range*(step==3 and 1.1 or 1)
    local hitDot=(step==3 and .45 or .66)
    broadcastAction(root.Position,"Attack",dir,cfg.Color,step,player:GetAttribute("SelectedWhip"),player.UserId,
        {shape="sweptLash",range=visualRange,impactAt=timeline.impactAt-serverStart,duration=timeline.endsAt-serverStart},serverStart)
    player:SetAttribute("WhipWindupAt", os.clock())
    player:SetAttribute("LastCombatAt",os.clock())
    player:SetAttribute("WhipAim", dir)
    local range=cfg.Range*(step==3 and 1.1 or 1)
    local center=root.Position+Vector3.new(0,2,0)
    fxLine(center,center+dir*(range*.83),cfg.Color,step==3 and .38 or .22)
    -- Impact lands after the visible wind-up; Sentinels and players can react.
    task.spawn(function()
        if not AttackTimeline.waitUntil(timeline.impactAt,function()
            return player.Parent==Players and root.Parent~=nil and player.Character==character
                and character:GetAttribute("LashAttackSerial")==attackSerial and isArena(player)
        end) then return end
        if player.Parent~=Players or not root.Parent or player.Character~=character
           or character:GetAttribute("LashAttackSerial")~=attackSerial
           or not isArena(player) then return end
        if os.clock()<(player:GetAttribute("StunnedUntil") or 0) then return end
        local hits=lashContacts(player,root,character,dir,range,step,false,step==3 and 3 or 1)
        local legendary=(player:GetAttribute("SelectedWhip")=="Legend")
        local count=0
        for _,entry in ipairs(hits) do
            if count>=(step==3 and 3 or 1) then break end
            if damage(player,entry.t,math.floor(cfg.Damage*({.88,1.08,1.68})[step]),
                legendary and (step==3 and 100 or 0) or (step==3 and 58 or 24),root.Position) then
                if legendary then
                    if step<3 then
                        tugTarget(entry.t,root.Position+dir*4,55)
                        stunTarget(entry.t,.42)
                    else
                        broadcastAction(entry.t.pos,"PowerPulse",dir,cfg.Color,3,"Legend",player.UserId)
                    end
                end
                count+=1
            end
        end
        notify(player,"Attack",tostring(step),{step=step,hit=count>0})
    end)
end

local function heavyStrike(player,root,character,dir)
    local attackSerial=(character:GetAttribute("LashAttackSerial") or 0)+1
    character:SetAttribute("LashAttackSerial",attackSerial)
    local serverStart=Workspace:GetServerTimeNow()
    local cfg=Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Whips.Rope
    markWhipMotion(character,"Heavy",4,.9)
    swingModel(character,4,"Heavy")
    broadcastAction(root.Position,"Heavy",dir,cfg.Color,4,player:GetAttribute("SelectedWhip"),player.UserId,
        {shape="sweptLash",range=cfg.Range*1.21,impactAt=.33,duration=.44},serverStart)
    player:SetAttribute("WhipWindupAt",os.clock())
    player:SetAttribute("LastCombatAt",os.clock())
    player:SetAttribute("WhipAim",dir)
    task.delay(.33,function()
        if not root.Parent or player.Parent~=Players or player.Character~=character
           or character:GetAttribute("LashAttackSerial")~=attackSerial or not isArena(player)
           or os.clock()<(player:GetAttribute("StunnedUntil") or 0) then return end
        local hits=lashContacts(player,root,character,dir,cfg.Range*1.21,4,true,3)
        local count=0
        for _,entry in ipairs(hits) do
            if count>=3 then break end
            if damage(player,entry.t,math.floor(cfg.Damage*2.65),85,root.Position,.55) then
                count+=1
            end
        end
        broadcastAction(root.Position+dir*10,"PowerPulse",dir,cfg.Color,4,"Heavy",player.UserId)
        notify(player,"Attack",count>0 and "HEAVY CONNECTED" or "HEAVY MISSED",{step=4,hit=count>0})
    end)
end

local function statusTarget(t,kind,duration,attacker)
    if not t or not t.hum or t.hum.Health<=0 then return end
    local model=t.kind=="Player" and t.player and t.player.Character or t.model
    if model and t.kind~="Boss" then
        ApplyStatus:Fire(model,kind,duration,attacker.UserId)
    end
end

-- One server-authoritative mirrored companion per player. This clone carries
-- appearance only: scripts are removed, it cannot grant coins or attack itself.
local mirrorCompanions={}
local function destroyMirrorCompanion(player)
    local item=mirrorCompanions[player]
    mirrorCompanions[player]=nil
    if item and item.Parent then item:Destroy() end
end
local function summonMirrorCompanion(player,character,cfg)
    destroyMirrorCompanion(player)
    if player.Parent~=Players or not isArena(player) or not character.Parent then return end
    local wasArchivable=character.Archivable
    character.Archivable=true
    local ok,clone=pcall(function() return character:Clone() end)
    character.Archivable=wasArchivable
    if not ok or not clone then return end
    clone.Name="MirrorCompanion_"..player.UserId
    clone:SetAttribute("LashboundMirroredCompanion",true)
    for _,object in ipairs(clone:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")
            or object:IsA("ProximityPrompt") then
            object:Destroy()
        elseif object:IsA("BasePart") then
            object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
            object.Massless=true
        end
    end
    local cloneRoot=clone:FindFirstChild("HumanoidRootPart")
    local h=clone:FindFirstChildOfClass("Humanoid")
    if not cloneRoot or not h then clone:Destroy();return end
    cloneRoot.Anchored=true
    h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    local shine=Instance.new("Highlight")
    shine.Name="MirrorAura";shine.FillColor=cfg.Color
    shine.OutlineColor=Color3.fromRGB(215,255,251)
    shine.FillTransparency=.70;shine.OutlineTransparency=.19
    shine.DepthMode=Enum.HighlightDepthMode.Occluded
    shine.Parent=clone
    local active=Workspace:FindFirstChild("LashboundBattleArena")
    if not active then clone:Destroy();return end
    local group=active:FindFirstChild("LashboundCompanions")
    if not group then group=Instance.new("Folder");group.Name="LashboundCompanions";group.Parent=active end
    clone.Parent=group
    mirrorCompanions[player]=clone
    local original=character:FindFirstChild("HumanoidRootPart")
    if not original then destroyMirrorCompanion(player);return end
    local rootAt=original.Position
    clone:PivotTo(CFrame.lookAt(rootAt+original.CFrame.RightVector*5,rootAt+original.CFrame.RightVector*5+original.CFrame.LookVector))
    local shoulder=nil
    for _,item in ipairs(clone:GetDescendants()) do
        if item:IsA("Motor6D") and (item.Name=="RightShoulder" or item.Name=="Right Shoulder") then shoulder=item;break end
    end
    local originalC0=shoulder and shoulder.C0
    local expire=os.clock()+22
    local nextStrike=os.clock()+.55
    local lastAt=os.clock()
    task.spawn(function()
        while mirrorCompanions[player]==clone and clone.Parent and player.Parent==Players
            and os.clock()<expire and isArena(player) do
            local now=os.clock()
            local dt=math.min(.2,now-lastAt);lastAt=now
            local realChar,realHum,realRoot=charInfo(player)
            if not realChar or realHum.Health<=0 or not realRoot or realChar~=character then break end
            local goal=realRoot.Position-realRoot.CFrame.RightVector*5-realRoot.CFrame.LookVector*6
            local chosen,best=nil,math.huge
            for _,t in ipairs(allTargets(player)) do
                if t.root and t.root.Parent and t.hum and t.hum.Health>0 then
                    local fromOwner=(t.pos-realRoot.Position).Magnitude
                    local fromMirror=(t.pos-cloneRoot.Position).Magnitude
                    if fromOwner<57 and fromMirror<best then chosen=t;best=fromMirror end
                end
            end
            if chosen and best<45 then
                local away=cloneRoot.Position-chosen.pos
                if away.Magnitude>.1 then goal=chosen.pos+away.Unit*9 else goal=chosen.pos+realRoot.CFrame.RightVector*9 end
            end
            local nowPos=cloneRoot.Position
            local delta=Vector3.new(goal.X-nowPos.X,0,goal.Z-nowPos.Z)
            local step=delta.Magnitude>0 and math.min(delta.Magnitude,30*dt) or 0
            local nextPos=nowPos+(step>0 and delta.Unit*step or Vector3.zero)
            local facing=chosen and (chosen.pos-nextPos) or realRoot.CFrame.LookVector
            local flat=Vector3.new(facing.X,0,facing.Z)
            if flat.Magnitude<.05 then flat=Vector3.new(0,0,-1) end
            local facingFrame=CFrame.lookAt(nextPos,nextPos+flat.Unit)
            if (nextPos-realRoot.Position).Magnitude>88 then
                nextPos=realRoot.Position-realRoot.CFrame.RightVector*5
                facingFrame=CFrame.lookAt(nextPos,nextPos+flat.Unit)
            end
            clone:PivotTo(facingFrame)
            if chosen and best<19 and now>=nextStrike then
                nextStrike=now+.91
                local victim=chosen
                local impactDir=Vector3.new(victim.pos.X-nextPos.X,0,victim.pos.Z-nextPos.Z)
                if impactDir.Magnitude>.05 then
                    broadcastAction(nextPos,"Attack",impactDir.Unit,cfg.Color,1,"Echo",0)
                    if shoulder then
                        TweenService:Create(shoulder,TweenInfo.new(.13,Enum.EasingStyle.Quad),{
                            C0=originalC0*CFrame.Angles(math.rad(-48),math.rad(30),math.rad(26))}):Play()
                    end
                    task.delay(.22,function()
                        if mirrorCompanions[player]~=clone or not clone.Parent or not victim.root or not victim.root.Parent then return end
                        if (victim.root.Position-cloneRoot.Position).Magnitude<=20 and victim.hum and victim.hum.Health>0 then
                            local amount=math.max(1,math.floor(cfg.Damage*.25+.5))
                            damage(player,victim,amount,7,cloneRoot.Position)
                        end
                        if shoulder and shoulder.Parent then
                            TweenService:Create(shoulder,TweenInfo.new(.19,Enum.EasingStyle.Quad),{C0=originalC0}):Play()
                        end
                    end)
                end
            end
            task.wait(.10)
        end
        if mirrorCompanions[player]==clone then destroyMirrorCompanion(player) end
    end)
end
Players.PlayerRemoving:Connect(destroyMirrorCompanion)
-- Specials intentionally change combat rules; none are just stronger basic attacks.
-- No unlimited loops, server-side authority for damage and cooldowns.
local function power(player,root,character,dir)
    local id=player:GetAttribute("SelectedWhip") or "Rope"
    local cfg=Whips[id] or Whips.Rope
    player:SetAttribute("WhipWindupAt",os.clock())
    player:SetAttribute("LastCombatAt",os.clock())
    player:SetAttribute("WhipAim",dir)
    markWhipMotion(character,"Power",3,.65)
    swingModel(character,3,"Power",id)
    local powerBox=nil
    if id=="Rope" then
        powerBox={shape="lane",range=33,halfWidth=8,duration=.53}
    elseif id=="Ember" then
        powerBox={shape="ring",radius=23,duration=.56}
    elseif id=="Frost" then
        powerBox={shape="cone",range=38,dot=.72,duration=.54}
    elseif id=="Volt" then
        powerBox={shape="ring",radius=37,duration=.54}
    elseif id=="Gravity" then
        powerBox={shape="ring",centerOffset=19,radius=25,duration=1.83}
    elseif id=="Legend" then
        powerBox={shape="cone",range=48,dot=.57,duration=.57}
    elseif id=="Phantom" then
        powerBox={shape="cone",range=34,dot=.33,duration=.48}
    elseif id=="Judgement" then
        powerBox={shape="cone",range=30,dot=.62,duration=.63}
    elseif id=="Echo" then
        powerBox={shape="ring",radius=12,duration=.55}
    end
    broadcastAction(root.Position,"Power",dir,cfg.Color,3,id,player.UserId,powerBox)
    -- Commit the ability on the same synchronized whip-tip snap as the client.
    -- The marker/pose is the 0.37s windup, not premature damage.
    task.delay(.37,function()
        if player.Parent~=Players or not root.Parent or not isArena(player)
            or os.clock()<(player:GetAttribute("StunnedUntil") or 0) then return end
        local all=allTargets(player)
        if id=="Rope" then
        -- Slingline: rushing knockback and a second tug that drags opponents behind you.
        local start=root.Position
        local driveAttachment=Instance.new("Attachment")
        driveAttachment.Name="SlinglineDrive";driveAttachment.Parent=root
        local drive=Instance.new("LinearVelocity")
        drive.Name="SlinglineVelocity"
        drive.Attachment0=driveAttachment
        drive.RelativeTo=Enum.ActuatorRelativeTo.World
        drive.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
        drive.VectorVelocity=dir*76+Vector3.new(0,5,0)
        drive.ForceLimitsEnabled=false
        drive.Parent=root
        Debris:AddItem(drive,.29);Debris:AddItem(driveAttachment,.34)
        root.AssemblyLinearVelocity=dir*76+Vector3.new(0,7,0)
        for _,t in ipairs(all) do
            local delta=t.pos-start
            local flat=Vector3.new(delta.X,0,delta.Z)
            local along=flat:Dot(dir)
            if along>0 and along<33 and (flat-dir*along).Magnitude<8 then
                if damage(player,t,20,20,start) and t.root and t.root:IsA("BasePart") then
                    local away=start+dir*6-t.root.Position
                    local pull=Vector3.new(away.X,0,away.Z)
                    if pull.Magnitude>1 then
                        t.root.AssemblyLinearVelocity=pull.Unit*52+Vector3.new(0,11,0)
                    end
                end
            end
        end
    elseif id=="Ember" then
        -- Firestorm: three delayed burn waves linger at the cast point.
        local origin=root.Position
        for pulse=1,3 do
            task.delay((pulse-1)*.48,function()
                if player.Parent~=Players then return end
                broadcastAction(origin,"PowerPulse",dir,cfg.Color,pulse,"Ember",player.UserId,{shape="ring",radius=21+pulse*2,duration=.43})
                for _,t in ipairs(allTargets(player)) do
                    if (t.pos-origin).Magnitude<21+pulse*2 then
                        if damage(player,t,pulse==1 and 12 or 8,pulse==3 and 22 or 5,origin) then
                            statusTarget(t,"Burn",3.6,player)
                        end
                    end
                end
            end)
        end
    elseif id=="Frost" then
        -- Glacier lance: narrow forward cone with hard stop followed by a slow.
        local epicenter=root.Position+dir*16
        for _,t in ipairs(all) do
            local delta=t.pos-root.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            if flat.Magnitude<38 and flat.Magnitude>1 and flat.Unit:Dot(dir)>.72 then
                local ok=damage(player,t,20,7,epicenter,2.6)
                if ok then statusTarget(t,"Freeze",2.3,player) end
                if ok and t.kind=="Bot" then
                    t.model:SetAttribute("BotFrozenUntil",os.clock()+2.8)
                elseif ok and t.kind=="Player" then
                    local hum=t.hum
                    local endAt=os.clock()+.65
                    t.player:SetAttribute("FreezeUntil",endAt)
                    hum.WalkSpeed=0
                    task.delay(.65,function()
                        if hum.Parent and t.player:GetAttribute("FreezeUntil")==endAt then hum.WalkSpeed=9 end
                    end)
                end
            end
        end
    elseif id=="Volt" then
        -- Chain storm: lightning hops to several nearby fighters, not a frontal sweep.
        local remaining=allTargets(player)
        local at=root.Position
        for hop=1,math.min(5,#remaining) do
            local best,dist,index=nil,math.huge,nil
            for i,t in ipairs(remaining) do
                local d=(t.pos-at).Magnitude
                if d<dist and d<(hop==1 and 37 or 25) then best,dist,index=t,d,i end
            end
            if not best then break end
            table.remove(remaining,index)
            fxLine(at+Vector3.new(0,2,0),best.pos+Vector3.new(0,2,0),cfg.Color,.55)
            if damage(player,best,math.max(10,27-hop*3),7,at,best.kind=="Player" and .65 or nil) then
                statusTarget(best,"Shock",.95,player)
            end
            if best.kind=="Bot" then best.model:SetAttribute("BotFrozenUntil",os.clock()+.65) end
            at=best.pos
        end
    elseif id=="Gravity" then
        -- Gravity well: persistent pull for 1.8 seconds, then a damaging implosion.
        local center=root.Position+dir*19
        for tickNo=1,5 do
            task.delay((tickNo-1)*.36,function()
                if player.Parent~=Players then return end
                broadcastAction(center,"PowerPulse",dir,cfg.Color,tickNo,"Gravity",player.UserId,{shape="ring",radius=tickNo==5 and 22 or 25,duration=.41})
                for _,t in ipairs(allTargets(player)) do
                    local displacement=center-t.pos
                    local flat=Vector3.new(displacement.X,0,displacement.Z)
                    if flat.Magnitude>2 and flat.Magnitude<25 then
                        if t.kind=="Player" and canDamage(t.player) or t.kind=="Bot" and os.clock()>=(t.model:GetAttribute("BotDodgeUntil") or 0) then
                            t.root.AssemblyLinearVelocity=flat.Unit*(tickNo==5 and 65 or 38)+Vector3.new(0,8,0)
                        end
                    end
                    if tickNo==5 and flat.Magnitude<22 then
                        if damage(player,t,30,45,center) then statusTarget(t,"Slow",3.8,player) end
                    end
                end
            end)
        end
    elseif id=="Legend" then
        -- ROYAL BIND: a true grapple, not a reskinned line attack. Nearest forward target
        -- within 48 studs is yanked toward the caster, immobilized briefly, then comboable.
        local opts=targetsInCone(player,root,dir,48,.57)
        local selected=opts[1] and opts[1].t
        if selected then
            if damage(player,selected,22,0,root.Position) then
                tugTarget(selected,root.Position+dir*5,82)
                stunTarget(selected,1.15)
                statusTarget(selected,"Slow",1.45,player)
                fxLine(root.Position+Vector3.new(0,2.2,0),selected.pos+Vector3.new(0,2,0),cfg.Color,.8)
                broadcastAction(selected.pos,"PowerPulse",dir,cfg.Color,1,"Legend",player.UserId)
            end
        else
            notify(player,"Message","ROYAL BIND: aim at an enemy within 48 studs")
        end
    elseif id=="Judgement" then
        -- THUNDER VERDICT: one visible lock, loft, and delayed vertical lightning.
        -- Bosses resist instant death; targets may dodge out of the marked strike.
        local opts=targetsInCone(player,root,dir,30,.62,20)
        local chosen=nil
        for _,entry in ipairs(opts) do
            local t=entry.t
            if (t.kind~="Player" or canDamage(t.player))
                and (t.kind~="Bot" or os.clock()>=(t.model:GetAttribute("BotDodgeUntil") or 0)) then
            local castOrigin=root.Position+Vector3.new(0,2,0)
            local towards=t.pos+Vector3.new(0,2,0)-castOrigin
            local rayParams=RaycastParams.new()
            rayParams.FilterType=Enum.RaycastFilterType.Exclude
            local ignored={character}
            if t.model then table.insert(ignored,t.model) end
            if t.player and t.player.Character then table.insert(ignored,t.player.Character) end
            rayParams.FilterDescendantsInstances=ignored
            rayParams.RespectCanCollide=true
            if not Workspace:Raycast(castOrigin,towards,rayParams) then chosen=t;break end
            end
        end
        if not chosen then
            notify(player,"Message","THUNDER VERDICT: target a visible foe within 30 studs")
        else
            local t=chosen
            local victimModel=t.model or (t.player and t.player.Character)
            local targetRoot=t.root
            local initial=targetRoot.Position
            statusTarget(t,"Shock",1.35,player)
            if t.kind=="Bot" and t.model and t.model:GetAttribute("LashboundDog") then
                local timestamp=os.clock()
                t.model:SetAttribute("JudgementLiftStart",timestamp)
                t.model:SetAttribute("JudgementLiftUntil",timestamp+.86)
            end
            broadcastAction(initial,"JudgementLock",dir,cfg.Color,1,"Judgement",player.UserId,
                {duration=1.05})
            if t.kind~="Boss" and not targetRoot.Anchored then
                targetRoot.AssemblyLinearVelocity=Vector3.new(0,58,0)
            end
            task.delay(.86,function()
                if player.Parent~=Players or not isArena(player) or not targetRoot.Parent
                    or not t.hum or t.hum.Health<=0 then return end
                local hitPlace=targetRoot.Position
                broadcastAction(hitPlace,"JudgementStrike",dir,cfg.Color,1,"Judgement",player.UserId)
                -- Dodge/protection is checked by the normal server-authoritative damage function.
                local amount=t.kind=="Boss" and 120 or t.hum.Health+10
                if damage(player,t,amount,0,root.Position) then
                    if t.kind=="Boss" then statusTarget(t,"Shock",.65,player) end
                end
            end)
        end
    elseif id=="Echo" then
        summonMirrorCompanion(player,character,cfg)
        broadcastAction(root.Position,"PowerPulse",dir,cfg.Color,1,"Echo",player.UserId,{shape="ring",radius=12,duration=.75})
    elseif id=="Phantom" then
        -- Shadowstep: blink BEHIND one enemy and follow with a delayed ambush.
        local targets=targetsInCone(player,root,dir,34,.33)
        local chosen=targets[1] and targets[1].t
        local start=root.Position
        local destination=chosen and (chosen.pos-dir*5) or (start+dir*20)
        -- Every map is centered on z=-620 in the V7/V8 layout.
        destination=Vector3.new(math.clamp(destination.X,-210,210),5,math.clamp(destination.Z,-830,-410))
        character:PivotTo(CFrame.lookAt(destination,destination+dir))
        root.AssemblyLinearVelocity=Vector3.zero
        if chosen then
            task.delay(.22,function()
                if player.Parent==Players and chosen.root.Parent and (chosen.root.Position-root.Position).Magnitude<20 then
                    if damage(player,chosen,35,49,root.Position) then
                        statusTarget(chosen,"Poison",4.2,player)
                    end
                    broadcastAction(root.Position,"PowerPulse",dir,cfg.Color,2,"Phantom",player.UserId)
                end
            end)
        end
    end
    end)
    notify(player,"Power",cfg.PowerName,{cooldown=cfg.PowerCooldown})
end
-- Reliable dodge: short-lived server-controlled LinearVelocity constraint, rather
-- than a single velocity assignment that Humanoid movement may immediately erase.
-- V12 dodge: sweep a body-sized shape and use Roblox physics to respect walls.
-- Never PivotTo during a dodge: teleporting parts across walls caused clipping.
local function executeDodge(player,character,humanoid,root,requested)
    local v=typeof(requested)=="Vector3" and Vector3.new(requested.X,0,requested.Z) or Vector3.zero
    if v.Magnitude<.15 or v.Magnitude>100 or v.X~=v.X or v.Z~=v.Z then
        local f=root.CFrame.LookVector
        v=Vector3.new(f.X,0,f.Z)
    end
    if v.Magnitude<.1 then v=Vector3.new(0,0,-1) end
    local direction=v.Unit
    local token=(player:GetAttribute("DodgeToken") or 0)+1
    player:SetAttribute("DodgeToken",token)
    animateBody(character,"Dodge",1)
    local whip=Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Whips.Rope
    broadcastAction(root.Position,"Dodge",direction,whip.Color,1,nil,player.UserId)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character,fxFolder}
    params.IgnoreWater=true
    params.RespectCanCollide=true -- ignore noncolliding map embellishments
    local intended=12.5
    local width=Vector3.new(3.1,4.5,3.1)
    local function clearance(distance)
        local hit=Workspace:Blockcast(CFrame.new(root.Position),width,direction*distance,params)
        if hit then return math.max(0,hit.Distance-1.2) end
        return distance
    end
    local travel=clearance(intended)
    if travel<.55 then return end
    local duration=.24
    local attachment=Instance.new("Attachment")
    attachment.Name="LashboundDodgeAnchor"
    attachment.Parent=root
    local dash=Instance.new("LinearVelocity")
    dash.Name="LashboundWallSafeDash"
    dash.Attachment0=attachment
    dash.RelativeTo=Enum.ActuatorRelativeTo.World
    dash.MaxForce=60000
    dash.VectorVelocity=direction*(travel/duration)
    dash.Parent=root
    task.spawn(function()
        local started=os.clock()
        while os.clock()-started<duration do
            if not root.Parent or humanoid.Health<=0 or player:GetAttribute("DodgeToken")~=token then break end
            if clearance(2.65)<.35 then break end
            task.wait(.035)
        end
        if dash.Parent then dash:Destroy() end
        if attachment.Parent then attachment:Destroy() end
        -- The Humanoid's native collision solver remains active throughout.
    end)
end

-- All shop actions return an explicit result to the open UI. The server remains
-- authoritative for coins, purchases, ownership and equipped slot.
local function sendShopState(player)
    local d=data[player]
    if not d then return end
    local owned={}
    for _,id in ipairs(Config.Order) do owned[id]=d.Owned[id]==true end
    notify(player,"ShopState","SHOP READY",{coins=d.Coins,selected=d.Selected,owned=owned,loading=not d.Loaded})
end
local function shopResult(player,message,success)
    sendShopState(player)
    notify(player,"ShopResult",message,{success=success==true})
end
local function buyOrEquip(player,id)
    local d=data[player]
    if not d or typeof(id)~="string" or not Whips[id] then
        shopResult(player,"That whip isn't available.",false); return
    end
    if not d.Loaded then
        shopResult(player,"Coins and ownership are still loading. Try again in a moment.",false); return
    end
    if not isArena(player) and player:GetAttribute("Zone")~="Lobby" then
        shopResult(player,"Enter the lobby before using the shop.",false); return
    end
    if isArena(player) then shopResult(player,"Shop purchases are lobby-only.",false); return end
    local cfg=Whips[id]
    -- Owner-only weapons must NEVER be bought or equipped through this remote.
    if cfg.OwnerOnly then shopResult(player,"Owner-only weapon: cannot be purchased.",false);return end
    if cfg.Legendary and not d.Owned[id] then
        shopResult(player,"Sovereign's Grasp is wheel-only (1% chance).",false)
        return
    end
    if not d.Owned[id] then
        if d.Coins<cfg.Price then
            shopResult(player,"Need "..(cfg.Price-d.Coins).." more coins for "..cfg.Name..".",false)
            return
        end
        d.Coins-=cfg.Price
        d.Owned[id]=true
        player:SetAttribute("Coins",d.Coins)
        player:SetAttribute("Owns_"..id,true)
        queueSave(player)
        notify(player,"Message","UNLOCKED: "..cfg.Name)
    end
    d.Selected=id
    player:SetAttribute("RegularWhip",id)
    queueSave(player)
    cooldowns[player]={last=0,light=0,power=0,dodge=0,step=0,comboAt=0}
    equipWeapon(player,true)
    shopResult(player,"PURCHASE / EQUIP CONFIRMED: "..cfg.Name,true)
end

-- PAID-IN-EARNED-COINS WHEEL: server-side RNG, 50/30/14/5/1% = 100%.
-- Deduct exactly 200 earned coins before rolling. No Robux-to-coin sale.
local wheelRNG=Random.new()
local wheelLastRequest={}
local function spinWheel(player)
    local d=data[player]
    if not d then return end
    if not d.Loaded then notify(player,"Message","Progress still loading"); return end
    if player:GetAttribute("Zone")~="Lobby" then notify(player,"Message","Spin only in the lobby"); return end
    if os.clock()<(wheelLastRequest[player] or 0) then return end
    wheelLastRequest[player]=os.clock()+2.8
    if d.Coins<Config.WheelPrice then
        notify(player,"Message","Wheel costs 200 coins. Need "..(Config.WheelPrice-d.Coins).." more.")
        return
    end
    d.Coins-=Config.WheelPrice
    player:SetAttribute("Coins",d.Coins)
    queueSave(player)
    local roll=wheelRNG:NextInteger(1,100)
    local found
    local total=0
    for _,outcome in ipairs(Config.WheelOdds) do
        total+=outcome.Weight
        if roll<=total then found=outcome;break end
    end
    if not found then return end
    local prize=found.Prize
    if found.Legend then
        if d.Owned.Legend then
            addCoins(player,500)
            prize="LEGENDARY DUPLICATE · +500 COINS"
        else
            d.Owned.Legend=true
            d.Selected="Legend"
            player:SetAttribute("Owns_Legend",true)
            player:SetAttribute("RegularWhip","Legend")
            equipWeapon(player,true)
            prize="SOVEREIGN'S GRASP UNLOCKED!"
        end
    else
        addCoins(player,found.Coins)
    end
    queueSave(player)
    notify(player,"SpinResult",prize,{legend=found.Legend==true,roll=roll,coins=d.Coins})
end
local function bindLobbyKiosk(name,feedbackKind)
    local lobby=Workspace:WaitForChild("LashboundLobby",15)
    local kiosk=lobby and lobby:FindFirstChild(name)
    if not kiosk then warn("[Lashbound] Missing lobby kiosk",name);return end
    local prompt=kiosk:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then warn("[Lashbound] Missing prompt",name);return end
    prompt.Triggered:Connect(function(player)
        if player.Parent==Players and player:GetAttribute("Zone")=="Lobby" then
            notify(player,feedbackKind,name)
        end
    end)
end
task.spawn(bindLobbyKiosk,"WhipShopKiosk","OpenShop")
task.spawn(bindLobbyKiosk,"SpinWheelKiosk","OpenWheel")
-- Seven anchored lobby models are previews only; interacting opens the real shop.
-- The Founder showcase has no purchase prompt and never grants its Tool.
task.spawn(function()
    local lobby=Workspace:WaitForChild("LashboundLobby",15)
    local gallery=lobby and lobby:FindFirstChild("LobbyWhipGallery")
    if not gallery then warn("[Lashbound] Lobby gallery missing"); return end
    for _,display in ipairs(gallery:GetChildren()) do
        local plinth=display:FindFirstChild("DisplayStand")
        local prompt=plinth and plinth:FindFirstChild("InspectWhipPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.Triggered:Connect(function(player)
                if player.Parent==Players and player:GetAttribute("Zone")=="Lobby" then
                    notify(player,"OpenShop",display.Name)
                end
            end)
        end
    end
end)

Action.OnServerEvent:Connect(function(player,action,parameter)
    if typeof(action)~="string" then return end
    -- V13 founder strike: permission is set by a SERVER script, never by a client.
    -- There is no gameplay cooldown; a 45 ms safety throttle prevents packet floods.
    if action=="OwnerStrike" then
        -- Double-check the authoritative UserId, not just replicated UI state.
        local authorized=(player.UserId==3122892445)
            or (game.CreatorType==Enum.CreatorType.User and game.CreatorId>0 and player.UserId==game.CreatorId)
        if not authorized or player:GetAttribute("OwnerVerified")~=true
            or player:GetAttribute("SelectedWhip")~="Owner" then return end
        local character,humanoid,root=charInfo(player)
        -- Owner damage is impossible without the actual separately equipped item.
        if not character or not isArena(player) or not character:FindFirstChild("FounderTempest") then return end
        local state=cooldowns[player]
        if not state then return end
        local now=os.clock()
        if now-(state.ownerStrikeAt or -100)<.045 then return end
        state.ownerStrikeAt=now
        local direction=vectorFacing(parameter,root)
        local founder=Whips.Owner
        player:SetAttribute("LastCombatAt",now)
        markWhipMotion(character,"Attack",3,.32)
        swingModel(character,3)
        broadcastAction(root.Position,"Attack",direction,founder.Color,3,"Owner",player.UserId,
            {range=founder.Range,impactAt=.29})
        local landed=0
        local starts=root.Position+Vector3.new(0,2,0)
        for _,entry in ipairs(lashContacts(player,root,character,direction,founder.Range,3,false,8)) do
            if landed>=8 then break end
            if damage(player,entry.t,founder.Damage,45,starts) then
                landed+=1
            end
        end
        notify(player,"OwnerStrike","FOUNDER STRIKE",{hits=landed})
        return
    end
    if action=="Ping" then notify(player,"Pong","COMBAT ONLINE"); return end
    if action=="GetShop" then
        if player:GetAttribute("Zone")=="Lobby" then sendShopState(player) end
        return
    end
    if action=="Shop" then buyOrEquip(player,parameter); return end
    if action=="SpinWheel" then spinWheel(player); return end
    if action=="DevUnlockLegend" then
        if RunService:IsStudio() and player:GetAttribute("Zone")=="Lobby" then
            local d=data[player]
            if d and d.Loaded then
                d.Owned.Legend=true; d.Selected="Legend"
                player:SetAttribute("Owns_Legend",true)
                player:SetAttribute("RegularWhip","Legend")
                queueSave(player)
                equipWeapon(player,true)
                notify(player,"Message","STUDIO TEST: LEGENDARY EQUIPPED")
            end
        end
        return
    end
    if action=="Equip" then equipWeapon(player); return end
    if action=="ChargeStart" then
        local c=cooldowns[player]
        if c and isArena(player) and charInfo(player) and os.clock()>=(c.light or 0)
            and os.clock()>=(player:GetAttribute("StunnedUntil") or 0) then
            c.chargeAt=os.clock()
            player:SetAttribute("HeavyCharging",true)
        end
        return
    end
    if action=="ChargeCancel" then
        local c=cooldowns[player]
        if c then c.chargeAt=nil end
        player:SetAttribute("HeavyCharging",false)
        return
    end
    -- No Return action: the arena has no exit door.
    if action~="Light" and action~="Heavy" and action~="Power" and action~="Dodge" then return end
    if not isArena(player) then
        notify(player,"Message","Enter the arena to attack or dodge")
        return
    end
    local character,hum,root=charInfo(player)
    if not character then return end
    if os.clock()<(player:GetAttribute("StunnedUntil") or 0) then
        local c=cooldowns[player]; if c then c.chargeAt=nil end
        player:SetAttribute("HeavyCharging",false)
        notify(player,"Message","STUNNED! Try again")
        return
    end
    if action~="Dodge" then
        -- Standard powers require the standard physical Tool. The founder item
        -- is handled only by the separate, server-verified OwnerStrike path.
        if not character:FindFirstChild("LashboundWhip")
            or player:GetAttribute("SelectedWhip")=="Owner" then
            if not character:FindFirstChild("FounderTempest") then equipWeapon(player) end
            notify(player,"Message","Equip your regular whip for this attack")
            return
        end
    end
    local c=cooldowns[player]
    if not c then return end
    local now=os.clock()
    if now-c.last<.095 then return end
    c.last=now
    local dir=vectorFacing(parameter,root)
    local cfg=Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Whips.Rope
    if action=="Heavy" then
        local charged=c.chargeAt and (now-c.chargeAt) or 0
        c.chargeAt=nil
        player:SetAttribute("HeavyCharging",false)
        if now<c.light or charged<.52 or charged>6 then
            notify(player,"Message","Hold attack for at least 0.6s to HEAVY HIT")
            return
        end
        c.step=0;c.comboAt=0
        c.light=now+1.5*(cfg.AttackCooldown/.68)
        heavyStrike(player,root,character,dir)
    elseif action=="Light" then
        c.chargeAt=nil
        player:SetAttribute("HeavyCharging",false)
        if now<c.light then return end
        local step=(now-c.comboAt<Config.ComboReset and c.step<3) and c.step+1 or 1
        c.step=step
        c.comboAt=now
        c.light=now+math.max(.3,Config.ComboCooldowns[step]*(cfg.AttackCooldown/.68))
        melee(player,root,character,dir,step)
    elseif action=="Power" then
        if now<c.power then return end
        player:SetAttribute("LastCombatAt",now)
        c.power=now+cfg.PowerCooldown
        c.step=0
        power(player,root,character,dir)
    elseif action=="Dodge" then
        if now<c.dodge then return end
        player:SetAttribute("LastCombatAt",now)
        c.dodge=now+Config.DodgeCooldown
        c.step=0
        player:SetAttribute("DodgeUntil",now+.26)
        markWhipMotion(character,"Dodge",1,.42)
        executeDodge(player,character,hum,root,parameter)
        notify(player,"Dodge","DODGED",{cooldown=Config.DodgeCooldown})
    end
end)

save=function(player)
    local d=data[player]
    if not d or not d.Loaded or d.SaveDisabled or not datastore then return end
    if d.Saving then d.SaveRequested=true;return end
    if not d.Dirty then return end
    d.Saving=true
    local revision=d.Revision
    -- Snapshot before yielding. UpdateAsync saves all earned coins, owned weapons,
    -- selected whip and cooldown in the SAME atomic player record.
    local owned={}
    for id,yes in pairs(d.Owned) do if yes and Whips[id] and not Whips[id].OwnerOnly then owned[id]=true end end
    local payload={Coins=d.Coins,KOs=d.KOs,Owned=owned,Selected=d.Selected,
        SpinReadyAt=d.SpinReadyAt or 0,Version=2,SavedAt=os.time()}
    local ok,err=pcall(function()
        datastore:UpdateAsync("p_"..player.UserId,function(previous)
            return payload
        end)
    end)
    if ok then
        d.Dirty=(d.Revision~=revision)
        d.LastSaveAt=os.clock()
        player:SetAttribute("ProgressSaved",true)
        player:SetAttribute("WalletSaveStatus",d.Dirty and "PENDING" or "SAVED")
    else
        warn("[Lashbound Save] Failed for",player.UserId,err)
        player:SetAttribute("ProgressSaved",false)
        player:SetAttribute("WalletSaveStatus","RETRYING")
        d.Dirty=true
    end
    d.Saving=false
    if d.SaveRequested then
        d.SaveRequested=false
        if d.Dirty then task.delay(2,function()if data[player]==d then save(player) end end) end
    end
end
-- Low request frequency and retries via regular autosave; no write per pickup.
task.spawn(function()
    while task.wait(60) do
        for _,p in ipairs(Players:GetPlayers()) do
            local d=data[p]
            if d and d.Dirty and d.Loaded then task.spawn(save,p) end
        end
    end
end)
local function onPlayer(player)
    local d={Coins=0,KOs=0,Owned={Rope=true},Selected="Rope",SpinReadyAt=0,
        Loaded=false,SaveDisabled=false,Dirty=false,Revision=0,Saving=false,SaveQueued=false}
    data[player]=d
    cooldowns[player]={last=0,light=0,power=0,dodge=0,step=0,comboAt=0}
    player:SetAttribute("Zone","Lobby")
    player:SetAttribute("Coins",0); player:SetAttribute("KOs",0)
    player:SetAttribute("SelectedWhip","Rope")
    player:SetAttribute("RegularWhip","Rope")
    player:SetAttribute("HasWhip",false)
    player:SetAttribute("Owns_Rope",true)
    player:SetAttribute("SpinReadyAt",0)
    player:SetAttribute("ProgressSaved",false)
    player:SetAttribute("WalletSaveStatus","LOADING")
    local leader=Instance.new("Folder")
    leader.Name="leaderstats"; leader.Parent=player
    local ko=Instance.new("IntValue"); ko.Name="KOs"; ko.Parent=leader
    local coins=Instance.new("IntValue"); coins.Name="Coins"; coins.Parent=leader
    player:GetAttributeChangedSignal("KOs"):Connect(function() ko.Value=player:GetAttribute("KOs") or 0 end)
    player:GetAttributeChangedSignal("Coins"):Connect(function() coins.Value=player:GetAttribute("Coins") or 0 end)
    player.CharacterAdded:Connect(function(character)
        player:SetAttribute("Zone","Lobby")
        player:SetAttribute("SafeUntil",os.clock()+999999)
        local humanoid=character:WaitForChild("Humanoid",8)
        local root=character:WaitForChild("HumanoidRootPart",8)
        if not humanoid or not root then return end
        humanoid.WalkSpeed=18
        humanoid.JumpPower=52
        attachCombatHealth(character,humanoid,player.DisplayName,Color3.fromRGB(106,230,149))
        player:SetAttribute("LastCombatAt",os.clock())
        humanoid.Died:Connect(function()
            local tag=lastHit[player]
            if tag and os.clock()-tag.at<8 then
                -- The lethal-hit path handles awards already; no duplicate credit here.
            end
            lastHit[player]=nil
        end)
        task.delay(.4,function()
            if player.Character==character and humanoid.Health>0 then
                character:PivotTo(lobbySpot)
                equipWeapon(player)
            end
        end)
        task.delay(1.8,function()
            if player.Character==character and humanoid.Health>0 then equipWeapon(player) end
        end)
    end)
    -- Never overwrite existing progress with the temporary zero shown during loading.
    -- Keep any coin/KO gains occurring while GetAsync yields.
    task.spawn(function()
        local ok,saved=false,nil
        if datastore then
            for attempt=1,3 do
                ok,saved=pcall(function() return datastore:GetAsync("p_"..player.UserId) end)
                if ok then break end
                task.wait(attempt)
            end
        end
        if not player.Parent or data[player]~=d then return end
        local earnedBeforeLoad=(d.Coins>0 or d.KOs>0)
        if ok and type(saved)=="table" then
            d.Coins=math.max(0,math.floor(tonumber(saved.Coins) or 0))+d.Coins
            d.KOs=math.max(0,math.floor(tonumber(saved.KOs) or 0))+d.KOs
            d.SpinReadyAt=math.max(0,math.floor(tonumber(saved.SpinReadyAt) or 0))
            if type(saved.Owned)=="table" then
                for id,has in pairs(saved.Owned) do
                    if Whips[id] and not Whips[id].OwnerOnly and has==true then d.Owned[id]=true end
                end
            end
            if type(saved.Selected)=="string" and d.Owned[saved.Selected] and Whips[saved.Selected] then d.Selected=saved.Selected end
        elseif not ok then
            d.SaveDisabled=true
            notify(player,"Message","DATA SAVE OFFLINE: Progress will not persist until Studio API access is enabled")
            warn("[Lashbound] DataStore not available for",player.UserId)
        end
        d.Loaded=true
        if earnedBeforeLoad or (ok and saved==nil) then queueSave(player) end
        player:SetAttribute("Coins",d.Coins); player:SetAttribute("KOs",d.KOs)
        for _,id in ipairs(Config.Order) do player:SetAttribute("Owns_"..id,d.Owned[id]==true) end
        player:SetAttribute("RegularWhip",d.Selected)
        if not (player.Character and player.Character:FindFirstChild("FounderTempest")) then
            player:SetAttribute("SelectedWhip",d.Selected)
        end
        player:SetAttribute("SpinReadyAt",d.SpinReadyAt)
        player:SetAttribute("ProgressSaved",not d.SaveDisabled and not d.Dirty)
        player:SetAttribute("WalletSaveStatus",d.SaveDisabled and "OFFLINE" or d.Dirty and "PENDING" or "SAVED")
        equipWeapon(player)
    end)
end
Players.PlayerAdded:Connect(onPlayer)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(onPlayer,player) end
Players.PlayerRemoving:Connect(function(player)
    local d=data[player]
    if d then
        local untilAt=os.clock()+8
        while not d.Loaded and os.clock()<untilAt do task.wait(.2) end
        while d.Saving and os.clock()<untilAt do task.wait(.2) end
    end
    save(player)
    data[player]=nil; cooldowns[player]=nil; lastHit[player]=nil
    wheelLastRequest[player]=nil
end)
game:BindToClose(function()
    for _,player in ipairs(Players:GetPlayers()) do task.spawn(save,player) end
    task.wait(5)
end)

RS:SetAttribute("LashboundCombatReady", true)
print("[Lashbound V11] Combat balance, raid, regen, paid-coin wheel and saving ONLINE")
