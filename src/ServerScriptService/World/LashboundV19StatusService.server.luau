-- Server-authoritative elemental statuses. Effects cannot be requested by clients.
local SSS=game:GetService("ServerScriptService")
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local Apply=SSS:FindFirstChild("LashboundApplyStatus") or Instance.new("BindableEvent")
Apply.Name="LashboundApplyStatus"
Apply.Parent=SSS
local alive=setmetatable({}, {__mode="k"})
local priority={Freeze=5,Shock=4,Poison=3,Burn=2,Slow=1}
local kinds={
    Slow={color=Color3.fromRGB(105,190,255),speed=.52},
    Freeze={color=Color3.fromRGB(178,244,255),speed=0},
    Burn={color=Color3.fromRGB(255,103,43),speed=1,damage=2.5},
    Poison={color=Color3.fromRGB(120,255,115),speed=.9,damage=2},
    Shock={color=Color3.fromRGB(255,238,83),speed=.20},
}
local function setDisplay(model,states)
    local best=nil
    local now=Workspace:GetServerTimeNow()
    for name,state in pairs(states) do
        if state.untilTime>now and (not best or priority[name]>priority[best]) then best=name end
    end
    model:SetAttribute("LashboundStatus",best or "")
    model:SetAttribute("LashboundStatusUntil",best and states[best].untilTime or 0)
end
Apply.Event:Connect(function(model,name,duration,attackerId)
    if typeof(model)~="Instance" or not model:IsA("Model") or not model.Parent then return end
    local spec=kinds[name]
    local hum=model:FindFirstChildOfClass("Humanoid")
    if not spec or not hum or hum.Health<=0 then return end
    if model:GetAttribute("LashboundBoss") then return end -- boss resistance
    duration=math.clamp(tonumber(duration) or 1,.2,8)
    local item=alive[model]
    if not item then
        item={hum=hum,baseSpeed=hum.WalkSpeed,states={},tick=Workspace:GetServerTimeNow()}
        alive[model]=item
    end
    item.states[name]={untilTime=Workspace:GetServerTimeNow()+duration,attackerId=attackerId}
    setDisplay(model,item.states)
end)
task.spawn(function()
    while script.Parent do
        task.wait(.20)
        local now=Workspace:GetServerTimeNow()
        for model,item in pairs(alive) do
            local hum=item.hum
            if not model.Parent or not hum.Parent or hum.Health<=0 then
                alive[model]=nil
                if model.Parent then model:SetAttribute("LashboundStatus","");model:SetAttribute("LashboundStatusUntil",0) end
            else
                local speed=1
                local active=false
                for kind,s in pairs(item.states) do
                    if now>=s.untilTime then
                        item.states[kind]=nil
                    else
                        active=true
                        speed=math.min(speed,kinds[kind].speed)
                    end
                end
                if not active then
                    if hum.WalkSpeed<item.baseSpeed then hum.WalkSpeed=item.baseSpeed end
                    model:SetAttribute("LashboundStatus","")
                    model:SetAttribute("LashboundStatusUntil",0)
                    alive[model]=nil
                else
                    hum.WalkSpeed=item.baseSpeed*speed
                    setDisplay(model,item.states)
                    if now-item.tick>=.8 then
                        item.tick=now
                        local total=0
                        for kind,s in pairs(item.states) do
                            if kinds[kind].damage then
                                total+=kinds[kind].damage
                                if s.attackerId then hum:SetAttribute("LastAttackerId",s.attackerId) end
                            end
                        end
                        if total>0 then
                            local p=Players:GetPlayerFromCharacter(model)
                            if p then p:SetAttribute("LastCombatAt",os.clock()) end
                            hum:TakeDamage(total)
                        end
                    end
                end
            end
        end
    end
end)
