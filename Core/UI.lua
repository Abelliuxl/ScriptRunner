-- ScriptRunner - 用户界面模块
-- 负责创建和管理插件的图形界面

local ScriptRunner = _G.ScriptRunner or {}

-- UI模块
ScriptRunner.UI = {}

-- UI状态
local UIState = {
    isVisible = false,
    selectedScriptID = nil,
    isEditing = false,
    currentTheme = "default"
}

-- 颜色主题
local Themes = {
    default = {
        background = {0.1, 0.1, 0.1, 0.95},
        header = {0.2, 0.2, 0.2, 1},
        button = {0.3, 0.3, 0.3, 1},
        buttonHover = {0.4, 0.4, 0.4, 1},
        buttonPressed = {0.2, 0.2, 0.2, 1},
        text = {1, 1, 1, 1},
        textDisabled = {0.5, 0.5, 0.5, 1},
        accent = {0.2, 0.6, 1, 1},
        success = {0.2, 0.8, 0.2, 1},
        error = {0.8, 0.2, 0.2, 1},
        warning = {0.8, 0.6, 0.2, 1}
    }
}

-- 主窗口
local MainWindow = nil
local ScriptListFrame = nil
local EditorFrame = nil
local ConfigFrame = nil

-- 创建主窗口
local function CreateMainWindow()
    if MainWindow then return MainWindow end
    
    MainWindow = CreateFrame("Frame", "LuaManagerMainWindow", UIParent, "BackdropTemplate")
    MainWindow:SetSize(800, 600)
    MainWindow:SetPoint("CENTER")
    MainWindow:SetFrameStrata("DIALOG")
    MainWindow:SetMovable(true)
    MainWindow:EnableMouse(true)
    MainWindow:RegisterForDrag("LeftButton")
    MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
    MainWindow:SetScript("OnDragStop", MainWindow.StopMovingOrSizing)
    
    -- 设置背景
    MainWindow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    
    -- 标题栏
    local titleBar = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
    titleBar:SetSize(800, 32)
    titleBar:SetPoint("TOP")
    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    titleBar:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER")
    title:SetText("ScriptRunner - 脚本管理器")
    
    -- 关闭按钮
    local closeButton = CreateFrame("Button", nil, MainWindow, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        ScriptRunner.UI:Hide()
    end)
    
    -- 创建子区域
    CreateScriptListFrame()
    CreateEditorFrame()
    CreateConfigFrame()
    
    return MainWindow
end

-- 创建脚本列表区域
function CreateScriptListFrame()
    ScriptListFrame = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
    ScriptListFrame:SetSize(250, 550)
    ScriptListFrame:SetPoint("TOPLEFT", 10, -40)
    ScriptListFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    ScriptListFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    -- 标题
    local listTitle = ScriptListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOP", 0, -10)
    listTitle:SetText("脚本列表")
    
    -- 新建按钮
    local newButton = CreateFrame("Button", nil, ScriptListFrame, "UIPanelButtonTemplate")
    newButton:SetSize(60, 25)
    newButton:SetPoint("TOPRIGHT", -10, -10)
    newButton:SetText("新建")
    newButton:SetScript("OnClick", function()
        ScriptRunner.UI:CreateNewScript()
    end)
    
    -- 脚本列表滚动区域
    local scrollFrame = CreateFrame("ScrollFrame", nil, ScriptListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(230, 480)
    scrollFrame:SetPoint("TOP", 0, -40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    scrollChild:SetSize(230, 480)
    scrollChild:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    scrollFrame:SetScrollChild(scrollChild)
    
    ScriptListFrame.scrollChild = scrollChild
    ScriptListFrame.scrollFrame = scrollFrame
    
    ScriptRunner.UI:RefreshScriptList()
end

-- 创建编辑器区域
function CreateEditorFrame()
    EditorFrame = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
    EditorFrame:SetSize(520, 550)
    EditorFrame:SetPoint("TOPRIGHT", -10, -40)
    EditorFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    EditorFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    -- 标题
    local editorTitle = EditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editorTitle:SetPoint("TOP", 0, -10)
    editorTitle:SetText("ScriptRunner - 脚本编辑器")
    
    -- 脚本名称输入框
    local nameLabel = EditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 10, -40)
    nameLabel:SetText("名称:")
    
    local nameEditBox = CreateFrame("EditBox", nil, EditorFrame, "InputBoxTemplate")
    nameEditBox:SetSize(200, 32)
    nameEditBox:SetPoint("TOPLEFT", 50, -45)
    nameEditBox:SetAutoFocus(false)
    EditorFrame.nameEditBox = nameEditBox
    
    -- 代码编辑区域
    local codeLabel = EditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    codeLabel:SetPoint("TOPLEFT", 10, -85)
    codeLabel:SetText("代码:")
    
    local codeScrollFrame = CreateFrame("ScrollFrame", nil, EditorFrame, "UIPanelScrollFrameTemplate")
    codeScrollFrame:SetSize(480, 300)
    codeScrollFrame:SetPoint("TOPLEFT", 10, -105)
    
    local codeEditBox = CreateFrame("EditBox", nil, codeScrollFrame, "BackdropTemplate")
    codeEditBox:SetSize(480, 300)
    codeEditBox:SetMultiLine(true)
    codeEditBox:SetAutoFocus(false)
    codeEditBox:SetFontObject("ChatFontNormal")
    
    -- 为代码输入框添加背景和边框
    codeEditBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    codeEditBox:SetBackdropColor(0.05, 0.05, 0.05, 0.9)  -- 深色背景
    codeEditBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)  -- 灰色边框
    
    codeScrollFrame:SetScrollChild(codeEditBox)
    EditorFrame.codeEditBox = codeEditBox
    
    -- 配置区域
    CreateConfigFrame()

    -- 按钮容器
    local ActionBar = CreateFrame("Frame", nil, EditorFrame)
    ActionBar:SetSize(500, 40)
    ActionBar:SetPoint("TOP", ConfigFrame, "BOTTOM", 0, 0)
    
    -- 操作按钮
    local saveButton = CreateFrame("Button", nil, ActionBar, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 25)
    saveButton:SetPoint("CENTER", -95, 0)
    saveButton:SetText("保存")
    saveButton:SetScript("OnClick", function()
        ScriptRunner.UI:SaveCurrentScript()
    end)
    
    local deleteButton = CreateFrame("Button", nil, ActionBar, "UIPanelButtonTemplate")
    deleteButton:SetSize(80, 25)
    deleteButton:SetPoint("CENTER", 0, 0)
    deleteButton:SetText("删除")
    deleteButton:SetScript("OnClick", function()
        ScriptRunner.UI:DeleteCurrentScript()
    end)
    
    local executeButton = CreateFrame("Button", nil, ActionBar, "UIPanelButtonTemplate")
    executeButton:SetSize(80, 25)
    executeButton:SetPoint("CENTER", 95, 0)
    executeButton:SetText("执行")
    executeButton:SetScript("OnClick", function()
        ScriptRunner.UI:ExecuteCurrentScript()
    end)
end

-- 创建配置区域
function CreateConfigFrame()
    if ConfigFrame then return end
    
    ConfigFrame = CreateFrame("Frame", nil, EditorFrame, "BackdropTemplate")
    ConfigFrame:SetSize(500, 120)
    ConfigFrame:SetPoint("TOPLEFT", 10, -415)
    ConfigFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    ConfigFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    
    -- 执行模式
    local modeLabel = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetPoint("TOPLEFT", 10, -10)
    modeLabel:SetText("执行模式:")
    
    -- 自动执行单选按钮
    local autoRadio = CreateFrame("CheckButton", nil, ConfigFrame, "UIRadioButtonTemplate")
    autoRadio:SetPoint("TOPLEFT", 80, -10)
    autoRadio.text = autoRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoRadio.text:SetPoint("LEFT", 20, 0)
    autoRadio.text:SetText("自动执行")
    ConfigFrame.autoRadio = autoRadio
    
    -- 延迟执行单选按钮
    local delayRadio = CreateFrame("CheckButton", nil, ConfigFrame, "UIRadioButtonTemplate")
    delayRadio:SetPoint("TOPLEFT", 180, -10)
    delayRadio.text = delayRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    delayRadio.text:SetPoint("LEFT", 20, 0)
    delayRadio.text:SetText("延迟执行")
    ConfigFrame.delayRadio = delayRadio
    
    -- 手动执行单选按钮
    local manualRadio = CreateFrame("CheckButton", nil, ConfigFrame, "UIRadioButtonTemplate")
    manualRadio:SetPoint("TOPLEFT", 280, -10)
    manualRadio.text = manualRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manualRadio.text:SetPoint("LEFT", 20, 0)
    manualRadio.text:SetText("手动执行")
    ConfigFrame.manualRadio = manualRadio
    
    -- 延迟时间输入
    local delayLabel = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    delayLabel:SetPoint("TOPLEFT", 80, -40)
    delayLabel:SetText("延迟时间(秒):")
    ConfigFrame.delayLabel = delayLabel
    
    local delayEditBox = CreateFrame("EditBox", nil, ConfigFrame, "InputBoxTemplate")
    delayEditBox:SetSize(60, 32)
    delayEditBox:SetPoint("TOPLEFT", 180, -45)
    delayEditBox:SetAutoFocus(false)
    delayEditBox:SetNumeric(true)
    ConfigFrame.delayEditBox = delayEditBox
    
    -- 延迟时间输入框事件 - 立即保存
    delayEditBox:SetScript("OnEnterPressed", function()
        local delayValue = tonumber(delayEditBox:GetText()) or 5
        ScriptRunner.UI:SaveDelayOnly(delayValue)
        delayEditBox:ClearFocus()
    end)
    
    delayEditBox:SetScript("OnEscapePressed", function()
        -- 恢复原值
        if UIState.selectedScriptID then
            local script = ScriptRunner.Storage:GetScript(UIState.selectedScriptID)
            if script then
                delayEditBox:SetText(tostring(script.delay))
            end
        end
        delayEditBox:ClearFocus()
    end)
    
    
    -- 设置单选按钮事件
    autoRadio:SetScript("OnClick", function()
        ScriptRunner.UI:SetExecutionMode("auto")
        ScriptRunner.UI:SaveExecutionModeOnly("auto")
    end)
    
    delayRadio:SetScript("OnClick", function()
        ScriptRunner.UI:SetExecutionMode("delay")
        ScriptRunner.UI:SaveExecutionModeOnly("delay")
    end)
    
    manualRadio:SetScript("OnClick", function()
        ScriptRunner.UI:SetExecutionMode("manual")
        ScriptRunner.UI:SaveExecutionModeOnly("manual")
    end)
    
    EditorFrame.configFrame = ConfigFrame
end

-- 显示UI
function ScriptRunner.UI:Show()
    if not MainWindow then
        CreateMainWindow()
    end
    MainWindow:Show()
    UIState.isVisible = true
    self:RefreshScriptList()
end

-- 隐藏UI
function ScriptRunner.UI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
    UIState.isVisible = false
end

-- 切换UI显示状态
function ScriptRunner.UI:Toggle()
    if UIState.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

-- 刷新脚本列表
function ScriptRunner.UI:RefreshScriptList()
    if not ScriptListFrame or not ScriptListFrame.scrollChild then return end
    
    -- 清空现有列表
    for _, child in pairs({ScriptListFrame.scrollChild:GetChildren()}) do
        child:Hide()
    end
    
    local scripts = ScriptRunner.Storage:GetAllScripts()
    local yOffset = 0
    local buttonHeight = 25
    
    for scriptID, script in pairs(scripts) do
        local button = CreateFrame("Button", nil, ScriptListFrame.scrollChild, "BackdropTemplate")
        button:SetSize(230, buttonHeight)
        button:SetPoint("TOP", 0, -yOffset)
        
        -- 背景
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-Listbox-Highlight"
        })
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        
        -- 选中高亮
        if UIState.selectedScriptID == scriptID then
            button:SetBackdropColor(0.2, 0.6, 1, 0.3)
        end
        
        -- 脚本名称
        local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", 5, 0)
        nameText:SetText(script.name)
        if not script.enabled then
            nameText:SetTextColor(0.5, 0.5, 0.5)
        end
        
        -- 模式标识
        local modeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        modeText:SetPoint("RIGHT", -35, 0)
        local modeIcon = ""
        if script.mode == "auto" then
            modeIcon = "[A]"
        elseif script.mode == "delay" then
            modeIcon = "[D]"
        else
            modeIcon = "[M]"
        end
        modeText:SetText(modeIcon)
        
        -- 启用/禁用切换按钮
        local toggleButton = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
        toggleButton:SetSize(20, 20)
        toggleButton:SetPoint("RIGHT", -8, 0)
        toggleButton:SetChecked(script.enabled)
        toggleButton:SetScript("OnClick", function()
            local newEnabled = toggleButton:GetChecked()
            -- 直接更新启用状态
            local success, result = ScriptRunner.Storage:UpdateScript(scriptID, {
                enabled = newEnabled
            })
            
            if success then
                print("|cff00ff00ScriptRunner|r: 脚本 '" .. script.name .. "' 已" .. (newEnabled and "启用" or "禁用"))
                -- 刷新列表显示
                ScriptRunner.UI:RefreshScriptList()
            else
                print("|cffff0000ScriptRunner|r: 启用状态更新失败: " .. result)
                -- 恢复按钮状态
                toggleButton:SetChecked(script.enabled)
            end
        end)
        
        -- 点击事件（选择脚本）
        button:SetScript("OnClick", function()
            ScriptRunner.UI:SelectScript(scriptID)
        end)
        
        yOffset = yOffset + buttonHeight + 2
    end
    
    ScriptListFrame.scrollChild:SetHeight(yOffset)
end

-- 选择脚本
function ScriptRunner.UI:SelectScript(scriptID)
    UIState.selectedScriptID = scriptID
    local script = ScriptRunner.Storage:GetScript(scriptID)
    
    if script then
        -- 更新编辑器内容
        EditorFrame.nameEditBox:SetText(script.name)
        EditorFrame.codeEditBox:SetText(script.code)
        
        -- 更新配置
        self:SetExecutionMode(script.mode)
        ConfigFrame.delayEditBox:SetText(tostring(script.delay))
        
        -- 刷新列表显示
        self:RefreshScriptList()
    end
end

-- 创建新脚本
function ScriptRunner.UI:CreateNewScript()
    local newScript = ScriptRunner.Storage:CreateScript("新脚本", "", "manual", 5)
    self:SelectScript(newScript.id)
    self:RefreshScriptList()
end

-- 保存当前脚本
function ScriptRunner.UI:SaveCurrentScript()
    if not UIState.selectedScriptID then return end
    
    local name = EditorFrame.nameEditBox:GetText()
    local code = EditorFrame.codeEditBox:GetText()
    local delay = tonumber(ConfigFrame.delayEditBox:GetText()) or 5
    -- 从存储中获取当前启用状态，因为编辑器中不再有复选框
    local script = ScriptRunner.Storage:GetScript(UIState.selectedScriptID)
    local enabled = script and script.enabled or true
    
    -- 验证语法
    local isValid, errorMsg = ScriptRunner.Executor:ValidateScript(code)
    if not isValid then
        print("|cffff0000ScriptRunner|r: " .. errorMsg)
        return
    end
    
    -- 获取当前模式
    local mode = "manual"
    if ConfigFrame.autoRadio:GetChecked() then
        mode = "auto"
    elseif ConfigFrame.delayRadio:GetChecked() then
        mode = "delay"
    end
    
    -- 保存脚本
    local success, result = ScriptRunner.Storage:UpdateScript(UIState.selectedScriptID, {
        name = name,
        code = code,
        mode = mode,
        delay = delay,
        enabled = enabled
    })
    
    if success then
        print("|cff00ff00ScriptRunner|r: 脚本已保存")
        self:RefreshScriptList()
    else
        print("|cffff0000ScriptRunner|r: 保存失败: " .. result)
    end
end

-- 删除当前脚本
function ScriptRunner.UI:DeleteCurrentScript()
    if not UIState.selectedScriptID then return end
    
    -- 简单确认（可以改为弹出确认框）
    local script = ScriptRunner.Storage:GetScript(UIState.selectedScriptID)
    if script then
        ScriptRunner.Storage:DeleteScript(UIState.selectedScriptID)
        print("|cff00ff00ScriptRunner|r: 脚本 '" .. script.name .. "' 已删除")
        
        UIState.selectedScriptID = nil
        self:RefreshScriptList()
        
        -- 清空编辑器
        EditorFrame.nameEditBox:SetText("")
        EditorFrame.codeEditBox:SetText("")
    end
end

-- 执行当前脚本
function ScriptRunner.UI:ExecuteCurrentScript()
    if not UIState.selectedScriptID then return end
    
    local success, result = ScriptRunner.Executor:ExecuteManualScript(UIState.selectedScriptID)
    if success then
        print("|cff00ff00ScriptRunner|r: 脚本执行成功")
    else
        print("|cffff0000ScriptRunner|r: 脚本执行失败: " .. result)
    end
end

-- 设置执行模式
function ScriptRunner.UI:SetExecutionMode(mode)
    ConfigFrame.autoRadio:SetChecked(mode == "auto")
    ConfigFrame.delayRadio:SetChecked(mode == "delay")
    ConfigFrame.manualRadio:SetChecked(mode == "manual")
    
    -- 显示/隐藏延迟时间输入
    if mode == "delay" then
        ConfigFrame.delayEditBox:Show()
        ConfigFrame.delayLabel:Show()
    else
        ConfigFrame.delayEditBox:Hide()
        ConfigFrame.delayLabel:Hide()
    end
end

-- 只保存执行模式（立即生效）
function ScriptRunner.UI:SaveExecutionModeOnly(mode)
    if not UIState.selectedScriptID then return end
    
    -- 只更新执行模式
    local success, result = ScriptRunner.Storage:UpdateScript(UIState.selectedScriptID, {
        mode = mode
    })
    
    if success then
        print("|cff00ff00ScriptRunner|r: 执行模式已更新为 " .. 
              (mode == "auto" and "自动执行" or 
               mode == "delay" and "延迟执行" or "手动执行"))
        -- 刷新列表显示
        self:RefreshScriptList()
    else
        print("|cffff0000ScriptRunner|r: 执行模式更新失败: " .. result)
    end
end

-- 只保存延迟时间（立即生效）
function ScriptRunner.UI:SaveDelayOnly(delay)
    if not UIState.selectedScriptID then return end
    
    -- 验证延迟时间值
    if delay <= 0 then
        delay = 5
        ConfigFrame.delayEditBox:SetText("5")
    end
    
    -- 只更新延迟时间
    local success, result = ScriptRunner.Storage:UpdateScript(UIState.selectedScriptID, {
        delay = delay
    })
    
    if success then
        print("|cff00ff00ScriptRunner|r: 延迟时间已更新为 " .. delay .. " 秒")
    else
        print("|cffff0000ScriptRunner|r: 延迟时间更新失败: " .. result)
    end
end

-- 只保存启用状态（立即生效）
function ScriptRunner.UI:SaveEnabledOnly(enabled)
    if not UIState.selectedScriptID then return end
    
    -- 只更新启用状态
    local success, result = ScriptRunner.Storage:UpdateScript(UIState.selectedScriptID, {
        enabled = enabled
    })
    
    if success then
        print("|cff00ff00ScriptRunner|r: 脚本已" .. (enabled and "启用" or "禁用"))
        -- 刷新列表显示
        self:RefreshScriptList()
    else
        print("|cffff0000ScriptRunner|r: 启用状态更新失败: " .. result)
    end
end

-- 注册UI模块到全局
_G.ScriptRunner = ScriptRunner
