-- Local-only hovering/spinning weapons. The stands and shop interactions remain stable.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local lobby=workspace:WaitForChild("LashboundLobby")
local gallery=lobby:WaitForChild("LobbyWhipGallery")
local displays={}
for _,stand in ipairs(gallery:GetChildren()) do
    if stand:IsA("Folder") then
        local grip=stand:FindFirstChild("GripHandle")
        if grip then
            local pieces={}
            for _,piece in ipairs(stand:GetChildren()) do
                if piece:IsA("BasePart") and piece~=stand:FindFirstChild("DisplayStand")
                    and piece.Name~="TrimRing" and piece.Name~="Cradle" and piece.Name~="NameAnchor" then
                    table.insert(pieces,{part=piece,base=piece.CFrame})
                end
            end
            table.insert(displays,{pivot=grip.Position,parts=pieces})
        end
    end
end
local accum=0
local phase=0
RunService.RenderStepped:Connect(function(dt)
    accum+=dt
    if accum<1/25 then return end
    local tick=math.min(accum,.08);accum=0;phase+=tick
    if player:GetAttribute("Zone")~="Lobby" then return end
    for idx,dis in ipairs(displays) do
        local lift=.48+math.sin(phase*1.6+idx*.45)*.26
        local spin=CFrame.new(dis.pivot+Vector3.new(0,lift,0))*CFrame.Angles(0,phase*.65+idx*.12,0)*CFrame.new(-dis.pivot)
        for _,entry in ipairs(dis.parts) do
            if entry.part.Parent then entry.part.CFrame=spin*entry.base end
        end
    end
end)
