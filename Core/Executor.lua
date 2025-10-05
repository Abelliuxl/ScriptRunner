-- ScriptRunner - 执行引擎模块
-- 简化的Lua脚本执行器，依赖游戏本身的安全机制

local ScriptRunner = _G.ScriptRunner or {}

-- 执行引擎模块
ScriptRunner.Executor = {}

-- 执行脚本
function ScriptRunner.Executor:ExecuteScript(script, context)
    if not script or not script.code then
        return false, "无效的脚本"
    end
    
    -- 检查脚本是否启用
    if not script.enabled then
        return false, "脚本已禁用"
    end
    
    -- 使用 WoW 安全的代码加载方式
    local func, loadError
    if loadstring then
        func, loadError = loadstring(script.code, script.name)
    elseif _G.load then
        func, loadError = _G.load(script.code, script.name)
    else
        -- 如果都不可用，使用 RunScript 作为最后的备选方案
        local success, execResult = pcall(function()
            -- 创建一个临时的全局函数来执行代码
            local tempFunc = function()
                return assert(loadstring or load, "代码加载功能不可用")(script.code, script.name)
            end
            return tempFunc()
        end)
        
        if not success then
            -- 尝试直接使用 RunScript（仅用于简单脚本）
            if script.code and string.len(script.code) < 1000 then
                local runSuccess, runError = pcall(function()
                    -- 创建一个包装函数来捕获输出
                    local wrappedCode = "local function _tempScript() " .. script.code .. " end return _tempScript()"
                    return assert(loadstring or load, "代码加载功能不可用")(wrappedCode, script.name)
                end)
                
                if runSuccess then
                    func = runError
                    loadError = nil
                else
                    return false, "代码加载失败: " .. tostring(runError)
                end
            else
                return false, "代码加载功能不可用且脚本过长"
            end
        else
            func = execResult
        end
    end
    
    if not func then
        return false, "代码编译错误: " .. tostring(loadError)
    end
    
    -- 执行函数
    local success, execResult = pcall(func)
    
    if success then
        if ScriptRunner.Storage:GetSettings().debug then
            print("|cff00ff00ScriptRunner|r: 脚本 '" .. script.name .. "' 执行成功")
        end
        return true, execResult
    else
        print("|cffff0000ScriptRunner|r: 脚本 '" .. script.name .. "' 执行失败: " .. execResult)
        return false, execResult
    end
end

-- 自动执行所有自动模式的脚本
function ScriptRunner.Executor:ExecuteAutoScripts()
    local scripts = ScriptRunner.Storage:GetAllScripts()
    local executedCount = 0
    local errorCount = 0
    
    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "auto" then
            local success, result = self:ExecuteScript(script)
            if success then
                executedCount = executedCount + 1
            else
                errorCount = errorCount + 1
            end
        end
    end
    
    if executedCount > 0 or errorCount > 0 then
        print(string.format("|cff00ff00ScriptRunner|r: 自动执行完成 - 成功: %d, 失败: %d", executedCount, errorCount))
    end
end

-- 延迟执行脚本
function ScriptRunner.Executor:ExecuteDelayedScript(script, delay)
    if not script or script.mode ~= "delay" then
        return false, "无效的延迟脚本"
    end
    
    local actualDelay = tonumber(script.delay) or delay or 5
    if actualDelay <= 0 then
        actualDelay = 5
    end
    
    C_Timer.After(actualDelay, function()
        local success, result = self:ExecuteScript(script)
        if success then
            print(string.format("|cff00ff00ScriptRunner|r: 延迟脚本 '%s' 执行成功", script.name))
        else
            print(string.format("|cffff0000ScriptRunner|r: 延迟脚本 '%s' 执行失败: %s", script.name, result))
        end
    end)
    
    print(string.format("|cff00ff00ScriptRunner|r: 延迟脚本 '%s' 已安排在 %.1f 秒后执行", script.name, actualDelay))
    return true
end

-- 安排所有延迟执行的脚本
function ScriptRunner.Executor:ScheduleDelayedScripts()
    local scripts = ScriptRunner.Storage:GetAllScripts()
    local scheduledCount = 0
    
    for _, script in pairs(scripts) do
        if script.enabled and script.mode == "delay" then
            self:ExecuteDelayedScript(script)
            scheduledCount = scheduledCount + 1
        end
    end
    
    if scheduledCount > 0 then
        print(string.format("|cff00ff00ScriptRunner|r: 已安排 %d 个延迟脚本", scheduledCount))
    end
end

-- 手动执行脚本
function ScriptRunner.Executor:ExecuteManualScript(scriptID)
    local script = ScriptRunner.Storage:GetScript(scriptID)
    if not script then
        return false, "脚本不存在"
    end
    
    if script.mode ~= "manual" then
        return false, "该脚本不是手动执行模式"
    end
    
    return self:ExecuteScript(script)
end

-- 验证脚本语法
function ScriptRunner.Executor:ValidateScript(code)
    if not code or code == "" then
        return false, "代码为空"
    end
    
    -- 使用 WoW 安全的代码验证方式
    local func, loadError
    if loadstring then
        func, loadError = loadstring(code, "validation")
    elseif _G.load then
        func, loadError = _G.load(code, "validation")
    else
        -- 如果都不可用，使用基本的语法检查
        -- 检查是否包含基本的 Lua 语法结构
        local hasBasicSyntax = true
        local errorMessage = ""
        
        -- 检查括号匹配
        local openParen = 0
        local openBrace = 0
        local openBracket = 0
        
        for i = 1, string.len(code) do
            local char = string.sub(code, i, i)
            if char == "(" then
                openParen = openParen + 1
            elseif char == ")" then
                openParen = openParen - 1
                if openParen < 0 then
                    hasBasicSyntax = false
                    errorMessage = "括号不匹配"
                    break
                end
            elseif char == "{" then
                openBrace = openBrace + 1
            elseif char == "}" then
                openBrace = openBrace - 1
                if openBrace < 0 then
                    hasBasicSyntax = false
                    errorMessage = "大括号不匹配"
                    break
                end
            elseif char == "[" then
                openBracket = openBracket + 1
            elseif char == "]" then
                openBracket = openBracket - 1
                if openBracket < 0 then
                    hasBasicSyntax = false
                    errorMessage = "方括号不匹配"
                    break
                end
            end
        end
        
        if hasBasicSyntax and (openParen ~= 0 or openBrace ~= 0 or openBracket ~= 0) then
            hasBasicSyntax = false
            errorMessage = "括号不匹配"
        end
        
        if hasBasicSyntax then
            -- 进行更基本的检查
            if string.find(code, "function%s+%w+%s*%(") or 
               string.find(code, "local%s+function%s+%w+%s*%(") or
               string.find(code, "if%s+.-%s+then") or
               string.find(code, "for%s+.-%s+do") or
               string.find(code, "while%s+.-%s+do") or
               string.find(code, "repeat") or
               string.find(code, "return") or
               string.find(code, "print") or
               string.find(code, "MessageFrame") then
                return true, "基本语法检查通过（代码加载功能不可用，仅进行基础检查）"
            else
                -- 如果没有找到任何 Lua 关键字，可能是纯文本
                return true, "基本语法检查通过（代码加载功能不可用，仅进行基础检查）"
            end
        else
            return false, "语法错误: " .. errorMessage
        end
    end
    
    if not func then
        return false, "语法错误: " .. tostring(loadError)
    end
    
    return true, "语法检查通过"
end

-- 获取执行统计信息
function ScriptRunner.Executor:GetExecutionStats()
    -- 这里可以添加执行统计功能
    return {
        totalExecutions = 0,
        successfulExecutions = 0,
        failedExecutions = 0,
        lastExecutionTime = nil
    }
end

-- 注册执行引擎模块到全局
_G.ScriptRunner = ScriptRunner
