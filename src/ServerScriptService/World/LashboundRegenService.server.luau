-- V11: Players regenerate only after 10 full seconds with no attack or damage.
-- Regeneration does not count as damage and won't reset its own timer.
local Players=game:GetService("Players")
local REGEN_DELAY=10
local HEAL_PER_SECOND=6
local active={}
local function bind(player,character)
    local hum=character:WaitForChild("Humanoid",8)
    if not hum then return end
    local serial=(active[player] and active[player].serial or 0)+1
    active[player]={hum=hum,serial=serial}
    player:SetAttribute("LastCombatAt",os.clock())
    local previous=hum.Health
    hum.HealthChanged:Connect(function(value)
        if active[player] and active[player].serial==serial and value+0.05<previous then
            player:SetAttribute("LastCombatAt",os.clock())
        end
        previous=value
    end)
    hum.Died:Connect(function()if active[player] and active[player].serial==serial then active[player]=nil end end)
end
local function init(player)
    player.CharacterAdded:Connect(function(char)task.spawn(bind,player,char)end)
    if player.Character then task.spawn(bind,player,player.Character) end
end
Players.PlayerAdded:Connect(init)
Players.PlayerRemoving:Connect(function(p)active[p]=nil end)
for _,p in ipairs(Players:GetPlayers()) do init(p) end
while task.wait(.5) do
    local now=os.clock()
    for player,state in pairs(active) do
        local hum=state.hum
        if player.Parent==Players and hum.Parent and hum.Health>0 and hum.Health<hum.MaxHealth then
            local last=player:GetAttribute("LastCombatAt") or now
            if player:GetAttribute("Zone")=="Arena" and now-last>=REGEN_DELAY then
                hum.Health=math.min(hum.MaxHealth,hum.Health+HEAL_PER_SECOND*.5)
                player:SetAttribute("Regenerating",true)
            else
                player:SetAttribute("Regenerating",false)
            end
        elseif player.Parent==Players then
            player:SetAttribute("Regenerating",false)
        end
    end
end
