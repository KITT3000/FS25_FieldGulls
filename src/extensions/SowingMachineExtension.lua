---
-- SowingMachineExtension
-- Hooks into the SowingMachine specialization to spawn following birds
---

SowingMachineExtension = {}

---
-- Hook into sowing machine area processing to track grid cells for bird feeding
-- @param superFunc: Original processSowingMachineArea function
-- @param workArea: The work area being processed
-- @param dt: Delta time
---
function SowingMachineExtension:processSowingMachineArea(superFunc, workArea, dt)
    local changedArea, totalArea = superFunc(self, workArea, dt)

    -- Track grid cells for bird feeding if we're working
    if changedArea and changedArea > 0 and g_gridFeedingZones then
        local sx, sy, sz = getWorldTranslation(workArea.start)
        local wx, wy, wz = getWorldTranslation(workArea.width)
        local hx, hy, hz = getWorldTranslation(workArea.height)

        -- Get affected grid cells
        local cells = GridFeedingZones.getAffectedGridCells(sx, sz, wx, wz, hx, hz)

        -- Initialize frame cell counter if needed
        if not self.birdCellsThisFrame then
            self.birdCellsThisFrame = 0
        end
        
        self.birdCellsThisFrame = self.birdCellsThisFrame + #cells

        -- Add cells to global grid system
        for _, cell in ipairs(cells) do
            g_gridFeedingZones:addCell(cell.gridX, cell.gridZ)
        end
    end

    return changedArea, totalArea
end

---
-- Extended onEndWorkAreaProcessing for SowingMachine specialization
-- @param superFunc: Original function
-- @param dt: Delta time in milliseconds
-- @param hasProcessed: Whether areas were processed
---
function SowingMachineExtension:onEndWorkAreaProcessing(superFunc, dt, hasProcessed)
    if superFunc ~= nil then
        superFunc(self, dt, hasProcessed)
    end

    if not self.toolBirdsData or not self.toolBirdsData.initialized then
        ToolBirdsExtension:initialize(self, WorkAreaType.SOWINGMACHINE)
    end

    -- Reset frame cell counter
    if self.birdCellsThisFrame then
        self.birdCellsThisFrame = 0
    end

    local spec = self.spec_sowingMachine
    local isCurrentlyWorking = spec and spec.isWorking or false
    ToolBirdsExtension:onUpdate(self, dt, isCurrentlyWorking)
end

---
-- Extended onDelete function for SowingMachine specialization
-- @param superFunc: Original function
---
function SowingMachineExtension:onDelete(superFunc)
    ToolBirdsExtension:onDelete(self)

    if superFunc ~= nil then
        superFunc(self)
    end
end

-- Hook into SowingMachine specialization
SowingMachine.processSowingMachineArea = Utils.overwrittenFunction(
    SowingMachine.processSowingMachineArea,
    SowingMachineExtension.processSowingMachineArea
)

SowingMachine.onEndWorkAreaProcessing = Utils.overwrittenFunction(
    SowingMachine.onEndWorkAreaProcessing,
    SowingMachineExtension.onEndWorkAreaProcessing
)

SowingMachine.onDelete = Utils.overwrittenFunction(
    SowingMachine.onDelete,
    SowingMachineExtension.onDelete
)
