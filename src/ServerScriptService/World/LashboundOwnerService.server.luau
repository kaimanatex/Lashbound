-- LASHBOUND V13.1: PERMANENT founder access for explicitly approved Roblox user IDs.
-- This server-side whitelist is bundled with the published place. It survives deaths,
-- reconnects, and DataStore failures, without adding the whip to public shop inventory.
-- The user who personally owns the experience also retains founder access.
local PERMANENT_FOUNDER_USER_IDS = {
    [3122892445] = true, -- explicitly authorized permanent Founder's Tempest holder
}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Workspace=game:GetService("Workspace")
local Action=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Action")
local Config=require(RS:WaitForChild("WhipConfig"))
local ownerStates={}
local function verified(player)
    local id=player.UserId
    return PERMANENT_FOUNDER_USER_IDS[id]==true
        or (game.CreatorType==Enum.CreatorType.User and game.CreatorId>0 and id==game.CreatorId)
end
local function getRoot(player)
    local ch=player.Character
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    local root=ch and ch:FindFirstChild("HumanoidRootPart")
    if not root or not hum or hum.Health<=0 then return nil end
    return ch,hum,root
end
local function stopFlight(player)
    local state=ownerStates[player]
    if state then
        state.flying=false
        if state.constraint then state.constraint:Destroy();state.constraint=nil end
        if state.attachment then state.attachment:Destroy();state.attachment=nil end
        state.vector=Vector3.zero
        state.lastInput=0
    end
    local _,hum,root=getRoot(player)
    if hum then hum.PlatformStand=false;hum.AutoRotate=true end
    if root then
        root.AssemblyLinearVelocity=Vector3.zero
        pcall(function() root:SetNetworkOwnershipAuto() end)
    end
    player:SetAttribute("OwnerFlying",false)
end
-- FounderTempest is kept in ServerStorage, never in StarterPack. Cloning it
-- into one verified player's Backpack preserves the ordinary LashboundWhip.
local boundTools=setmetatable({}, {__mode="k"})
local function bindFounderTool(player,tool)
    if boundTools[tool] then return end
    boundTools[tool]=true
    tool:SetAttribute("WhipId","Owner")
    tool.Equipped:Connect(function()
        if not verified(player) or not player.Character or tool.Parent~=player.Character then return end
        player:SetAttribute("OwnerEquipped",true)
        player:SetAttribute("SelectedWhip","Owner")
        player:SetAttribute("HasWhip",true)
    end)
    tool.Unequipped:Connect(function()
        stopFlight(player)
        player:SetAttribute("OwnerEquipped",false)
        task.defer(function()
            if player.Parent and not (player.Character and player.Character:FindFirstChild("FounderTempest")) then
                local regular=player:GetAttribute("RegularWhip") or "Rope"
                player:SetAttribute("SelectedWhip",regular)
                player:SetAttribute("HasWhip",player.Character~=nil and player.Character:FindFirstChild("LashboundWhip")~=nil)
            end
        end)
    end)
end
local function grantFounderTool(player)
    if not verified(player) then return end
    local ch=player.Character
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return end
    local backpack=player:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    local tool=ch:FindFirstChild("FounderTempest") or backpack:FindFirstChild("FounderTempest")
    if not tool then
        local template=ServerStorage:FindFirstChild("FounderTempest")
        if not template then warn("[Lashbound] FounderTempest template missing");return end
        tool=template:Clone()
        tool.Name="FounderTempest"
        tool.Parent=backpack
    end
    bindFounderTool(player,tool)
end
local function enableFlight(player)
    local state=ownerStates[player]
    local ch,hum,root=getRoot(player)
    if not state or not ch then return end
    stopFlight(player)
    local att=Instance.new("Attachment")
    att.Name="FounderFlightAttachment"
    att.Parent=root
    local mover=Instance.new("LinearVelocity")
    mover.Name="FounderFlightVelocity"
    mover.Attachment0=att
    mover.RelativeTo=Enum.ActuatorRelativeTo.World
    mover.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    mover.ForceLimitsEnabled=false
    mover.VectorVelocity=Vector3.zero
    mover.Parent=root
    -- Server-owned flight prevents clients from bypassing arena collision limits.
    pcall(function()root:SetNetworkOwner(nil)end)
    hum.PlatformStand=true
    hum.AutoRotate=false
    state.flying=true
    state.attachment=att
    state.constraint=mover
    state.vector=Vector3.zero
    state.lastInput=os.clock()
    player:SetAttribute("OwnerFlying",true)
end
local function setUp(player)
    if not verified(player) then
        player:SetAttribute("OwnerVerified",false)
        return
    end
    ownerStates[player]={flying=false,vector=Vector3.zero,lastInput=0}
    player:SetAttribute("OwnerVerified",true)
    player:SetAttribute("OwnerFlying",false)
    player:SetAttribute("OwnerEquipped",false)
    player.CharacterAdded:Connect(function(ch)
        stopFlight(player)
        -- Never force FounderTempest equipped or overwrite the normal loadout.
        task.delay(.7,function() if player.Character==ch and player.Parent then grantFounderTool(player) end end)
        task.delay(1.8,function() if player.Character==ch and player.Parent then grantFounderTool(player) end end)
    end)
    if player.Character then task.defer(grantFounderTool,player) end
end
Action.OnServerEvent:Connect(function(player,action,param)
    if not verified(player) or not ownerStates[player] then return end
    if action=="OwnerFlyToggle" then
        if not (player.Character and player.Character:FindFirstChild("FounderTempest"))
            or player:GetAttribute("OwnerEquipped")~=true then return end
        local state=ownerStates[player]
        if state.flying then stopFlight(player) else enableFlight(player) end
    elseif action=="OwnerFlyInput" then
        local state=ownerStates[player]
        if not state.flying or typeof(param)~="Vector3" then return end
        if param.X~=param.X or param.Y~=param.Y or param.Z~=param.Z or param.Magnitude>1.05 then return end
        state.vector=param
        state.lastInput=os.clock()
    end
end)
-- 10Hz movement / boundary sweeps; no expensive per-frame remote updates.
task.spawn(function()
    while task.wait(.1) do
        for player,state in pairs(ownerStates) do
            if state.flying then
                local ch,hum,root=getRoot(player)
                if not ch or not state.constraint or not state.constraint.Parent then
                    stopFlight(player)
                else
                    local v=(os.clock()-state.lastInput<.45) and state.vector or Vector3.zero
                    if v.Magnitude>1 then v=v.Unit end
                    local desired=v*64
                    local pos=root.Position
                    local inArena=player:GetAttribute("Zone")=="Arena"
                    local centerZ=inArena and -620 or 0
                    local limit=inArena and 214 or 85
                    local nextPoint=pos+desired*.12
                    if math.abs(nextPoint.X)>limit or math.abs(nextPoint.Z-centerZ)>limit
                        or nextPoint.Y>110 or nextPoint.Y<4.5 then
                        desired=Vector3.zero
                    end
                    if desired.Magnitude>.1 then
                        local params=RaycastParams.new()
                        params.FilterType=Enum.RaycastFilterType.Exclude
                        params.FilterDescendantsInstances={ch}
                        params.RespectCanCollide=true
                        local hit=Workspace:Blockcast(CFrame.new(pos),Vector3.new(2.7,4.2,2.7),desired.Unit*math.max(5,desired.Magnitude*.14),params)
                        if hit then desired=Vector3.zero end
                    end
                    state.constraint.VectorVelocity=desired
                end
            end
        end
    end
end)
Players.PlayerAdded:Connect(setUp)
for _,p in ipairs(Players:GetPlayers()) do task.defer(setUp,p) end
Players.PlayerRemoving:Connect(function(p)stopFlight(p);ownerStates[p]=nil end)
