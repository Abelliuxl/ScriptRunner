-- ScriptRunner - Execution engine module (Standalone)
-- Executes stored scripts with optional scheduling helpers.

local Executor = {}
local addon
local Storage

local scheduledTimers = {}

local executionStats = {
    totalExecutions = 0,
    successfulExecutions = 0,
    failedExecutions = 0,
    lastExecutionTime = nil,
}

local function compileChunk(source, chunkName, env)
    if loadstring then
        local chunk, loadError = loadstring(source, chunkName)
        if chunk then
            if env and setfenv then
                setfenv(chunk, env)
            end
            return chunk
        end
        return nil, loadError
    end

    if load then
        if env then
            return load(source, chunkName, "t", env)
        end
        return load(source, chunkName)
    end

    return nil, "No supported Lua loader is available."
end

function Executor:Initialize(mainAddon)
    addon = mainAddon
    Storage = addon.Storage
end

local function cancelTimer(scriptID)
    local handle = scheduledTimers[scriptID]
    if handle then
        if handle.Cancel then -- C_Timer ticker
            handle:Cancel()
        else -- C_Timer.After handle
             -- No standard way to cancel C_Timer.After, just wipe the handle
        end
        scheduledTimers[scriptID] = nil
    end
end

function Executor:CreateExecutionEnvironment(script, context)
    local env = {
        print = print,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        string = string,
        table = table,
        math = math,
        coroutine = coroutine,
        date = date,
        time = time,
        ScriptRunner = addon,
        script = script,
        context = context or {},
    }

    setmetatable(env, {
        __index = _G,
        __newindex = function(tbl, key, value)
            rawset(tbl, key, value)
        end,
    })

    return env
end

function Executor:ExecuteScript(script, context)
    if not script or type(script.code) ~= "string" then
        return false, "Invalid script."
    end

    if not script.enabled then
        return false, "Script is disabled."
    end

    executionStats.totalExecutions = executionStats.totalExecutions + 1
    executionStats.lastExecutionTime = time()

    local env = self:CreateExecutionEnvironment(script, context)

    local chunk, loadError = compileChunk(script.code, script.name or "ScriptRunner", env)

    if not chunk then
        executionStats.failedExecutions = executionStats.failedExecutions + 1
        return false, "Syntax error: " .. tostring(loadError)
    end

    local ok, result = pcall(chunk)
    if ok then
        executionStats.successfulExecutions = executionStats.successfulExecutions + 1
        return true, result
    end

    executionStats.failedExecutions = executionStats.failedExecutions + 1
    return false, result
end

function Executor:ExecuteManualScript(scriptID)
    if not Storage then
        return false, "Storage module is not loaded."
    end

    local script = Storage:GetScript(scriptID)
    if not script then
        return false, "Script does not exist."
    end

    if script.mode ~= "manual" then
        return false, "Script is not set to manual mode."
    end

    return self:ExecuteScript(script)
end

function Executor:ValidateScript(code)
    if not code or code == "" then
        return false, "Code is empty."
    end

    local chunk, loadError = compileChunk("return function() " .. code .. " end", "ScriptRunnerValidation")

    if not chunk then
        return false, "Syntax error: " .. tostring(loadError)
    end

    return true, "Syntax OK"
end


function Executor:ScheduleDelayedScript(script)
    if not script or script.mode ~= "delay" or not script.enabled then
        return false
    end

    cancelTimer(script.id)

    local delay = tonumber(script.delay) or 5
    if delay < 0 then
        delay = 0
    end

    scheduledTimers[script.id] = C_Timer.After(delay, function()
        local current = Storage:GetScript(script.id)
        if current and current.enabled and current.mode == "delay" then
            self:ExecuteScript(current)
        end
        scheduledTimers[script.id] = nil
    end)

    return true
end

function Executor:ExecuteAutoScripts()
    if not Storage then
        print("|cffff0000ScriptRunner|r: Storage module is not loaded.")
        return
    end

    local scripts = Storage:GetAllScripts()
    local executedCount = 0
    local errorCount = 0

    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "auto" then
            local success, _ = self:ExecuteScript(script)
            if success then
                executedCount = executedCount + 1
            else
                errorCount = errorCount + 1
            end
        end
    end

    if executedCount > 0 or errorCount > 0 then
        print(string.format("|cff00ff00ScriptRunner|r: Auto run finished - success: %d, failed: %d", executedCount, errorCount))
    end
end

function Executor:ScheduleDelayedScripts()
    if not Storage then
        print("|cffff0000ScriptRunner|r: Storage module is not loaded.")
        return
    end

    local scripts = Storage:GetAllScripts()
    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "delay" then
            self:ScheduleDelayedScript(script)
        end
    end
end

function Executor:GetExecutionStats()
    return executionStats
end

ScriptRunner.Executor = Executor
