-- ScriptRunner - Execution engine module (Ace3 build)
-- Executes stored scripts with optional scheduling helpers.

local ScriptRunner = LibStub("AceAddon-3.0"):GetAddon("ScriptRunner")
local Executor = ScriptRunner:NewModule("Executor", "AceEvent-3.0", "AceTimer-3.0")

local scheduledTimers = {}

local executionStats = {
    totalExecutions = 0,
    successfulExecutions = 0,
    failedExecutions = 0,
    lastExecutionTime = nil,
}

local function cancelTimer(self, scriptID)
    local handle = scheduledTimers[scriptID]
    if handle then
        self:CancelTimer(handle)
        scheduledTimers[scriptID] = nil
    end
end

function Executor:OnInitialize()
end

function Executor:OnEnable()
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_TOGGLED", "OnScriptToggled")
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_UPDATED", "OnScriptUpdated")
end

function Executor:OnDisable()
    self:CancelAllTimers()
    wipe(scheduledTimers)
end

function Executor:OnScriptToggled(_, scriptID, script)
    cancelTimer(self, scriptID)

    if script.enabled then
        if script.mode == "auto" then
            self:ScheduleAutoScript(scriptID)
        elseif script.mode == "delay" then
            self:ScheduleDelayedScript(script)
        end
    end
end

function Executor:OnScriptUpdated(_, scriptID, script, oldValues)
    if oldValues.mode and oldValues.mode ~= script.mode then
        cancelTimer(self, scriptID)
    elseif oldValues.delay and oldValues.delay ~= script.delay then
        cancelTimer(self, scriptID)
    end

    if script.enabled then
        if script.mode == "auto" then
            self:ScheduleAutoScript(scriptID)
        elseif script.mode == "delay" then
            self:ScheduleDelayedScript(script)
        end
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
        ScriptRunner = ScriptRunner,
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

    local chunk, loadError
    if loadstring then
        chunk, loadError = loadstring(script.code, script.name or "ScriptRunner")
    else
        chunk, loadError = load(script.code, script.name or "ScriptRunner")
    end

    if not chunk then
        executionStats.failedExecutions = executionStats.failedExecutions + 1
        self:SendMessage("SCRIPTRUNNER_SCRIPT_EXECUTED", script.id, script, loadError, false)
        return false, "Syntax error: " .. tostring(loadError)
    end

    if setfenv then
        setfenv(chunk, env)
    end

    local ok, result = pcall(chunk)
    if ok then
        executionStats.successfulExecutions = executionStats.successfulExecutions + 1
        self:SendMessage("SCRIPTRUNNER_SCRIPT_EXECUTED", script.id, script, result, true)
        return true, result
    end

    executionStats.failedExecutions = executionStats.failedExecutions + 1
    self:SendMessage("SCRIPTRUNNER_SCRIPT_EXECUTED", script.id, script, result, false)
    return false, result
end

function Executor:ExecuteManualScript(scriptID)
    if not ScriptRunner.Storage then
        return false, "Storage module is not loaded."
    end

    local script = ScriptRunner.Storage:GetScript(scriptID)
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

    local chunk, loadError
    if loadstring then
        chunk, loadError = loadstring(code, "ScriptRunnerValidation")
    else
        chunk, loadError = load(code, "ScriptRunnerValidation")
    end

    if not chunk then
        return false, "Syntax error: " .. tostring(loadError)
    end

    return true, "Syntax OK"
end

function Executor:ScheduleAutoScript(scriptID)
    if not ScriptRunner.Storage then
        return false, "Storage module is not loaded."
    end

    local script = ScriptRunner.Storage:GetScript(scriptID)
    if not script or not script.enabled or script.mode ~= "auto" then
        return false
    end

    cancelTimer(self, scriptID)

    local interval = tonumber(script.delay) or 30
    if interval <= 0 then
        interval = 30
    end

    scheduledTimers[scriptID] = self:ScheduleRepeatingTimer(function()
        local current = ScriptRunner.Storage and ScriptRunner.Storage:GetScript(scriptID)
        if current and current.enabled and current.mode == "auto" then
            self:ExecuteScript(current)
        else
            cancelTimer(self, scriptID)
        end
    end, interval)

    return true
end

function Executor:ScheduleDelayedScript(script)
    if not script or script.mode ~= "delay" then
        return false
    end

    cancelTimer(self, script.id)

    local delay = tonumber(script.delay) or 5
    if delay < 0 then
        delay = 0
    end

    scheduledTimers[script.id] = self:ScheduleTimer(function()
        local current = ScriptRunner.Storage and ScriptRunner.Storage:GetScript(script.id)
        if current and current.enabled and current.mode == "delay" then
            self:ExecuteScript(current)
        end
        cancelTimer(self, script.id)
    end, delay)

    return true
end

function Executor:CancelScriptExecution(scriptID)
    cancelTimer(self, scriptID)
end

function Executor:ExecuteAutoScripts()
    if not ScriptRunner.Storage then
        print("|cffff0000ScriptRunner|r: Storage module is not loaded.")
        return
    end

    local scripts = ScriptRunner.Storage:GetAllScripts()
    local executedCount = 0
    local errorCount = 0

    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "auto" then
            local success = self:ExecuteScript(script)
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
    if not ScriptRunner.Storage then
        print("|cffff0000ScriptRunner|r: Storage module is not loaded.")
        return
    end

    local scripts = ScriptRunner.Storage:GetAllScripts()
    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "delay" then
            self:ScheduleDelayedScript(script)
        end
    end
end

function Executor:BatchExecute(scriptIDs, parallel)
    if not ScriptRunner.Storage then
        return false, "Storage module is not loaded."
    end

    if type(scriptIDs) ~= "table" then
        return false, "scriptIDs must be a table."
    end

    local results = {}
    local successCount = 0
    local errorCount = 0

    local function run(scriptID)
        local script = ScriptRunner.Storage:GetScript(scriptID)
        if script then
            local success, result = self:ExecuteScript(script)
            results[scriptID] = { success = success, result = result }
            if success then
                successCount = successCount + 1
            else
                errorCount = errorCount + 1
            end
        else
            results[scriptID] = { success = false, result = "Script does not exist." }
            errorCount = errorCount + 1
        end
    end

    if parallel then
        for _, scriptID in ipairs(scriptIDs) do
            self:ScheduleTimer(function()
                run(scriptID)
            end, 0)
        end
    else
        for _, scriptID in ipairs(scriptIDs) do
            run(scriptID)
        end
    end

    self:SendMessage("SCRIPTRUNNER_BATCH_EXECUTION", scriptIDs, results, successCount, errorCount)
    return results, successCount, errorCount
end

function Executor:GetExecutionStats()
    return executionStats
end

ScriptRunner.Executor = Executor
