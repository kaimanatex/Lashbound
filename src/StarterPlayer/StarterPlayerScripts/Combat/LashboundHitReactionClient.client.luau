-- V17: additive local flinch to R6/R15 shoulders and torso on replicated health loss.
-- PreSimulation overlay leaves combat/server C0 poses and locomotion intact.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local tracked={}
local active={}

local function watch(character)
    if tracked[character] then return end
    tracked[character]=true
    local upper=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local root=character:FindFirstChild("HumanoidRootPart")
    if not upper or not root then
        task.delay(.3,function() if character.Parent then tracked[character]=nil;watch(character) end end)
        return
    end
    local right=upper:FindFirstChild("RightShoulder") or upper:FindFirstChild("Right Shoulder")
    local left=upper:FindFirstChild("LeftShoulder") or upper:FindFirstChild("Left Shoulder")
    local lower=character:FindFirstChild("LowerTorso")
    local torso=upper:FindFirstChild("Waist") or (lower and lower:FindFirstChild("Root")) or root:FindFirstChild("RootJoint")
    if not right or not left then
        task.delay(.25,function()
            if character.Parent then tracked[character]=nil;watch(character) end
        end)
        return
    end
    local function react()
        local damage=tonumber(character:GetAttribute("LashboundHitDamage")) or 10
        local time=tonumber(character:GetAttribute("LashboundHitAt")) or Workspace:GetServerTimeNow()
        active[character]={right=right,left=left,torso=torso,at=time,strength=math.clamp(.6+damage/90,.6,1.4)}
    end
    character:GetAttributeChangedSignal("LashboundHitAt"):Connect(react)
    if character:GetAttribute("LashboundHitAt") then react() end
end
local function playerWatch(player)
    player.CharacterAdded:Connect(function(char) task.defer(watch,char) end)
    if player.Character then task.defer(watch,player.Character) end
end
Players.PlayerAdded:Connect(playerWatch)
for _,p in ipairs(Players:GetPlayers()) do playerWatch(p) end

RunService.PreSimulation:Connect(function(_dt)
    local now=Workspace:GetServerTimeNow()
    for character,state in pairs(active) do
        local elapsed=now-state.at
        if elapsed>.42 or not character.Parent or not state.right.Parent then
            if state.right.Parent then state.right.Transform=CFrame.identity end
            if state.left.Parent then state.left.Transform=CFrame.identity end
            if state.torso and state.torso.Parent then state.torso.Transform=CFrame.identity end
            active[character]=nil
        else
            -- Fast recoil, settling overshoot, then gentle reset.
            local bump=math.sin(math.pi*math.clamp(elapsed/.42,0,1))
            local recoil=bump*state.strength
            state.right.Transform=CFrame.Angles(math.rad(21)*recoil,0,math.rad(-18)*recoil)
            state.left.Transform=CFrame.Angles(math.rad(19)*recoil,0,math.rad(15)*recoil)
            if state.torso and state.torso.Parent then
                state.torso.Transform=CFrame.Angles(math.rad(12)*recoil,math.rad(8)*recoil,0)
            end
        end
    end
end)
