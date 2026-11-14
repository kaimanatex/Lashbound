-- LASHBOUND V21. Both the cabin table and the chess window use the SAME
-- server-validated game state and the SAME unique 3D piece models.
-- The viewport camera is directly overhead: black at top, white at bottom.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local TweenService=game:GetService('TweenService')
local me=Players.LocalPlayer
local Request=RS:WaitForChild('LashboundChessRequest')
local State=RS:WaitForChild('LashboundChessState')
local Feedback=RS:WaitForChild('LashboundV5Remotes'):WaitForChild('Feedback')
local Factory=require(RS:WaitForChild('LashboundChessPieceFactory'))
local MOVE_TIME=.40
local function button(parent,words,position,size,color)
    local obj=Instance.new('TextButton')
    obj.Text=words;obj.Font=Enum.Font.GothamBold;obj.TextScaled=true
    obj.TextColor3=Color3.fromRGB(255,247,230)
    obj.BackgroundColor3=color or Color3.fromRGB(112,80,56)
    obj.BorderSizePixel=0;obj.Position=position;obj.Size=size
    obj.Parent=parent
    return obj
end
local function label(parent,words,position,size,font,color)
    local obj=Instance.new('TextLabel')
    obj.BackgroundTransparency=1;obj.Text=words;obj.Position=position;obj.Size=size
    obj.Font=font or Enum.Font.GothamBold;obj.TextScaled=true
    obj.TextColor3=color or Color3.fromRGB(255,247,230)
    obj.TextStrokeTransparency=.7;obj.Parent=parent
    return obj
end
local gui=Instance.new('ScreenGui')
gui.Name='LashboundChess';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true
 gui.DisplayOrder=28;gui.Enabled=false;gui.Parent=me:WaitForChild('PlayerGui')
local shade=Instance.new('Frame')
shade.Name='ChessBackdrop';shade.Size=UDim2.fromScale(1,1)
shade.BackgroundColor3=Color3.fromRGB(14,11,9)
shade.BackgroundTransparency=.10;shade.Parent=gui
local panel=Instance.new('Frame')
panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
panel.Size=UDim2.fromOffset(496,602)
panel.BackgroundColor3=Color3.fromRGB(57,40,30)
panel.BorderSizePixel=0;panel.Parent=shade
local scale=Instance.new('UIScale');scale.Parent=panel
local outline=Instance.new('UIStroke');outline.Color=Color3.fromRGB(220,177,103)
outline.Thickness=3;outline.Parent=panel
label(panel,'CABIN CHESS  ·  BIRD\'S-EYE VIEW',UDim2.fromOffset(15,9),UDim2.fromOffset(404,43),Enum.Font.GothamBlack,Color3.fromRGB(250,224,168))
local close=button(panel,'X',UDim2.fromOffset(439,11),UDim2.fromOffset(42,37),Color3.fromRGB(140,73,60))
local versus=button(panel,'2 PLAYERS',UDim2.fromOffset(16,57),UDim2.fromOffset(150,35))
local bot=button(panel,'BOT ~600',UDim2.fromOffset(174,57),UDim2.fromOffset(140,35))
local resign=button(panel,'RESIGN',UDim2.fromOffset(323,57),UDim2.fromOffset(156,35),Color3.fromRGB(133,67,58))
local info=label(panel,'Choose a game mode.',UDim2.fromOffset(14,96),UDim2.fromOffset(469,30),Enum.Font.GothamBold,Color3.fromRGB(255,216,148))
info.TextWrapped=true

-- Orthogonal bird's-eye composition, looking straight down the Y axis.
-- A WorldModel presents real 3D silhouettes, avoiding unsupported chess fonts.
local boardFrame=Instance.new('Frame')
boardFrame.Name='TrueTopDownChessBoard'
boardFrame.Position=UDim2.fromOffset(36,133)
boardFrame.Size=UDim2.fromOffset(424,424)
boardFrame.BackgroundColor3=Color3.fromRGB(81,61,42)
boardFrame.BorderSizePixel=0;boardFrame.ClipsDescendants=true
boardFrame.Parent=panel
local viewport=Instance.new('ViewportFrame')
viewport.Name='Overhead3DView'
viewport.Size=UDim2.fromScale(1,1)
viewport.BackgroundColor3=Color3.fromRGB(68,47,31)
viewport.BorderSizePixel=0
viewport.Ambient=Color3.fromRGB(198,193,178)
viewport.LightColor=Color3.fromRGB(255,246,223)
viewport.LightDirection=Vector3.new(-.5,-1,-.5)
viewport.Parent=boardFrame
viewport.Visible=false -- V38 uses readable flat pieces on the board instead of top-down 3D silhouettes
local viewCamera=Instance.new('Camera')
viewCamera.Name='VerticalChessCamera'
viewCamera.FieldOfView=26
viewCamera.CFrame=CFrame.lookAt(Vector3.new(0,15,0),Vector3.zero,Vector3.new(0,0,-1))
viewCamera.Parent=viewport
viewport.CurrentCamera=viewCamera
local world=Instance.new('WorldModel');world.Name='TabletopScene';world.Parent=viewport
local tiles=Instance.new('Folder');tiles.Name='ChessSquareModels';tiles.Parent=world
local visualFolder=Instance.new('Folder');visualFolder.Name='ChessPieceModels';visualFolder.Parent=world
for row=1,8 do
    for col=1,8 do
        local tile=Instance.new('Part')
        tile.Name='BoardSquare_'..row..'_'..col
        tile.Anchored=true;tile.CanCollide=false;tile.CanTouch=false;tile.CanQuery=false
        tile.CastShadow=false
        tile.Size=Vector3.new(Factory.Square,.04,Factory.Square)
        tile.Material=Enum.Material.SmoothPlastic
        tile.Color=(row+col)%2==0 and Color3.fromRGB(232,209,169) or Color3.fromRGB(109,77,53)
        tile.CFrame=CFrame.new((col-4.5)*Factory.Square,-.035,(row-4.5)*Factory.Square)
        tile.Parent=tiles
    end
end
local boardEdge=Instance.new('Part')
boardEdge.Name='SolidWoodChessEdge';boardEdge.Anchored=true
boardEdge.CanCollide=false;boardEdge.CanTouch=false;boardEdge.CanQuery=false
boardEdge.Size=Vector3.new(7.04,.11,7.04)
boardEdge.Material=Enum.Material.WoodPlanks
boardEdge.Color=Color3.fromRGB(96,62,43)
boardEdge.Position=Vector3.new(0,-.11,0);boardEdge.Parent=tiles

local board={}
local state=nil
local selected=nil
local frames={}
local shownPieces={}
local flatPieces={}
local visibleBoard={}
local shownVersion=-1
local shownMode=''
local glyphLetters={k='K',q='Q',r='R',b='B',n='N',p='P'}
local function sqCFrame(index)
    local row=math.floor((index-1)/8)+1
    local col=(index-1)%8+1
    return CFrame.new((col-4.5)*Factory.Square,.03,(row-4.5)*Factory.Square)
end
local function removeSquare(i)
    local model=shownPieces[i]
    if model then model:Destroy() end
    shownPieces[i]=nil
end
local function addSquare(i,piece)
    if not piece or piece=='' then return end
    local model=Factory.Create(piece,visualFolder,sqCFrame(i))
    model:SetAttribute('Square',i)
    shownPieces[i]=model
end
local function fullSync(b)
    visualFolder:ClearAllChildren()
    shownPieces={}
    for i=1,64 do
        if b[i] and b[i]~='' then addSquare(i,b[i]) end
    end
end
local function repairPieces(b)
    for i=1,64 do
        local want=b[i]
        local model=shownPieces[i]
        if not want or want=='' then
            if model then removeSquare(i) end
        elseif not model or model:GetAttribute('ChessPiece')~=want then
            if model then removeSquare(i) end
            addSquare(i,want)
        end
    end
end
local function animateMove(model,i)
    if not model or not model.PrimaryPart then return end
    TweenService:Create(model.PrimaryPart,
        TweenInfo.new(MOVE_TIME,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {CFrame=sqCFrame(i)}):Play()
end
local function applyViewState(data)
    local b=data.board or {}
    if data.version==shownVersion then return end
    local move=data.lastMove
    local from=type(move)=='table' and move[1]
    local to=type(move)=='table' and move[2]
    local simpleMove=type(from)=='number' and type(to)=='number'
        and data.version==shownVersion+1 and shownPieces[from]~=nil
        and (data.mode=='pvp' or data.mode=='bot')
    if not simpleMove then
        fullSync(b)
    else
        local moving=shownPieces[from]
        removeSquare(to) -- captured piece leaves immediately
        shownPieces[from]=nil
        shownPieces[to]=moving
        moving:SetAttribute('Square',to)
        animateMove(moving,to)
        -- If a king castles, move the rook at the same instant.
        local prevPiece=moving:GetAttribute('ChessPiece')
        if prevPiece and prevPiece:lower()=='k' and math.abs(to-from)==2 then
            local r=math.floor((from-1)/8)+1
            local kingSide=to>from
            local rookFrom=(r-1)*8+(kingSide and 8 or 1)
            local rookTo=(r-1)*8+(kingSide and 6 or 4)
            local rook=shownPieces[rookFrom]
            if rook then
                shownPieces[rookFrom]=nil;shownPieces[rookTo]=rook
                rook:SetAttribute('Square',rookTo)
                animateMove(rook,rookTo)
            end
        end
        local version=data.version
        task.delay(MOVE_TIME+.02,function()
            if shownVersion==version and gui.Enabled then repairPieces(b) end
        end)
    end
    -- Keep the displayed pieces and authoritative board state synchronized.
    -- Chess Unicode glyphs can render blank in a font fallback on some devices.
    -- All six types now have legible letter marks on distinct team-colored tokens.
    for i=1,64 do
        local token=flatPieces[i]
        if token then
            local piece=b[i] or ''
            local occupied=type(piece)=='string' and piece~=''
            token.Visible=occupied
            if occupied then
                local white=piece:match('%u')~=nil
                token.BackgroundColor3=white and Color3.fromRGB(249,245,227) or Color3.fromRGB(37,44,42)
                local rim=token:FindFirstChildOfClass('UIStroke')
                if rim then rim.Color=white and Color3.fromRGB(82,80,69) or Color3.fromRGB(237,239,222) end
                local mark=token:FindFirstChild('PieceLetter')
                if mark then
                    mark.Text=piece:upper() -- K Q R B N P in GothamBlack; original 3D piece remains beneath it
                    mark.TextColor3=white and Color3.fromRGB(40,48,43) or Color3.fromRGB(251,251,239)
                end
            end
        end
    end
    shownVersion=data.version
    shownMode=data.mode
end

-- Transparent 8x8 click grid OVER the rendered 3D pieces.
-- White's home row is on the bottom and black's home row at the top.
local function highlight()
    for ix,tile in ipairs(frames) do
        local last=state and state.lastMove
        local active=selected==ix
        local recent=last and (last[1]==ix or last[2]==ix)
        local row=math.floor((ix-1)/8)+1
        local col=(ix-1)%8+1
        tile.BackgroundColor3=active and Color3.fromRGB(246,246,105) or recent and Color3.fromRGB(202,211,104) or ((row+col)%2==0 and Color3.fromRGB(238,238,210) or Color3.fromRGB(118,150,86))
        tile.BackgroundTransparency=0
    end
end
for row=1,8 do for col=1,8 do
    local i=(row-1)*8+col
    -- There is a small 6px border around the 3D tiles; each tile is 51.5px.
    local tile=button(boardFrame,'',UDim2.fromOffset(6+(col-1)*51.5,6+(row-1)*51.5),
        UDim2.fromOffset(51.5,51.5),Color3.fromRGB(245,212,115))
    tile.Name='Square_'..i
    tile.BackgroundTransparency=1;tile.Text=''
    tile.AutoButtonColor=false;tile.ZIndex=3
    frames[i]=tile
    tile.BackgroundColor3=(row+col)%2==0 and Color3.fromRGB(238,238,210) or Color3.fromRGB(118,150,86)
    tile.BackgroundTransparency=0
    local token=Instance.new('Frame')
    token.Name='ChessPieceToken'
    token.AnchorPoint=Vector2.new(.5,.5)
    token.Position=UDim2.fromScale(.5,.5)
    token.Size=UDim2.fromScale(.76,.76)
    token.BorderSizePixel=0
    token.ZIndex=4
    token.Visible=false
    token.Parent=tile
    local round=Instance.new('UICorner')
    round.CornerRadius=UDim.new(1,0)
    round.Parent=token
    local rim=Instance.new('UIStroke')
    rim.Thickness=2
    rim.Parent=token
    local mark=Instance.new('TextLabel')
    mark.Name='PieceLetter'
    mark.BackgroundTransparency=1
    mark.Size=UDim2.fromScale(1,1)
    mark.Font=Enum.Font.GothamBlack
    mark.TextScaled=true
    mark.Text=''
    mark.ZIndex=5
    mark.Parent=token
    flatPieces[i]=token
    local tiny=label(tile,'',UDim2.fromOffset(34,35),UDim2.fromOffset(15,13),Enum.Font.GothamBold,Color3.fromRGB(102,87,72))
    tiny.Name='RoleHint'
    tiny.TextStrokeColor3=Color3.fromRGB(12,14,20)
    tiny.TextStrokeTransparency=.10
    tiny.ZIndex=7
    tiny.TextStrokeTransparency=0
    tile.Activated:Connect(function()
        if not state or state.ended then return end
        local ownColor=me.UserId==state.white and 'w' or me.UserId==state.black and 'b' or ''
        if ownColor~=state.turn then return end
        local piece=board[i]
        local friendly=piece and piece~='' and ((piece:match('%u')~=nil and ownColor=='w') or (piece:match('%l')~=nil and ownColor=='b'))
        if selected and selected~=i then
            if friendly then selected=i
            else Request:FireServer('Move',selected,i);selected=nil end
        elseif friendly then selected=i
        else selected=nil end
        highlight()
    end)
end end
local message=label(panel,'WHITE AT BOTTOM  ·  SELECT PIECE → DESTINATION  ·  LIVE TABLE SYNC',
    UDim2.fromOffset(14,559),UDim2.fromOffset(468,27),Enum.Font.Gotham,Color3.fromRGB(227,206,169))
message.TextSize=13;message.TextScaled=false
local function refresh(data)
    if type(data)~='table' or type(data.board)~='table' then return end
    local previousVersion=state and state.version or -1
    state=data
    board=data.board
    selected=nil
    if data.mode=='idle' then
        info.Text='Choose 2 players or bot to begin.'
    else
        local identity=me.UserId==data.white and 'WHITE' or me.UserId==data.black and 'BLACK' or 'SPECTATOR'
        info.Text=identity..'  ·  '..tostring(data.status or '')
    end
    if gui.Enabled then applyViewState(data) end
    for i,tile in ipairs(frames) do
        local piece=board[i]
        local hint=tile:FindFirstChild('RoleHint')
        if hint then
            hint.Text=(piece and piece~='') and (glyphLetters[piece:lower()] or '?') or ''
            hint.TextColor3=(piece and piece:match('%u')) and Color3.fromRGB(255,255,245) or Color3.fromRGB(17,20,24)
        end
    end
    highlight()
end
local function open()
    gui.Enabled=true;selected=nil;shownVersion=-1
    Request:FireServer('View')
end
local function hide()
    gui.Enabled=false;selected=nil;highlight()
end
close.Activated:Connect(hide)
versus.Activated:Connect(function()selected=nil;Request:FireServer('PvP')end)
bot.Activated:Connect(function()selected=nil;Request:FireServer('Bot')end)
resign.Activated:Connect(function()selected=nil;Request:FireServer('Resign')end)
-- Only one chess table exists: never block waiting for removed remotes 2-4.
State.OnClientEvent:Connect(refresh)
Feedback.OnClientEvent:Connect(function(kind)
    if kind=='OpenChess' then
        shownVersion=-1
        open()
    end
end)
local function resize()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local size=camera.ViewportSize
    scale.Scale=math.min(1,(size.X-12)/496,(size.Y-12)/602)
end
resize()
workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(resize)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(resize) end
me:GetAttributeChangedSignal('Zone'):Connect(function()
    if me:GetAttribute('Zone')=='Arena' then hide() end
end)
