-- V17: server-authoritative health loss is the only trigger for visual player flinches.
-- Applies to PvP, Sentinels, dogs and boss hits; never alters controls or damage.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

local function monitor(character)
    local hum=character:WaitForChild("Humanoid",8)
    if not hum then return end
    local previous=hum.Health
    local lastAt=-100
    hum.HealthChanged:Connect(function(health)
        if health<previous-.5 and health>0 then
            local now=Workspace:GetServerTimeNow()
            if now-lastAt>.12 then
                lastAt=now
                character:SetAttribute("LashboundHitDamage",previous-health)
                character:SetAttribute("LashboundHitAt",now)
            end
        end
        previous=health
    end)
end
local function connect(player)
    player.CharacterAdded:Connect(monitor)
    if player.Character then task.defer(monitor,player.Character) end
end
Players.PlayerAdded:Connect(connect)
for _,player in ipairs(Players:GetPlayers()) do connect(player) end
