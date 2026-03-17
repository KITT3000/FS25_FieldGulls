---
-- BirdManager
-- Global manager for all bird flock managers that runs independent of vehicle state.
-- Owns the update lifecycle for all flocks. Tools only report activity; if a tool
-- disappears (returned/sold/deleted) the flock gracefully transitions to dispersal.
---

BirdManager = {}
BirdManager.activeFlockManagers = {}  -- toolId -> ToolBirdFlockManager
BirdManager.nextToolId = 1           -- Auto-incrementing ID for flock managers

-- How long (ms) after the last tool activity report before we consider the tool gone
BirdManager.TOOL_INACTIVE_TIMEOUT = 2000

---
-- Initialize the bird manager
---
function BirdManager:loadMap()
    if not g_currentMission:getIsClient() then return end

    local birdConfig = BirdConfig.loadConfig()
    if birdConfig and birdConfig.filename then
        g_i3DManager:loadSharedI3DFileAsync(
            birdConfig.filename,
            false, -- callOnCreate
            false, -- addToPhysics
            function(i3dNode, failedReason, args)
                if failedReason ~= 0 then
                    print("[BirdManager] Warning: Failed to preload bird i3d model")
                end
            end,
            nil,
            nil
        )
    end

    -- Initialize global grid feeding zones system
    g_gridFeedingZones = GridFeedingZones.new()
end

---
-- Global update function called every frame
-- @param dt: Delta time in milliseconds
---
function BirdManager:update(dt)
    if not g_currentMission:getIsClient() then return end

    if g_gridFeedingZones then
        g_gridFeedingZones:update(dt)
    end

    -- Update all flock managers and detect disappeared tools
    for toolId, flockManager in pairs(self.activeFlockManagers) do
        if flockManager and flockManager.update then
            -- Check if the tool has gone silent (deleted/returned without onDelete)
            if flockManager.isActive and flockManager.lastToolReportTime then
                local timeSinceReport = g_time - flockManager.lastToolReportTime
                if timeSinceReport > BirdManager.TOOL_INACTIVE_TIMEOUT then
                    -- Tool has disappeared or stopped reporting — treat as "stopped working"
                    flockManager:onToolLost()
                end
            end

            flockManager:update(dt)
        end
    end
end

---
-- Register a flock manager for continuous updates (keyed by unique tool ID)
-- @param toolId: Unique numeric ID for this tool's flock
-- @param flockManager: The flock manager instance
---
function BirdManager:registerFlockManager(toolId, flockManager)
    if toolId and flockManager then
        self.activeFlockManagers[toolId] = flockManager
    end
end

---
-- Unregister a flock manager when fully inactive (all birds despawned)
-- @param toolId: The unique tool ID
---
function BirdManager:unregisterFlockManager(toolId)
    if toolId then
        self.activeFlockManagers[toolId] = nil
    end
end

---
-- Generate a unique tool ID for a new flock manager
-- @return number: Unique tool ID
---
function BirdManager:generateToolId()
    local id = self.nextToolId
    self.nextToolId = self.nextToolId + 1
    return id
end

---
-- Cleanup on map unload
---
function BirdManager:deleteMap()
    -- Cleanup all active flock managers
    for toolId, flockManager in pairs(self.activeFlockManagers) do
        if flockManager and flockManager.forceCleanup then
            flockManager:forceCleanup()
        end
    end

    self.activeFlockManagers = {}
    self.nextToolId = 1

    if g_gridFeedingZones then
        g_gridFeedingZones:clear()
        g_gridFeedingZones = nil
    end
end

addModEventListener(BirdManager)
