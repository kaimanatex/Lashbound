-- Three interactive cabin NPCs. Client never grants currency from dialogue.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local Workspace=game:GetService("Workspace")
local lobby=Workspace:WaitForChild("LashboundLobby")
local palette={
    {name="Mara the Quartermaster",role="WHIP SMITH",pos=Vector3.new(-29,1,-23),color=Color3.fromRGB(156,100,63),action="OpenShop"},
    {name="Elder Rowan",role="BOSS LORE",pos=Vector3.new(24,1,16),color=Color3.fromRGB(81,111,96),action="BossLore"},
    {name="Scout Finn",role="RAID GUIDE",pos=Vector3.new(-20,1,27),color=Color3.fromRGB(116,91,136),action="RaidGuide"},
}
local function part(parent,name,size,pos,color,shape)
    local x=Instance.new("Part")
    x.Name=name;x.Size=size;x.CFrame=CFrame.new(pos);x.Anchored=true
    x.CanCollide=false;x.CanTouch=false;x.CanQuery=false
    x.Material=Enum.Material.SmoothPlastic;x.Color=color;x.CastShadow=false
    if shape then x.Shape=shape end
    x.Parent=parent
    return x
end
for i,info in ipairs(palette) do
    local npc=Instance.new("Model")
    npc.Name="LobbyNPC_"..i
    npc.Parent=lobby
    local p=info.pos
    local skin=Color3.fromRGB(211,168,126)
    local shoes=Color3.fromRGB(54,44,40)
    local torso=part(npc,"Torso",Vector3.new(2.4,2.4,1.2),p+Vector3.new(0,3.1,0),info.color)
    part(npc,"Head",Vector3.new(1.75,1.75,1.6),p+Vector3.new(0,5.25,0),skin,Enum.PartType.Ball)
    part(npc,"Apron",Vector3.new(2.0,1.65,.28),p+Vector3.new(0,2.65,-.72),Color3.fromRGB(84,59,42))
    part(npc,"LeftArm",Vector3.new(.67,2.2,.9),p+Vector3.new(-1.56,3.0,0),skin)
    part(npc,"RightArm",Vector3.new(.67,2.2,.9),p+Vector3.new(1.56,3.0,0),skin)
    part(npc,"LeftLeg",Vector3.new(.86,2.1,1.0),p+Vector3.new(-.58,1.15,0),shoes)
    part(npc,"RightLeg",Vector3.new(.86,2.1,1.0),p+Vector3.new(.58,1.15,0),shoes)
    part(npc,"HatBrim",Vector3.new(2.5,.26,2.2),p+Vector3.new(0,6.22,0),shoes)
    part(npc,"HatTop",Vector3.new(1.6,.73,1.45),p+Vector3.new(0,6.64,0),info.color)
    for side=-1,1,2 do
        part(npc,"Eye"..side,Vector3.new(.18,.18,.12),p+Vector3.new(side*.34,5.35,-.77),Color3.fromRGB(34,28,22),Enum.PartType.Ball)
    end
    local prompt=Instance.new("ProximityPrompt")
    prompt.Name="NPCInteract"
    prompt.ActionText=info.role=="WHIP SMITH" and "Browse whips" or "Talk"
    prompt.ObjectText=info.name
    prompt.MaxActivationDistance=12
    prompt.HoldDuration=0
    prompt.RequiresLineOfSight=false
    prompt.Parent=torso
    prompt.Triggered:Connect(function(player)
        if player:GetAttribute("Zone")~="Lobby" then return end
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root or (root.Position-torso.Position).Magnitude>15 then return end
        if info.action=="OpenShop" then
            Feedback:FireClient(player,"OpenShop","Mara: Every whip is different. Choose wisely!")
        elseif info.action=="BossLore" then
            Feedback:FireClient(player,"LobbyDialogue",info.name,{
                "The Colossus falls once... then rises in the color of this land.",
                "Its second form has ranged spells and sweeping shockwaves. Watch the warning lines.",
                "Move out of its marked attacks. The respawn timer begins only after the second defeat."})
        else
            Feedback:FireClient(player,"LobbyDialogue",info.name,{
                "Storm clouds mean the hound raid is coming.",
                "Thirty hounds spawn two minutes into each map. Each is worth one coin.",
                "If you need a break, the lobby is always safe. Try the chess table!"})
        end
    end)
end
