-- === Eldar Dashboard + Office Lights Control ===

local function isDocked()
    local output = hs.execute("system_profiler SPThunderboltDataType", true)
    return output:find("Studio Display") ~= nil and output:find("Vendor ID: 0x2188") ~= nil
end

local function dashboardOn()
    hs.execute("~/bin/dashboard-display on &", true)
end

local function dashboardOff()
    hs.execute("~/bin/dashboard-display off &", true)
end

local function officeLightsOn()
    hs.execute("~/bin/ha-light vibe &", true)
end

local function officeLightsOff()
    hs.execute("~/bin/ha-light off &", true)
end

-- Dock/undock
local screenWatcher = hs.screen.watcher.new(function()
    hs.timer.doAfter(3, function()
        if isDocked() then
            dashboardOn()
            officeLightsOn()
        else
            dashboardOff()
            officeLightsOff()
        end
    end)
end)
screenWatcher:start()

-- Lock/unlock
local caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidLock then
        dashboardOff()
        officeLightsOff()
    elseif event == hs.caffeinate.watcher.screensDidUnlock then
        hs.timer.doAfter(2, function()
            if isDocked() then
                dashboardOn()
                officeLightsOn()
            end
        end)
    end
end)
caffeinateWatcher:start()