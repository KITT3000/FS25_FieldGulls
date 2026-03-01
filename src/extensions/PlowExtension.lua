---
-- PlowExtension
-- Hooks into the Plow specialization to spawn following birds
---

PlowExtension = {}

---
-- Hook into plow area processing to track grid cells for bird feeding
-- @param superFunc: Original processPlowArea function
-- @param workArea: The work area being processed
-- @param dt: Delta time
---
function PlowExtension:processPlowArea(superFunc, workArea, dt)
    -- Call original function first
    local changedArea, totalArea = superFunc(self, workArea, dt)

    -- Track grid cells for bird feeding
    if g_gridFeedingZones then
        local sx, sy, sz = getWorldTranslation(workArea.start)
        local wx, wy, wz = getWorldTranslation(workArea.width)
        local hx, hy, hz = getWorldTranslation(workArea.height)

        -- Get affected grid cells
        local cells = GridFeedingZones.getAffectedGridCells(sx, sz, wx, wz, hx, hz)

        -- Add cells to global grid system
        for _, cell in ipairs(cells) do
            g_gridFeedingZones:addCell(cell.gridX, cell.gridZ)
        end
    end

    return changedArea, totalArea
end

---
-- Extended onEndWorkAreaProcessing for Plow specialization
-- @param superFunc: Original function
-- @param dt: Delta time in milliseconds
---
function PlowExtension:onEndWorkAreaProcessing(superFunc, dt)
    -- Call original function
    if superFunc ~= nil then
        superFunc(self, dt)
    end

    -- Initialize birds data if needed
    if not self.toolBirdsData or not self.toolBirdsData.initialized then
        ToolBirdsExtension:initialize(self, WorkAreaType.PLOW)
    end

    -- Determine if plow is currently working
    local spec = self.spec_plow
    local isCurrentlyWorking = spec and spec.isWorking or false

    -- Update bird spawning logic
    ToolBirdsExtension:onUpdate(self, dt, isCurrentlyWorking)
end

---
-- Extended onDelete function for Plow specialization
-- @param superFunc: Original function
---
function PlowExtension:onDelete(superFunc)
    -- Cleanup our extension
    ToolBirdsExtension:onDelete(self)

    -- Call original function
    if superFunc ~= nil then
        superFunc(self)
    end
end

-- Hook into Plow specialization
Plow.processPlowArea = Utils.overwrittenFunction(
    Plow.processPlowArea,
    PlowExtension.processPlowArea
)

Plow.onEndWorkAreaProcessing = Utils.overwrittenFunction(
    Plow.onEndWorkAreaProcessing,
    PlowExtension.onEndWorkAreaProcessing
)

Plow.onDelete = Utils.overwrittenFunction(
    Plow.onDelete,
    PlowExtension.onDelete
)

