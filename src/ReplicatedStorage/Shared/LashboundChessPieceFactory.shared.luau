-- Shared chess-piece geometry used on BOTH the real cabin table and the
-- orthographic-overhead chess window. No uploaded textures or font glyphs needed.
local Factory={}
Factory.Square=0.84
local W=Color3.fromRGB(246,233,205)
local WS=Color3.fromRGB(203,177,131)
local B=Color3.fromRGB(52,47,53)
local BS=Color3.fromRGB(105,101,109)
local GOLD=Color3.fromRGB(218,172,92)
local function makePart(model,root,name,size,relative,kind,col,mat)
    local p=Instance.new(kind or 'Part')
    p.Name=name
    p.Size=size
    p.CFrame=root.CFrame*relative
    p.Color=col
    p.Material=mat or Enum.Material.SmoothPlastic
    p.Anchored=false
    p.Massless=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false
    p.Parent=model
    local weld=Instance.new('WeldConstraint')
    weld.Part0=root;weld.Part1=p;weld.Parent=p
    return p
end
function Factory.SquareCFrame(r,c,baseY,baseX,baseZ)
    return CFrame.new(baseX+(c-4.5)*Factory.Square,baseY,baseZ+(r-4.5)*Factory.Square)
end
function Factory.Create(piece,parent,origin)
    assert(type(piece)=='string' and #piece==1,'Invalid chess piece')
    local white=piece==piece:upper()
    local base=white and W or B
    local shade=white and WS or BS
    local role=piece:lower()
    local model=Instance.new('Model')
    model.Name=(white and 'Ivory_' or 'Ebony_')..role
    model:SetAttribute('ChessPiece',piece)
    model.Parent=parent
    local root=Instance.new('Part')
    root.Name='Mover'
    root.Size=Vector3.new(.08,.08,.08)
    root.CFrame=origin
    root.Anchored=true
    root.Transparency=1
    root.CanCollide=false;root.CanTouch=false;root.CanQuery=false
    root.CastShadow=false
    root.Parent=model
    model.PrimaryPart=root
    local function p(name,size,offset,kind,col,material)
        return makePart(model,root,name,size,CFrame.new(offset),kind or 'Part',col or base,material)
    end
    p('EngravedFoot',Vector3.new(.65,.11,.65),Vector3.new(0,.085,0),'Part',shade)
    p('RoundPlinth',Vector3.new(.53,.10,.53),Vector3.new(0,.17,0),'Part',base)
    p('Column',Vector3.new(.36,.29,.36),Vector3.new(0,.35,0),'Part',base)
    if role=='p' then
        p('PawnShoulder',Vector3.new(.34,.10,.34),Vector3.new(0,.50,0),'Part',shade)
        p('PawnRoundHead',Vector3.new(.31,.31,.31),Vector3.new(0,.69,0),'Part',base).Shape=Enum.PartType.Ball
    elseif role=='r' then
        p('CastleTurret',Vector3.new(.49,.29,.49),Vector3.new(0,.60,0),'Part',base)
        p('CastleRim',Vector3.new(.61,.09,.61),Vector3.new(0,.77,0),'Part',shade)
        for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
            p('Battlement_'..x..'_'..z,Vector3.new(.20,.17,.20),Vector3.new(x*.22,.87,z*.22),'Part',base)
        end end
    elseif role=='n' then
        p('HorseNeck',Vector3.new(.32,.35,.37),Vector3.new(.02,.57,0),'Part',base)
        local head=makePart(model,root,'HorseHead',Vector3.new(.33,.28,.37),CFrame.new(0,.78,-.12)*CFrame.Angles(math.rad(-26),0,0),'Part',base)
        local muzzle=p('HorseMuzzle',Vector3.new(.37,.18,.33),Vector3.new(0,.76,-.34),'Part',shade)
        p('HorseEarL',Vector3.new(.10,.21,.10),Vector3.new(-.12,1.02,-.10),'Part',base)
        p('HorseEarR',Vector3.new(.10,.21,.10),Vector3.new(.12,1.02,-.10),'Part',base)
        p('HorseEyeLeft',Vector3.new(.07,.08,.07),Vector3.new(-.18,.84,-.23),'Part',GOLD).Shape=Enum.PartType.Ball
        p('HorseEyeRight',Vector3.new(.07,.08,.07),Vector3.new(.18,.84,-.23),'Part',GOLD).Shape=Enum.PartType.Ball
    elseif role=='b' then
        p('BishopNeck',Vector3.new(.40,.20,.40),Vector3.new(0,.54,0),'Part',shade)
        p('BishopMitre',Vector3.new(.37,.43,.37),Vector3.new(0,.78,0),'Part',base).Shape=Enum.PartType.Ball
        p('BishopStripe',Vector3.new(.08,.32,.09),Vector3.new(0,.84,-.19),'Part',GOLD)
        p('BishopTip',Vector3.new(.11,.11,.11),Vector3.new(0,1.03,0),'Part',GOLD).Shape=Enum.PartType.Ball
    elseif role=='q' then
        p('QueenCrownBand',Vector3.new(.60,.12,.60),Vector3.new(0,.65,0),'Part',GOLD)
        for i=1,5 do
            local a=(i-1)*math.pi*2/5
            local x,z=math.cos(a)*.23,math.sin(a)*.23
            p('QueenProng'..i,Vector3.new(.13,.29,.13),Vector3.new(x,.85,z),'Part',base)
            p('QueenPearl'..i,Vector3.new(.12,.12,.12),Vector3.new(x,1.03,z),'Part',GOLD).Shape=Enum.PartType.Ball
        end
        p('QueenCentralJewel',Vector3.new(.17,.17,.17),Vector3.new(0,.86,0),'Part',shade).Shape=Enum.PartType.Ball
    elseif role=='k' then
        p('RoyalCrown',Vector3.new(.51,.18,.51),Vector3.new(0,.63,0),'Part',GOLD)
        p('CrossUpright',Vector3.new(.16,.46,.16),Vector3.new(0,.92,0),'Part',base)
        p('CrossBeam',Vector3.new(.43,.12,.14),Vector3.new(0,1.01,0),'Part',base)
        p('RoyalGem',Vector3.new(.20,.10,.20),Vector3.new(0,.75,0),'Part',shade)
    end
    -- High-contrast chess crest, readable from the genuine overhead camera.
    -- Standard algebraic symbols: N is the knight, never K (king).
    local roleNames={p='P',r='R',n='N',b='B',q='Q',k='K'}
    local nameMap={p='PAWN',r='ROOK',n='KNIGHT',b='BISHOP',q='QUEEN',k='KING'}
    local cap=p('RoleCrest',Vector3.new(.48,.075,.48),Vector3.new(0,1.18,0),'Part',shade)
    cap.Material=Enum.Material.Metal
    local crest=Instance.new('SurfaceGui')
    crest.Name='OverheadPieceIdentifier'
    crest.Face=Enum.NormalId.Top
    crest.AlwaysOnTop=true
    crest.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
    crest.PixelsPerStud=170
    crest.Parent=cap
    local text=Instance.new('TextLabel')
    text.Name='Role'
    text.Size=UDim2.fromScale(1,1)
    text.BackgroundTransparency=1
    text.Text=roleNames[role]
    text.Font=Enum.Font.GothamBlack
    text.TextScaled=true
    text.TextColor3=white and Color3.fromRGB(36,31,29) or Color3.fromRGB(251,236,194)
    text.TextStrokeTransparency=.27
    text.TextStrokeColor3=white and Color3.fromRGB(250,237,207) or Color3.fromRGB(21,19,21)
    text.Parent=crest
    model:SetAttribute('PieceRole',nameMap[role])
    return model,root
end
return Factory
