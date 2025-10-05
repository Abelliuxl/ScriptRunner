-- ScriptRunner - 游戏内自定义Lua脚本执行器
-- 版本: 1.0.0
-- 作者: Custom

-- 创建插件主框架
local ScriptRunner = CreateFrame("Frame", "ScriptRunner")
ScriptRunner:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, event, ...)
    end
end)

-- 插件模块命名空间
_G.ScriptRunner = ScriptRunner

-- 插件初始化状态
local isInitialized = false

-- 插件加载事件
function ScriptRunner:ADDON_LOADED(event, addonName)
    if addonName == "ScriptRunner" then
        self:Initialize()
    end
end

-- 插件初始化
function ScriptRunner:Initialize()
    if isInitialized then return end
    
    print("|cff00ff00ScriptRunner|r: 游戏内自定义Lua脚本执行器 v1.0.0")
    
    -- 初始化存储模块
    if self.Storage and self.Storage.Initialize then
        self.Storage:Initialize()
        print("|cff00ff00ScriptRunner|r: 存储模块已加载")
    else
        print("|cffff0000ScriptRunner|r: 存储模块加载失败")
        return
    end
    
    -- 注册斜杠命令
    self:RegisterSlashCommands()
    
    -- 注册事件
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    isInitialized = true
    print("|cff00ff00ScriptRunner|r: 插件初始化完成")
    print("|cff00ff00ScriptRunner|r: 使用 /sr 命令打开管理界面")
end

-- 注册斜杠命令
function ScriptRunner:RegisterSlashCommands()
    -- 主命令
    SlashCmdList["SCRIPTRUNNER"] = function(msg)
        self:HandleSlashCommand(msg)
    end
    SLASH_SCRIPTRUNNER1 = "/sr"
    SLASH_SCRIPTRUNNER2 = "/scriptrunner"
    
    -- 调试命令
    SlashCmdList["SCRIPTRUNNER_DEBUG"] = function(msg)
        self:HandleDebugCommand(msg)
    end
    SLASH_SCRIPTRUNNER_DEBUG1 = "/srd"
    SLASH_SCRIPTRUNNER_DEBUG2 = "/scriptrunnerdebug"
    
    print("|cff00ff00ScriptRunner|r: 斜杠命令已注册")
end

-- 处理斜杠命令
function ScriptRunner:HandleSlashCommand(msg)
    if not msg or msg == "" then
        -- 显示UI
        if self.UI then
            self.UI:Toggle()
        else
            print("|cffff0000ScriptRunner|r: UI模块未加载")
        end
        return
    end
    
    local cmd, arg1, arg2 = strsplit(" ", msg:lower(), 3)
    
    if cmd == "help" then
        self:ShowHelp()
    elseif cmd == "list" then
        self:ListScripts()
    elseif cmd == "run" and arg1 then
        self:RunScript(arg1)
    elseif cmd == "create" and arg1 then
        self:CreateScript(arg1)
    elseif cmd == "delete" and arg1 then
        self:DeleteScript(arg1)
    elseif cmd == "stats" then
        self:ShowStats()
    elseif cmd == "export" then
        self:ExportScripts()
    elseif cmd == "import" and arg1 then
        self:ImportScripts(arg1)
    else
        print("|cffff0000ScriptRunner|r: 未知命令。使用 /sr help 查看帮助")
    end
end

-- 处理调试命令
function ScriptRunner:HandleDebugCommand(msg)
    if not msg or msg == "" then
        -- 切换调试模式
        local settings = self.Storage:GetSettings()
        settings.debug = not settings.debug
        self.Storage:UpdateSettings({debug = settings.debug})
        
        if settings.debug then
            print("|cff00ff00ScriptRunner|r: 调试模式已开启")
        else
            print("|cff00ff00ScriptRunner|r: 调试模式已关闭")
        end
        return
    end
    
    local cmd = msg:lower()
    
    if cmd == "validate" then
        self:ValidateAllScripts()
    elseif cmd == "test" then
        self:RunTestScript()
    elseif cmd == "reset" then
        self:ResetDatabase()
    else
        print("|cffff0000ScriptRunner|r: 未知调试命令")
    end
end

-- 显示帮助信息
function ScriptRunner:ShowHelp()
    print("|cff00ff00=== ScriptRunner 帮助 ===|r")
    print("|cff00ccff基本命令:|r")
    print("  /sr 或 /scriptrunner - 打开管理界面")
    print("  /sr help - 显示此帮助信息")
    print("  /sr list - 列出所有脚本")
    print("  /sr stats - 显示统计信息")
    print("|cff00ccff脚本管理:|r")
    print("  /sr create <名称> - 创建新脚本")
    print("  /sr delete <ID或名称> - 删除脚本")
    print("  /sr run <ID或名称> - 执行脚本")
    print("|cff00ccff数据管理:|r")
    print("  /sr export - 导出所有脚本")
    print("  /sr import <数据> - 导入脚本数据")
    print("|cff00ccff调试命令:|r")
    print("  /srd 或 /scriptrunnerdebug - 切换调试模式")
    print("  /srd validate - 验证所有脚本")
    print("  /srd test - 运行测试脚本")
    print("  /srd reset - 重置数据库")
end

-- 列出所有脚本
function ScriptRunner:ListScripts()
    local scripts = self.Storage:GetAllScripts()
    local count = 0
    
    print("|cff00ff00=== 脚本列表 ===|r")
    
    for id, script in pairs(scripts) do
        local status = script.enabled and "|cff00ff00[启用]|r" or "|cffff0000[禁用]|r"
        local mode = ""
        if script.mode == "auto" then
            mode = "|cff00ccff[自动]|r"
        elseif script.mode == "delay" then
            mode = "|cffffcc00[延迟:" .. script.delay .. "s]|r"
        else
            mode = "|cffcccccc[手动]|r"
        end
        
        print(string.format("  %s %s %s |cff00ccff%s|r |cff888888(%s)|r", 
            status, mode, script.name, id:sub(1, 8), 
            script.code:len() > 50 and script.code:sub(1, 47) .. "..." or script.code))
        count = count + 1
    end
    
    if count == 0 then
        print("  |cffcccccc暂无脚本|r")
    else
        print(string.format("|cff00ff00总计: %d 个脚本|r", count))
    end
end

-- 显示统计信息
function ScriptRunner:ShowStats()
    local stats = self.Storage:GetStats()
    local settings = self.Storage:GetSettings()
    
    print("|cff00ff00=== 统计信息 ===|r")
    print(string.format("  总脚本数: |cff00ccff%d|r", stats.total))
    print(string.format("  启用脚本: |cff00ff00%d|r", stats.enabled))
    print(string.format("  自动执行: |cff00ccff%d|r", stats.auto))
    print(string.format("  延迟执行: |cffffcc00%d|r", stats.delay))
    print(string.format("  手动执行: |cffcccccc%d|r", stats.manual))
    print(string.format("  调试模式: |cff%s%s|r", settings.debug and "00ff00" or "ff0000", settings.debug and "开启" or "关闭"))
end

-- 运行脚本
function ScriptRunner:RunScript(identifier)
    local script = nil
    
    -- 尝试按ID查找
    script = self.Storage:GetScript(identifier)
    
    -- 如果没找到，尝试按名称查找
    if not script then
        local scripts = self.Storage:GetAllScripts()
        for id, s in pairs(scripts) do
            if s.name:lower():find(identifier:lower(), 1, true) then
                script = s
                break
            end
        end
    end
    
    if script then
        local success, result = self.Executor:ExecuteManualScript(script.id)
        if success then
            print(string.format("|cff00ff00ScriptRunner|r: 脚本 '%s' 执行成功", script.name))
        else
            print(string.format("|cffff0000ScriptRunner|r: 脚本 '%s' 执行失败: %s", script.name, result))
        end
    else
        print(string.format("|cffff0000ScriptRunner|r: 未找到脚本 '%s'", identifier))
    end
end

-- 创建脚本
function ScriptRunner:CreateScript(name)
    local newScript = self.Storage:CreateScript(name, "-- " .. name .. "\n\nprint('Hello from " .. name .. "')", "manual", 5)
    print(string.format("|cff00ff00ScriptRunner|r: 脚本 '%s' 已创建，ID: %s", name, newScript.id:sub(1, 8)))
    
    -- 如果UI可用，自动选中新创建的脚本
    if self.UI then
        self.UI:SelectScript(newScript.id)
        self.UI:Show()
    end
end

-- 删除脚本
function ScriptRunner:DeleteScript(identifier)
    local script = nil
    local scriptID = nil
    
    -- 尝试按ID查找
    script = self.Storage:GetScript(identifier)
    if script then
        scriptID = identifier
    else
        -- 尝试按名称查找
        local scripts = self.Storage:GetAllScripts()
        for id, s in pairs(scripts) do
            if s.name:lower():find(identifier:lower(), 1, true) then
                script = s
                scriptID = id
                break
            end
        end
    end
    
    if script then
        self.Storage:DeleteScript(scriptID)
        print(string.format("|cff00ff00ScriptRunner|r: 脚本 '%s' 已删除", script.name))
        
        -- 刷新UI
        if self.UI then
            self.UI:RefreshScriptList()
        end
    else
        print(string.format("|cffff0000ScriptRunner|r: 未找到脚本 '%s'", identifier))
    end
end

-- 导出脚本
function ScriptRunner:ExportScripts()
    local exportData = self.Storage:ExportScripts()
    local exportString = self:SerializeTable(exportData)
    
    print("|cff00ff00=== 脚本导出数据 ===|r")
    print(exportString)
    print("|cff00ff00=== 导出完成 ===|r")
end

-- 导入脚本
function ScriptRunner:ImportScripts(data)
    local importData = self:DeserializeTable(data)
    if importData then
        local success, count = self.Storage:ImportScripts(importData)
        if success then
            print(string.format("|cff00ff00ScriptRunner|r: 成功导入 %d 个脚本", count))
            if self.UI then
                self.UI:RefreshScriptList()
            end
        else
            print("|cffff0000ScriptRunner|r: 导入失败: " .. count)
        end
    else
        print("|cffff0000ScriptRunner|r: 无效的导入数据格式")
    end
end

-- 验证所有脚本
function ScriptRunner:ValidateAllScripts()
    local scripts = self.Storage:GetAllScripts()
    local validCount = 0
    local invalidCount = 0
    
    print("|cff00ff00=== 脚本验证 ===|r")
    
    for id, script in pairs(scripts) do
        local isValid, errorMsg = self.Executor:ValidateScript(script.code)
        if isValid then
            print(string.format("  |cff00ff00✓|r %s", script.name))
            validCount = validCount + 1
        else
            print(string.format("  |cffff0000✗|r %s: %s", script.name, errorMsg))
            invalidCount = invalidCount + 1
        end
    end
    
    print(string.format("|cff00ff00验证完成: %d 个有效, %d 个无效|r", validCount, invalidCount))
end

-- 运行测试脚本
function ScriptRunner:RunTestScript()
    local testCode = [[
-- ScriptRunner 测试脚本
print("=== ScriptRunner 测试开始 ===")

-- 基础功能测试
local testTable = {1, 2, 3}
print("表操作测试:", table.concat(testTable, ", "))

-- 数学函数测试
local randomNum = math.random(1, 100)
print("随机数测试:", randomNum)

-- 字符串测试
    local testString = "Hello ScriptRunner"
    print("字符串测试:", string.upper(testString))

-- 时间测试
local currentTime = date("%H:%M:%S")
print("当前时间:", currentTime)

print("=== ScriptRunner 测试完成 ===")
]]
    
    local testScript = {
        name = "测试脚本",
        code = testCode,
        enabled = true
    }
    
    local success, result = self.Executor:ExecuteScript(testScript)
    if success then
        print("|cff00ff00ScriptRunner|r: 测试脚本执行成功")
    else
        print("|cffff0000ScriptRunner|r: 测试脚本执行失败: " .. result)
    end
end

-- 重置数据库
function ScriptRunner:ResetDatabase()
    print("|cffff0000ScriptRunner|r: 警告！这将删除所有脚本数据。")
    print("|cffff0000ScriptRunner|r: 请在聊天框输入 'CONFIRM RESET' 来确认重置。")
    
    -- 创建确认输入框
    local confirmFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    confirmFrame:SetSize(300, 100)
    confirmFrame:SetPoint("CENTER")
    confirmFrame:SetFrameStrata("DIALOG")
    confirmFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    
    local confirmText = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirmText:SetPoint("TOP", 0, -20)
    confirmText:SetText("确认重置所有数据？")
    
    local yesButton = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    yesButton:SetSize(80, 25)
    yesButton:SetPoint("BOTTOMLEFT", 50, 20)
    yesButton:SetText("确认")
    yesButton:SetScript("OnClick", function()
        self.Storage:ClearAllScripts()
        print("|cff00ff00ScriptRunner|r: 数据库已重置")
        confirmFrame:Hide()
    end)
    
    local noButton = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    noButton:SetSize(80, 25)
    noButton:SetPoint("BOTTOMRIGHT", -50, 20)
    noButton:SetText("取消")
    noButton:SetScript("OnClick", function()
        print("|cff00ff00ScriptRunner|r: 重置操作已取消")
        confirmFrame:Hide()
    end)
end

-- 序列化表为字符串
function ScriptRunner:SerializeTable(t)
    if type(t) ~= "table" then return tostring(t) end
    
    local result = "{"
    for k, v in pairs(t) do
        local key = type(k) == "string" and '["' .. k .. '"]' or "[" .. tostring(k) .. "]"
        local value = type(v) == "table" and self:SerializeTable(v) or '"' .. tostring(v) .. '"'
        result = result .. key .. "=" .. value .. ","
    end
    result = result .. "}"
    return result
end

-- 反序列化字符串为表（简化版本）
function ScriptRunner:DeserializeTable(str)
    local func, error = load("return " .. str)
    if func then
        local success, result = pcall(func)
        return success and result or nil
    end
    return nil
end

-- 玩家进入世界事件
function ScriptRunner:PLAYER_ENTERING_WORLD()
    -- 延迟执行自动和延迟脚本
    C_Timer.After(2, function()
        if self.Executor then
            self.Executor:ExecuteAutoScripts()
            self.Executor:ScheduleDelayedScripts()
        end
    end)
end

-- 注册事件
ScriptRunner:RegisterEvent("ADDON_LOADED")

-- 全局函数，供其他插件或脚本调用
_G.ScriptRunner = ScriptRunner
