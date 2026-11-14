#!/usr/bin/env python3
"""Lashbound V52: optimize V51 without changing gameplay, combat reach or damage."""
from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"builds/Lashbound_V51_Preserved_Combat_Mega_Whip.rbxlx"
OUT=ROOT/"builds/Lashbound_V52_Lag_Optimized.rbxlx"

def replace(code,old,new,label):
    if code.count(old)!=1:
        raise RuntimeError(f"{label}: expected 1 anchor, found {code.count(old)}")
    return code.replace(old,new,1)

def combat(code):
    a=code.index("local function pointSegmentDistance(")
    b=code.index("local function lashPosition(",a)
    code=code[:a]+"""-- Distance squared avoids a costly square root for every swept hitbox check.
local function pointSegmentDistanceSquared(point,a,b)
    local delta=b-a
    local len2=delta:Dot(delta)
    if len2<.0001 then
        local offset=point-a
        return offset:Dot(offset)
    end
    local t=math.clamp((point-a):Dot(delta)/len2,0,1)
    local offset=point-(a+delta*t)
    return offset:Dot(offset)
end
"""+code[b:]
    a=code.index("local function lashContacts(")
    b=code.index("local function melee(",a)
    code=code[:a]+"""-- One full-fidelity server lash sweep per attack, shared across all victims.
-- Earlier builds regenerated all 6 x 52-72 curved links for every target.
local function lashContacts(player,root,character,dir,reach,step,heavy,maxHits)
    local targets=allTargets(player)
    local result={}
    if #targets==0 then return result end
    local start=root.Position+Vector3.new(0,2.35,0)
    local block=RaycastParams.new()
    block.FilterType=Enum.RaycastFilterType.Exclude
    block.FilterDescendantsInstances={character}
    block.RespectCanCollide=true
    local frames=heavy and {.16,.22,.27,.31,.33,.36} or {.14,.18,.22,.26,.29,.31}
    local links=reach>140 and 72 or reach>80 and 56 or 52
    local sweep=nil
    local function segments()
        if sweep then return sweep end
        sweep={}
        local old=nil
        for _,clock in ipairs(frames) do
            local previous=lashPosition(start,dir,reach,step,clock,0,heavy)
            local current={}
            for joint=1,links do
                local at=lashPosition(start,dir,reach,step,clock,joint/links,heavy)
                sweep[#sweep+1]={a=previous,b=at,prior=old and old[joint] or nil}
                current[joint]=at
                previous=at
            end
            old=current
        end
        return sweep
    end
    for _,t in ipairs(targets) do
        if #result>=maxHits then break end
        local targetRoot=t.root
        if targetRoot and targetRoot.Parent then
            local isHound=t.kind=="Bot" and t.model and t.model:GetAttribute("LashboundDog")==true
            local point=targetRoot.Position+Vector3.new(0,isHound and .35 or math.min(4.2,math.max(1.4,targetRoot.Size.Y*.6)),0)
            local radial=Vector3.new(point.X-start.X,0,point.Z-start.Z)
            local bossPoints=t.kind=="Boss" and t.model and bossContactPoints(t.model) or nil
            if radial.Magnitude<=reach+18 and (bossPoints or math.abs(point.Y-start.Y)<17) then
                local candidates=bossPoints and #bossPoints>0 and bossPoints or {{position=point,radius=isHound and 4.0 or math.clamp(math.max(targetRoot.Size.X,targetRoot.Size.Z)*.62+1.5,2.4,6.8)}}
                local eligible={}
                for _,candidate in ipairs(candidates) do
                    if (candidate.position-start).Magnitude<=reach+candidate.radius+5 then
                        eligible[#eligible+1]={pos=candidate.position,radius2=candidate.radius*candidate.radius}
                    end
                end
                if #eligible>0 then
                    local contactPoint=nil
                    for _,segment in ipairs(segments()) do
                        for _,candidate in ipairs(eligible) do
                            local cp=candidate.pos
                            if pointSegmentDistanceSquared(cp,segment.a,segment.b)<=candidate.radius2
                                or (segment.prior and pointSegmentDistanceSquared(cp,segment.prior,segment.b)<=candidate.radius2) then
                                contactPoint=cp
                                break
                            end
                        end
                        if contactPoint then break end
                    end
                    if contactPoint then
                        local ray=Workspace:Raycast(start,contactPoint-start,block)
                        local victimModel=t.model or (t.player and t.player.Character)
                        if not ray or (victimModel and ray.Instance:IsDescendantOf(victimModel)) then
                            table.insert(result,{t=t,dist=radial.Magnitude})
                        end
                    end
                end
            end
        end
    end
    return result
end

"""+code[b:]
    return code

def whip(code):
    code=replace(code,"local links=viewerDistance<75 and 36 or viewerDistance<130 and 16 or 8",
         "local links=viewerDistance<75 and 20 or viewerDistance<130 and 10 or 5","whip LOD")
    code=replace(code,"if range>80 then links=math.min(links,24) end",
         "if range>80 then links=math.min(links,18) end","Mega whip LOD")
    return replace(code,
        "        RunService.RenderStepped:Wait()\n    end\n    if tool and current[tool]==token then",
        "        task.wait(viewerDistance<85 and 1/30 or 1/22)\n    end\n    if tool and current[tool]==token then",
        "bounded client whip animation rate")

def boss_fx(code):
    return replace(code,"    local slices=20\n    local low=math.max(0,inner or 0)",
        "    local slices=14 -- exact ring radius, fewer cosmetic ribs\n    local low=math.max(0,inner or 0)","boss fx LOD")

def hounds(code):
    code=replace(code,"if accumulated<1/30 then return end","if accumulated<1/20 then return end","hound motion")
    return replace(code,"local interval=dist<120 and 1/30 or dist<200 and .12 or .5",
        "local interval=dist<120 and 1/20 or dist<200 and .17 or .55","hound LOD")

def sentinels(code):
    code=replace(code,"if accumulate<1/30 then return end","if accumulate<1/24 then return end","sentinel motion")
    return replace(code,"local budget=distance<95 and (1/30) or distance<175 and .09 or .24",
        "local budget=distance<95 and (1/24) or distance<175 and .12 or .28","sentinel LOD")

def gallery(code):
    return replace(code,"if accum<1/25 then return end","if accum<1/16 then return end","gallery motion")

def portal(code):
    code=replace(code,"local t=0\nlocal connection","local t=0\nlocal accumulated=0\nlocal connection","portal timer")
    return replace(code,"    t+=dt\n    surface.Transparency=",
        "    accumulated+=dt\n    if accumulated<1/15 then return end\n    t+=accumulated\n    accumulated=0\n    surface.Transparency=","portal LOD")

UPDATES={
 "LashboundV5Server":combat,
 "LashboundV8WhipSpectacle":whip,
 "LashboundV22CinematicBossFX":boss_fx,
 "LashboundV12HoundMotion":hounds,
 "LashboundV25EnemyMotion":sentinels,
 "LashboundV19GallerySpin":gallery,
 "LashboundV37PortalVisuals":portal,
}
SOURCES={
 "LashboundV5Server":"src/ServerScriptService/Combat/LashboundV5Server.server.luau",
 "LashboundV8WhipSpectacle":"src/StarterPlayer/StarterPlayerScripts/Combat/LashboundV8WhipSpectacle.client.luau",
 "LashboundV22CinematicBossFX":"src/StarterPlayer/StarterPlayerScripts/Boss/LashboundV22CinematicBossFX.client.luau",
 "LashboundV12HoundMotion":"src/StarterPlayer/StarterPlayerScripts/World/LashboundV12HoundMotion.client.luau",
 "LashboundV25EnemyMotion":"src/StarterPlayer/StarterPlayerScripts/World/LashboundV25EnemyMotion.client.luau",
 "LashboundV19GallerySpin":"src/StarterPlayer/StarterPlayerScripts/World/LashboundV19GallerySpin.client.luau",
 "LashboundV37PortalVisuals":"src/StarterPlayer/StarterPlayerScripts/World/LashboundV37PortalVisuals.client.luau",
}
def main():
    tree=ET.parse(BASE)
    touched={}
    for item in tree.iter("Item"):
        n=item.find("./Properties/string[@name='Name']")
        s=item.find("./Properties/ProtectedString[@name='Source']")
        if n is not None and s is not None and n.text in UPDATES:
            if n.text in touched:raise RuntimeError("Duplicate script "+n.text)
            s.text=UPDATES[n.text](s.text or "")
            touched[n.text]=s.text
    if set(touched)!=set(UPDATES):raise RuntimeError("Missing script: "+str(set(UPDATES)-set(touched)))
    if len(list(tree.iter("Item")))<3400:raise RuntimeError("Scene geometry missing")
    scripts={}
    for it in tree.iter("Item"):
        n=it.find("./Properties/string[@name='Name']")
        s=it.find("./Properties/ProtectedString[@name='Source']")
        if n is not None and s is not None:scripts[n.text]=s.text
    for needle in ("AttackTimeline","megaGrow(player,character)","LashPreStunSpeed",
                   "bossContactPoints","pointSegmentDistanceSquared"):
        if needle not in scripts["LashboundV5Server"]:raise RuntimeError("Combat regression: "+needle)
    if "Range = 220" not in scripts["WhipConfig"]:raise RuntimeError("Mega Whip regression")
    if "groundBossFeet" not in scripts["LashboundBossService"]:raise RuntimeError("NPC grounding regression")
    OUT.parent.mkdir(parents=True,exist_ok=True)
    tree.write(OUT,encoding="UTF-8",xml_declaration=True)
    ET.parse(OUT)
    for name,source in touched.items():
        path=ROOT/SOURCES[name];path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(source,encoding="utf-8")
    print("Verified V52, bytes",OUT.stat().st_size,"sha256",hashlib.sha256(OUT.read_bytes()).hexdigest(),
          "updated scripts",len(touched))
if __name__=="__main__":main()
