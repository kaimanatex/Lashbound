-- LASHBOUND V6 | five-minute server-authoritative arena rotation.
-- Only ONE map is cloned into Workspace; unused map templates stay in ServerStorage.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local templates = ServerStorage:WaitForChild("LashboundMapTemplates",15)
if not templates then warn("[Lashbound Maps] Map templates are missing") return end
local order = {
    {key="PrismCitadel", name="PRISM CITADEL"},
    {key="CinderFoundry", name="CINDER FOUNDRY"},
    {key="GlacialDivide", name="GLACIAL DIVIDE"},
    {key="ThornTemple", name="THORN TEMPLE"},
    {key="StormReactor", name="STORM REACTOR"},
}
local DURATION = 300 -- Exactly 5 minutes, server-wide.
-- For a quick local test temporarily change DURATION to 25 and then back to 300.
local index = 0
local currentArena
local hazards={}
local nextDamage={}
local nextChange=0
local rng=Random.new()
local function findSpawnCf(arena)
    local group=arena and arena:FindFirstChild("ArenaSpawns")
    local spots=group and group:GetChildren() or {}
    if #spots>0 then
        local marker=spots[rng:NextInteger(1,#spots)]
        if marker and marker:IsA("BasePart") then
            local p=marker.Position+Vector3.new(0,3.5,0)
            local center=Vector3.new(0,p.Y,-620)
            if (center-p).Magnitude<1 then center=p+Vector3.new(0,0,1) end
            return CFrame.lookAt(p,center)
        end
    end
    return CFrame.new(0,6,-620)
end
-- Share spawn markers across all players instead of randomly piling fighters
-- on the same point when maps rotate during a crowded match.
local function relocateArenaPlayers(arena)
    local folder=arena and arena:FindFirstChild("ArenaSpawns")
    local points={}
    if folder then
        for _,p in ipairs(folder:GetChildren()) do
            if p:IsA("BasePart") then table.insert(points,p) end
        end
    end
    for i=#points,2,-1 do
        local j=rng:NextInteger(1,i)
        points[i],points[j]=points[j],points[i]
    end
    local count=0
    for _,player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Zone")=="Arena" then
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health>0 and root then
                count+=1
                player:SetAttribute("SafeUntil",os.clock()+4)
                local cf
                if #points>0 then
                    local spot=points[((count-1)%#points)+1]
                    cf=CFrame.new(spot.Position+Vector3.new(0,3.5,0))
                    local face=Vector3.new(0,cf.Position.Y,-620)
                    if (face-cf.Position).Magnitude>1 then
                        cf=CFrame.lookAt(cf.Position,face)
                    end
                else
                    cf=findSpawnCf(arena)
                end
                char:PivotTo(cf)
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                hum.Health=hum.MaxHealth
            end
        end
    end
end
local function collectHazards(arena)
    hazards={}
    for _,part in ipairs(arena:GetDescendants()) do
        if part:IsA("BasePart") and string.sub(part.Name,1,7)=="Hazard_" then
            table.insert(hazards,part)
        end
    end
end
local function rotate()
    local nextIndex=(index%#order)+1
    local template=templates:FindFirstChild(order[nextIndex].key)
    if not template then warn("[Lashbound Maps] Missing map "..order[nextIndex].key) return end
    local replacement=template:Clone()
    replacement.Name="LashboundBattleArena"
    replacement:SetAttribute("BiomeIndex",nextIndex)
    -- Rename old first so scripts requesting the active map never pick it by mistake.
    local old=currentArena
    if old and old.Parent then old.Name="RetiringBattleArena" end
    replacement.Parent=Workspace
    currentArena=replacement
    index=nextIndex
    collectHazards(replacement)
    nextDamage={}
    nextChange=Workspace:GetServerTimeNow()+DURATION
    RS:SetAttribute("LashboundMapName",order[index].name)
    RS:SetAttribute("LashboundMapIndex",index)
    RS:SetAttribute("LashboundNextMapTime",nextChange)
    RS:SetAttribute("LashboundMapDuration",DURATION)
    relocateArenaPlayers(replacement)
    if old and old.Parent then old:Destroy() end
    print("[Lashbound Maps] Active:",order[index].name," next rotation in",DURATION,"seconds")
end

local function standingOnHazard(root,part)
    local p=part.CFrame:PointToObjectSpace(root.Position)
    return math.abs(p.X)<part.Size.X/2+1.6
        and math.abs(p.Z)<part.Size.Z/2+1.6
        and p.Y>=-2 and p.Y<=4.8
end
-- One low-frequency loop handles both the timer and map hazards.
-- No continuous per-part listeners or RenderStepped physics effects.
rotate()
while script.Parent do
    if Workspace:GetServerTimeNow()>=nextChange then rotate() end
    if #hazards>0 then
        local now=os.clock()
        local stormActive=(index==5) and (math.floor(Workspace:GetServerTimeNow())%8<2)
        for _,part in ipairs(hazards) do
            if part.Parent and string.find(part.Name,"Surge") then
                part.Transparency=stormActive and .16 or .8
            end
        end
        for _,player in ipairs(Players:GetPlayers()) do
            if player:GetAttribute("Zone")=="Arena" and now>=(nextDamage[player] or 0)
               and now>=(player:GetAttribute("SafeUntil") or 0)
               and now>=(player:GetAttribute("DodgeUntil") or 0) then
                local character=player.Character
                local hum=character and character:FindFirstChildOfClass("Humanoid")
                local root=character and character:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health>0 and root then
                    for _,part in ipairs(hazards) do
                        if part.Parent and (not string.find(part.Name,"Surge") or stormActive)
                            and standingOnHazard(root,part) then
                            hum:TakeDamage(10)
                            nextDamage[player]=now+1.05
                            break
                        end
                    end
                end
            end
        end
    end
    task.wait(.5)
end
