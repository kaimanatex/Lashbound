-- One local Highlight + optional light per active status, never hundreds of particles.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local colors={
    Slow=Color3.fromRGB(92,175,255),
    Freeze=Color3.fromRGB(182,249,255),
    Burn=Color3.fromRGB(255,106,39),
    Poison=Color3.fromRGB(108,245,91),
    Shock=Color3.fromRGB(255,232,80),
}
local tracked=setmetatable({}, {__mode="k"})
local player=Players.LocalPlayer
local tickAt=0
local function strip(model)
    local x=tracked[model]
    if x then
        for _,v in ipairs(x) do if v.Parent then v:Destroy() end end
        tracked[model]=nil
    end
end
local function apply(model,status)
    if not model:IsA("Model") then return end
    local old=tracked[model]
    if old and old[1].Parent and old[1]:GetAttribute("Type")==status then return end
    strip(model)
    local hi=Instance.new("Highlight")
    hi.Name="LashboundElementalGlow"
    hi.FillColor=colors[status]
    hi.OutlineColor=colors[status]
    hi.FillTransparency=.62
    hi.OutlineTransparency=.04
    hi.DepthMode=Enum.HighlightDepthMode.Occluded
    hi.Adornee=model
    hi:SetAttribute("Type",status)
    hi.Parent=model
    local head=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    local objects={hi}
    if head then
        local gui=Instance.new("BillboardGui")
        gui.Name="StatusLabel"
        gui.Size=UDim2.fromOffset(92,20)
        gui.StudsOffsetWorldSpace=Vector3.new(0,4.9,0)
        gui.MaxDistance=100
        gui.AlwaysOnTop=true
        gui.Adornee=head
        gui.Parent=gui.Parent or head
        local text=Instance.new("TextLabel")
        text.BackgroundTransparency=1
        text.Size=UDim2.fromScale(1,1)
        text.Text=status:upper()
        text.TextColor3=colors[status]
        text.TextStrokeTransparency=.1
        text.Font=Enum.Font.GothamBlack
        text.TextScaled=true
        text.Parent=gui
        table.insert(objects,gui)
    end
    tracked[model]=objects
end
RunService.Heartbeat:Connect(function()
    if os.clock()-tickAt<.22 then return end
    tickAt=os.clock()
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local models={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(models,p.Character) end
    end
    local arena=Workspace:FindFirstChild("LashboundBattleArena")
    if arena then
        for _,folder in ipairs(arena:GetChildren()) do
            if folder.Name=="LashboundBots" or folder.Name=="LashboundBosses" then
                for _,model in ipairs(folder:GetChildren()) do
                    if model:IsA("Model") then table.insert(models,model) end
                end
            end
        end
    end
    local seen={}
    for _,model in ipairs(models) do
        seen[model]=true
        local part=model:FindFirstChild("HumanoidRootPart")
        local status=model:GetAttribute("LashboundStatus")
        local expiry=model:GetAttribute("LashboundStatusUntil") or 0
        if part and (root.Position-part.Position).Magnitude<160 and colors[status]
            and expiry>Workspace:GetServerTimeNow() then
            apply(model,status)
        else
            strip(model)
        end
    end
    for model in pairs(tracked) do if not seen[model] then strip(model) end end
end)
