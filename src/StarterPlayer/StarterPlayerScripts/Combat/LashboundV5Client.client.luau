-- LASHBOUND V9 | Map HUD, one-way arena entry, original sound hooks, and combat controls.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local StarterGui=game:GetService("StarterGui")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local Config=require(RS:WaitForChild("WhipConfig"))
local SoundIds=require(RS:WaitForChild("LashboundSoundIds"))
-- These remotes are PREBUILT in ReplicatedStorage: no server-startup wait.
local remotes=RS:WaitForChild("LashboundV5Remotes",8)
if not remotes then warn("[Lashbound V5] Missing remotes folder") return end
local Action=remotes:WaitForChild("Action",8)
local Feedback=remotes:WaitForChild("Feedback",8)
if not Action or not Feedback then warn("[Lashbound V5] Missing events") return end
local bg=Color3.fromRGB(15,21,37)
local panel=Color3.fromRGB(31,42,64)
local primary=Color3.fromRGB(90,225,220)
local white=Color3.fromRGB(245,249,255)
local muted=Color3.fromRGB(179,196,221)

local gui=Instance.new("ScreenGui")
gui.Name="LashboundV5HUD"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild("PlayerGui")
local function corner(x,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=x
end
local function stroke(x,col)
    local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=1.5; s.Parent=x
end
local function frame(parent,name,pos,size,color)
    local f=Instance.new("Frame")
    f.Name=name; f.Position=pos; f.Size=size
    f.BackgroundColor3=color or bg; f.BackgroundTransparency=.07
    f.BorderSizePixel=0; f.Parent=parent; corner(f,11)
    return f
end
local function label(parent,name,text,pos,size,sz,col)
    local v=Instance.new("TextLabel")
    v.Name=name; v.Position=pos; v.Size=size
    v.BackgroundTransparency=1; v.Text=text; v.TextColor3=col or white
    v.Font=Enum.Font.GothamBold; v.TextSize=sz or 16
    v.TextWrapped=true; v.TextXAlignment=Enum.TextXAlignment.Left
    v.Parent=parent
    return v
end
local function button(parent,name,text,pos,size,color)
    local b=Instance.new("TextButton")
    b.Name=name; b.Text=text; b.Position=pos; b.Size=size
    b.BackgroundColor3=color or panel; b.TextColor3=white
    b.BorderSizePixel=0; b.Font=Enum.Font.GothamBold
    b.TextSize=17; b.TextWrapped=true; b.Parent=parent
    corner(b,12)
    return b
end
local top=frame(gui,"Top",UDim2.fromOffset(12,10),UDim2.fromOffset(320,107),bg)
stroke(top,Color3.fromRGB(60,92,117))
label(top,"Title","LASHBOUND V53 · WHIP WARS",UDim2.fromOffset(12,7),UDim2.fromOffset(296,27),19,primary)
local status=label(top,"Status","LOBBY  •  ENTER THE PORTAL",UDim2.fromOffset(12,36),UDim2.fromOffset(300,23),13,muted)
local stats=label(top,"Stats","0 COINS  |  0 KOs",UDim2.fromOffset(12,64),UDim2.fromOffset(296,25),15,white)
local whipBadge=label(top,"WhipBadge","ROOKIE ROPE",UDim2.fromOffset(12,89),UDim2.fromOffset(296,16),13,primary)
-- Five-minute countdown is synced to server time, not to any player's device clock.
local mapHud=frame(gui,"MapRotationHUD",UDim2.new(.5,-189,0,66),UDim2.fromOffset(378,60),bg)
stroke(mapHud,Color3.fromRGB(97,112,174))
local mapTitle=label(mapHud,"MapTitle","MAP LOADING...",UDim2.fromOffset(12,3),UDim2.new(1,-24,0,28),17,primary)
mapTitle.TextXAlignment=Enum.TextXAlignment.Center
local mapTime=label(mapHud,"MapCountdown","NEXT MAP IN 05:00",UDim2.fromOffset(12,29),UDim2.new(1,-24,0,24),15,white)
mapTime.TextXAlignment=Enum.TextXAlignment.Center
-- The boss timer is shown ONLY after an actual boss defeat.
local bossStatus=label(gui,"BossStatus","",UDim2.new(.5,-188,0,131),UDim2.fromOffset(376,26),14,Color3.fromRGB(255,193,112))
bossStatus.TextXAlignment=Enum.TextXAlignment.Center
bossStatus.TextStrokeTransparency=.35
local shopButton=button(gui,"ShopButton","WHIP SHOP  [B]",UDim2.new(1,-165,0,10),UDim2.fromOffset(153,49),Color3.fromRGB(58,87,120))
local equipButton=button(gui,"EquipButton","EQUIP WHIP",UDim2.new(1,-165,0,66),UDim2.fromOffset(153,38),Color3.fromRGB(65,103,110))
local wheelButton=button(gui,"WheelButton","SPIN 200 · 1% LEGEND",UDim2.new(1,-165,0,113),UDim2.fromOffset(153,42),Color3.fromRGB(157,100,51))
wheelButton.TextSize=12
local instructions=frame(gui,"Instructions",UDim2.new(.5,-205,0,10),UDim2.fromOffset(410,46),bg)
local guide=label(instructions,"Guide","WALK INTO THE GLOWING DOOR TO BATTLE",UDim2.fromOffset(10,4),UDim2.new(1,-20,1,-8),14,white)
guide.TextXAlignment=Enum.TextXAlignment.Center
local notice=frame(gui,"Notice",UDim2.new(.5,-180,.18,0),UDim2.fromOffset(360,48),panel)
notice.Visible=false
local noticeText=label(notice,"NoticeText","",UDim2.fromOffset(8,4),UDim2.new(1,-16,1,-8),16,white)
noticeText.TextXAlignment=Enum.TextXAlignment.Center
local info=frame(gui,"EquippedPanel",UDim2.fromOffset(12,0),UDim2.fromOffset(285,66),bg)
info.AnchorPoint=Vector2.new(0,1)
info.Position=UDim2.new(0,12,1,-12)
local selectedName=label(info,"Selected","ROOKIE ROPE",UDim2.fromOffset(12,5),UDim2.fromOffset(260,23),19,primary)
local powerName=label(info,"Power","Q / POWER: LASH DASH",UDim2.fromOffset(12,29),UDim2.fromOffset(260,23),13,white)
local attack=button(gui,"Attack","WHIP\nTAP",UDim2.new(1,-145,1,-147),UDim2.fromOffset(128,128),Color3.fromRGB(30,142,153))
corner(attack,60);stroke(attack,Color3.fromRGB(144,248,247))
local special=button(gui,"Special","POWER\nQ",UDim2.new(1,-276,1,-114),UDim2.fromOffset(113,96),Color3.fromRGB(101,69,159))
local dodge=button(gui,"Dodge","DODGE\nE",UDim2.new(1,-268,1,-210),UDim2.fromOffset(94,79),Color3.fromRGB(47,96,129))
local timer=label(gui,"Timer","",UDim2.new(1,-282,1,-246),UDim2.fromOffset(255,23),12,muted)
local abilityTrack=frame(gui,"PowerCooldownTrack",UDim2.new(1,-276,1,-13),UDim2.fromOffset(110,8),Color3.fromRGB(42,48,70))
local abilityFill=frame(abilityTrack,"Fill",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(190,134,247))
local dodgeTrack=frame(gui,"DodgeCooldownTrack",UDim2.new(1,-269,1,-20),UDim2.fromOffset(90,7),Color3.fromRGB(42,48,70))
local dodgeFill=frame(dodgeTrack,"Fill",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(105,211,248))
timer.TextXAlignment=Enum.TextXAlignment.Right
local connection=label(gui,"Connection","CONNECTING...",UDim2.new(0,12,0,120),UDim2.fromOffset(320,20),12,Color3.fromRGB(255,183,91))
local doorButton=button(gui,"DoorButton","ENTER ARENA",UDim2.new(.5,-95,1,-64),UDim2.fromOffset(190,48),Color3.fromRGB(49,129,110))
doorButton.Visible=false


local shade=frame(gui,"ShopOverlay",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(0,0,0))
shade.BackgroundTransparency=.25; shade.Visible=false; shade.ZIndex=20
local shop=frame(shade,"Shop",UDim2.new(.5,-270,.5,-245),UDim2.fromOffset(540,490),bg)
shop.ZIndex=21; stroke(shop,primary)
local header=label(shop,"Header","WHIP VAULT",UDim2.fromOffset(18,10),UDim2.fromOffset(420,40),26,primary)
header.ZIndex=23
local shopStatus=label(shop,"ShopStatus","Select a whip to view its price and unlock it.",
    UDim2.fromOffset(18,53),UDim2.new(1,-38,0,29),13,Color3.fromRGB(227,207,155))
shopStatus.ZIndex=25
local function shopMessage(message,success)
    shopStatus.Text=tostring(message)
    shopStatus.TextColor3=success and Color3.fromRGB(145,244,185) or Color3.fromRGB(255,196,142)
end
local close=button(shop,"Close","X",UDim2.new(1,-55,0,12),UDim2.fromOffset(42,37),Color3.fromRGB(110,57,66))
close.ZIndex=24
local scroller=Instance.new("ScrollingFrame")
scroller.Name="Whips"; scroller.Position=UDim2.fromOffset(12,86)
scroller.Size=UDim2.new(1,-24,1,-98)
scroller.BackgroundTransparency=1; scroller.BorderSizePixel=0
scroller.ScrollBarThickness=6; scroller.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroller.CanvasSize=UDim2.fromOffset(0,0); scroller.ZIndex=22
scroller.Parent=shop
local layout=Instance.new("UIListLayout")
layout.Padding=UDim.new(0,8); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=scroller
local shopButtons={}
-- Never leave the Vault on 'Checking...' if the server fails to reply.
local shopRequestSerial=0
local shopAwaitingReply=false
local function requestShop(action,id,message)
    shopRequestSerial+=1
    local requestSerial=shopRequestSerial
    shopAwaitingReply=true
    shopMessage(message or "Contacting the combat server...",true)
    Action:FireServer(action,id)
    task.delay(6,function()
        if shopAwaitingReply and shopRequestSerial==requestSerial and shade.Visible then
            shopAwaitingReply=false
            shopMessage("Combat server did not respond. Check Studio Output for server errors.",false)
        end
    end)
end
for i,id in ipairs(Config.Order) do
    local cfg=Config.Whips[id]
    local card=frame(scroller,id,UDim2.new(),UDim2.new(1,-10,0,84),panel)
    card.LayoutOrder=i; card.ZIndex=22
    local name=label(card,"Name",cfg.Name,UDim2.fromOffset(12,4),UDim2.new(1,-150,0,27),18,cfg.Color)
    name.ZIndex=23
    local desc=label(card,"Desc",cfg.PowerName,UDim2.fromOffset(12,31),UDim2.new(1,-150,0,22),13,muted)
    desc.ZIndex=23
    local stat=label(card,"Stat","DAMAGE "..cfg.Damage.."   RANGE "..cfg.Range,UDim2.fromOffset(12,54),UDim2.new(1,-150,0,20),12,white)
    stat.ZIndex=23
    local buy=button(card,"Equip",cfg.Legendary and "WHEEL 1%" or "◈ "..cfg.Price,UDim2.new(1,-132,.5,-20),UDim2.fromOffset(122,40),Color3.fromRGB(59,111,118))
    buy.TextSize=14; buy.ZIndex=24
    buy.Activated:Connect(function()
        if player:GetAttribute("Zone")=="Arena" then return end
        requestShop("Shop",id,"Checking "..cfg.Name.." with the server...")
    end)
    shopButtons[id]=buy
end
-- Lobby-only 200 earned-coin prize wheel. Server chooses result and debits wallet.
local wheelShade=frame(gui,"WheelOverlay",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(2,5,13))
wheelShade.BackgroundTransparency=.24;wheelShade.ZIndex=30;wheelShade.Visible=false
local wheelPanel=frame(wheelShade,"WheelPanel",UDim2.fromScale(.5,.5),UDim2.fromOffset(430,500),Color3.fromRGB(27,26,52))
wheelPanel.AnchorPoint=Vector2.new(.5,.5);wheelPanel.ZIndex=31
stroke(wheelPanel,Color3.fromRGB(246,194,92))
local wheelScale=Instance.new("UIScale");wheelScale.Parent=wheelPanel
local wheelHeader=label(wheelPanel,"WheelTitle","THE SOVEREIGN WHEEL",UDim2.fromOffset(20,10),UDim2.fromOffset(340,35),24,Color3.fromRGB(255,206,91))
wheelHeader.ZIndex=33
local wheelClose=button(wheelPanel,"WheelClose","X",UDim2.fromOffset(380,12),UDim2.fromOffset(36,34),Color3.fromRGB(112,58,69))
wheelClose.ZIndex=35
local wheelDisc=frame(wheelPanel,"WheelFace",UDim2.fromOffset(136,49),UDim2.fromOffset(159,159),Color3.fromRGB(93,59,132))
wheelDisc.ZIndex=32;corner(wheelDisc,82)
for i=0,11 do
    local angle=math.pi*2*i/12
    local stripe=frame(wheelDisc,"Spoke"..i,UDim2.new(.5+math.sin(angle)*.29,-2,.5-math.cos(angle)*.29,-34),UDim2.fromOffset(4,68),i%3==0 and Color3.fromRGB(255,213,113) or i%3==1 and Color3.fromRGB(108,224,237) or Color3.fromRGB(212,111,247))
    stripe.Rotation=i*30;stripe.ZIndex=33
end
local wheelHub=frame(wheelDisc,"WheelHub",UDim2.new(.5,-19,.5,-19),UDim2.fromOffset(38,38),Color3.fromRGB(255,220,128))
wheelHub.ZIndex=34;corner(wheelHub,25)
local wheelPointer=label(wheelPanel,"WheelPointer","▼",UDim2.fromOffset(194,205),UDim2.fromOffset(60,24),21,Color3.fromRGB(255,223,111))
wheelPointer.ZIndex=35;wheelPointer.TextXAlignment=Enum.TextXAlignment.Center
local wheelOdds=label(wheelPanel,"WheelOdds","50% +20   |   30% +50   |   14% +100\n5% +200   |   1% LEGENDARY WHIP",UDim2.fromOffset(20,233),UDim2.fromOffset(390,55),17,white)
wheelOdds.ZIndex=33;wheelOdds.TextXAlignment=Enum.TextXAlignment.Center
local wheelNote=label(wheelPanel,"WheelNote","Costs 200 earned coins per spin. No Robux.\nLegend duplicate: +500 coins.",UDim2.fromOffset(25,289),UDim2.fromOffset(380,44),13,muted)
wheelNote.ZIndex=33;wheelNote.TextXAlignment=Enum.TextXAlignment.Center
local wheelReward=label(wheelPanel,"WheelReward","PAY 200 COINS TO SPIN!",UDim2.fromOffset(10,338),UDim2.fromOffset(410,34),14,Color3.fromRGB(255,209,91))
wheelReward.ZIndex=33;wheelReward.TextXAlignment=Enum.TextXAlignment.Center
local spinButton=button(wheelPanel,"SpinButton","SPIN · 200 COINS",UDim2.fromOffset(92,386),UDim2.fromOffset(246,51),Color3.fromRGB(153,106,57))
spinButton.ZIndex=35
if RunService:IsStudio() then
    local testLegend=button(wheelPanel,"TestLegend","STUDIO ONLY: UNLOCK LEGEND TO TEST",UDim2.fromOffset(53,448),UDim2.fromOffset(324,38),Color3.fromRGB(84,68,125))
    testLegend.ZIndex=36
    testLegend.TextSize=13
    testLegend.Activated:Connect(function()Action:FireServer("DevUnlockLegend") end)
end
local wheelAnimating=false
local lastSpinRequest=-100
local function closeWheel() wheelShade.Visible=false end
local function openWheel()
    if player:GetAttribute("Zone")=="Arena" then return end
    shade.Visible=false;wheelShade.Visible=true
end
wheelClose.Activated:Connect(closeWheel)
wheelButton.Activated:Connect(openWheel)
spinButton.Activated:Connect(function()
    if wheelAnimating or os.clock()-lastSpinRequest<1 then return end
    if player:GetAttribute("Zone")=="Arena" then return end
    local coins=player:GetAttribute("Coins") or 0
    if coins<Config.WheelPrice then wheelReward.Text="NOT ENOUGH COINS · 200 REQUIRED" return end
    lastSpinRequest=os.clock()
    Action:FireServer("SpinWheel")
end)

local function update()
    local id=player:GetAttribute("SelectedWhip") or "Rope"
    local cfg=Config.Whips[id] or Config.Whips.Rope
    local zone=player:GetAttribute("Zone") or "Lobby"
    local coin=player:GetAttribute("Coins") or 0
    stats.Text=tostring(coin).." COINS  |  "..tostring(player:GetAttribute("KOs") or 0).." KOs"
    selectedName.Text=cfg.Name
    selectedName.TextColor3=cfg.Color
    powerName.Text="Q / POWER: "..cfg.PowerName
    whipBadge.Text=cfg.Name.."  •  "..(player:GetAttribute("HasWhip") and "WHIP READY" or "EQUIPPING...")
    local wallet=player:GetAttribute("WalletSaveStatus") or "LOADING"
    status.Text=(zone=="Arena" and "BATTLE ARENA" or "SAFE LOBBY") .. "  •  SAVE: "..wallet
    wheelButton.Visible=zone~="Arena"
    shopButton.Visible=zone~="Arena"
    guide.Text=(zone=="Arena") and "DEFEAT SENTINELS • COLLECT +10 COIN DROPS • Q POWER • E DODGE" or "WALK THROUGH THE GLOWING DOOR  •  ONE WAY"
    for key,b in pairs(shopButtons) do
        if key==id then b.Text="EQUIPPED"
        elseif player:GetAttribute("Owns_"..key)==true then b.Text="EQUIP"
        elseif Config.Whips[key].Legendary then b.Text="WHEEL ONLY"
        else b.Text="◈ "..tostring(Config.Whips[key].Price) end
    end
end
-- Remove the default Reset Character escape route while actively fighting.
-- This can fail briefly while Roblox CoreScripts initialize, so retry only on zone changes.
local resetToken=0
local function updateReset()
    resetToken+=1
    local token=resetToken
    local inArena=player:GetAttribute("Zone")=="Arena"
    task.spawn(function()
        for _=1,8 do
            if resetToken~=token then return end
            local ok=pcall(function() StarterGui:SetCore("ResetButtonCallback",not inArena) end)
            if ok then return end
            task.wait(.35)
        end
    end)
end
for _,a in ipairs({"SelectedWhip","Coins","KOs","Zone","HasWhip","WalletSaveStatus"}) do player:GetAttributeChangedSignal(a):Connect(update) end
player:GetAttributeChangedSignal("Zone"):Connect(updateReset)
player:GetAttributeChangedSignal("WalletSaveStatus"):Connect(function()
    -- Re-query the server after the initial DataStore load if the shop is open.
    if shade.Visible and player:GetAttribute("WalletSaveStatus")~="LOADING" then
        requestShop("GetShop",nil,"Refreshing your saved whips...")
    end
end)
player:GetAttributeChangedSignal("Zone"):Connect(function()
    if player:GetAttribute("Zone")=="Arena" then
        shade.Visible=false
        wheelShade.Visible=false
    end
end)
updateReset()
for _,id in ipairs(Config.Order) do player:GetAttributeChangedSignal("Owns_"..id):Connect(update) end
update()
local noticeNo=0
local function show(msg)
    noticeNo+=1
    local number=noticeNo
    notice.Visible=true
    noticeText.Text=tostring(msg)
    task.delay(1.7,function() if noticeNo==number then notice.Visible=false end end)
end
local lastLight=0
local nextBasicReadyAt=0
local comboStage=0
local comboAt=-100
local lastPower=0
local lastDodge=0
local lastPointerPosition=nil
local function aim()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local camera=workspace.CurrentCamera
    if not root then return Vector3.new(0,0,-1) end
    if camera then
        -- First-person is locked to the central crosshair; free camera aims
        -- at the clicked or tapped world pixel (not the avatar facing vector).
        local screen
        if player.CameraMode==Enum.CameraMode.LockFirstPerson or player:GetAttribute("LashboundCameraLocked")==true then
            screen=camera.ViewportSize*.5
        elseif lastPointerPosition then
            screen=lastPointerPosition
        elseif UIS.MouseEnabled then
            local m=UIS:GetMouseLocation()
            screen=Vector2.new(m.X,m.Y)
        else
            screen=camera.ViewportSize*.5
        end
        local ray=camera:ViewportPointToRay(screen.X,screen.Y)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={char}
        local hit=workspace:Raycast(ray.Origin,ray.Direction*600,params)
        local target=hit and hit.Position or ray.Origin+ray.Direction*120
        local delta=target-root.Position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude>.08 then return flat.Unit end
        local forward=camera.CFrame.LookVector
        flat=Vector3.new(forward.X,0,forward.Z)
        if flat.Magnitude>.08 then return flat.Unit end
    end
    local forward=root.CFrame.LookVector
    local flat=Vector3.new(forward.X,0,forward.Z)
    return flat.Magnitude>.08 and flat.Unit or Vector3.new(0,0,-1)
end
local function guard()
    if shade.Visible or wheelShade.Visible then return false end
    if player:GetAttribute("Zone")~="Arena" then
        show("Enter the battle door first!")
        return false
    end
    return true
end
-- Owner only controls are shown only after server-side verification.
local flyButton=button(gui,"FounderFlight","FLY  [F]",UDim2.new(1,-165,0,162),UDim2.fromOffset(153,46),Color3.fromRGB(146,113,48))
flyButton.Visible=false
local ascendButton=button(gui,"FounderAscend","UP",UDim2.new(1,-120,1,-355),UDim2.fromOffset(90,43),Color3.fromRGB(95,123,167))
local descendButton=button(gui,"FounderDescend","DOWN",UDim2.new(1,-120,1,-304),UDim2.fromOffset(90,43),Color3.fromRGB(95,123,167))
ascendButton.Visible=false;descendButton.Visible=false
local flyUpHeld=false;local flyDownHeld=false
local function founderActive()
    return player:GetAttribute("OwnerVerified")==true
        and player:GetAttribute("SelectedWhip")=="Owner"
        and player.Character~=nil
        and player.Character:FindFirstChild("FounderTempest")~=nil
end
local function toggleFounderFlight()
    if founderActive() then Action:FireServer("OwnerFlyToggle") end
end
flyButton.Activated:Connect(toggleFounderFlight)
local function attachHold(control, setter)
    control.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then setter(true) end
    end)
    control.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then setter(false) end
    end)
end
attachHold(ascendButton,function(b)flyUpHeld=b end)
attachHold(descendButton,function(b)flyDownHeld=b end)
local function refreshFounderUI()
    local isOwner=player:GetAttribute("OwnerVerified")==true
    flyButton.Visible=isOwner and founderActive()
    local flying=founderActive() and player:GetAttribute("OwnerFlying")==true
    flyButton.Text=flying and "LAND  [F]" or "FLY  [F]"
    ascendButton.Visible=flying and UIS.TouchEnabled
    descendButton.Visible=flying and UIS.TouchEnabled
    if founderActive() then
        special.Text="FLY / LAND"
        powerName.Text="F or Q: FLY / LAND  •  10,000 DMG"
    end
end
player:GetAttributeChangedSignal("OwnerVerified"):Connect(refreshFounderUI)
player:GetAttributeChangedSignal("OwnerFlying"):Connect(refreshFounderUI)
player:GetAttributeChangedSignal("SelectedWhip"):Connect(refreshFounderUI)
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F then toggleFounderFlight() end
end)
-- Direction reports are rate-limited; the server checks permissions and collisions.
task.spawn(function()
    while gui.Parent do
        task.wait(.10)
        if player:GetAttribute("OwnerFlying")==true and founderActive() then
            local camera=workspace.CurrentCamera
            local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if camera and root then
                local f=camera.CFrame.LookVector
                local right=camera.CFrame.RightVector
                f=Vector3.new(f.X,0,f.Z)
                right=Vector3.new(right.X,0,right.Z)
                if f.Magnitude>.1 then f=f.Unit end
                if right.Magnitude>.1 then right=right.Unit end
                local forward=(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
                local sideways=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
                local up=(UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.ButtonA) or flyUpHeld) and 1 or 0
                local down=(UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) or flyDownHeld) and 1 or 0
                local movement=f*forward+right*sideways+Vector3.new(0,up-down,0)
                if forward==0 and sideways==0 and humanoid and humanoid.MoveDirection.Magnitude>.1 then
                    movement+=humanoid.MoveDirection
                end
                if movement.Magnitude>1 then movement=movement.Unit end
                Action:FireServer("OwnerFlyInput",movement)
            end
        end
    end
end)
local holdStart=nil
local heavyThreshold=.60
local chargeSerial=0
local function pressAttack()
    if holdStart or not guard() then return end
    holdStart=os.clock()
    chargeSerial+=1
    local token=chargeSerial
    if founderActive() then
        attack.Text="FOUNDER • 10K"
        return
    end
    Action:FireServer("ChargeStart")
    attack.Text="CHARGING..."
    task.spawn(function()
        while holdStart and token==chargeSerial do
            local fraction=math.clamp((os.clock()-holdStart)/heavyThreshold,0,1)
            attack.Text=fraction>=1 and "HEAVY READY!\nRELEASE" or string.format("CHARGE %d%%",math.floor(fraction*100))
            task.wait(.06)
        end
    end)
end
local function releaseAttack()
    if not holdStart then return end
    local aimed=aim()
    lastPointerPosition=nil
    local held=os.clock()-holdStart
    holdStart=nil;chargeSerial+=1
    attack.Text="WHIP / HOLD HEAVY"
    if not guard() then Action:FireServer("ChargeCancel");return end
    if founderActive() then
        Action:FireServer("OwnerStrike",aimed)
        return
    end
    local now=os.clock()
    if now<nextBasicReadyAt then
        Action:FireServer("ChargeCancel")
        return
    end
    local cfg=Config.Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Config.Whips.Rope
    if held>=heavyThreshold then
        lastLight=now
        nextBasicReadyAt=now+1.5*(cfg.AttackCooldown/.68)
        comboStage=0
        Action:FireServer("Heavy",aimed)
    else
        Action:FireServer("ChargeCancel")
        local step=(now-comboAt<Config.ComboReset and comboStage<3) and comboStage+1 or 1
        comboStage=step
        comboAt=now
        lastLight=now
        nextBasicReadyAt=now+math.max(.3,Config.ComboCooldowns[step]*(cfg.AttackCooldown/.68))
        Action:FireServer("Light",aimed)
    end
end
local function usePower()
    if founderActive() then toggleFounderFlight();return end
    if not guard() then return end
    if os.clock()<lastPower then return end
    lastPower=os.clock()+.2
    Action:FireServer("Power",aim())
end
local function useDodge()
    if not guard() then return end
    if os.clock()<lastDodge then return end
    lastDodge=os.clock()+.2
    local ch=player.Character
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    local root=ch and ch:FindFirstChild("HumanoidRootPart")
    local moving=hum and hum.MoveDirection
    local direction=moving and moving.Magnitude>.1 and moving.Unit or aim()
    -- Server performs sweep-checked movement: no client velocity that tunnels through walls.
    Action:FireServer("Dodge",direction)
    show("DODGE!")
end
attack.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then lastPointerPosition=nil;pressAttack() end
end)
attack.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then releaseAttack() end
end)
special.Activated:Connect(usePower)
dodge.Activated:Connect(useDodge)
equipButton.Activated:Connect(function() show("EQUIP REQUESTED") Action:FireServer("Equip") end)
local function toggleShop()
    if player:GetAttribute("Zone")=="Arena" then return end
    wheelShade.Visible=false
    shade.Visible=not shade.Visible
    if shade.Visible then
        requestShop("GetShop",nil,"Checking your saved whips...")
    end
    update()
end
shopButton.Activated:Connect(toggleShop)
CAS:BindActionAtPriority("LashboundControllerShop",function(_,state)
    if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox() then toggleShop() end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.Low.Value,Enum.KeyCode.ButtonY)
close.Activated:Connect(toggleShop)
local portalRequest=RS:FindFirstChild("LashboundPortalRequest")
doorButton.Activated:Connect(function()
    if portalRequest then
        portalRequest:FireServer("Enter")
        show("PORTAL REQUESTED")
    else show("PORTAL SERVICE NOT FOUND") end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then releaseAttack() end
end)
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        lastPointerPosition=Vector2.new(input.Position.X,input.Position.Y)
        pressAttack()
    end
    if input.KeyCode==Enum.KeyCode.Q then usePower() end
    if input.KeyCode==Enum.KeyCode.B then toggleShop() end
    if input.KeyCode==Enum.KeyCode.Escape and wheelShade.Visible then closeWheel() end
end)
CAS:BindActionAtPriority("LashboundChargedAttack",function(_,state)
    if state==Enum.UserInputState.Begin then pressAttack()
    elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then releaseAttack() end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.ButtonR2)
-- High priority keyboard/gamepad dodge binding. The on-screen DODGE button
-- remains wired with Activated for touch and controller UI selection.
CAS:BindActionAtPriority("LashboundDodge",function(_,state)
    if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox() then
        useDodge()
    end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.E,Enum.KeyCode.ButtonB)
CAS:BindActionAtPriority("LashboundControllerPower",function(_,state)
    if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox() then usePower() end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.Medium.Value,Enum.KeyCode.ButtonR1)
local hooked=setmetatable({}, {__mode="k"})
local function hookTool(child)
    if child:IsA("Tool") and child.Name=="LashboundWhip" and not hooked[child] then
        hooked[child]=true
        -- InputBegan/Ended handles charged taps; Tool.Activated would double-fire.
    end
end
local function watchCharacter(character)
    character.ChildAdded:Connect(hookTool)
    for _,child in ipairs(character:GetChildren()) do hookTool(child) end
    task.delay(2,function()
        if player.Character==character and not character:FindFirstChild("LashboundWhip") then Action:FireServer("Equip") end
    end)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end
-- Local-only, capped visual effects: other players receive the same FX event.
local fxParent=Instance.new("Folder")
fxParent.Name="LashboundV5LocalFX"
fxParent.Parent=workspace
local function streak(a,b,color,thickness,lifetime)
    local len=(b-a).Magnitude
    if len<.12 then return end
    local p=Instance.new("Part")
    p.Name="LocalLashArc"
    p.Size=Vector3.new(thickness,thickness,len)
    p.CFrame=CFrame.lookAt((a+b)/2,b)
    p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    p.Material=Enum.Material.Neon; p.Color=color; p.Transparency=.20
    p.CastShadow=false; p.Parent=fxParent
    TweenService:Create(p,TweenInfo.new(lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Transparency=1}):Play()
    Debris:AddItem(p,lifetime+.04)
end
-- Audio is local and distance-scaled to avoid replicating a fresh Sound object per attack.
-- Upload original audio/*.wav and replace the 0 values in LashboundSoundIds to enable the custom pack.
local bundled={
    Attack1="rbxasset://sounds/swordslash.wav", Attack2="rbxasset://sounds/swordslash.wav",
    Attack3="rbxasset://sounds/swordlunge.wav", Hit="rbxasset://sounds/impact_generic.mp3",
    DashPower="rbxasset://sounds/action_jump.mp3", FirePower="rbxasset://sounds/impact_generic.mp3",
    FrostPower="rbxasset://sounds/electronicpingshort.wav", VoltPower="rbxasset://sounds/electronicpingshort.wav",
    GravityPower="rbxasset://sounds/impact_water.mp3", PhantomPower="rbxasset://sounds/action_jump.mp3",
    Dodge="rbxasset://sounds/action_jump.mp3", MapSwitch="rbxasset://sounds/electronicpingshort.wav",
    WheelTick="rbxasset://sounds/electronicpingshort.wav", WheelWin="rbxasset://sounds/impact_generic.mp3",
    WhipCrackHeavy="rbxasset://sounds/impact_generic.mp3",
}
local lastSfx={}
local function playSfx(which, distance)
    local now=os.clock()
    if now-(lastSfx[which] or -10)<.065 then return end
    lastSfx[which]=now
    if distance and distance>110 then return end
    local id=SoundIds[which]
    local source=(type(id)=="number" and id>0) and ("rbxassetid://"..id) or bundled[which]
    if not source then return end
    local sound=Instance.new("Sound")
    sound.Name="Lashbound_"..which
    sound.SoundId=source
    sound.Volume=.43*(distance and math.clamp(1-distance/120,.14,1) or 1)
    sound.PlaybackSpeed=(which=="Attack2" and 1.12) or (which=="Attack3" and .88) or 1
    sound.Parent=SoundService
    sound:Play()
    Debris:AddItem(sound,3)
end
local powerKeys={Rope="DashPower",Ember="FirePower",Frost="FrostPower",Volt="VoltPower",Gravity="GravityPower",Phantom="PhantomPower",Echo="PhantomPower"}
local function localVisual(payload)
    if type(payload)~="table" or typeof(payload.origin)~="Vector3" or typeof(payload.direction)~="Vector3" then return end
    local origin=payload.origin
    local flat=Vector3.new(payload.direction.X,0,payload.direction.Z)
    if flat.Magnitude<.1 then return end
    local dir=flat.Unit
    local side=Vector3.new(-dir.Z,0,dir.X)
    local clr=typeof(payload.color)=="Color3" and payload.color or primary
    local kind=payload.kind
    -- V8 WhipSpectacle handles whip movement, crack audio, dodge trails and power art.
    -- Avoid the old generic arc on top of the new distinct attack presentations.
    if kind=="Attack" or kind=="Heavy" or kind=="Dodge" or kind=="BotDodge" or kind=="PowerPulse" then return end
    if kind=="Power" then
        playSfx(powerKeys[payload.whipId] or "DashPower")
        return
    end
    local me=player.Character
    local myRoot=me and me:FindFirstChild("HumanoidRootPart")
    local distance=myRoot and (myRoot.Position-origin).Magnitude or 120
    if kind=="Dodge" then playSfx("Dodge",distance)
    elseif kind=="Power" then playSfx(powerKeys[payload.whipId] or "DashPower",distance)
    else playSfx("Attack"..tostring(payload.step or 1),distance) end
    if kind=="Impact" then
        playSfx("Hit",distance)
        local flash=Instance.new("Part")
        flash.Anchored=true;flash.CanCollide=false;flash.CanTouch=false;flash.CanQuery=false
        flash.Shape=Enum.PartType.Ball;flash.Material=Enum.Material.Neon
        flash.Color=clr;flash.Transparency=.12;flash.Size=Vector3.new(1.5,1.5,1.5)
        flash.Position=origin+Vector3.new(0,2.1,0);flash.Parent=workspace
        TweenService:Create(flash,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(8,8,8),Transparency=1}):Play()
        Debris:AddItem(flash,.22)
        for i=1,8 do
            local ang=(i/8)*math.pi*2
            local start=origin+Vector3.new(0,2.2,0)
            local offset=Vector3.new(math.cos(ang)*4,math.sin(ang*.5)*1.5,math.sin(ang)*4)
            streak(start,start+offset,clr,.28,.18)
        end
    elseif kind=="Dodge" then
        -- Two short neon skid streaks + a brief expanding dust puff.
        for i=-1,1,2 do
            streak(origin+side*(i*1.5)+Vector3.new(0,.35,0),origin-dir*6+side*(i*1.5)+Vector3.new(0,.4,0),clr,.32,.25)
        end
    else
        local finishing=payload.step==3
        local rad=kind=="Power" and 13 or finishing and 11 or 8
        local center=origin+dir*(kind=="Power" and 8 or 5)+Vector3.new(0,2.8,0)
        local arcSide=(payload.step==2) and -1 or 1
        local last=nil
        local segments=kind=="Power" and 6 or 4
        for j=0,segments do
            local angle=(j/segments-.5)*2.3*arcSide
            local pt=center+side*(math.sin(angle)*rad)+dir*(math.cos(angle)*rad*.33)+Vector3.new(0,math.cos(angle*1.25)*2.0,0)
            if last then streak(last,pt,clr,kind=="Power" and .4 or finishing and .36 or .25,.20) end
            last=pt
        end
    end
    local me=player.Character
    local root=me and me:FindFirstChild("HumanoidRootPart")
    if root and (root.Position-origin).Magnitude<18 then
        local camera=workspace.CurrentCamera
        if camera then
            local original=camera.FieldOfView
            TweenService:Create(camera,TweenInfo.new(.07),{FieldOfView=original+(kind=="Dodge" and 2 or payload.step==3 and 3.2 or 1.3)}):Play()
            task.delay(.08,function()
                if camera.Parent then TweenService:Create(camera,TweenInfo.new(.22),{FieldOfView=original}):Play() end
            end)
        end
    end
end

Feedback.OnClientEvent:Connect(function(kind,msg,extra)
    if kind=="Visual" then localVisual(extra); return end
    if kind=="OpenShop" then
        if player:GetAttribute("Zone")=="Lobby" then
            wheelShade.Visible=false;shade.Visible=true;update()
            requestShop("GetShop",nil,"Checking your whips...")
        end
        return
    end
    if kind=="ShopState" then
        shopAwaitingReply=false
        if type(extra)=="table" then
            local coins=tonumber(extra.coins) or 0
            local selected=tostring(extra.selected or "Rope")
            if extra.loading==true then
                shopMessage("Loading your saved coins and whips...",false)
            else
                shopMessage("Wallet: "..math.floor(coins).." coins   |   Equipped: "..selected,true)
            end
        else
            shopMessage(tostring(msg),false)
        end
        update()
        return
    end
    if kind=="ShopResult" then
        shopAwaitingReply=false
        local success=type(extra)=="table" and extra.success==true
        shopMessage(msg,success)
        update()
        return
    end
    if kind=="OpenWheel" then openWheel();return end
    if kind=="SpinResult" then
        wheelAnimating=true
        wheelReward.Text="SPINNING..."
        wheelReward.TextColor3=(type(extra)=="table" and extra.legend) and Color3.fromRGB(255,220,105) or primary
        wheelDisc.Rotation=wheelDisc.Rotation%360
        local rotate=TweenService:Create(wheelDisc,TweenInfo.new(2.3,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
            Rotation=wheelDisc.Rotation+1080+math.random(1,11)*30
        })
        rotate:Play()
        playSfx("MapSwitch")
        task.spawn(function()
            for i=1,18 do
                task.wait(.12)
                playSfx("WheelTick")
            end
        end)
        task.delay(2.35,function()
            wheelAnimating=false
            wheelReward.Text=tostring(msg)
            show("WHEEL: "..tostring(msg))
            playSfx("WheelWin")
        end)
        return
    end
    if kind=="Pong" then connection.Text="CONTROLS ONLINE  •  SERVER READY"; connection.TextColor3=primary; return end
    if kind=="Message" then
        show(msg)
        if shade.Visible then shopMessage(msg,false) end
    elseif kind=="Zone" then show(msg=="Arena" and "BATTLE START!" or "WELCOME TO THE LOBBY")
    elseif kind=="Hit" then
        show("DIRECT HIT  "..tostring(msg))
        playSfx("Hit")
        if type(extra)=="table" and typeof(extra.position)=="Vector3" then
            local hitPart=Instance.new("Part")
            hitPart.Anchored=true;hitPart.CanCollide=false;hitPart.CanTouch=false;hitPart.CanQuery=false
            hitPart.Transparency=1;hitPart.Size=Vector3.new(.2,.2,.2);hitPart.Position=extra.position+Vector3.new(0,3,0);hitPart.Parent=workspace
            local gui=Instance.new("BillboardGui");gui.Size=UDim2.fromOffset(185,82);gui.AlwaysOnTop=true
            gui.MaxDistance=165;gui.Parent=hitPart
            local txt=Instance.new("TextLabel");txt.BackgroundTransparency=1;txt.Size=UDim2.fromScale(1,1)
            txt.Text="-"..tostring(extra.amount or msg)
            txt.TextColor3=extra.heavy and Color3.fromRGB(255,81,70) or Color3.fromRGB(255,231,108)
            txt.TextStrokeTransparency=.15;txt.Font=Enum.Font.GothamBlack;txt.TextScaled=true;txt.Parent=gui
            TweenService:Create(gui,TweenInfo.new(.62),{StudsOffsetWorldSpace=Vector3.new(0,7.6,0)}):Play()
            TweenService:Create(txt,TweenInfo.new(.62),{TextTransparency=1,TextStrokeTransparency=1,Rotation=math.random(-4,4)}):Play()
            Debris:AddItem(hitPart,.65)
        end
    elseif kind=="Power" then
        local secs=type(extra)=="table" and extra.cooldown or 8
        lastPower=os.clock()+secs
        show("POWER: "..tostring(msg))
    elseif kind=="Dodge" then
        lastDodge=os.clock()+Config.DodgeCooldown
    elseif kind=="Attack" then
        if type(extra)=="table" then
            if extra.hit and extra.step==3 then show("THREE-HIT FINISHER!")
            elseif extra.hit and extra.step==2 then show("COMBO CONNECTED · 2/3")
            elseif extra.step==4 then show(extra.hit and "HEAVY STRIKE CONNECTED!" or "HEAVY MISSED")
            end
        end
    end
end)
local priorMapIndex=RS:GetAttribute("LashboundMapIndex")
RS:GetAttributeChangedSignal("LashboundMapIndex"):Connect(function()
    local index=RS:GetAttribute("LashboundMapIndex")
    if priorMapIndex~=nil and index~=priorMapIndex then
        show("NEW MAP: "..tostring(RS:GetAttribute("LashboundMapName") or "BATTLE"))
        playSfx("MapSwitch")
    end
    priorMapIndex=index
end)
-- Text is the only periodic HUD update, once per 0.25s; no per-frame rendering loop.
task.spawn(function()
    while gui.Parent do
        task.wait(.25)
        local p=math.max(0,math.ceil(lastPower-os.clock()))
        local d=math.max(0,math.ceil(lastDodge-os.clock()))
        timer.Text=(p>0 and "POWER "..p.."s  " or "POWER READY  ") .. (d>0 and "DODGE "..d.."s" or "DODGE READY")
        local cfg=Config.Whips[player:GetAttribute("SelectedWhip") or "Rope"] or Config.Whips.Rope
        local pc=math.clamp(1-math.max(0,lastPower-os.clock())/cfg.PowerCooldown,0,1)
        local dc=math.clamp(1-math.max(0,lastDodge-os.clock())/Config.DodgeCooldown,0,1)
        abilityFill.Size=UDim2.fromScale(founderActive() and 1 or pc,1)
        dodgeFill.Size=UDim2.fromScale(dc,1)
        special.Text=founderActive() and (player:GetAttribute("OwnerFlying") and "LAND\nF" or "FLY\nF") or (p>0 and "POWER\n"..p.."s" or "POWER\nREADY")
        dodge.Text=d>0 and "DODGE\n"..d.."s" or "DODGE\nREADY"
        if not holdStart and founderActive() then
            attack.Text="FOUNDER 10K\nNO COOLDOWN"
        elseif not holdStart then
            local cooldown=math.max(0,nextBasicReadyAt-os.clock())
            attack.Text=cooldown>.06 and string.format("WHIP\n%.1fs",cooldown) or "WHIP\nHOLD HEAVY"
        end
        spinButton.Text=(player:GetAttribute("Coins") or 0)<200 and "NEED 200 COINS" or "SPIN · 200 COINS"
        spinButton.Active=not wheelAnimating
        local r=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local zone=player:GetAttribute("Zone") or "Lobby"
        local target=Vector3.new(0,7,-52)
        doorButton.Visible=(not shade.Visible) and zone~="Arena" and r~=nil and (r.Position-target).Magnitude<19
        doorButton.Text="ENTER ARENA"
        local nextAt=RS:GetAttribute("LashboundNextMapTime")
        local mapName=RS:GetAttribute("LashboundMapName") or "MAP LOADING"
        local secs=typeof(nextAt)=="number" and math.max(0,math.ceil(nextAt-workspace:GetServerTimeNow())) or 300
        mapTitle.Text="MAP  •  "..mapName
        mapTime.Text=string.format("NEXT MAP IN  %02d:%02d",math.floor(secs/60),secs%60)
        local bossState=RS:GetAttribute("LashboundBossState") or "WAITING_FOR_PLAYERS"
        local spawnEnd=RS:GetAttribute("LashboundBossCountdownEnd") or 0
        if zone~="Arena" then
            bossStatus.Text=""
        elseif bossState=="RESPAWNING" and spawnEnd>0 then
            local bossSecs=math.max(0,math.ceil(spawnEnd-workspace:GetServerTimeNow()))
            bossStatus.Text=string.format("COLOSSUS RESPAWNS IN  %02d:%02d",math.floor(bossSecs/60),bossSecs%60)
        elseif bossState=="REVIVING" then
            bossStatus.Text="SECOND WIND · COLOSSUS IS REVIVING!"
        elseif bossState=="BOSS_ASCENDED" then
            bossStatus.Text="ASCENDED COLOSSUS · PHASE II · 10 NEW ATTACKS"
        elseif bossState=="BOSS_ACTIVE" then
            bossStatus.Text="COLOSSUS ALIVE · DEFEAT BOTH PHASES"
        else
            bossStatus.Text="COLOSSUS APPROACHING"
        end
        if RS:GetAttribute("LashboundCombatReady") then
            connection.Text="CONTROLS ONLINE  •  SERVER READY"; connection.TextColor3=primary
        end
    end
end)
-- Mobile/low-resolution layout: the shop fits the available width.
local camera=workspace.CurrentCamera
if camera then
    local function resize()
        local v=camera.ViewportSize
        if v.X<690 or v.Y<560 then
            shop.Size=UDim2.new(.94,0,.88,0)
            shop.Position=UDim2.new(.03,0,.06,0)
            top.Size=UDim2.fromOffset(224,107)
            local titleLabel=top:FindFirstChild("Title")
            if titleLabel then titleLabel.TextSize=14 end
            wheelScale.Scale=math.min(1,(v.X-14)/430,(v.Y-14)/500)
            shopButton.Position=UDim2.new(1,-120,0,9)
            shopButton.Size=UDim2.fromOffset(108,45)
            equipButton.Position=UDim2.new(1,-120,0,60)
            equipButton.Size=UDim2.fromOffset(108,37)
            wheelButton.Position=UDim2.new(1,-120,0,105)
            wheelButton.Size=UDim2.fromOffset(108,37)
            instructions.Visible=false
            info.Size=UDim2.fromOffset(185,65)
            selectedName.TextSize=15
            powerName.TextSize=11
            attack.Size=UDim2.fromOffset(92,92)
            attack.Position=UDim2.new(1,-103,1,-105)
            special.Size=UDim2.fromOffset(83,74)
            special.Position=UDim2.new(1,-193,1,-97)
            dodge.Size=UDim2.fromOffset(74,68)
            dodge.Position=UDim2.new(1,-190,1,-176)
            timer.Visible=false
            connection.Visible=false
            mapHud.Position=UDim2.new(.5,-115,0,4)
            mapHud.Size=UDim2.fromOffset(230,53)
            mapTitle.TextSize=11
            mapTime.TextSize=12
            doorButton.Position=UDim2.new(.5,-75,1,-55)
            doorButton.Size=UDim2.fromOffset(150,43)
        end
    end
    resize()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end

refreshFounderUI()
-- Startup handshake: if server combat never starts, show a visible error instead of inert controls.
task.delay(2, function()
    if not gui.Parent then return end
    Action:FireServer("Ping")
    if not RS:GetAttribute("LashboundCombatReady") then
        connection.Text="SERVER NOT READY - CHECK VIEW > OUTPUT"
        connection.TextColor3=Color3.fromRGB(255,132,120)
    end
end)
