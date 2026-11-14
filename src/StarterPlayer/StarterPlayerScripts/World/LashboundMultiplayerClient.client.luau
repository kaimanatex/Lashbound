-- LASHBOUND V14: optional friend invitations and live same-server player count.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SocialService=game:GetService("SocialService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="LashboundMultiplayerHUD"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.Parent=player:WaitForChild("PlayerGui")

local counter=Instance.new("TextLabel")
counter.Name="LivePopulation"
counter.Position=UDim2.fromOffset(12,145)
counter.Size=UDim2.fromOffset(258,31)
counter.BackgroundColor3=Color3.fromRGB(15,29,47)
counter.BackgroundTransparency=.12
counter.BorderSizePixel=0
counter.TextColor3=Color3.fromRGB(163,242,229)
counter.Font=Enum.Font.GothamBold
counter.TextSize=13
counter.Text="PLAYERS LOADING..."
counter.Parent=gui
local cr=Instance.new("UICorner")
cr.CornerRadius=UDim.new(0,8)
cr.Parent=counter

local invite=Instance.new("TextButton")
invite.Name="InviteFriends"
invite.Position=UDim2.new(1,-165,0,166)
invite.Size=UDim2.fromOffset(153,42)
invite.Text="INVITE FRIENDS"
invite.Font=Enum.Font.GothamBold
invite.TextSize=14
invite.TextColor3=Color3.fromRGB(246,250,255)
invite.BackgroundColor3=Color3.fromRGB(61,104,139)
invite.BorderSizePixel=0
invite.Parent=gui
local icr=Instance.new("UICorner")
icr.CornerRadius=UDim.new(0,10)
icr.Parent=invite

local function update()
    local total=RS:GetAttribute("LashboundPlayersTotal") or #Players:GetPlayers()
    local lobby=RS:GetAttribute("LashboundPlayersLobby") or 0
    local arena=RS:GetAttribute("LashboundPlayersArena") or 0
    counter.Text=string.format("PLAYERS %d/%d  |  FIGHTING %d",total,Players.MaxPlayers,arena)
    invite.Visible=true
end
for _,attr in ipairs({"LashboundPlayersTotal","LashboundPlayersLobby","LashboundPlayersArena"}) do
    RS:GetAttributeChangedSignal(attr):Connect(update)
end
update()

local busy=false
invite.Activated:Connect(function()
    if busy then return end
    busy=true
    invite.Text="CHECKING INVITES..."
    if RunService:IsStudio() then
        invite.Text="PUBLISH TO INVITE"
        task.wait(2)
        invite.Text="INVITE FRIENDS"
        busy=false
        return
    end
    local ok,canInvite=pcall(function()
        return SocialService:CanSendGameInviteAsync(player)
    end)
    if ok and canInvite then
        local prompted,err=pcall(function()
            SocialService:PromptGameInvite(player)
        end)
        if not prompted then
            warn("[Lashbound Multiplayer] Invite prompt unavailable: ",err)
            invite.Text="INVITE UNAVAILABLE"
        end
    else
        invite.Text="INVITE UNAVAILABLE"
    end
    task.wait(2)
    invite.Text="INVITE FRIENDS"
    busy=false
end)
