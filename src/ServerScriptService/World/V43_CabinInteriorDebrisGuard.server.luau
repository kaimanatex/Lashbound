-- V43: keep arena ice and crystal hazards out of the cabin only.
local workspace = game:GetService("Workspace")
local function inside(p)
 local v=p.Position
 return math.abs(v.X)<82 and v.Z>-78 and v.Z<78 and v.Y>-8 and v.Y<52
end
local function debris(p)
 if not p:IsA("BasePart") then return false end
 local n=p.Name:lower()
 return n:find("crystal",1,true) or n:find("iceshard",1,true) or n:find("icelane",1,true) or n:find("iceramp",1,true) or n:find("prism",1,true)
end
local function inspect(p)
 if debris(p) and inside(p) then p:Destroy() end
end
for _,p in ipairs(workspace:GetDescendants()) do inspect(p) end
workspace.DescendantAdded:Connect(function(p)
 task.defer(function() if p.Parent then inspect(p) end end)
end)
