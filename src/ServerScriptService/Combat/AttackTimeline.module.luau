-- Shared server-authoritative clock for whip and boss attacks.
-- Require from ServerScriptService; clients only receive timestamps.
local Workspace = game:GetService("Workspace")
local Timeline = {}
function Timeline.begin(windup, active, recovery)
    assert(type(windup)=="number" and windup>=0)
    local startedAt=Workspace:GetServerTimeNow()
    return {startedAt=startedAt, impactAt=startedAt+windup,
        activeUntil=startedAt+windup+(active or 0),
        endsAt=startedAt+windup+(active or 0)+(recovery or 0)}
end
function Timeline.waitUntil(timestamp, valid)
    while true do
        if valid and not valid() then return false end
        local remaining=timestamp-Workspace:GetServerTimeNow()
        if remaining<=0 then return not valid or valid() end
        task.wait(math.min(remaining,.05))
    end
end
return Timeline
