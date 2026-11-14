-- V37: animate the portal without changing the teleport trigger.
local RunService=game:GetService("RunService")
local lobby=workspace:WaitForChild("LashboundLobby")
local surface=lobby:WaitForChild("V37_PortalEnergySurface")
local light=surface:FindFirstChild("PortalGlow")
local t=0
local accumulated=0
local connection
connection=RunService.Heartbeat:Connect(function(dt)
    if not surface.Parent then connection:Disconnect() return end
    accumulated+=dt
    if accumulated<1/15 then return end
    t+=accumulated
    accumulated=0
    surface.Transparency=.25+.14*math.sin(t*2.1)
    surface.Color=Color3.fromRGB(110+math.floor(25*math.sin(t*1.7)),85,235)
    if light then light.Brightness=2.1+.65*math.sin(t*2.1) end
end)
