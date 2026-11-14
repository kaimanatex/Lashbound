#!/usr/bin/env python3
"""Upgrade V50 geometry to V51 with modern GitHub combat and original Mega Whip."""
from pathlib import Path
from xml.etree import ElementTree as ET
from collections import Counter
import hashlib

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"builds"/"Lashbound_V50_Full_Backlog_Mega_Whip.rbxlx"
OUT=ROOT/"builds"/"Lashbound_V51_Preserved_Combat_Mega_Whip.rbxlx"
V50_SHA="7f4c64d122fcb033fd2a590af20db538d899d5595084d1c831a6e81b56920e32"
FROM_V50={
    "WhipConfig","LashboundV5PortalController","LashboundV37PortalVisuals",
    "V43_CabinInteriorDebrisGuard","LashboundV22WhipPowerFX",
    "LashboundWhipDecoration","LashboundV19ChessClient",
    "LashboundDogRaidService",
}
ALIASES={"LashboundV31CameraToggle":"LashboundCameraToggle"}
NEW={"LashboundV37PortalVisuals","V43_CabinInteriorDebrisGuard"}
def replace_one(source,old,new,label):
    n=source.count(old)
    if n!=1:raise RuntimeError(f"{label}: expected 1 anchor, found {n}")
    return source.replace(old,new,1)
def slice_between(text,beg,end,label):
    a=text.find(beg);b=text.find(end,a+len(beg))
    if a<0 or b<0:raise RuntimeError("Missing "+label)
    return text[a:b]
def upgrade_combat(modern,legacy):
    # Important: preserve the latest AttackTimeline, stun recovery, hitbox
    # protections, and character-serial checks from modern GitHub source.
    assert "AttackTimeline" in modern and "LashPreStunSpeed" in modern
    limb=slice_between(legacy,
        "-- Use actual boss limbs instead of the elevated HumanoidRootPart.",
        "local function melee(","actual leg hitboxes")
    # Replace only isolated lash geometry helper. Keep modern melee/heavy timelines.
    start=modern.index("local function lashContacts(")
    end=modern.index("local function melee(",start)
    modern=modern[:start]+limb+modern[end:]
    mega=slice_between(legacy,"-- Mega Whip: a genuine server-owned",
         "-- Specials intentionally change combat rules","Mega transformation")
    modern=replace_one(modern,
        "-- Specials intentionally change combat rules",
        mega+"-- Specials intentionally change combat rules","Mega insertion")
    modern=replace_one(modern,
        '    elseif id=="Echo" then\n        powerBox={shape="ring",radius=12,duration=.55}',
        '    elseif id=="Echo" then\n        powerBox={shape="ring",radius=12,duration=.55}\n    elseif id=="Mega" then\n        powerBox={shape="ring",radius=15,duration=.75}',"Mega power telegraph")
    modern=replace_one(modern,
        '    elseif id=="Echo" then\n        summonMirrorCompanion(player,character,cfg)',
        '    elseif id=="Mega" then\n        megaGrow(player,character)\n    elseif id=="Echo" then\n        summonMirrorCompanion(player,character,cfg)',
        "Mega power execution")
    return modern
def upgrade_spectacle(modern):
    modern=replace_one(modern,
        'local range=tonumber(payload.range) or (heavy and 33 or power and 27 or step==3 and 25 or 19)',
        'local range=(not power and payload.hitbox and tonumber(payload.hitbox.range)) or tonumber(payload.range) or (heavy and 33 or power and 27 or step==3 and 25 or 19)',
        "true extended whip visual reach")
    modern=replace_one(modern,
        'local links=viewerDistance<75 and 100 or viewerDistance<130 and 50 or 25',
        'local links=viewerDistance<75 and 36 or viewerDistance<130 and 16 or 8\n    if range>80 then links=math.min(links,24) end',
        "lower impact FX cost")
    return modern
def main():
    data=BASE.read_bytes()
    if hashlib.sha256(data).hexdigest()!=V50_SHA:raise SystemExit("Wrong V50 source revision")
    tree=ET.fromstring(data)
    scripts={}
    for item in tree.iter("Item"):
        props=item.find("Properties")
        if props is None:continue
        n=props.find("./string[@name='Name']")
        src=props.find("./ProtectedString[@name='Source']")
        if n is not None and src is not None:
            if n.text in scripts:raise RuntimeError("Duplicate script "+n.text)
            scripts[n.text]=(item,src.text or "")
    if len(scripts)!=43:raise RuntimeError(f"Expected 43 game scripts, got {len(scripts)}")
    pathmap={}
    for path in (ROOT/"src").rglob("*.luau"):
        name=path.name.split(".")[0]
        if name in pathmap:raise RuntimeError("Ambiguous source "+name)
        pathmap[name]=path
    changed=[]
    for name,(item,legacy) in scripts.items():
        modern_path=pathmap.get(ALIASES.get(name,name))
        if modern_path is None:
            if name not in NEW:raise RuntimeError("Unknown source "+name)
            modern_path=ROOT/"src"/"ServerScriptService"/"World"/f"{name}.server.luau"
        modern=modern_path.read_text() if modern_path.exists() else ""
        if name in FROM_V50:code=legacy
        elif name=="LashboundV5Server":code=upgrade_combat(modern,legacy)
        elif name=="LashboundV8WhipSpectacle":code=upgrade_spectacle(modern)
        else:code=modern
        if not code:raise RuntimeError("Empty source "+name)
        item.find("./Properties/ProtectedString[@name='Source']").text=code
        if code!=modern:
            modern_path.parent.mkdir(parents=True,exist_ok=True)
            modern_path.write_text(code,encoding="utf-8")
            changed.append(str(modern_path.relative_to(ROOT)))
    contents={i.findtext("./Properties/string[@name='Name']") for i in tree.iter("Item")}
    for n in ("GameRoom_ConnectFour","GameRoom_Battleship","GameRoom_PoolA","LashboundChessBoard","V37_PortalEnergySurface"):
        if sum(1 for i in tree.iter("Item") if i.findtext("./Properties/string[@name='Name']")==n)!=1:
            raise RuntimeError("Missing/duplicated game element "+n)
    assert "Range = 220" in next(s.find("./Properties/ProtectedString[@name='Source']").text for s,_ in scripts.values() if s.findtext("./Properties/string[@name='Name']")=="WhipConfig")
    boss=next(s.find("./Properties/ProtectedString[@name='Source']").text for s,_ in scripts.values() if s.findtext("./Properties/string[@name='Name']")=="LashboundBossService")
    combat=next(s.find("./Properties/ProtectedString[@name='Source']").text for s,_ in scripts.values() if s.findtext("./Properties/string[@name='Name']")=="LashboundV5Server")
    for text,need in ((boss,"AttackTimeline"),(boss,"clearBossLine"),(combat,"AttackTimeline"),(combat,"LashPreStunSpeed"),(combat,"megaGrow(player,character)"),(combat,"bossContactPoints")):
        if need not in text:raise RuntimeError("Regression check failed: "+need)
    ET.ElementTree(tree).write(OUT,encoding="UTF-8",xml_declaration=True)
    ET.parse(OUT)
    print("V51 verified",OUT.stat().st_size,"bytes; sha256",hashlib.sha256(OUT.read_bytes()).hexdigest())
    print("Modern scripting preserved; updated sources:",len(changed))
    for p in changed:print("SOURCE",p)
if __name__=="__main__":main()
