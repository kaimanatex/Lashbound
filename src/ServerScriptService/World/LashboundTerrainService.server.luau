-- LASHBOUND V17: organic, textured terrain pieces along the borders of each map.
-- Gameplay center stays open. Only one biome's voxel terrain exists at a time.
-- Deterministic seed makes all clients see the same server-authored landforms.
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local Terrain=Workspace.Terrain
local generation=0
local function build(arena)
    if not arena or not arena.Parent or arena.Name~="LashboundBattleArena" then return end
    generation+=1
    local token=generation
    local index=arena:GetAttribute("BiomeIndex") or RS:GetAttribute("LashboundMapIndex") or 1
    local material={
        [1]=Enum.Material.Slate, [2]=Enum.Material.Basalt,
        [3]=Enum.Material.Snow, [4]=Enum.Material.LeafyGrass,
        [5]=Enum.Material.Rock,
    }
    local base=material[index] or Enum.Material.Rock
    local accent=index==1 and Enum.Material.Limestone or index==2 and Enum.Material.CrackedLava
        or index==3 and Enum.Material.Ice or index==4 and Enum.Material.Grass or Enum.Material.Slate
    local rng=Random.new(index*2219+17)
    -- MapArea only; never clear the cabin or other game worlds.
    Terrain:FillBlock(CFrame.new(0,0,-620),Vector3.new(470,36,470),Enum.Material.Air)
    local count=index==4 and 46 or 34
    local created=0
    for i=1,count do
        if generation~=token or not arena.Parent then return end
        local x,z
        if i%2==0 then
            x=(rng:NextNumber()<.5 and -1 or 1)*rng:NextNumber(149,211)
            z=rng:NextNumber(-193,193)
        else
            z=(rng:NextNumber()<.5 and -1 or 1)*rng:NextNumber(147,208)
            x=rng:NextNumber(-190,190)
        end
        local radius=rng:NextNumber(7,19)
        -- Low, convex mounds rather than block piles. A thin top is visible
        -- above the original collidable floor, preserving the main arena.
        local height=rng:NextNumber(.9,4.3)
        local where=Vector3.new(x,-radius+height,-620+z)
        Terrain:FillBall(where,radius,(i%4==0) and accent or base)
        created+=1
        if i%8==0 then task.wait() end
    end
    print("[Lashbound Terrain] Biome",index,"organic mounds",created)
end
Workspace.ChildAdded:Connect(function(obj)
    if obj.Name=="LashboundBattleArena" then
        task.defer(build,obj)
    end
end)
local active=Workspace:FindFirstChild("LashboundBattleArena")
if active then task.defer(build,active) end
