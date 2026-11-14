-- LASHBOUND V22: shared upstairs game tables. The server owns every move.
-- Connect Four: 7x6 rules. Battleship: hidden 10x10 fleets, five ships.
-- Pool: lightweight turn-based arcade billiards with server ball physics.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local rng=Random.new()
local remote=RS:FindFirstChild("LashboundGameRoomRequest") or Instance.new("RemoteEvent")
remote.Name="LashboundGameRoomRequest";remote.Parent=RS
local stateRemote=RS:FindFirstChild("LashboundGameRoomState") or Instance.new("RemoteEvent")
stateRemote.Name="LashboundGameRoomState";stateRemote.Parent=RS
local lobby=Workspace:WaitForChild("LashboundLobby")
local names={"ConnectFour","Battleship","PoolA","PoolB"}
local sessions={}
local cooldown={}
local function tableOf(key) return lobby:FindFirstChild("GameRoom_"..key) end
local function nearby(p,key)
    local tablePart=tableOf(key)
    local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    return p:GetAttribute("Zone")=="Lobby" and root and tablePart
        and (root.Position-tablePart.Position).Magnitude<=33
end
local function session(key)
    if not sessions[key] then sessions[key]={key=key,mode="idle",version=0,turn=1,score={0,0},winner=0} end
    return sessions[key]
end
local function isPool(key) return key=="PoolA" or key=="PoolB" end
local function playerSide(g,p)
    if g.p1==p then return 1 end
    if g.p2==p then return 2 end
    return 0
end
local function publicSnap(g,p)
    local side=playerSide(g,p)
    local s={mode=g.mode,turn=g.turn,winner=g.winner or 0,version=g.version or 0,
        side=side,waiting=g.mode=="waiting",key=g.key,
        white=g.p1 and g.p1.DisplayName or "",black=g.p2 and g.p2.DisplayName or (g.mode=="bot" and "Beginner Bot" or ""),
        score=g.score or {0,0},busy=g.busy or false,notice=g.notice or ""}
    if g.key=="ConnectFour" then
        s.board=g.board or {};s.winning=g.winning or {}
    elseif g.key=="Battleship" then
        local own=side==1 and 1 or side==2 and 2 or 0
        s.enemyMarks=own>0 and g.shots and g.shots[own] or {}
        s.incomingMarks=own>0 and g.shots and g.shots[3-own] or {}
        s.ownFleet=own>0 and g.fleets and g.fleets[own] or {}
        s.shipsLeft=g.hits and {17-g.hits[1],17-g.hits[2]} or {17,17}
    elseif isPool(g.key) then
        s.balls={}
        for _,b in ipairs(g.balls or {}) do
            table.insert(s.balls,{n=b.n,x=b.x,z=b.z,active=b.active})
        end
    end
    return s
end
local function send(g,p,verb)
    if p and p.Parent==Players then stateRemote:FireClient(p,g.key,verb or "State",publicSnap(g,p)) end
end
-- The cabin display mirrors the server-owned Connect Four board.
-- Inactive slots never contain proxy rewards or collision geometry.
local function mirrorFour(g)
    if g.key~="ConnectFour" then return end
    local tablePart=tableOf(g.key)
    if not tablePart then return end
    local folder=tablePart:FindFirstChild("PlacedFourDiscs")
    if not folder then
        folder=Instance.new("Folder")
        folder.Name="PlacedFourDiscs"
        folder.Parent=tablePart
    end
    for row=1,6 do
        for col=1,7 do
            local ix=(row-1)*7+col
            local val=g.board and g.board[ix] or 0
            local disk=folder:FindFirstChild("Disc"..ix)
            if val==0 then if disk then disk:Destroy() end
            else
                if not disk then
                    disk=Instance.new("Part")
                    disk.Name="Disc"..ix
                    disk.Shape=Enum.PartType.Ball
                    disk.Size=Vector3.new(.94,.55,.33)
                    disk.Anchored=true;disk.CanCollide=false;disk.CanTouch=false;disk.CanQuery=false
                    disk.Material=Enum.Material.SmoothPlastic
                    disk.Parent=folder
                end
                disk.Color=val==1 and Color3.fromRGB(237,71,57) or Color3.fromRGB(244,213,68)
                disk.CFrame=CFrame.new(-6+(col-1)*2,18.3+(row-1)*.67,10.19)
            end
        end
    end
end
local function broadcast(g)
    mirrorFour(g)
    g.version=(g.version or 0)+1
    for _,p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("Zone")=="Lobby" then send(g,p,"State") end
    end
end
local function reset(g,mode,p)
    g.mode=mode;g.p1=p;g.p2=nil;g.turn=1;g.winner=0;g.version=(g.version or 0)+1
    g.notice=mode=="waiting" and "Waiting for another player to join." or "Your turn."
    g.score={0,0};g.busy=false
    g.round=(g.round or 0)+1 -- invalidate any prior physics/AI task on restart
end
-- CONNECT FOUR
local function dropIn(board,col,who)
    if type(col)~="number" or col%1~=0 or col<1 or col>7 then return nil end
    for row=1,6 do
        local i=(row-1)*7+col
        if not board[i] or board[i]==0 then board[i]=who;return row end
    end
    return nil
end
local function fourWin(board,row,col,who)
    for _,d in ipairs({{1,0},{0,1},{1,1},{1,-1}}) do
        local count=1
        for sign=-1,1,2 do
            for k=1,3 do
                local r=row+d[1]*k*sign
                local c=col+d[2]*k*sign
                if r<1 or r>6 or c<1 or c>7 or board[(r-1)*7+c]~=who then break end
                count=count+1
            end
        end
        if count>=4 then return true end
    end
    return false
end
local function fourBotMove(g)
    local options={}
    for _,col in ipairs({4,3,5,2,6,1,7}) do
        local test=table.clone(g.board)
        local row=dropIn(test,col,2)
        if row then
            if fourWin(test,row,col,2) then return col end
            table.insert(options,col)
        end
    end
    for _,col in ipairs(options) do
        local test=table.clone(g.board)
        local row=dropIn(test,col,1)
        if row and fourWin(test,row,col,1) then return col end
    end
    if #options==0 then return nil end
    return options[math.clamp(rng:NextInteger(1,math.min(3,#options)),1,#options)]
end
local function fourPlay(g,col,who)
    local row=dropIn(g.board,col,who)
    if not row then return false end
    if fourWin(g.board,row,col,who) then g.winner=who;g.notice=(who==1 and "Red" or "Yellow").." wins!"
    elseif not table.find(g.board,0) then g.winner=3;g.notice="Draw — board full."
    else g.turn=3-who;g.notice=who==1 and "Yellow's turn." or "Red's turn." end
    broadcast(g)
    return true
end
-- BATTLESHIP
local ships={5,4,3,3,2}
local function fleet()
    local cells={}
    for _,length in ipairs(ships) do
        local placed=false
        for trial=1,250 do
            local horiz=rng:NextInteger(0,1)==0
            local r=rng:NextInteger(1,horiz and 10 or 11-length)
            local c=rng:NextInteger(1,horiz and 11-length or 10)
            local nextCells={}
            local okay=true
            for k=0,length-1 do
                local rr=r+(horiz and 0 or k)
                local cc=c+(horiz and k or 0)
                local i=(rr-1)*10+cc
                if cells[i] then okay=false;break end
                table.insert(nextCells,i)
            end
            if okay then
                for _,i in ipairs(nextCells) do cells[i]=1 end
                placed=true;break
            end
        end
        if not placed then error("Unable to place a Battleship vessel") end
    end
    return cells
end
local function shipShot(g,who,cell)
    if type(cell)~="number" or cell%1~=0 or cell<1 or cell>100 then return false end
    if g.shots[who][cell] then return false end
    local opponent=3-who
    local hit=g.fleets[opponent][cell]==1
    g.shots[who][cell]=hit and 2 or 1
    if hit then g.hits[opponent]=g.hits[opponent]+1 end
    g.notice=hit and "Direct hit!" or "Miss!"
    if g.hits[opponent]>=17 then
        g.winner=who;g.notice=(who==1 and "Admiral One" or "Admiral Two").." wins the sea!"
    else
        g.turn=opponent
    end
    broadcast(g)
    return true
end
local function shipBotPick(g)
    local shot=g.shots[2]
    local candidates={}
    for i,val in pairs(shot) do
        if val==2 then
            local r=math.floor((i-1)/10)+1
            local c=(i-1)%10+1
            for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                local rr=r+v[1];local cc=c+v[2]
                if rr>=1 and rr<=10 and cc>=1 and cc<=10 then
                    local n=(rr-1)*10+cc
                    if not shot[n] then table.insert(candidates,n) end
                end
            end
        end
    end
    if #candidates>0 and rng:NextNumber()<.78 then return candidates[rng:NextInteger(1,#candidates)] end
    for _=1,120 do
        local i=rng:NextInteger(1,100)
        if not shot[i] then return i end
    end
    for i=1,100 do if not shot[i] then return i end end
    return nil
end
-- POOL, normalized 2:1 tabletop. Six pockets, equal-mass ball collisions.
local pockets={{-.91,-.43},{0,-.43},{.91,-.43},{-.91,.43},{0,.43},{.91,.43}}
local function initBalls()
    local b={{n=0,x=-.54,z=0,active=true,vx=0,vz=0}}
    local n=1
    for row=0,4 do
        for j=0,row do
            local id=n
            if row==2 and j==1 then id=8 end
            if row>=2 and j==1 and n==8 then id=n end
            local x=.30+row*.080
            local z=(j-row*.5)*.081
            table.insert(b,{n=n,x=x,z=z,active=true,vx=0,vz=0})
            n=n+1
        end
    end
    return b
end
local function poolBallPosition(top,b)
    return top.CFrame:PointToWorldSpace(Vector3.new(b.x*9.8,top.Size.Y/2+.53,b.z*9.0))
end
local function ensurePoolModels(g)
    local top=tableOf(g.key)
    if not top then return end
    if g.physical and g.physical.Parent then return end
    local folder=Instance.new("Folder")
    folder.Name="PoolBalls";folder.Parent=top
    g.physical=folder;g.models={}
    local colorList={Color3.fromRGB(249,242,226),Color3.fromRGB(240,203,71),Color3.fromRGB(80,125,221),Color3.fromRGB(216,65,69),
        Color3.fromRGB(138,82,187),Color3.fromRGB(240,140,54),Color3.fromRGB(82,176,94),Color3.fromRGB(153,59,61),Color3.fromRGB(28,32,43),
        Color3.fromRGB(239,203,92),Color3.fromRGB(76,115,221),Color3.fromRGB(229,69,72),Color3.fromRGB(138,75,200),Color3.fromRGB(240,153,66),
        Color3.fromRGB(94,171,90),Color3.fromRGB(159,66,70)}
    for _,b in ipairs(g.balls) do
        local ball=Instance.new("Part")
        ball.Name="PoolBall_"..b.n;ball.Shape=Enum.PartType.Ball
        ball.Size=Vector3.new(.76,.76,.76)
        ball.Anchored=true;ball.CanCollide=false;ball.CanTouch=false;ball.CanQuery=false
        ball.Material=Enum.Material.SmoothPlastic
        ball.Color=colorList[b.n+1] or Color3.new(1,1,1)
        ball.CFrame=CFrame.new(poolBallPosition(top,b));ball.Parent=folder
        g.models[b.n]=ball
        if b.n~=0 then
            local tag=Instance.new("BillboardGui");tag.Name="Number";tag.Size=UDim2.fromOffset(25,25)
            tag.AlwaysOnTop=true;tag.StudsOffsetWorldSpace=Vector3.new(0,.4,0);tag.Parent=ball
            local txt=Instance.new("TextLabel");txt.Size=UDim2.fromScale(1,1);txt.BackgroundTransparency=1
            txt.Font=Enum.Font.GothamBold;txt.TextScaled=true;txt.TextColor3=Color3.new(1,1,1)
            txt.TextStrokeTransparency=.16;txt.Text=tostring(b.n);txt.Parent=tag
        end
    end
end
local function syncPool(g)
    local top=tableOf(g.key)
    if not top or not g.models then return end
    for _,b in ipairs(g.balls or {}) do
        local model=g.models[b.n]
        if model and model.Parent then
            model.Transparency=b.active and 0 or 1
            model.CFrame=CFrame.new(poolBallPosition(top,b))
        end
    end
end
local function simulatePool(g,angle,power,who)
    if g.busy then return end
    g.busy=true
    local round=g.round
    local cue=g.balls[1]
    if not cue.active then cue.active=true;cue.x=-.52;cue.z=0 end
    local a=math.rad(angle)
    local speed=.25+2.3*power/100
    cue.vx=math.cos(a)*speed
    cue.vz=math.sin(a)*speed
    broadcast(g)
    task.spawn(function()
        local potted=0
        for frame=1,220 do
            if g.round~=round or g.mode=="idle" then return end
            local still=false
            for _,b in ipairs(g.balls) do
                if b.active then
                    local vx,vz=b.vx,b.vz
                    if vx*vx+vz*vz>.0009 then still=true end
                    b.x=b.x+vx*.033;b.z=b.z+vz*.033
                    b.vx=b.vx*.975;b.vz=b.vz*.975
                    if math.abs(b.vx)<.015 then b.vx=0 end
                    if math.abs(b.vz)<.015 then b.vz=0 end
                    local pocketed=false
                    for _,pk in ipairs(pockets) do
                        local dx,dz=b.x-pk[1],b.z-pk[2]
                        if dx*dx+dz*dz<.0144 then pocketed=true;break end
                    end
                    if pocketed then
                        b.active=false;b.vx=0;b.vz=0
                        if b.n~=0 then
                            potted+=1
                            g.score[who]=g.score[who]+(b.n==8 and 3 or 1)
                        end
                    else
                        if b.x>.91 then b.x=.91;b.vx=-math.abs(b.vx)*.78 end
                        if b.x<-.91 then b.x=-.91;b.vx=math.abs(b.vx)*.78 end
                        if b.z>.43 then b.z=.43;b.vz=-math.abs(b.vz)*.78 end
                        if b.z<-.43 then b.z=-.43;b.vz=math.abs(b.vz)*.78 end
                    end
                end
            end
            -- Pairwise equal-mass collisions, with gentle restitution.
            for i=1,#g.balls do
                local aBall=g.balls[i]
                if aBall.active then
                    for j=i+1,#g.balls do
                        local bBall=g.balls[j]
                        if bBall.active then
                            local dx=bBall.x-aBall.x;local dz=bBall.z-aBall.z
                            local d2=dx*dx+dz*dz
                            if d2>.000001 and d2<.00518 then
                                local dist=math.sqrt(d2)
                                local nx,nz=dx/dist,dz/dist
                                local overlap=(.072-dist)*.5
                                aBall.x-=nx*overlap;aBall.z-=nz*overlap
                                bBall.x+=nx*overlap;bBall.z+=nz*overlap
                                local relative=(aBall.vx-bBall.vx)*nx+(aBall.vz-bBall.vz)*nz
                                if relative>0 then
                                    local impulse=relative*.92
                                    aBall.vx-=impulse*nx;aBall.vz-=impulse*nz
                                    bBall.vx+=impulse*nx;bBall.vz+=impulse*nz
                                end
                            end
                        end
                    end
                end
            end
            if frame%2==0 then syncPool(g) end
            -- Send throttled snapshots so the top-down UI also tracks moving balls.
            if frame%9==0 then broadcast(g) end
            if not still and frame>12 then break end
            task.wait(.033)
            if g.mode=="idle" or not g.physical or not g.physical.Parent then break end
        end
        if g.round~=round or g.mode=="idle" then return end
        if not cue.active then cue.active=true;cue.x=-.55;cue.z=0 end
        for _,b in ipairs(g.balls) do b.vx=0;b.vz=0 end
        syncPool(g)
        local left=0
        for _,b in ipairs(g.balls) do if b.n>0 and b.active then left=left+1 end end
        if left==0 then
            g.winner=g.score[1]==g.score[2] and 3 or g.score[1]>g.score[2] and 1 or 2
            g.notice="Rack cleared! "..(g.winner==3 and "Tie game." or "Player "..g.winner.." wins.")
        else
            g.turn=3-who
            g.notice=(potted>0 and ("Pocketed "..potted.." balls! ") or "No balls pocketed. ").."Next turn."
        end
        g.busy=false
        broadcast(g)
        if g.mode=="bot" and g.turn==2 and g.winner==0 then
            task.delay(.65,function()
                if g.mode=="bot" and g.turn==2 and not g.busy then
                    local target=nil
                    for _,b in ipairs(g.balls) do
                        if b.n>0 and b.active then
                            if not target or (b.x-cue.x)^2+(b.z-cue.z)^2<(target.x-cue.x)^2+(target.z-cue.z)^2 then target=b end
                        end
                    end
                    if target then
                        local angle2=math.deg(math.atan2(target.z-cue.z,target.x-cue.x))+rng:NextNumber(-17,17)
                        simulatePool(g,angle2,rng:NextInteger(55,88),2)
                    end
                end
            end)
        end
    end)
end
local function start(g,mode,p)
    if g.busy then return end
    if g.mode~="idle" and g.winner==0 and playerSide(g,p)==0 then return end
    reset(g,mode,p)
    if g.key=="ConnectFour" then
        g.board=table.create(42,0)
    elseif g.key=="Battleship" then
        g.fleets={fleet(),fleet()};g.shots={{},{}};g.hits={0,0}
    elseif isPool(g.key) then
        if g.physical and g.physical.Parent then g.physical:Destroy() end
        g.physical=nil;g.balls=initBalls()
        ensurePoolModels(g);syncPool(g)
    end
    broadcast(g)
end
local function getReady(g,p)
    if g.mode~="waiting" or g.p1==p or g.p2~=nil then return end
    if not g.p1 or g.p1.Parent~=Players then
        g.round=(g.round or 0)+1
        g.mode="idle";g.p1=nil;g.p2=nil;g.busy=false
        g.notice="Host disconnected. Table ready for a new match."
        broadcast(g)
        return
    end
    g.p2=p;g.mode="pvp";g.notice="Both players ready! Player One goes first."
    broadcast(g)
end
local function doBotTurn(g, expectedRound)
    -- A delayed bot move must never affect a restarted match.
    if g.round~=expectedRound then return end
    if g.mode~="bot" or g.turn~=2 or g.winner~=0 then return end
    if g.key=="ConnectFour" then
        local col=fourBotMove(g)
        if col then fourPlay(g,col,2) end
    elseif g.key=="Battleship" then
        local i=shipBotPick(g)
        if i then shipShot(g,2,i) end
    end
end
remote.OnServerEvent:Connect(function(p,key,action,arg)
    if type(key)~="string" or not table.find(names,key) or type(action)~="string" then return end
    if not nearby(p,key) then return end
    local now=os.clock()
    if now-(cooldown[p] or 0)<.11 then return end
    cooldown[p]=now
    local g=session(key)
    if action=="Open" then send(g,p,"Open");return end
    if action=="StartBot" or action=="HostPvP" then
        start(g,action=="StartBot" and "bot" or "waiting",p)
    elseif action=="Join" then
        getReady(g,p)
    elseif action=="Move" and g.winner==0 and not g.busy then
        local who=playerSide(g,p)
        if who~=g.turn or (g.mode~="bot" and g.mode~="pvp") then return end
        if g.key=="ConnectFour" then
            if typeof(arg)=="number" then
                if fourPlay(g,arg,who) and g.mode=="bot" and g.turn==2 and g.winner==0 then
                    local expectedRound=g.round
                    task.delay(.55,function() doBotTurn(g,expectedRound) end)
                end
            end
        elseif g.key=="Battleship" then
            if typeof(arg)=="number" then
                if shipShot(g,who,arg) and g.mode=="bot" and g.turn==2 and g.winner==0 then
                    local expectedRound=g.round
                    task.delay(.72,function() doBotTurn(g,expectedRound) end)
                end
            end
        elseif isPool(key) then
            if typeof(arg)=="table" and typeof(arg.angle)=="number" and typeof(arg.power)=="number" and
                arg.angle==arg.angle and arg.power==arg.power and math.abs(arg.angle)<math.huge and math.abs(arg.power)<math.huge and arg.angle>=-360 and arg.angle<=360 and
                arg.power>=10 and arg.power<=100 then
                simulatePool(g,arg.angle,arg.power,who)
            end
        end
    elseif action=="Exit" then
        send(g,p,"Close")
    end
end)
for _,key in ipairs(names) do
    local top=tableOf(key)
    if top then
        -- Repair missing prompts in older saves and show unmistakable table cues.
        local prompt=top:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            prompt=Instance.new("ProximityPrompt")
            prompt.Name="V26GamePrompt"
            prompt.Parent=top
        end
        prompt.ActionText="PLAY GAME"
        prompt.ObjectText=(key=="ConnectFour" and "CONNECT FOUR") or
            (key=="Battleship" and "BATTLESHIP") or (key=="PoolA" and "POOL - TABLE A") or "POOL - TABLE B"
        prompt.HoldDuration=0
        prompt.MaxActivationDistance=17
        prompt.RequiresLineOfSight=false
        prompt.Enabled=true
        local sign=top:FindFirstChild("LashboundGameCue")
        if not sign then
            sign=Instance.new("BillboardGui")
            sign.Name="LashboundGameCue"
            sign.Adornee=top
            sign.AlwaysOnTop=true
            sign.MaxDistance=115
            sign.StudsOffsetWorldSpace=Vector3.new(0,3.4,0)
            sign.Size=UDim2.fromOffset(260,62)
            sign.Parent=top
            local label=Instance.new("TextLabel")
            label.Name="Cue"
            label.Size=UDim2.fromScale(1,1)
            label.BackgroundColor3=Color3.fromRGB(57,35,24)
            label.BackgroundTransparency=.12
            label.TextColor3=Color3.fromRGB(255,233,185)
            label.TextStrokeTransparency=.45
            label.Font=Enum.Font.GothamBold
            label.TextScaled=true
            label.TextWrapped=true
            label.Text=prompt.ObjectText.."\nE / TAP TO PLAY"
            label.Parent=sign
            Instance.new("UICorner",label).CornerRadius=UDim.new(0,12)
            local border=Instance.new("UIStroke")
            border.Color=Color3.fromRGB(235,186,103)
            border.Thickness=1.7
            border.Parent=label
        end
        prompt.Triggered:Connect(function(player)
            if nearby(player,key) then send(session(key),player,"Open") end
        end)
    else
        warn("[Lashbound Games] Missing upstairs table: "..key)
    end
end
Players.PlayerRemoving:Connect(function(p)
    cooldown[p]=nil
    for _,g in pairs(sessions) do
        if g.p1==p or g.p2==p then
            local remaining=g.p1==p and g.p2 or g.p1
            g.round=(g.round or 0)+1 -- cancel pending bot moves and pool simulation
            g.version=(g.version or 0)+1
            g.winner=0;g.mode="idle";g.busy=false;g.p1=nil;g.p2=nil
            g.notice="A player left. Table ready for a new match."
            if g.physical and g.physical.Parent then g.physical:Destroy() end
            g.physical=nil
            broadcast(g)
            if remaining and remaining.Parent==Players then send(g,remaining) end
        end
    end
end)
