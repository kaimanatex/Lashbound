#!/usr/bin/env python3
"""Reassemble the exact V50 Studio file, validate it, and sync source scripts."""
from pathlib import Path
import hashlib
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
PARTS=[ROOT/"builds"/".staging"/f"v50_part_{i:02d}.txt" for i in range(1,7)]
OUTPUT=ROOT/"builds"/"Lashbound_V50_Full_Backlog_Mega_Whip.rbxlx"
SIZE=4217603
SHA256="7f4c64d122fcb033fd2a590af20db538d899d5595084d1c831a6e81b56920e32"
ALIASES={"LashboundV31CameraToggle":"LashboundCameraToggle"}
NEW={"LashboundV37PortalVisuals","V43_CabinInteriorDebrisGuard"}

def main():
    data=b"\n".join(p.read_bytes() for p in PARTS)+b"\n"
    digest=hashlib.sha256(data).hexdigest()
    if len(data)!=SIZE or digest!=SHA256:
        raise SystemExit(f"V50 content mismatch: {len(data)} bytes, {digest}")
    tree=ET.fromstring(data)
    if tree.tag!="roblox":
        raise SystemExit("Invalid Roblox XML")
    items=list(tree.iter("Item"))
    sources={}
    for item in items:
        props=item.find("Properties")
        if props is None:continue
        name=props.find("./string[@name='Name']")
        src=props.find("./ProtectedString[@name='Source']")
        if name is not None and src is not None:
            if name.text in sources:raise SystemExit("Repeated script name: "+name.text)
            sources[name.text]=src.text or ""
    if len(items)<3400 or len(sources)!=43:
        raise SystemExit(f"Wrong place contents: {len(items)} items, {len(sources)} scripts")
    names=[item.findtext("./Properties/string[@name='Name']") for item in items]
    from collections import Counter
    c=Counter(names)
    for n in ("LashboundChessBoard","GameRoom_PoolA","GameRoom_Battleship",
              "GameRoom_ConnectFour","V37_PortalEnergySurface"):
        if c[n]!=1:raise SystemExit(f"Expected one {n}, got {c[n]}")
    if "Range = 220" not in sources.get("WhipConfig","") or "megaGrow(player,character)" not in sources.get("LashboundV5Server",""):
        raise SystemExit("Mega Whip missing from Studio file")
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    OUTPUT.write_bytes(data)
    # Match existing Rojo source tree to actual Studio scripts, including
    # old gameplay edits that were not previously synced from the game place.
    mapped={}
    for path in (ROOT/"src").rglob("*.luau"):
        stem=path.name.split(".")[0]
        if stem in mapped:raise SystemExit(f"Ambiguous script name {stem}")
        mapped[stem]=path
    updated=[]
    for name,code in sources.items():
        alias=ALIASES.get(name,name)
        path=mapped.get(alias)
        if not path:
            if name not in NEW:raise SystemExit(f"Missing repo source mapping for {name}")
            path=ROOT/"src"/"ServerScriptService"/"World"/f"{name}.server.luau"
        path.parent.mkdir(parents=True,exist_ok=True)
        if not path.exists() or path.read_text()!=code:
            path.write_text(code,encoding="utf-8")
            updated.append(str(path.relative_to(ROOT)))
    print(f"Verified {OUTPUT.relative_to(ROOT)} ({len(data)} bytes, sha256 {digest})")
    print(f"Matched {len(sources)} scripts; source files changed: {len(updated)}")
    for path in updated:print("SYNC",path)

if __name__=="__main__":
    main()
