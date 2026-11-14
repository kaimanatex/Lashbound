-- LASHBOUND V17 Studio preflight checks. Non-destructive and no developer access
-- changes; prints actionable warnings in View > Output when something is missing.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local Workspace=game:GetService("Workspace")
if not RunService:IsStudio() then return end
local issues=0
local function check(condition,description)
    if condition then print("[LASHBOUND QA] OK -",description)
    else issues+=1;warn("[LASHBOUND QA] FIX -",description) end
end
local remotes=RS:FindFirstChild("LashboundV5Remotes")
check(remotes and remotes:FindFirstChild("Action") and remotes:FindFirstChild("Feedback"),
    "Combat remote events exist")
check(RS:FindFirstChild("WhipConfig")~=nil,"Whip balancing configuration")
local lobby=Workspace:FindFirstChild("LashboundLobby")
check(lobby~=nil,"Cabin lobby")
check(lobby and lobby:FindFirstChild("ArenaDoorTrigger")~=nil,"Battle portal")
for _,item in ipairs({"WhipShopKiosk","SpinWheelKiosk"}) do
    local kiosk=lobby and lobby:FindFirstChild(item)
    check(kiosk and kiosk:FindFirstChildOfClass("ProximityPrompt")~=nil,
        item.." has an E/tap prompt")
end
check(lobby and lobby:FindFirstChild("CabinRugWoven")~=nil,"Non-overlapping cabin rug")
check(lobby and lobby:FindFirstChild("LobbyWhipGallery")~=nil,"Shop weapon displays")
local templates=ServerStorage:FindFirstChild("LashboundMapTemplates")
for _,item in ipairs({"PrismCitadel","CinderFoundry","GlacialDivide","ThornTemple","StormReactor"}) do
    check(templates and templates:FindFirstChild(item)~=nil,"Arena template "..item)
end
check(ServerStorage:FindFirstChild("FounderTempest")~=nil,"Separate founder-only Tool")
check(ServerScriptService:FindFirstChild("LashboundOwnerService")~=nil,"Permanent founder gate")
check(ServerScriptService:FindFirstChild("LashboundTerrainService")~=nil,"Organic terrain controller")
check(ServerScriptService:FindFirstChild("LashboundHitReactionServer")~=nil,"PvP hit-reaction events")
check(ServerScriptService:FindFirstChild("LashboundV5Server")~=nil,"Coins, shop and combat service")
local playerScripts=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
check(playerScripts and playerScripts:FindFirstChild("LashboundV5Client")~=nil,"Shop/HUD client")
check(playerScripts and playerScripts:FindFirstChild("LashboundHitReactionClient")~=nil,"Hit flinch animation client")
print("[LASHBOUND QA] Startup checks complete; missing components:",issues)
print("[LASHBOUND QA] Studio run with Server & Clients (2) to test purchases and PvP")
