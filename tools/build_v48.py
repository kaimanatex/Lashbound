#!/usr/bin/env python3
"""Build V48 directly from V47, preserving all previous scenes and systems."""
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"builds/Lashbound_V47_Boss_Recovery_Whip_Impact.rbxlx"
OUTPUT=ROOT/"builds/Lashbound_V48_Camera_Lock_Grounded_NPCs.rbxlx"

def rep(code,old,new,label):
    if code.count(old)!=1: raise RuntimeError(f"{label}: expected one anchor, got {code.count(old)}")
    return code.replace(old,new,1)

def update_boss(code):
    code=rep(code,
        "    local clearance=floorY+(extra or .9)-lowest\n    if clearance>.08 and clearance<45 then\n        boss.model:PivotTo(boss.model:GetPivot()+Vector3.new(0,clearance,0))\n    end",
        """    local clearance=floorY+(extra or .9)-lowest
    local footSpan=boss.root.Position.Y-lowest -- snapshot before PivotTo
    if math.abs(clearance)>.09 and math.abs(clearance)<45 then
        boss.model:PivotTo(boss.model:GetPivot()+Vector3.new(0,clearance,0))
    end""","boss two-way placement")
    code=rep(code,
        """    -- Humanoid.HipHeight controls physics *after* the initial PivotTo.
    -- R6 neutral standing reference: half root + half upper leg.
    local upper=boss.model:FindFirstChild('Right Leg')
    local neutral=boss.root.Size.Y*.5+(upper and upper.Size.Y*.5 or 1.5)
    local required=math.max(0,boss.root.Position.Y-floorY-neutral)
    boss.hum.HipHeight=math.max(boss.hum.HipHeight,required)""",
        """    -- R6 standing root Y = upper leg Y + half root Y + HipHeight.
    -- Set the real offset without compounding the old, excessive HipHeight.
    local upper=boss.model:FindFirstChild('Right Leg')
    if not upper then return end
    boss.hum.HipHeight=math.clamp(footSpan+.18-upper.Size.Y-boss.root.Size.Y*.5,0,28)""","boss R6 height")
    code=rep(code,
        "    hum.HipHeight=7.8 -- tall R6 articulated feet, adjusted again after phase-two scaling",
        "    hum.HipHeight=5.01 -- calibrated R6 first-form foot height","boss initial hip")
    code=rep(code,"local spawn=Vector3.new(x,floorY+11.9,z)","local spawn=Vector3.new(x,floorY+10.16,z)","boss spawn")
    code=rep(code,"    groundBossFeet(boss,1.1)\n    currentBoss=boss",
        "    groundBossFeet(boss,.18)\n    currentBoss=boss","initial ground")
    code=code.replace("groundBossFeet(boss,2.1)","groundBossFeet(boss,.28)")
    code=rep(code,
        """if floorY and footBottom(model)<floorY-.35 then
                    groundBossFeet(boss,boss.phase==2 and 2.1 or 1.1)
                end""",
        """if floorY and not model:GetAttribute("BossMoving")
                    and not model:GetAttribute("BossInAttack")
                    and math.abs(root.AssemblyLinearVelocity.Y)<2.4 then
                    local error=footBottom(model)-(floorY+.18)
                    if math.abs(error)>.4 and math.abs(error)<7 then
                        hum.HipHeight=math.clamp(hum.HipHeight-error*.45,0,28)
                    end
                end""","stable idle settlement")
    return code

def update_bot(code):
    code=rep(code,"    hum.HipHeight=2.55 -- R6 physics floor height matches long shins and boot meshes",
                 "    hum.HipHeight=1.50 -- R6 articulated shin and boot calibration","sentinel R6 height")
    code=rep(code,"model:PivotTo(CFrame.new(markerPos.X,floorY+3.85,markerPos.Z))",
                 "model:PivotTo(CFrame.new(markerPos.X,floorY+3.60,markerPos.Z))","sentinel spawn")
    code=rep(code,
        """    local sink=hit.Position.Y+.25-lower
    if sink>.40 and sink<9 then
        state.model:PivotTo(state.model:GetPivot()+Vector3.new(0,sink,0))
    end""",
        """    if lower==math.huge then return end
    local error=lower-(hit.Position.Y+.18)
    local v=state.root.AssemblyLinearVelocity
    if math.abs(error)>.30 and math.abs(error)<4.5
        and math.abs(v.Y)<2
        and now>=(state.model:GetAttribute("BotDodgeUntil") or 0) then
        state.hum.HipHeight=math.clamp(state.hum.HipHeight-error*.55,0,5)
    end""","sentinel bidirectional settlement")
    return code

def main():
    tree=ET.parse(BASE)
    touched=set()
    for item in tree.iter("Item"):
        props=item.find("Properties")
        if props is None:continue
        nm=props.find("./string[@name='Name']")
        src=props.find("./ProtectedString[@name='Source']")
        if nm is None or src is None:continue
        name=nm.text
        if name=="LashboundV31CameraToggle":
            src.text=(ROOT/"src/StarterPlayer/StarterPlayerScripts/Combat/LashboundCameraToggle.client.luau").read_text()
        elif name=="LashboundBossService":
            src.text=update_boss(src.text or "")
        elif name=="LashboundBotService":
            src.text=update_bot(src.text or "")
        elif name=="LashboundV5Client":
            src.text=rep(src.text or "",
                "if player.CameraMode==Enum.CameraMode.LockFirstPerson or not UIS.MouseEnabled then",
                'if player.CameraMode==Enum.CameraMode.LockFirstPerson or player:GetAttribute("LashboundCameraLocked")==true or not UIS.MouseEnabled then',
                "locked camera crosshair aim")
        else:continue
        touched.add(name)
    expected={"LashboundV31CameraToggle","LashboundBossService","LashboundBotService","LashboundV5Client"}
    if touched!=expected:raise RuntimeError(f"Wrong script set {touched}")
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    tree.write(OUTPUT,encoding="utf-8",xml_declaration=True)
    loaded=ET.parse(OUTPUT)
    sources=[it.find("./Properties/ProtectedString[@name='Source']") for it in loaded.iter("Item")]
    sources=[src for src in sources if src is not None]
    if len(sources)<40:raise RuntimeError("Expected 43 scripts in complete Studio project")
    if len(list(loaded.iter("Item")))<3000:raise RuntimeError("Studio geometry absent")
    print(f"Verified {OUTPUT.name}: {OUTPUT.stat().st_size} bytes; {len(sources)} scripts; {len(touched)} updated")

if __name__=="__main__":main()
