-- V22 upstairs game room client. Board visuals are driven exclusively by server snapshots.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local Request=RS:WaitForChild("LashboundGameRoomRequest")
local State=RS:WaitForChild("LashboundGameRoomState")
local ui=Instance.new("ScreenGui")
ui.Name="LashboundV22GameRoom";ui.ResetOnSpawn=false;ui.IgnoreGuiInset=true
ui.DisplayOrder=40;ui.Enabled=false;ui.Parent=player:WaitForChild("PlayerGui")
local function create(parent,cls,props)
    local obj=Instance.new(cls)
    for name,val in pairs(props or {}) do obj[name]=val end
    obj.Parent=parent;return obj
end
local function corners(parent,r)
    create(parent,"UICorner",{CornerRadius=UDim.new(0,r or 8)})
end
local dark=Color3.fromRGB(27,24,30)
local wood=Color3.fromRGB(95,63,42)
local gold=Color3.fromRGB(238,193,116)
local frame=create(ui,"Frame",{Name="GamePanel",Size=UDim2.new(.92,0,.89,0),Position=UDim2.new(.04,0,.055,0),BackgroundColor3=dark,BorderSizePixel=0})
create(frame,"UISizeConstraint",{MaxSize=Vector2.new(790,680),MinSize=Vector2.new(280,350)})
corners(frame,12)
create(frame,"UIStroke",{Color=gold,Thickness=2,Transparency=.14})
local title=create(frame,"TextLabel",{Size=UDim2.new(1,-100,0,49),Position=UDim2.fromOffset(16,8),BackgroundTransparency=1,
    Text="CABIN GAME ROOM",Font=Enum.Font.GothamBlack,TextScaled=true,TextColor3=gold,TextXAlignment=Enum.TextXAlignment.Left})
local close=create(frame,"TextButton",{Size=UDim2.fromOffset(53,42),Position=UDim2.new(1,-61,0,11),Text="X",Font=Enum.Font.GothamBold,
    TextSize=22,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(141,65,57),BorderSizePixel=0})
corners(close,8)
local status=create(frame,"TextLabel",{Name="Status",Size=UDim2.new(1,-28,0,30),Position=UDim2.fromOffset(14,55),
    Text="Choose a mode to play.",TextColor3=Color3.fromRGB(242,229,209),TextSize=18,Font=Enum.Font.GothamSemibold,BackgroundTransparency=1})
local buttons=create(frame,"Frame",{Size=UDim2.new(1,-24,0,43),Position=UDim2.fromOffset(12,90),BackgroundTransparency=1})
local function actionButton(text,index)
    local b=create(buttons,"TextButton",{Size=UDim2.new(.245,-5,1,0),Position=UDim2.new(.25*(index-1),2,0,0),Text=text,
        BackgroundColor3=wood,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextScaled=true,BorderSizePixel=0})
    corners(b,7);return b
end
local bot=actionButton("VS BOT",1)
local host=actionButton("HOST PVP",2)
local join=actionButton("JOIN PVP",3)
local restart=actionButton("NEW GAME",4)
local body=create(frame,"Frame",{Name="BoardArea",Size=UDim2.new(1,-20,1,-190),Position=UDim2.fromOffset(10,139),
    BackgroundTransparency=1,ClipsDescendants=true})
local tip=create(frame,"TextLabel",{Size=UDim2.new(1,-20,0,41),Position=UDim2.new(0,10,1,-45),BackgroundTransparency=1,
    TextColor3=Color3.fromRGB(213,205,194),Text="",TextScaled=true,Font=Enum.Font.Gotham})
local current="";local snap=nil
local poolView=nil
local previousFour={}
local previousShots={}
local lastVersion=-1
local function boardTick(win)
    local snd=Instance.new("Sound")
    snd.SoundId="rbxasset://sounds/electronicpingshort.wav"
    snd.Volume=win and .6 or .27
    snd.PlaybackSpeed=win and .76 or 1.22
    snd.Parent=SoundService;snd:Play();Debris:AddItem(snd,1.2)
end

local angle=0;local power=65
local mapping={ConnectFour="CONNECT FOUR",Battleship="BATTLESHIP",PoolA="POOL TABLE A",PoolB="POOL TABLE B"}
close.MouseButton1Click:Connect(function()
    if current~="" then Request:FireServer(current,"Exit") end
    ui.Enabled=false
end)
bot.MouseButton1Click:Connect(function() if current~="" then Request:FireServer(current,"StartBot") end end)
host.MouseButton1Click:Connect(function() if current~="" then Request:FireServer(current,"HostPvP") end end)
join.MouseButton1Click:Connect(function() if current~="" then Request:FireServer(current,"Join") end end)
restart.MouseButton1Click:Connect(function() if current~="" then Request:FireServer(current,"StartBot") end end)
local function label(parent,text,sz,pos,color,size)
    return create(parent,"TextLabel",{Text=text,Size=sz,Position=pos or UDim2.new(),BackgroundTransparency=1,
        TextColor3=color or gold,Font=Enum.Font.GothamBold,TextSize=size or 18,TextScaled=false})
end
local function panel(parent,sz,pos,color)
    local f=create(parent,"Frame",{Size=sz,Position=pos,BackgroundColor3=color or wood,BorderSizePixel=0})
    corners(f,6);return f
end
local function clickable()
    return snap and snap.side>0 and snap.turn==snap.side and (snap.mode=="bot" or snap.mode=="pvp")
        and snap.winner==0 and not snap.busy
end
local function addConnectFour()
    local board=snap.board or {}
    local holder=panel(body,UDim2.new(.94,0,.93,0),UDim2.new(.03,0,.04,0),Color3.fromRGB(32,67,157))
    local grid=create(holder,"UIGridLayout",{CellSize=UDim2.new(1/7,-6,1/6,-5),CellPadding=UDim2.fromOffset(3,3),
        SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,
        VerticalAlignment=Enum.VerticalAlignment.Center})
    for row=6,1,-1 do
        for col=1,7 do
            local value=board[(row-1)*7+col] or 0
            local disk=create(holder,"TextButton",{Name="Column"..col,LayoutOrder=(6-row)*7+col,Text="",
                BackgroundColor3=Color3.fromRGB(27,60,137),BorderSizePixel=0})
            create(disk,"UICorner",{CornerRadius=UDim.new(1,0)})
            local ball=create(disk,"Frame",{Size=UDim2.fromScale(.84,.84),AnchorPoint=Vector2.new(.5,.5),
                Position=UDim2.fromScale(.5,.5),BorderSizePixel=0,
                BackgroundColor3=value==1 and Color3.fromRGB(246,81,62) or
                    value==2 and Color3.fromRGB(255,222,72) or Color3.fromRGB(218,231,237)})
            create(ball,"UICorner",{CornerRadius=UDim.new(1,0)})
            local index=(row-1)*7+col
            if value>0 and (previousFour[index] or 0)==0 then
                ball.Position=UDim2.fromScale(.5,-3.2)
                TweenService:Create(ball,TweenInfo.new(.36,Enum.EasingStyle.Bounce,Enum.EasingDirection.Out),{
                    Position=UDim2.fromScale(.5,.5)}):Play()
            end
            disk.MouseButton1Click:Connect(function()
                if clickable() then Request:FireServer(current,"Move",col) end
            end)
        end
    end
    previousFour=table.clone(board)
    tip.Text="Tap a column to drop a disc. Four in a row wins!"
end
local function miniGrid(parent,originX,text,colorSet,clickableEnemy)
    local labelText=label(parent,text,UDim2.new(.46,0,0,24),UDim2.new(originX,0,0,0),gold,17)
    local boardFrame=panel(parent,UDim2.new(.46,0,.84,0),UDim2.new(originX,0,.13,0),Color3.fromRGB(38,62,88))
    local layout=create(boardFrame,"UIGridLayout",{CellSize=UDim2.new(.1,-2,.1,-2),CellPadding=UDim2.fromOffset(1,1),
        HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
    for i=1,100 do
        local state=colorSet[i] or 0
        local fill=state==1 and Color3.fromRGB(210,211,219) or state==2 and Color3.fromRGB(233,77,64) or
            state==3 and Color3.fromRGB(135,176,183) or Color3.fromRGB(76,116,149)
        local square=create(boardFrame,"TextButton",{Text=state==2 and "X" or state==1 and "·" or "",
            LayoutOrder=i,BackgroundColor3=fill,TextColor3=Color3.new(1,1,1),TextScaled=true,Font=Enum.Font.GothamBold,BorderSizePixel=0})
        square.MouseButton1Click:Connect(function()
            if clickableEnemy and clickable() and state==0 then Request:FireServer(current,"Move",i) end
        end)
    end
end
local function addBattleship()
    local enemy=snap.enemyMarks or {}
    local incoming=snap.incomingMarks or {}
    local fleet=snap.ownFleet or {}
    local own={}
    for i=1,100 do
        if incoming[i]==2 then own[i]=2
        elseif incoming[i]==1 then own[i]=1
        elseif fleet[i]==1 then own[i]=3
        else own[i]=0 end
    end
    miniGrid(body,.02,"YOUR FLEET",own,false)
    miniGrid(body,.52,"FIRE HERE",enemy,true)
    tip.Text="Blue = ocean · gray = miss · red = hit · muted blue = your ship"
end
local function poolXY(b)
    return UDim2.fromScale(math.clamp((b.x+.91)/1.82,.03,.97),math.clamp((b.z+.43)/.86,.04,.96))
end
local function updatePool()
    if not poolView or not poolView.felt.Parent then return end
    for _,b in ipairs(snap.balls or {}) do
        local ball=poolView.balls[b.n]
        if ball then
            ball.Visible=b.active
            if b.active then
                TweenService:Create(ball,TweenInfo.new(.095,Enum.EasingStyle.Linear),{Position=poolXY(b)}):Play()
            end
        end
    end
    if poolView.guide then
        local cue=(snap.balls or {})[1]
        poolView.guide.Visible=cue and cue.active and not snap.busy or false
        if cue then
            poolView.guide.Position=poolXY(cue)
            poolView.guide.Rotation=angle
        end
    end
    poolView.turn.Text=string.format("AIM %d°    POWER %d%%    SCORE %d : %d",angle,power,
        (snap.score or {})[1] or 0,(snap.score or {})[2] or 0)
    tip.Text=snap.busy and "SHOT IN MOTION — WATCH THE BALLS ROLL" or
        "Line up your cue, adjust power, and SHOOT. Pocketed balls score points."
end
local function addPool()
    local felt=panel(body,UDim2.new(.93,0,.68,0),UDim2.new(.035,0,.02,0),Color3.fromRGB(20,107,77))
    create(felt,"UIStroke",{Thickness=5,Color=Color3.fromRGB(104,57,35)})
    for _,pocketLocation in ipairs({{0,0},{.5,0},{1,0},{0,1},{.5,1},{1,1}}) do
        local pocket=create(felt,"Frame",{Size=UDim2.fromOffset(16,16),Position=UDim2.fromScale(pocketLocation[1],pocketLocation[2]),AnchorPoint=Vector2.new(.5,.5),
            BackgroundColor3=Color3.fromRGB(8,10,10),BorderSizePixel=0})
        create(pocket,"UICorner",{CornerRadius=UDim.new(1,0)})
    end
    local guide=create(felt,"Frame",{Size=UDim2.fromOffset(80,2),AnchorPoint=Vector2.new(0,.5),
        Position=UDim2.fromScale(.25,.5),BackgroundColor3=Color3.fromRGB(246,244,218),BackgroundTransparency=.28,
        BorderSizePixel=0,ZIndex=3})
    local balls={}
    for _,b in ipairs(snap.balls or {}) do
        local ball=create(felt,"TextLabel",{Name="Ball"..b.n,Size=UDim2.fromOffset(16,16),AnchorPoint=Vector2.new(.5,.5),
            Position=poolXY(b),Visible=b.active,
            Text=b.n==0 and "" or tostring(b.n),TextSize=10,Font=Enum.Font.GothamBold,
            TextColor3=Color3.new(1,1,1),BackgroundColor3=b.n==0 and Color3.new(1,1,1) or b.n==8 and Color3.fromRGB(26,27,32) or
                (b.n%2==0 and Color3.fromRGB(212,80,76) or Color3.fromRGB(244,201,68)),BorderSizePixel=0,ZIndex=5})
        create(ball,"UICorner",{CornerRadius=UDim.new(1,0)})
        balls[b.n]=ball
    end
    local ctrl=panel(body,UDim2.new(.97,0,.24,0),UDim2.new(.015,0,.75,0),Color3.fromRGB(57,44,35))
    local function ctr(text,x,fn)
        local b=create(ctrl,"TextButton",{Text=text,Size=UDim2.new(.15,-3,.65,0),Position=UDim2.new(x,0,.15,0),
            BackgroundColor3=wood,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextScaled=true,BorderSizePixel=0})
        corners(b,6);b.MouseButton1Click:Connect(fn)
    end
    ctr("ANGLE -",.01,function() angle=(angle-10)%360;updatePool() end)
    ctr("ANGLE +",.17,function() angle=(angle+10)%360;updatePool() end)
    ctr("POWER -",.34,function() power=math.max(10,power-10);updatePool() end)
    ctr("POWER +",.50,function() power=math.min(100,power+10);updatePool() end)
    ctr("SHOOT",.70,function() if clickable() then Request:FireServer(current,"Move",{angle=angle,power=power}) end end)
    local turn=label(body,"",UDim2.new(.95,0,0,22),UDim2.new(.03,0,.72,0),gold,16)
    poolView={felt=felt,balls=balls,guide=guide,turn=turn}
    updatePool()
end
local function render()
    if not snap then return end
    title.Text=(mapping[current] or "CABIN GAME ROOM").."  ·  PLAYER "..tostring(snap.side)
    local statusText=snap.mode=="idle" and "Choose Bot or Host PvP." or
        snap.mode=="waiting" and "Waiting for a second player — press JOIN on their screen." or
        snap.winner>0 and (snap.winner==3 and "DRAW!" or "PLAYER "..tostring(snap.winner).." WINS!") or
        snap.busy and "Balls moving — watch the table!" or
        ("Turn: "..(snap.turn==1 and "Player 1" or "Player 2").." · "..(snap.notice or ""))
    status.Text=statusText
    if snap.mode=="idle" then
        tip.Text="START HERE: tap VS BOT for a solo game, or HOST PvP and invite a friend to JOIN."
        tip.TextColor3=Color3.fromRGB(255,223,142)
    elseif snap.mode=="waiting" then
        tip.Text="Second player: walk to this table and press JOIN PvP."
    else
        tip.TextColor3=Color3.fromRGB(213,205,194)
    end
    bot.Visible=snap.mode=="idle" or snap.winner~=0
    host.Visible=snap.mode=="idle" or snap.winner~=0
    join.Visible=snap.mode=="waiting" and snap.side==0
    restart.Visible=snap.winner~=0 and snap.side~=0
    local isPool=current=="PoolA" or current=="PoolB"
    if isPool and poolView and poolView.felt.Parent then
        updatePool() -- preserve UI and tween moving balls, don't rebuild at every snapshot
        return
    end
    for _,ch in ipairs(body:GetChildren()) do ch:Destroy() end
    poolView=nil
    if current=="ConnectFour" then addConnectFour()
    elseif current=="Battleship" then addBattleship()
    elseif isPool then addPool()
    end
    if snap.mode=="idle" then
        tip.Text="Choose VS BOT or HOST PvP at the top to begin."
    end
end
State.OnClientEvent:Connect(function(key,verb,data)
    if verb=="Close" and key==current then ui.Enabled=false;return end
    if verb=="Open" then
        if current~=key then poolView=nil;previousFour={} end
        current=key;snap=data;ui.Enabled=true;render()
    elseif key==current and ui.Enabled then
        local previousVersion=lastVersion
        lastVersion=data.version or -1
        if current~="PoolA" and current~="PoolB" and lastVersion~=previousVersion then
            boardTick(data.winner and data.winner>0)
        end
        snap=data;render()
    end
end)
-- Fit narrow mobile viewports without relying on the main combat HUD layout.
local cam=workspace.CurrentCamera
local scale=create(frame,"UIScale",{Scale=1})
local function resize()
    local c=workspace.CurrentCamera
    if c then
        local v=c.ViewportSize
        scale.Scale=math.clamp(math.min(v.X/810,v.Y/700),.5,1)
        frame.AnchorPoint=Vector2.new(.5,.5)
        frame.Position=UDim2.fromScale(.5,.5)
    end
end
resize()
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
