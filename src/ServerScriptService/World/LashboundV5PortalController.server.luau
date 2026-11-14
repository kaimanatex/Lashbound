-- LASHBOUND V6 | ONE-WAY entrance. The battle arena contains NO exit door.
-- Death returns players to the safe lobby. Maps rotate independently.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local lobby=Workspace:WaitForChild("LashboundLobby",15)
local door=lobby and lobby:WaitForChild("ArenaDoorTrigger",15)
local request=RS:WaitForChild("LashboundPortalRequest",15)
if not door or not request then warn("[Lashbound Door] Entry parts missing") return end
local nextUse={}
local rng=Random.new()
local function inside(root,interact)
    local p=door.CFrame:PointToObjectSpace(root.Position)
    local x=interact and 13 or 8
    local z=interact and 13 or 5.8
    return math.abs(p.X)<x and math.abs(p.Y)<12 and math.abs(p.Z)<z
end
-- Pick a free-ish spawn instead of stacking newcomers on existing fighters.
-- Uses both current character positions and recent portal reservations so two
 -- simultaneous entrants do not get the same marker.
local recentSpawnReservations={}
local function destination()
    local arena=Workspace:FindFirstChild("LashboundBattleArena")
    local spawns=arena and arena:FindFirstChild("ArenaSpawns")
    if not spawns then return nil end
    local choices={}
    for _,part in ipairs(spawns:GetChildren()) do
        if part:IsA("BasePart") then table.insert(choices,part) end
    end
    if #choices==0 then return nil end
    local now=os.clock()
    local best=nil
    local bestScore=-math.huge
    for _,spot in ipairs(choices) do
        local nearest=250
        for _,other in ipairs(Players:GetPlayers()) do
            if other:GetAttribute("Zone")=="Arena" then
                local c=other.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                if root then nearest=math.min(nearest,(root.Position-spot.Position).Magnitude) end
            end
        end
        local penalty=((recentSpawnReservations[spot] or 0)>now) and 1000 or 0
        local score=nearest-penalty+rng:NextNumber(0,8)
        if score>bestScore then bestScore=score;best=spot end
    end
    if not best then return nil end
    recentSpawnReservations[best]=now+4
    local p=best.Position+Vector3.new(0,3.5,0)
    local look=Vector3.new(0,p.Y,-620)
    if (look-p).Magnitude<1 then look=p+Vector3.new(0,0,1) end
    return CFrame.lookAt(p,look)
end
local function enter(player,interact)
    if not player or player.Parent~=Players then return end
    if player:GetAttribute("Zone")=="Arena" then return end
    if os.clock()<(nextUse[player] or 0) then return end
    local character=player.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health<=0 or not root or not inside(root,interact) then return end
    local cf=destination()
    if not cf then warn("[Lashbound Door] Arena still loading") return end
    nextUse[player]=os.clock()+2.5
    player:SetAttribute("Zone","Arena")
    player:SetAttribute("SafeUntil",os.clock()+3)
    character:PivotTo(cf)
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    print("[Lashbound Door] Entered:",player.Name)
end
-- Backups for Touch, E-key prompt, mobile input and missed touch events.
door.CanCollide=false
door.CanTouch=true
local prompt=door:FindFirstChildOfClass("ProximityPrompt")
if not prompt then prompt=Instance.new("ProximityPrompt");prompt.Parent=door end
prompt.ActionText="Enter Battle"
prompt.ObjectText="ONE WAY: FIGHT UNTIL DEFEATED"
prompt.RequiresLineOfSight=false
prompt.HoldDuration=0
prompt.MaxActivationDistance=15
prompt.KeyboardKeyCode=Enum.KeyCode.F -- E remains reserved for Dodge.
prompt.Triggered:Connect(function(player)enter(player,true) end)
door.Touched:Connect(function(touched)
    local model=touched:FindFirstAncestorOfClass("Model")
    local player=model and Players:GetPlayerFromCharacter(model)
    if player then enter(player,false) end
end)
request.OnServerEvent:Connect(function(player,action)
    if action=="Enter" then enter(player,true) end
    -- "Exit" intentionally ignored: there is no arena escape.
end)
task.spawn(function()
    while script.Parent do
        for _,player in ipairs(Players:GetPlayers()) do
            if player:GetAttribute("Zone")~="Arena" then
                local c=player.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                if root and inside(root,false) then enter(player,false) end
            end
        end
        task.wait(.22)
    end
end)
Players.PlayerRemoving:Connect(function(p)nextUse[p]=nil end)
print("[Lashbound Door] One-way lobby-to-arena gateway ready")

-- Keep terrain grass from poking through the cabin floor (not the arena).
-- V39: keep the entire enclosed lobby volume clear of stray voxel terrain.
-- Preserve arena terrain, which is centered 620 studs away.
local function clearCabinTerrain()
    Workspace.Terrain:FillBlock(CFrame.new(0,26,0),Vector3.new(178,102,178),Enum.Material.Air)
end
task.defer(clearCabinTerrain)
task.delay(2,clearCabinTerrain)
task.delay(8,clearCabinTerrain)

-- Original, license-clear portal energy decoration; one physical energy surface only.
local function lightPortal()
    local portal=lobby and lobby:FindFirstChild("V37_PortalEnergySurface")
    if not portal or not portal:IsA("BasePart") then return end
    portal.CanCollide=false
    portal.Transparency=.28
    portal.Material=Enum.Material.Neon
    portal.Color=Color3.fromRGB(114,70,240)
    if not portal:FindFirstChild("LashboundPortalGlow") then
        local glow=Instance.new("PointLight")
        glow.Name="LashboundPortalGlow";glow.Color=portal.Color
        glow.Brightness=3.2;glow.Range=26;glow.Shadows=false;glow.Parent=portal
    end
    if not portal:FindFirstChild("LashboundPortalMist") then
        local mist=Instance.new("ParticleEmitter")
        mist.Name="LashboundPortalMist"
        mist.Texture="rbxasset://textures/particles/sparkles_main.dds"
        mist.Color=ColorSequence.new(Color3.fromRGB(87,178,255),Color3.fromRGB(197,99,255))
        mist.LightEmission=1
        mist.Rate=45
        mist.Lifetime=NumberRange.new(.5,1.2)
        mist.Speed=NumberRange.new(.5,3)
        mist.SpreadAngle=Vector2.new(180,180)
        mist.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
        mist.Parent=portal
    end
end
lightPortal()
