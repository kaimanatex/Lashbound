-- LASHBOUND V14: authoritative same-server multiplayer population + lobby display.
-- Shared per-server count only. Coins, inventories and tools remain per-player.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local lobby = Workspace:WaitForChild("LashboundLobby", 25)
local board, counter
if lobby then
    board = Instance.new("Part")
    board.Name = "MultiplayerLobbySignAnchor"
    board.Anchored = true
    board.CanCollide = false
    board.CanTouch = false
    board.CanQuery = false
    board.Transparency = 1
    board.Size = Vector3.new(1,1,1)
    board.CFrame = CFrame.new(-34, 11, -21)
    board.Parent = lobby

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MultiplayerLobbySign"
    billboard.Adornee = board
    billboard.Size = UDim2.fromOffset(330,136)
    billboard.MaxDistance = 90
    billboard.AlwaysOnTop = false
    billboard.Parent = board

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromScale(1,1)
    panel.BackgroundColor3 = Color3.fromRGB(12, 25, 42)
    panel.BackgroundTransparency = .09
    panel.BorderSizePixel = 0
    panel.Parent = billboard
    local rounded = Instance.new("UICorner")
    rounded.CornerRadius = UDim.new(0, 13)
    rounded.Parent = panel
    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(74, 219, 214)
    border.Thickness = 2
    border.Parent = panel

    local function textLabel(name, content, y, height, size, color)
        local l = Instance.new("TextLabel")
        l.Name = name
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, -14, 0, height)
        l.Position = UDim2.fromOffset(7,y)
        l.Text = content
        l.Font = Enum.Font.GothamBold
        l.TextSize = size
        l.TextColor3 = color
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.Parent = panel
        return l
    end
    textLabel("Header", "LASHBOUND · LIVE BATTLE", 8, 30, 18, Color3.fromRGB(103,235,226))
    counter=textLabel("Population", "LOBBY 0  •  ARENA 0", 44, 35, 20, Color3.fromRGB(243,248,255))
    textLabel("Instructions", "Enter the green door to join the fight!", 86, 29, 13, Color3.fromRGB(177,204,231))
end

local function refresh(leavingPlayer)
    local players=Players:GetPlayers()
    local lobbyCount,arenaCount,total=0,0,0
    for _,p in ipairs(players) do
        if p~=leavingPlayer then
            total+=1
            if p:GetAttribute("Zone")=="Arena" then
                arenaCount += 1
            else
                lobbyCount += 1
            end
        end
    end
    RS:SetAttribute("LashboundPlayersTotal",total)
    RS:SetAttribute("LashboundPlayersLobby",lobbyCount)
    RS:SetAttribute("LashboundPlayersArena",arenaCount)
    if counter then
        counter.Text=string.format("LOBBY %d  •  ARENA %d", lobbyCount,arenaCount)
    end
end

local bindings={}
local function track(player)
    if bindings[player] then return end
    bindings[player]=player:GetAttributeChangedSignal("Zone"):Connect(refresh)
    refresh()
end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(function(player)
    if bindings[player] then bindings[player]:Disconnect();bindings[player]=nil end
    -- PlayerRemoving can fire while still in Players: discount departing user immediately.
    refresh(player)
end)
for _,p in ipairs(Players:GetPlayers()) do track(p) end
refresh()
print("[Lashbound Multiplayer] Live lobby and arena population ready")
