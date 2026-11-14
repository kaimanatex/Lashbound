-- LASHBOUND V12: reliable, independent attack sound controller.
-- Built-in Roblox sounds play immediately without custom asset upload.
-- Upload the original WAV pack and populate LashboundSoundIds for genuine whip cracks.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local me=Players.LocalPlayer
local ids=require(RS:WaitForChild("LashboundSoundIds"))
local feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local fallback={
  WhipCrack1="rbxasset://sounds/swordslash.wav",
  WhipCrack2="rbxasset://sounds/swordslash.wav",
  WhipCrack3="rbxasset://sounds/swordlunge.wav",
  WhipCrackHeavy="rbxasset://sounds/swordlunge.wav",
  WhipCrackPower="rbxasset://sounds/swordlunge.wav",
  Hit="rbxasset://sounds/impact_generic.mp3",
}
local last={}
local function play(key,volume,speed)
    local asset=ids[key]
    local uri=(type(asset)=="number" and asset>0) and "rbxassetid://"..asset or fallback[key]
    if not uri then return end
    local s=Instance.new("Sound")
    s.Name="LashboundAudible_"..key
    s.SoundId=uri
    s.Volume=volume
    s.PlaybackSpeed=speed
    s.Parent=SoundService
    s:Play()
    Debris:AddItem(s,3)
end
feedback.OnClientEvent:Connect(function(kind,_,payload)
    if kind~="Visual" or type(payload)~="table" or typeof(payload.origin)~="Vector3" then return end
    local event=payload.kind
    if event~="Attack" and event~="Heavy" and event~="Power" and event~="Impact" then return end
    local ch=me.Character
    local root=ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance=(root.Position-payload.origin).Magnitude
    if distance>115 then return end
    local factor=math.clamp(1-distance/145,.18,1)
    local key=event=="Attack" and "WhipCrack"..math.clamp(tonumber(payload.step) or 1,1,3)
          or event=="Heavy" and "WhipCrackHeavy"
          or event=="Power" and "WhipCrackPower" or "Hit"
    local now=os.clock()
    local dedupeKey=tostring(payload.actorUserId or "world")..":"..key
    if now-(last[dedupeKey] or -20)<.08 then return end
    last[dedupeKey]=now
    if event=="Impact" then
        play("Hit",.46*factor,1.12)
    else
        -- Sound onset follows the physical whip tip rather than input press.
        local delayTime=event=="Heavy" and .33 or event=="Power" and .37 or .29
        if typeof(payload.impactServerTime)=="number" then
            delayTime=math.max(0,payload.impactServerTime-workspace:GetServerTimeNow())
        end
        task.delay(delayTime,function()
            if not script.Parent then return end
            play(key,.9*factor,event=="Attack" and (payload.step==2 and 1.22 or payload.step==3 and .89 or 1.07) or .94)
            if (type(ids[key])~="number" or ids[key]==0) then
                play("Hit",.22*factor,1.46) -- brief crack transient on fallback
            end
        end)
    end
end)
