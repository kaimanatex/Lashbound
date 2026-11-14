-- One physical chess table, two-player challenge or beginner bot.
-- Server owns the board and validates all moves, including check and castling.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local TweenService=game:GetService("TweenService")
local PieceFactory=require(RS:WaitForChild("LashboundChessPieceFactory"))
local rng=Random.new()
local Request=RS:FindFirstChild("LashboundChessRequest") or Instance.new("RemoteEvent")
Request.Name="LashboundChessRequest";Request.Parent=RS
local State=RS:FindFirstChild("LashboundChessState") or Instance.new("RemoteEvent")
State.Name="LashboundChessState";State.Parent=RS
local lastAt={}
local function cell(r,c) return (r-1)*8+c end
local function coords(i) return math.floor((i-1)/8)+1,(i-1)%8+1 end
local function inBounds(r,c) return r>=1 and r<=8 and c>=1 and c<=8 end
local function color(p) return p and (p:match("%u") and "w" or "b") or nil end
local function initial()
    local b={}
    local back={"r","n","b","q","k","b","n","r"}
    for c=1,8 do
        b[cell(1,c)]=back[c]; b[cell(2,c)]="p"
        b[cell(7,c)]="P";b[cell(8,c)]=string.upper(back[c])
    end
    return b
end
local gameState={board=initial(),turn="w",white=nil,black=nil,mode="idle",status="Choose PvP or bot.",
    castling={K=true,Q=true,k=true,q=true}, ep=nil, ply=0, version=0, lastMove=nil, ended=false}
local tablePart=nil
local function chessPart()
    if tablePart and tablePart.Parent then return tablePart end
    local lobby=Workspace:FindFirstChild("LashboundLobby")
    tablePart=lobby and lobby:FindFirstChild("LashboundChessBoard")
    return tablePart
end
local function closeEnough(p)
    if p:GetAttribute("Zone")~="Lobby" then return false end
    local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    local tableTop=chessPart()
    return root and tableTop and (root.Position-tableTop.Position).Magnitude<32
end
local dirsRook={{1,0},{-1,0},{0,1},{0,-1}}
local dirsBishop={{1,1},{1,-1},{-1,1},{-1,-1}}
local knights={{-2,-1},{-2,1},{2,-1},{2,1},{-1,-2},{-1,2},{1,-2},{1,2}}
local function squareAttacked(b,r,c,by)
    local pawn=(by=="w" and "P" or "p")
    local pawnFrom=r+(by=="w" and 1 or -1)
    for _,dc in ipairs({-1,1}) do
        if inBounds(pawnFrom,c+dc) and b[cell(pawnFrom,c+dc)]==pawn then return true end
    end
    for _,d in ipairs(knights) do
        local rr,cc=r+d[1],c+d[2]
        if inBounds(rr,cc) and b[cell(rr,cc)]==(by=="w" and "N" or "n") then return true end
    end
    for _,d in ipairs(dirsRook) do
        local rr,cc=r+d[1],c+d[2]
        for range=1,7 do
            if not inBounds(rr,cc) then break end
            local p=b[cell(rr,cc)]
            if p then
                if color(p)==by and ((p:lower()=="r" or p:lower()=="q") or (range==1 and p:lower()=="k")) then return true end
                break
            end
            rr+=d[1];cc+=d[2]
        end
    end
    for _,d in ipairs(dirsBishop) do
        local rr,cc=r+d[1],c+d[2]
        for range=1,7 do
            if not inBounds(rr,cc) then break end
            local p=b[cell(rr,cc)]
            if p then
                if color(p)==by and ((p:lower()=="b" or p:lower()=="q") or (range==1 and p:lower()=="k")) then return true end
                break
            end
            rr+=d[1];cc+=d[2]
        end
    end
    return false
end
local function inCheck(b,side)
    local king=side=="w" and "K" or "k"
    for i=1,64 do
        if b[i]==king then
            local r,c=coords(i)
            return squareAttacked(b,r,c,side=="w" and "b" or "w")
        end
    end
    return true
end
local function pseudo(g,side)
    local b=g.board;local moves={}
    local function add(fr,to,castle,epCapture)
        local target=b[to]
        -- The king is never captured; the game ends through checkmate.
        if target and target:lower()=="k" then return end
        table.insert(moves,{from=fr,to=to,castle=castle,epCapture=epCapture})
    end
    local function scan(fr,r,c,directions)
        for _,d in ipairs(directions) do
            local rr,cc=r+d[1],c+d[2]
            while inBounds(rr,cc) do
                local to=cell(rr,cc)
                if color(b[to])==side then break end
                add(fr,to)
                if b[to] then break end
                rr+=d[1];cc+=d[2]
            end
        end
    end
    for i=1,64 do
        local p=b[i]
        if p and color(p)==side then
            local r,c=coords(i)
            local role=p:lower()
            if role=="p" then
                local dr=side=="w" and -1 or 1
                local one=r+dr
                if inBounds(one,c) and not b[cell(one,c)] then
                    add(i,cell(one,c))
                    local start=side=="w" and 7 or 2
                    if r==start and not b[cell(r+2*dr,c)] then add(i,cell(r+2*dr,c)) end
                end
                for _,dc in ipairs({-1,1}) do
                    if inBounds(one,c+dc) then
                        local sq=cell(one,c+dc)
                        if b[sq] and color(b[sq])~=side then add(i,sq)
                        elseif g.ep==sq then add(i,sq,nil,cell(r,c+dc)) end
                    end
                end
            elseif role=="n" then
                for _,d in ipairs(knights) do
                    local rr,cc=r+d[1],c+d[2]
                    if inBounds(rr,cc) and color(b[cell(rr,cc)])~=side then add(i,cell(rr,cc)) end
                end
            elseif role=="b" then scan(i,r,c,dirsBishop)
            elseif role=="r" then scan(i,r,c,dirsRook)
            elseif role=="q" then
                scan(i,r,c,dirsRook);scan(i,r,c,dirsBishop)
            elseif role=="k" then
                for dr=-1,1 do for dc=-1,1 do
                    if not(dr==0 and dc==0) and inBounds(r+dr,c+dc) and color(b[cell(r+dr,c+dc)])~=side then
                        add(i,cell(r+dr,c+dc))
                    end
                end end
                local home=side=="w" and 8 or 1
                local rights=g.castling
                if r==home and c==5 and not inCheck(b,side) then
                    local them=side=="w" and "b" or "w"
                    local rook=side=="w" and "R" or "r"
                    local kingRight=side=="w" and "K" or "k"
                    local queenRight=side=="w" and "Q" or "q"
                    if rights[kingRight] and b[cell(home,8)]==rook
                       and not b[cell(home,6)] and not b[cell(home,7)]
                       and not squareAttacked(b,home,6,them) and not squareAttacked(b,home,7,them) then
                        add(i,cell(home,7),"K")
                    end
                    if rights[queenRight] and b[cell(home,1)]==rook
                       and not b[cell(home,2)] and not b[cell(home,3)] and not b[cell(home,4)]
                       and not squareAttacked(b,home,4,them) and not squareAttacked(b,home,3,them) then
                        add(i,cell(home,3),"Q")
                    end
                end
            end
        end
    end
    return moves
end
local function applyMove(g,move)
    local b=table.clone(g.board)
    local castle=table.clone(g.castling)
    local p=b[move.from]
    local startR,startC=coords(move.from)
    local toR,toC=coords(move.to)
    local taken=b[move.to]
    b[move.to]=p;b[move.from]=nil
    if move.epCapture then b[move.epCapture]=nil end
    if move.castle then
        local rookFrom=cell(startR,move.castle=="K" and 8 or 1)
        local rookTo=cell(startR,move.castle=="K" and 6 or 4)
        b[rookTo]=b[rookFrom];b[rookFrom]=nil
    end
    if p:lower()=="p" and (toR==1 or toR==8) then b[move.to]=color(p)=="w" and "Q" or "q" end
    if p=="K" then castle.K=false;castle.Q=false end
    if p=="k" then castle.k=false;castle.q=false end
    if move.from==cell(8,1) or move.to==cell(8,1) then castle.Q=false end
    if move.from==cell(8,8) or move.to==cell(8,8) then castle.K=false end
    if move.from==cell(1,1) or move.to==cell(1,1) then castle.q=false end
    if move.from==cell(1,8) or move.to==cell(1,8) then castle.k=false end
    local ep=nil
    if p:lower()=="p" and math.abs(toR-startR)==2 then ep=cell(math.floor((startR+toR)/2),startC) end
    local opp=g.turn=="w" and "b" or "w"
    return {board=b,turn=opp,white=g.white,black=g.black,mode=g.mode,castling=castle,ep=ep,ply=g.ply+1,
        version=g.version+1,lastMove={move.from,move.to},ended=false,status="",captured=taken}
end
local function legal(g,side)
    local out={}
    for _,move in ipairs(pseudo(g,side)) do
        local nextG=applyMove(g,move)
        if not inCheck(nextG.board,side) then table.insert(out,move) end
    end
    return out
end
local function endCondition(g)
    local moves=legal(g,g.turn)
    if #moves==0 then
        g.ended=true
        if inCheck(g.board,g.turn) then
            g.status="CHECKMATE · "..(g.turn=="w" and "Black" or "White").." wins!"
        else
            g.status="STALEMATE · draw"
        end
    elseif inCheck(g.board,g.turn) then
        g.status=(g.turn=="w" and "White" or "Black").." is in check"
    else
        g.status=(g.turn=="w" and "White" or "Black").." to move"
    end
end
local function snapshot(g)
    local b={}
    for i=1,64 do b[i]=g.board[i] or "" end
    return {board=b,turn=g.turn,mode=g.mode,status=g.status,white=g.white and g.white.UserId or 0,
        black=g.black and g.black.UserId or 0,ended=g.ended,ply=g.ply,lastMove=g.lastMove,version=g.version,
        check=inCheck(g.board,g.turn)}
end
-- A single, persistent set of 3D pieces follows the SAME authoritative board
-- used by PvP, bot logic, captures, castling and the client's bird's-eye view.
-- Pieces tween between squares instead of deleting/rebuilding on each move.
local physical={folder=nil,bySquare={},version=-1,board=nil}
local MOVE_TIME=.40
local function pieceCFrame(boardTop,square)
    local r,c=coords(square)
    return boardTop.CFrame*CFrame.new((c-4.5)*PieceFactory.Square,boardTop.Size.Y/2+.065,(r-4.5)*PieceFactory.Square)
end
local function physicalFolder(boardTop)
    if not boardTop then return nil end
    local folder=boardTop:FindFirstChild('ChessPieces')
    if folder and physical.folder==folder then return folder end
    if folder then folder:Destroy() end
    folder=Instance.new('Folder')
    folder.Name='ChessPieces';folder.Parent=boardTop
    physical.folder=folder;physical.bySquare={};physical.version=-1
    return folder
end
local function fullRedraw()
    local boardTop=chessPart()
    if not boardTop then return end
    local folder=physicalFolder(boardTop)
    folder:ClearAllChildren()
    physical.bySquare={}
    for ix=1,64 do
        local piece=gameState.board[ix]
        if piece then
            local model=PieceFactory.Create(piece,folder,pieceCFrame(boardTop,ix))
            model:SetAttribute('Square',ix)
            physical.bySquare[ix]=model
        end
    end
    physical.version=gameState.version
end
local function glide(model,cf)
    if model and model.Parent and model.PrimaryPart then
        TweenService:Create(model.PrimaryPart, TweenInfo.new(MOVE_TIME,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{CFrame=cf}):Play()
    end
end
local function performVisualMove(move)
    local boardTop=chessPart()
    if not boardTop then return end
    local folder=physicalFolder(boardTop)
    if physical.version~=gameState.version-1 then fullRedraw();return end
    local moving=physical.bySquare[move.from]
    if not moving then fullRedraw();return end
    local target=physical.bySquare[move.to]
    if target then
        target:Destroy()
        physical.bySquare[move.to]=nil
    end
    if move.epCapture then
        local pawn=physical.bySquare[move.epCapture]
        if pawn then pawn:Destroy(); physical.bySquare[move.epCapture]=nil end
    end
    physical.bySquare[move.from]=nil
    physical.bySquare[move.to]=moving
    moving:SetAttribute('Square',move.to)
    glide(moving,pieceCFrame(boardTop,move.to))
    if move.castle then
        local r=math.floor((move.from-1)/8)+1
        local rf=cell(r,move.castle=='K' and 8 or 1)
        local rt=cell(r,move.castle=='K' and 6 or 4)
        local rook=physical.bySquare[rf]
        if rook then
            physical.bySquare[rf]=nil; physical.bySquare[rt]=rook
            rook:SetAttribute('Square',rt)
            glide(rook,pieceCFrame(boardTop,rt))
        end
    end
    physical.version=gameState.version
    -- Promotion gets a proper queen model once the movement finishes.
    local resulting=gameState.board[move.to]
    if resulting and resulting~=moving:GetAttribute('ChessPiece') then
        local version=gameState.version
        task.delay(MOVE_TIME+.015,function()
            if gameState.version~=version or physical.bySquare[move.to]~=moving then return end
            if moving.Parent then moving:Destroy() end
            local queen=PieceFactory.Create(resulting,folder,pieceCFrame(boardTop,move.to))
            queen:SetAttribute('Square',move.to)
            physical.bySquare[move.to]=queen
        end)
    end
end
local function redrawTable(move)
    if move then performVisualMove(move)
    elseif physical.version~=gameState.version then fullRedraw() end
end
local function broadcast(move)
    redrawTable(move)
    local info=snapshot(gameState)
    for _,p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute('Zone')=='Lobby' then State:FireClient(p,info) end
    end
end
local function fresh()
    return {board=initial(),turn="w",white=nil,black=nil,mode="idle",status="Choose PvP or bot.",
        castling={K=true,Q=true,k=true,q=true},ep=nil,ply=0,version=gameState.version+1,lastMove=nil,ended=false}
end
local function decideBot(g)
    local choices=legal(g,"b")
    if #choices==0 then return nil end
    -- ~600-style casual beginner: frequent mistakes and some free captures.
    -- This is NOT a calibrated external chess engine rating.
    if rng:NextNumber()<.42 then return choices[rng:NextInteger(1,#choices)] end
    local weights={p=1,n=3,b=3.15,r=5,q=9,k=0}
    local best=-math.huge;local candidates={}
    for _,m in ipairs(choices) do
        local target=g.board[m.to]
        local after=applyMove(g,m)
        local score=(target and (weights[target:lower()] or 0)*1.6 or 0)
        if m.epCapture then score = score + 1.5 end
        if m.castle then score = score + 1 end
        if inCheck(after.board,"w") then score = score + 1.5 end
        local r,c=coords(m.to)
        score = score + (3.5-math.abs(c-4.5))*.15
        score = score + rng:NextNumber(-2.8,2.8)
        if score>best then best=score;candidates={m} end
    end
    return candidates[1]
end
local function moveBot(expectedVersion)
    task.delay(.72,function()
        local g=gameState
        if g.version~=expectedVersion or g.mode~="bot" or g.ended or g.turn~="b" then return end
        local move=decideBot(g)
        if not move then endCondition(g);broadcast();return end
        local newer=applyMove(g,move)
        endCondition(newer)
        gameState=newer
        broadcast(move)
    end)
end
Request.OnServerEvent:Connect(function(p,action,from,to)
    if typeof(action)~="string" or not closeEnough(p) then return end
    local now=os.clock()
    if now-(lastAt[p] or -2)<.12 then return end
    lastAt[p]=now
    if action=="View" then
        State:FireClient(p,snapshot(gameState))
        return
    end
    if action=="Bot" then
        if gameState.mode~="idle" and not gameState.ended and (gameState.white~=p or gameState.mode~="bot") then
            State:FireClient(p,snapshot(gameState));return
        end
        gameState=fresh()
        gameState.mode="bot";gameState.white=p;gameState.status="White to move · beginner bot"
        broadcast();return
    end
    if action=="PvP" then
        if gameState.mode=="idle" or gameState.ended then
            gameState=fresh()
            gameState.mode="pvp";gameState.white=p
            gameState.status="Waiting for another player to join as Black..."
        elseif gameState.mode=="pvp" and not gameState.black and gameState.white~=p then
            gameState.black=p;gameState.status="White to move"
        end
        broadcast();return
    end
    if action=="Resign" then
        if gameState.white==p or gameState.black==p then
            gameState.status=p.DisplayName.." resigned. Select a new game."
            gameState.ended=true
            gameState.version+=1
            broadcast()
        end
        return
    end
    if action~="Move" or type(from)~="number" or type(to)~="number" or from%1~=0 or to%1~=0 then return end
    if from<1 or from>64 or to<1 or to>64 or gameState.ended then return end
    local side=gameState.turn
    if gameState.mode=="pvp" and not gameState.black then return end
    if (side=="w" and gameState.white~=p) or (side=="b" and gameState.black~=p) then return end
    for _,move in ipairs(legal(gameState,side)) do
        if move.from==from and move.to==to then
            local g=applyMove(gameState,move)
            endCondition(g)
            gameState=g
            broadcast(move)
            if g.mode=="bot" and g.turn=="b" and not g.ended then moveBot(g.version) end
            return
        end
    end
    State:FireClient(p,snapshot(gameState))
end)
Players.PlayerRemoving:Connect(function(p)
    lastAt[p]=nil
    if gameState.white==p or gameState.black==p then
        gameState=fresh()
        gameState.status="Previous player left. Choose a new game."
        broadcast()
    end
end)

task.defer(function()
    for _=1,20 do
        local boardTop=chessPart()
        if boardTop then
            redrawTable()
            local prompt=boardTop:FindFirstChild("ChessPrompt")
            if not prompt then
                prompt=Instance.new("ProximityPrompt")
                prompt.Name="ChessPrompt"
                prompt.Parent=boardTop
            end
            prompt.ActionText="PLAY CHESS"
            prompt.ObjectText="UPSTAIRS CHESS - BOT OR 2 PLAYERS"
            prompt.HoldDuration=0
            prompt.MaxActivationDistance=17
            prompt.RequiresLineOfSight=false
            prompt.Enabled=true
            if not boardTop:FindFirstChild("V26ChessCue") then
                local tag=Instance.new("BillboardGui")
                tag.Name="V26ChessCue"
                tag.Adornee=boardTop
                tag.AlwaysOnTop=true
                tag.MaxDistance=115
                tag.StudsOffsetWorldSpace=Vector3.new(0,4.1,0)
                tag.Size=UDim2.fromOffset(260,61)
                tag.Parent=boardTop
                local text=Instance.new("TextLabel")
                text.Size=UDim2.fromScale(1,1)
                text.BackgroundColor3=Color3.fromRGB(56,35,24)
                text.BackgroundTransparency=.11
                text.TextColor3=Color3.fromRGB(255,237,199)
                text.Font=Enum.Font.GothamBold
                text.TextScaled=true
                text.Text="CHESS  •  BOT / 2 PLAYERS\nE / TAP TO PLAY"
                text.Parent=tag
                Instance.new("UICorner",text).CornerRadius=UDim.new(0,12)
            end
            if prompt then
                prompt.Triggered:Connect(function(p)
                    if not closeEnough(p) then return end
                    RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback"):FireClient(p,"OpenChess")
                    State:FireClient(p,snapshot(gameState))
                end)
            end
            return
        end
        task.wait(.25)
    end
end)
