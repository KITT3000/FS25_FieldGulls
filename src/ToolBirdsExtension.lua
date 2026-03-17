---
-- ToolBirdsExtension
-- Thin registration layer between tool specializations and BirdManager.
-- Tools call reportToolActive() each frame they are working. BirdManager owns
-- the update lifecycle — if the tool disappears, the flock detects the silence
-- and transitions to dispersal automatically.
---

ToolBirdsExtension = {}

---
-- Initialize bird data on a vehicle (called once, lazily, from the tool extension)
-- @param vehicle: The vehicle to extend
-- @param workAreaType: The WorkAreaType enum value for this tool
---
function ToolBirdsExtension:initialize(vehicle, workAreaType)
    if not g_currentMission:getIsClient() then return end

    if not vehicle or not workAreaType then
        return
    end

    -- Generate a unique tool ID so the flock is not keyed on the vehicle reference
    local toolId = BirdManager:generateToolId()

    -- Add our extension data to the vehicle
    vehicle.toolBirdsData = {
        toolId = toolId,
        flockManager = nil,
        isWorking = false,
        initialized = true,
        workAreaType = workAreaType
    }
end

---
-- Report that a tool is actively working this frame.
-- Called every frame from the tool extension's onEndWorkAreaProcessing.
-- Handles work start/stop transitions and keeps the flock alive.
-- @param vehicle: The vehicle with tool
-- @param dt: Delta time in milliseconds
-- @param isCurrentlyWorking: Boolean indicating if the tool is currently working
---
function ToolBirdsExtension:reportToolActive(vehicle, dt, isCurrentlyWorking)
    if not g_currentMission:getIsClient() then return end

    if not vehicle.toolBirdsData or not vehicle.toolBirdsData.initialized then
        return
    end

    local data = vehicle.toolBirdsData

    -- Ensure we have a flock manager
    if not data.flockManager then
        data.flockManager = ToolBirdFlockManager.new(data.toolId, vehicle, data.workAreaType)
    end

    -- Report tool position/state to the flock manager (keeps it alive)
    data.flockManager:reportToolActive(vehicle)

    -- Handle state transitions
    if isCurrentlyWorking and not data.isWorking then
        -- Just started working - activate flock and cancel any despawn timer
        data.flockManager:activate()
        data.flockManager:cancelDespawnTimer()
        data.isWorking = true
    elseif not isCurrentlyWorking and data.isWorking then
        -- Just stopped working - start despawn timer on flock
        data.isWorking = false
        data.flockManager:startDespawnTimer()
    end
end
