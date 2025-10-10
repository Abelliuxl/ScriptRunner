-- ScriptRunner - Storage module (Standalone)
-- Persists and manages script data.

local Storage = {}
local addon

function Storage:Initialize(mainAddon)
    addon = mainAddon
    addon.db.global.scripts = addon.db.global.scripts or {}
    
    -- Migrate old profile scripts to global scripts
    self:MigrateLegacyData()
end

function Storage:MigrateLegacyData()
    -- Check if there are old profile scripts that need migration
    if addon.db.scripts and type(addon.db.scripts) == "table" then
        local migrated = 0
        local globalScripts = addon.db.global.scripts
        
        for scriptID, script in pairs(addon.db.scripts) do
            -- Only migrate if this script doesn't already exist in global
            if not globalScripts[scriptID] then
                -- Ensure the script has all required fields
                local migratedScript = {
                    id = script.id or scriptID,
                    name = script.name or "Migrated Script",
                    code = script.code or "",
                    mode = script.mode or "manual",
                    delay = tonumber(script.delay) or 5,
                    enabled = script.enabled ~= false,
                    createdAt = script.createdAt or time(),
                    updatedAt = script.updatedAt or time(),
                }
                
                globalScripts[scriptID] = migratedScript
                migrated = migrated + 1
            end
        end
        
        if migrated > 0 then
            print(string.format("|cff00ff00ScriptRunner|r: Migrated %d legacy scripts to new storage format.", migrated))
            
            -- Clear the old scripts after successful migration
            addon.db.scripts = nil
        end
    end
end

local function getScriptDB()
    return addon.db.global.scripts
end

local function generateUniqueID()
    return string.format("script_%d_%04d", time(), math.random(0, 9999))
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

    for key, value in pairs(updates) do
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
    return true, script
end

function Storage:DeleteScript(scriptID)
    local scripts = getScriptDB()
    local script = scripts[scriptID]
    if not script then
        return false, "Script does not exist."
    end

    scripts[scriptID] = nil
    return true
end

function Storage:ToggleScript(scriptID)
    local script = self:GetScript(scriptID)
    if not script then
        return false
    end

    script.enabled = not script.enabled
    script.updatedAt = time()
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
            count = count + 1
        end
    end

    return true, count
end

function Storage:ClearAllScripts()
    local scripts = getScriptDB()
    for id, _ in pairs(scripts) do
        scripts[id] = nil
    end
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

ScriptRunner.Storage = Storage
