-- ScriptRunner - Storage module (Ace3 build)
-- Persists and manages script data.

local ScriptRunner = LibStub("AceAddon-3.0"):GetAddon("ScriptRunner")
local Storage = ScriptRunner:NewModule("Storage", "AceEvent-3.0")

local function getScriptDB()
    ScriptRunner.db.global.scripts = ScriptRunner.db.global.scripts or {}
    return ScriptRunner.db.global.scripts
end

local function generateUniqueID()
    return string.format("script_%d_%04d", time(), math.random(0, 9999))
end

function Storage:OnInitialize()
    getScriptDB()
end

function Storage:OnEnable()
end

function Storage:OnDisable()
end

function Storage:GetAllScripts()
    return getScriptDB()
end

function Storage:GetScript(scriptID)
    if not scriptID then
        return nil
    end
    return getScriptDB()[scriptID]
end

function Storage:CreateScript(name, code, mode, delay)
    local scripts = getScriptDB()
    local scriptID = generateUniqueID()
    local normalizedMode = "manual"

    if mode == "auto" or mode == "delay" then
        normalizedMode = mode
    end

    local script = {
        id = scriptID,
        name = name or "New Script",
        code = code or "",
        mode = normalizedMode,
        delay = tonumber(delay) or 5,
        enabled = true,
        createdAt = time(),
        updatedAt = time(),
    }

    scripts[scriptID] = script
    self:SendMessage("SCRIPTRUNNER_SCRIPT_CREATED", scriptID, script)
    return script
end

function Storage:UpdateScript(scriptID, updates)
    local script = self:GetScript(scriptID)
    if not script then
        return false, "Script does not exist."
    end

    if type(updates) ~= "table" then
        return false, "Invalid update payload."
    end

    local oldValues = {}

    for key, value in pairs(updates) do
        oldValues[key] = script[key]
        if key == "name" and type(value) == "string" then
            script.name = value
        elseif key == "code" and type(value) == "string" then
            script.code = value
        elseif key == "mode" and (value == "auto" or value == "delay" or value == "manual") then
            script.mode = value
        elseif key == "delay" then
            local numeric = tonumber(value)
            if numeric and numeric >= 0 then
                script.delay = numeric
            end
        elseif key == "enabled" then
            script.enabled = not not value
        end
    end

    script.updatedAt = time()
    self:SendMessage("SCRIPTRUNNER_SCRIPT_UPDATED", scriptID, script, oldValues)
    return true, script
end

function Storage:DeleteScript(scriptID)
    local scripts = getScriptDB()
    local script = scripts[scriptID]
    if not script then
        return false, "Script does not exist."
    end

    scripts[scriptID] = nil
    self:SendMessage("SCRIPTRUNNER_SCRIPT_DELETED", scriptID, script)
    return true
end

function Storage:ToggleScript(scriptID)
    local script = self:GetScript(scriptID)
    if not script then
        return false
    end

    local oldEnabled = script.enabled
    script.enabled = not script.enabled
    script.updatedAt = time()
    self:SendMessage("SCRIPTRUNNER_SCRIPT_TOGGLED", scriptID, script, oldEnabled)
    return script.enabled
end

function Storage:ImportScripts(data)
    if type(data) ~= "table" then
        return false, "Import data must be a table."
    end

    local scripts = getScriptDB()
    local count = 0

    for _, info in pairs(data) do
        if type(info) == "table" and info.code then
            local scriptID = generateUniqueID()
            local mode = "manual"
            if info.mode == "auto" or info.mode == "delay" then
                mode = info.mode
            end

            local script = {
                id = scriptID,
                name = info.name or "Imported Script",
                code = info.code or "",
                mode = mode,
                delay = tonumber(info.delay) or 5,
                enabled = info.enabled ~= false,
                createdAt = info.createdAt or time(),
                updatedAt = time(),
            }

            scripts[scriptID] = script
            self:SendMessage("SCRIPTRUNNER_SCRIPT_CREATED", scriptID, script)
            count = count + 1
        end
    end

    return true, count
end

function Storage:ClearAllScripts()
    local scripts = getScriptDB()
    local removed = {}

    for id, script in pairs(scripts) do
        removed[id] = script
        self:SendMessage("SCRIPTRUNNER_SCRIPT_DELETED", id, script)
        scripts[id] = nil
    end

    self:SendMessage("SCRIPTRUNNER_DATABASE_CLEARED", removed)
end

function Storage:GetStats()
    local scripts = getScriptDB()
    local stats = {
        total = 0,
        enabled = 0,
        disabled = 0,
        auto = 0,
        delay = 0,
        manual = 0,
        totalCodeLength = 0,
        averageCodeLength = 0,
    }

    for _, script in pairs(scripts) do
        stats.total = stats.total + 1
        if script.enabled then
            stats.enabled = stats.enabled + 1
        else
            stats.disabled = stats.disabled + 1
        end

        if script.mode == "auto" then
            stats.auto = stats.auto + 1
        elseif script.mode == "delay" then
            stats.delay = stats.delay + 1
        else
            stats.manual = stats.manual + 1
        end

        if script.code then
            stats.totalCodeLength = stats.totalCodeLength + #script.code
        end
    end

    if stats.total > 0 then
        stats.averageCodeLength = math.floor(stats.totalCodeLength / stats.total)
    end

    return stats
end

function Storage:Maintenance()
    local scripts = getScriptDB()
    local fixed = 0

    for _, script in pairs(scripts) do
        local updated = false

        if not script.name or script.name == "" then
            script.name = "Untitled Script"
            updated = true
        end

        if script.mode ~= "auto" and script.mode ~= "delay" and script.mode ~= "manual" then
            script.mode = "manual"
            updated = true
        end

        if type(script.delay) ~= "number" or script.delay < 0 then
            script.delay = 5
            updated = true
        end

        if script.enabled == nil then
            script.enabled = true
            updated = true
        end

        if updated then
            script.updatedAt = time()
            fixed = fixed + 1
        end
    end

    return { fixedScripts = fixed }
end

ScriptRunner.Storage = Storage
