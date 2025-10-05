-- ScriptRunner - 存储模块
-- 负责脚本数据的持久化存储和管理

local ScriptRunner = _G.ScriptRunner or {}

-- 存储模块
ScriptRunner.Storage = {}

-- 生成唯一ID
local function GenerateUniqueID()
    local timestamp = time()
    local random = math.random(1000, 9999)
    return "script_" .. timestamp .. "_" .. random
end

-- 初始化数据库
function ScriptRunner.Storage:Initialize()
    if not ScriptRunnerDB then
        ScriptRunnerDB = {
            scripts = {},
            settings = {
                enabled = true,
                debug = false,
                theme = "default"
            }
        }
        print("|cff00ff00ScriptRunner|r: 数据库已初始化")
    end
end

-- 获取所有脚本
function ScriptRunner.Storage:GetAllScripts()
    return ScriptRunnerDB.scripts or {}
end

-- 根据ID获取脚本
function ScriptRunner.Storage:GetScript(scriptID)
    return ScriptRunnerDB.scripts[scriptID]
end

-- 创建新脚本
function ScriptRunner.Storage:CreateScript(name, code, mode, delay)
    local scriptID = GenerateUniqueID()
    local newScript = {
        id = scriptID,
        name = name or "新脚本",
        code = code or "",
        mode = mode or "manual", -- "auto"/"delay"/"manual"
        delay = delay or 5,
        enabled = true,
        createdAt = time(),
        updatedAt = time()
    }
    
    ScriptRunnerDB.scripts[scriptID] = newScript
    return newScript
end

-- 更新脚本
function ScriptRunner.Storage:UpdateScript(scriptID, updates)
    local script = ScriptRunnerDB.scripts[scriptID]
    if not script then
        return false, "脚本不存在"
    end
    
    -- 更新指定字段
    for key, value in pairs(updates) do
        script[key] = value
    end
    
    script.updatedAt = time()
    return true, script
end

-- 删除脚本
function ScriptRunner.Storage:DeleteScript(scriptID)
    if ScriptRunnerDB.scripts[scriptID] then
        ScriptRunnerDB.scripts[scriptID] = nil
        return true
    end
    return false
end

-- 切换脚本启用状态
function ScriptRunner.Storage:ToggleScript(scriptID)
    local script = ScriptRunnerDB.scripts[scriptID]
    if script then
        script.enabled = not script.enabled
        script.updatedAt = time()
        return script.enabled
    end
    return false
end

-- 获取设置
function ScriptRunner.Storage:GetSettings()
    return ScriptRunnerDB.settings
end

-- 更新设置
function ScriptRunner.Storage:UpdateSettings(newSettings)
    for key, value in pairs(newSettings) do
        ScriptRunnerDB.settings[key] = value
    end
end

-- 导出脚本数据
function ScriptRunner.Storage:ExportScripts()
    local exportData = {
        version = "1.0.0",
        exportTime = time(),
        scripts = {}
    }
    
    for id, script in pairs(ScriptRunnerDB.scripts) do
        exportData.scripts[id] = {
            name = script.name,
            code = script.code,
            mode = script.mode,
            delay = script.delay,
            enabled = script.enabled
        }
    end
    
    return exportData
end

-- 导入脚本数据
function ScriptRunner.Storage:ImportScripts(importData)
    if not importData or not importData.scripts then
        return false, "无效的导入数据"
    end
    
    local importCount = 0
    for id, scriptData in pairs(importData.scripts) do
        local newID = GenerateUniqueID() -- 生成新ID避免冲突
        local newScript = {
            id = newID,
            name = scriptData.name or "导入脚本",
            code = scriptData.code or "",
            mode = scriptData.mode or "manual",
            delay = scriptData.delay or 5,
            enabled = scriptData.enabled or true,
            createdAt = time(),
            updatedAt = time()
        }
        ScriptRunnerDB.scripts[newID] = newScript
        importCount = importCount + 1
    end
    
    return true, importCount
end

-- 清理所有脚本（危险操作，需要确认）
function ScriptRunner.Storage:ClearAllScripts()
    ScriptRunnerDB.scripts = {}
end

-- 获取脚本统计信息
function ScriptRunner.Storage:GetStats()
    local stats = {
        total = 0,
        enabled = 0,
        auto = 0,
        delay = 0,
        manual = 0
    }
    
    for _, script in pairs(ScriptRunnerDB.scripts) do
        stats.total = stats.total + 1
        if script.enabled then
            stats.enabled = stats.enabled + 1
        end
        
        if script.mode == "auto" then
            stats.auto = stats.auto + 1
        elseif script.mode == "delay" then
            stats.delay = stats.delay + 1
        elseif script.mode == "manual" then
            stats.manual = stats.manual + 1
        end
    end
    
    return stats
end

-- 注册存储模块到全局
_G.ScriptRunner = ScriptRunner
