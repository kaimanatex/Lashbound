#!/usr/bin/env python3
"""Build V53 by restoring the missing server AttackTimeline and making Vault checks finite."""
from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"builds/Lashbound_V52_Lag_Optimized.rbxlx"
OUT=ROOT/"builds/Lashbound_V53_Vault_Server_Fix.rbxlx"
CLIENT=ROOT/"src/StarterPlayer/StarterPlayerScripts/Combat/LashboundV5Client.client.luau"
TIMELINE=ROOT/"src/ServerScriptService/Combat/AttackTimeline.module.luau"

def rep(code,a,b,label):
    n=code.count(a)
    if n!=1: raise RuntimeError(f"{label}: expected 1 anchor, found {n}")
    return code.replace(a,b,1)
def name(item):
    return item.findtext("./Properties/string[@name='Name']")
def only(root, key):
    matches=[i for i in root.iter("Item") if name(i)==key]
    if len(matches)!=1:raise RuntimeError(f"Expected one {key}, got {len(matches)}")
    return matches[0]

tree=ET.parse(BASE)
root=tree.getroot()
sss=only(root,"ServerScriptService")
if any(name(i)=="Combat" for i in sss.findall("Item")): raise RuntimeError("Combat already exists")
if any(name(i)=="AttackTimeline" for i in root.iter("Item")): raise RuntimeError("AttackTimeline already exists")
combat=ET.Element("Item",{"class":"Folder","referent":"RBX95010"})
props=ET.SubElement(combat,"Properties")
ET.SubElement(props,"string",{"name":"Name"}).text="Combat"
module=ET.Element("Item",{"class":"ModuleScript","referent":"RBX95011"})
props=ET.SubElement(module,"Properties")
ET.SubElement(props,"string",{"name":"Name"}).text="AttackTimeline"
ET.SubElement(props,"ProtectedString",{"name":"Source"}).text=TIMELINE.read_text(encoding="utf-8")
combat.append(module)
sss.insert(0,combat)

src=only(root,"LashboundV5Client").find("./Properties/ProtectedString[@name='Source']")
code=src.text or ""
code=rep(code,"LASHBOUND V17 · WHIP WARS","LASHBOUND V53 · WHIP WARS","HUD version")
code=rep(code,
"""local shopButtons={}
for i,id in ipairs(Config.Order) do""",
"""local shopButtons={}
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
for i,id in ipairs(Config.Order) do""","Shop watchdog")
code=rep(code,
"""        shopMessage("Checking "..cfg.Name.." with the server...",true)
        Action:FireServer("Shop",id)""",
"""        requestShop("Shop",id,"Checking "..cfg.Name.." with the server...")""","Shop click")
code=rep(code,
"""        Action:FireServer("GetShop")
    end
end)
player:GetAttributeChangedSignal("Zone")""",
"""        requestShop("GetShop",nil,"Refreshing your saved whips...")
    end
end)
player:GetAttributeChangedSignal("Zone")""","Wallet refresh")
code=rep(code,
"""        shopMessage("Checking your saved whips...",true)
        Action:FireServer("GetShop")""",
"""        requestShop("GetShop",nil,"Checking your saved whips...")""","Vault open")
code=rep(code,
"""            shopMessage("Checking your whips...",true)
            Action:FireServer("GetShop")""",
"""            requestShop("GetShop",nil,"Checking your whips...")""","Kiosk open")
code=rep(code,
"""    if kind=="ShopState" then
        if type(extra)=="table" then""",
"""    if kind=="ShopState" then
        shopAwaitingReply=false
        if type(extra)=="table" then""","ShopState handling")
code=rep(code,
"""    if kind=="ShopResult" then
        local success=type(extra)=="table" """.rstrip(),
"""    if kind=="ShopResult" then
        shopAwaitingReply=false
        local success=type(extra)=="table" """.rstrip(),"ShopResult handling")
src.text=code

for key in ("Combat","AttackTimeline","LashboundV5Client","LashboundV5Server","LashboundBossService"):
    only(root,key)
for key in ("LashboundV5Server","LashboundBossService"):
    script=only(root,key).findtext("./Properties/ProtectedString[@name='Source']")
    if 'WaitForChild("Combat"):WaitForChild("AttackTimeline")' not in script: raise RuntimeError(key+" missing require")
if "Range = 220" not in only(root,"WhipConfig").findtext("./Properties/ProtectedString[@name='Source']"):
    raise RuntimeError("Mega Whip range missing")
for key in ("GameRoom_ConnectFour","GameRoom_Battleship","GameRoom_PoolA","LashboundChessBoard"):
    only(root,key)
if len(list(root.iter("Item")))<3400:raise RuntimeError("Geometry missing")
refs=[i.attrib["referent"] for i in root.iter("Item")]
if len(refs)!=len(set(refs)):raise RuntimeError("Duplicate referents")
OUT.parent.mkdir(parents=True,exist_ok=True)
tree.write(OUT,encoding="UTF-8",xml_declaration=True)
ET.parse(OUT)
CLIENT.write_text(code,encoding="utf-8")
print("V53 verified:",OUT.stat().st_size,"bytes; sha256",hashlib.sha256(OUT.read_bytes()).hexdigest())
