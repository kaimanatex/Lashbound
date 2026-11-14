-- LASHBOUND V17: distinctive branded insignias and lightweight in-world auras.
-- SurfaceGui emblems work without uploading image asset IDs; each is a built-in
-- visible decal-like mark. Visuals do NOT influence server damage or ownership.
local Players=game:GetService("Players")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("WhipConfig"))
local seen=setmetatable({}, {__mode="k"})
local GLYPH={Rope="R",Ember="F",Frost="I",Volt="V",Gravity="G",Phantom="P",Legend="S",Judgement="J",Echo="M",Owner="✦"}
local SYMBOL={Rope="◇",Ember="✦",Frost="❄",Volt="ϟ",Gravity="◎",Phantom="☽",Legend="♛",Judgement="ϟ",Echo="◈",Owner="✧"}
local function build(tool)
    local id=tool:GetAttribute("WhipId") or (tool.Name=="FounderTempest" and "Owner") or "Rope"
    local cfg=Config.Whips[id]
    local handle=tool:FindFirstChild("Handle")
    if not cfg or not handle then return end
    local old=handle:FindFirstChild("LashboundEtching")
    if old and old:GetAttribute("WhipId")==id then return end
    if old then old:Destroy() end
    local folder=Instance.new("Folder")
    folder.Name="LashboundEtching"
    folder:SetAttribute("WhipId",id)
    folder.Parent=handle
    -- Insignia plaque physically welded to the handle, rather than an overlay on UI.
    local crest=Instance.new("Part")
    crest.Name="CrestBadge"
    crest.Size=Vector3.new(.48,.68,.055)
    crest.Material=Enum.Material.Metal
    crest.Color=Color3.fromRGB(47,42,39)
    crest.Massless=true;crest.CanCollide=false;crest.CanTouch=false;crest.CanQuery=false
    crest.CastShadow=false
    crest.CFrame=handle.CFrame*CFrame.new(0,.13,-.28)
    crest.Parent=folder
    local weld=Instance.new("WeldConstraint")
    weld.Part0=handle;weld.Part1=crest;weld.Parent=crest
    local gui=Instance.new("SurfaceGui")
    gui.Name="EngravedInsignia"
    gui.Adornee=crest
    gui.Face=Enum.NormalId.Front
    gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud=130
    gui.LightInfluence=0
    gui.AlwaysOnTop=false
    gui.Parent=crest
    local panel=Instance.new("Frame")
    panel.Size=UDim2.fromScale(1,1)
    panel.BackgroundColor3=Color3.fromRGB(31,31,38)
    panel.BorderSizePixel=0
    panel.Parent=gui
    local stroke=Instance.new("UIStroke")
    stroke.Color=cfg.Color;stroke.Thickness=2
    stroke.Parent=panel
    local icon=Instance.new("TextLabel")
    icon.Name="CrestSymbol"
    icon.Size=UDim2.fromScale(1,.73)
    icon.BackgroundTransparency=1
    icon.Text=SYMBOL[id] or "✦"
    icon.TextColor3=cfg.Color
    icon.TextScaled=true
    icon.Font=Enum.Font.GothamBlack
    icon.Parent=panel
    local letter=Instance.new("TextLabel")
    letter.Size=UDim2.new(1,0,.25,0)
    letter.Position=UDim2.fromScale(0,.73)
    letter.BackgroundTransparency=1
    letter.Text=GLYPH[id] or id
    letter.TextColor3=Color3.fromRGB(240,234,210)
    letter.TextScaled=true
    letter.Font=Enum.Font.GothamBold
    letter.Parent=panel
    -- A low-rate glow aura uses a Roblox-bundled particle texture, no external ID.
    local attachment=Instance.new("Attachment")
    attachment.Name="LashboundAuraPoint"
    attachment.Position=Vector3.new(0,.75,0)
    attachment.Parent=handle
    -- Destroy old attachment on re-color to avoid duplicate particle systems.
    for _,a in ipairs(handle:GetChildren()) do
        if a~=attachment and a:IsA("Attachment") and a.Name=="LashboundAuraPoint" then a:Destroy() end
    end
    local particle=Instance.new("ParticleEmitter")
    particle.Name="WhipAura"
    particle.Texture="rbxasset://textures/particles/sparkles_main.dds"
    particle.Color=ColorSequence.new(cfg.Color,Color3.new(1,1,1))
    particle.LightEmission=.65
    particle.Size=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.20),
        NumberSequenceKeypoint.new(.45,.30),
        NumberSequenceKeypoint.new(1,0)})
    particle.Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.18),
        NumberSequenceKeypoint.new(1,1)})
    particle.Lifetime=NumberRange.new(.42,.8)
    particle.Speed=NumberRange.new(.4,1.2)
    particle.SpreadAngle=Vector2.new(35,35)
    particle.Rate=id=="Owner" and 10 or id=="Legend" and 7 or 3.5
    particle.Enabled=tool.Parent and tool.Parent:IsA("Model") or false
    particle.Parent=attachment
    local light=Instance.new("PointLight")
    light.Name="WhipCoreLight"
    light.Color=cfg.Color
    light.Range=id=="Owner" and 9 or 5
    light.Brightness=id=="Owner" and 1.25 or .52
    light.Enabled=particle.Enabled
    light.Parent=handle
    for _,obj in ipairs(handle:GetChildren()) do
        if obj~=light and obj:IsA("PointLight") and obj.Name=="WhipCoreLight" then obj:Destroy() end
    end
    tool:SetAttribute("LashboundInsignia",id)
end
local function bind(tool)
    if not tool:IsA("Tool") or (tool.Name~="LashboundWhip" and tool.Name~="FounderTempest") then return end
    if seen[tool] then return end
    seen[tool]=true
    local function update()
        build(tool)
        local handle=tool:FindFirstChild("Handle")
        local att=handle and handle:FindFirstChild("LashboundAuraPoint")
        local particle=att and att:FindFirstChild("WhipAura")
        local light=handle and handle:FindFirstChild("WhipCoreLight")
        local worn=tool.Parent and tool.Parent:IsA("Model") and tool.Parent:FindFirstChildOfClass("Humanoid")~=nil
        if particle then particle.Enabled=worn and true or false end
        if light then light.Enabled=worn and true or false end
    end
    tool:GetAttributeChangedSignal("WhipId"):Connect(update)
    tool.Equipped:Connect(update)
    tool.Unequipped:Connect(update)
    task.defer(update)
end
local function bindPlayer(player)
    local backpack=player:WaitForChild("Backpack",12)
    if backpack then
        backpack.ChildAdded:Connect(bind)
        for _,obj in ipairs(backpack:GetChildren()) do bind(obj) end
    end
    player.CharacterAdded:Connect(function(ch)
        ch.ChildAdded:Connect(bind)
        for _,obj in ipairs(ch:GetChildren()) do bind(obj) end
    end)
    if player.Character then
        player.Character.ChildAdded:Connect(bind)
        for _,obj in ipairs(player.Character:GetChildren()) do bind(obj) end
    end
end
Players.PlayerAdded:Connect(bindPlayer)
for _,player in ipairs(Players:GetPlayers()) do task.defer(bindPlayer,player) end
