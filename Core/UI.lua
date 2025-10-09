-- ScriptRunner - UI module (Ace3 build)
-- Uses AceGUI to build the management window

local ScriptRunner = LibStub("AceAddon-3.0"):GetAddon("ScriptRunner")

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local UI = ScriptRunner:NewModule("UI", "AceEvent-3.0", "AceConsole-3.0")

local UIState = {
    isVisible = false,
    selectedScriptID = nil,
    currentTab = "scripts",
    frame = nil,
    scriptListScrollFrame = nil,
    editorContainer = nil,
    editorWidgets = nil,
}

function UI:OnInitialize()
end

function UI:OnEnable()
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_CREATED", "OnScriptChanged")
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_UPDATED", "OnScriptChanged")
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_DELETED", "OnScriptChanged")
    self:RegisterMessage("SCRIPTRUNNER_SCRIPT_TOGGLED", "OnScriptChanged")
end

function UI:OnDisable()
    self:Hide()
end

function UI:OnScriptChanged()
    if UIState.isVisible and UIState.currentTab == "scripts" then
        self:RefreshScriptList()
    end
end

function UI:CreateMainWindow()
    if UIState.frame then
        return UIState.frame
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("ScriptRunner")
    frame:SetStatusText("就绪")
    frame:SetLayout("Fill")
    frame:SetWidth(900)
    frame:SetHeight(650)
    frame:SetCallback("OnClose", function()
        self:Hide()
    end)

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs({
        { text = "脚本管理", value = "scripts" },
        { text = "设置", value = "settings" },
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        UIState.currentTab = group
        self:UpdateTabContent(container, group)
    end)
    tabGroup:SelectTab("scripts")

    frame:AddChild(tabGroup)

    UIState.frame = frame
    return frame
end

function UI:UpdateTabContent(container, group)
    container:ReleaseChildren()

    if group ~= "scripts" then
        UIState.scriptListScrollFrame = nil
        UIState.editorContainer = nil
        UIState.editorWidgets = nil
    end

    if group == "scripts" then
        self:CreateScriptsTab(container)
    elseif group == "settings" then
        self:CreateSettingsTab(container)
    end
end

function UI:CreateScriptsTab(container)
    local hGroup = AceGUI:Create("SimpleGroup")
    hGroup:SetLayout("Flow")
    hGroup:SetFullWidth(true)
    hGroup:SetFullHeight(true)
    container:AddChild(hGroup)

    local leftGroup = AceGUI:Create("SimpleGroup")
    leftGroup:SetRelativeWidth(0.32)
    leftGroup:SetFullHeight(true)
    leftGroup:SetLayout("List")
    hGroup:AddChild(leftGroup)

    local listHeader = AceGUI:Create("SimpleGroup")
    listHeader:SetLayout("Flow")
    listHeader:SetFullWidth(true)
    listHeader:SetHeight(40)
    leftGroup:AddChild(listHeader)

    local titleLabel = AceGUI:Create("Label")
    titleLabel:SetText("脚本列表")
    titleLabel:SetWidth(150)
    listHeader:AddChild(titleLabel)

    local newButton = AceGUI:Create("Button")
    newButton:SetText("新建脚本")
    newButton:SetWidth(130)
    newButton:SetCallback("OnClick", function()
        self:CreateNewScript()
    end)
    listHeader:AddChild(newButton)

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    leftGroup:AddChild(scrollFrame)

    UIState.scriptListScrollFrame = scrollFrame
    self:PopulateScriptList(scrollFrame)

    local rightGroup = AceGUI:Create("SimpleGroup")
    rightGroup:SetRelativeWidth(0.68)
    rightGroup:SetFullHeight(true)
    rightGroup:SetLayout("Fill")
    hGroup:AddChild(rightGroup)

    UIState.editorContainer = rightGroup
    self:CreateEditorPanel(rightGroup)
end

local function scriptSummaryText(script)
    local status = script.enabled and "|cff00ff00[启用]|r" or "|cffff0000[禁用]|r"
    local mode = "|cffcccccc[手动]|r"
    if script.mode == "auto" then
        mode = "|cff00ccff[自动]|r"
    elseif script.mode == "delay" then
        mode = string.format("|cffffcc00[延迟:%ds]|r", tonumber(script.delay) or 0)
    end
    return string.format("%s %s %s", status, mode, script.name or "未命名")
end

function UI:PopulateScriptList(scrollFrame)
    scrollFrame:ReleaseChildren()

    if not ScriptRunner.Storage then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000存储模块未加载|r")
        scrollFrame:AddChild(errorLabel)
        return
    end

    local scripts = ScriptRunner.Storage:GetAllScripts()
    if not scripts or next(scripts) == nil then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("暂无脚本\n点击“新建脚本”添加新条目")
        emptyLabel:SetColor(1, 1, 1)
        scrollFrame:AddChild(emptyLabel)
        return
    end

    for id, script in pairs(scripts) do
        local button = AceGUI:Create("InteractiveLabel")
        button:SetText(scriptSummaryText(script))
        button:SetFullWidth(true)

        if UIState.selectedScriptID == id then
            button:SetColor(0.2, 0.6, 1)
        else
            button:SetColor(1, 1, 1)
        end

        button:SetCallback("OnClick", function()
            self:SelectScript(id)
            self:PopulateScriptList(scrollFrame)
        end)

        scrollFrame:AddChild(button)
    end
end

function UI:CreateEditorPanel(container)
    container:ReleaseChildren()
    container:SetLayout("Fill")
    UIState.editorWidgets = nil

    local host
    if container.type == "ScrollFrame" then
        host = container
    else
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("List")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        container:AddChild(scroll)
        host = scroll
    end

    if not UIState.selectedScriptID then
        local info = AceGUI:Create("Label")
        info:SetText("请在左侧选择一个脚本进行编辑")
        info:SetColor(1, 1, 1)
        host:AddChild(info)
        return
    end

    if not ScriptRunner.Storage then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000存储模块未加载|r")
        host:AddChild(errorLabel)
        return
    end

    local script = ScriptRunner.Storage:GetScript(UIState.selectedScriptID)
    if not script then
        UIState.selectedScriptID = nil
        local missingLabel = AceGUI:Create("Label")
        missingLabel:SetText("|cffff0000未找到选中的脚本|r")
        missingLabel:SetColor(1, 0.2, 0.2)
        host:AddChild(missingLabel)
        return
    end

    local vGroup = AceGUI:Create("SimpleGroup")
    vGroup:SetLayout("Flow")
    vGroup:SetFullWidth(true)
    host:AddChild(vGroup)

    local nameGroup = AceGUI:Create("SimpleGroup")
    nameGroup:SetLayout("Flow")
    nameGroup:SetFullWidth(true)
    nameGroup:SetHeight(40)
    vGroup:AddChild(nameGroup)

    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText("名称:")
    nameLabel:SetWidth(60)
    nameGroup:AddChild(nameLabel)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetText(script.name or "")
    nameEdit:SetWidth(220)
    nameEdit:SetCallback("OnEnterPressed", function(_, value)
        ScriptRunner.Storage:UpdateScript(script.id, { name = value })
        self:RefreshScriptList()
    end)
    nameGroup:AddChild(nameEdit)

    local enabledCheck = AceGUI:Create("CheckBox")
    enabledCheck:SetLabel("启用")
    enabledCheck:SetValue(script.enabled)
    enabledCheck:SetWidth(80)
    enabledCheck:SetCallback("OnValueChanged", function(_, _, value)
        ScriptRunner.Storage:UpdateScript(script.id, { enabled = value })
        self:RefreshScriptList()
    end)
    nameGroup:AddChild(enabledCheck)

    local modeDropdown = AceGUI:Create("Dropdown")
    modeDropdown:SetLabel("执行模式")
    modeDropdown:SetList({
        manual = "手动执行",
        auto = "自动执行",
        delay = "延迟执行",
    })
    modeDropdown:SetValue(script.mode or "manual")
    modeDropdown:SetWidth(160)
    modeDropdown:SetCallback("OnValueChanged", function(_, _, value)
        ScriptRunner.Storage:UpdateScript(script.id, { mode = value })
        self:RefreshScriptList()
        self:CreateEditorPanel(container)
    end)
    nameGroup:AddChild(modeDropdown)

    local delayEdit
    if script.mode == "delay" then
        local delayLabel = AceGUI:Create("Label")
        delayLabel:SetText("延迟(秒):")
        delayLabel:SetWidth(70)
        nameGroup:AddChild(delayLabel)

        delayEdit = AceGUI:Create("EditBox")
        delayEdit:SetText(tostring(script.delay or 5))
        delayEdit:SetWidth(80)
        delayEdit:SetCallback("OnEnterPressed", function(_, value)
            local delay = tonumber(value) or 5
            if delay < 0 then delay = 0 end
            ScriptRunner.Storage:UpdateScript(script.id, { delay = delay })
            self:CreateEditorPanel(container)
        end)
        nameGroup:AddChild(delayEdit)
    end

    local codeLabel = AceGUI:Create("Label")
    codeLabel:SetText("代码:")
    codeLabel:SetFullWidth(true)
    vGroup:AddChild(codeLabel)

    local codeEdit = AceGUI:Create("MultiLineEditBox")
    codeEdit:SetFullWidth(true)
    codeEdit:SetNumLines(20)
    codeEdit:SetLabel("")
    codeEdit:SetText(script.code or "")
    codeEdit:SetCallback("OnTextChanged", function(_, _, value)
        script.code = value
    end)
    vGroup:AddChild(codeEdit)

    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetFullWidth(true)
    vGroup:AddChild(buttonGroup)

    local saveButton = AceGUI:Create("Button")
    saveButton:SetText("保存")
    saveButton:SetWidth(90)
    saveButton:SetCallback("OnClick", function()
        self:SaveCurrentScript()
    end)
    buttonGroup:AddChild(saveButton)

    local runButton = AceGUI:Create("Button")
    runButton:SetText("执行")
    runButton:SetWidth(90)
    runButton:SetCallback("OnClick", function()
        self:ExecuteCurrentScript()
    end)
    buttonGroup:AddChild(runButton)

    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText("删除")
    deleteButton:SetWidth(90)
    deleteButton:SetCallback("OnClick", function()
        self:DeleteCurrentScript()
    end)
    buttonGroup:AddChild(deleteButton)

    UIState.editorWidgets = {
        nameEdit = nameEdit,
        enabledCheck = enabledCheck,
        modeDropdown = modeDropdown,
        delayEdit = delayEdit,
        codeEdit = codeEdit,
    }
end

function UI:CreateSettingsTab(container)
    local vGroup = AceGUI:Create("SimpleGroup")
    vGroup:SetLayout("List")
    vGroup:SetFullWidth(true)
    container:AddChild(vGroup)

    local header = AceGUI:Create("Label")
    header:SetText(string.format("ScriptRunner v%s", ScriptRunner.version or ""))
    header:SetColor(1, 0.82, 0)
    vGroup:AddChild(header)

    local openConfigButton = AceGUI:Create("Button")
    openConfigButton:SetText("Open Config Panel")
    openConfigButton:SetCallback("OnClick", function()
        AceConfigDialog:Open("ScriptRunner")
    end)
    vGroup:AddChild(openConfigButton)

    local statsButton = AceGUI:Create("Button")
    statsButton:SetText("Show Statistics")
    statsButton:SetWidth(150)
    statsButton:SetCallback("OnClick", function()
        ScriptRunner:ShowStats()
    end)
    vGroup:AddChild(statsButton)

    local validateButton = AceGUI:Create("Button")
    validateButton:SetText("Validate All Scripts")
    validateButton:SetWidth(150)
    validateButton:SetCallback("OnClick", function()
        ScriptRunner:ValidateAllScripts()
    end)
    vGroup:AddChild(validateButton)
end

function UI:Show()
    local frame = self:CreateMainWindow()
    frame:Show()
    UIState.isVisible = true
    self:RefreshScriptList()
end

function UI:Hide()
    if UIState.frame then
        UIState.frame:Hide()
    end
    UIState.isVisible = false
end

function UI:Toggle()
    if UIState.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function UI:RefreshScriptList()
    if UIState.isVisible and UIState.currentTab == "scripts" and UIState.scriptListScrollFrame then
        self:PopulateScriptList(UIState.scriptListScrollFrame)
    end
end

function UI:SelectScript(scriptID)
    UIState.selectedScriptID = scriptID

    if UIState.isVisible and UIState.currentTab == "scripts" then
        if UIState.editorContainer then
            self:CreateEditorPanel(UIState.editorContainer)
        end
        self:RefreshScriptList()
    end
end

function UI:CreateNewScript()
    if not ScriptRunner.Storage then
        print("|cffff0000ScriptRunner|r: 存储模块未加载")
        return
    end

    local newScript = ScriptRunner.Storage:CreateScript("新脚本", "-- 新脚本\n", "manual", 5)
    self:SelectScript(newScript.id)
    self:RefreshScriptList()
end

function UI:SaveCurrentScript()
    if not UIState.selectedScriptID or not ScriptRunner.Storage then
        return
    end

    local widgets = UIState.editorWidgets
    if not widgets then
        return
    end

    local updates = {}
    if widgets.codeEdit then
        updates.code = widgets.codeEdit:GetText() or ""
    end
    if widgets.modeDropdown then
        updates.mode = widgets.modeDropdown:GetValue()
    end
    if widgets.delayEdit then
        local delay = tonumber(widgets.delayEdit:GetText())
        if delay and delay >= 0 then
            updates.delay = delay
        end
    end

    local success, result = ScriptRunner.Storage:UpdateScript(UIState.selectedScriptID, updates)
    if success then
        print("|cff00ff00ScriptRunner|r: 脚本已保存")
        self:RefreshScriptList()
    else
        print("|cffff0000ScriptRunner|r: 保存失败: " .. tostring(result))
    end
end

function UI:DeleteCurrentScript()
    if not UIState.selectedScriptID or not ScriptRunner.Storage then
        return
    end

    local script = ScriptRunner.Storage:GetScript(UIState.selectedScriptID)
    if not script then
        return
    end

    local dialogKey = "SCRIPTRUNNER_DELETE_SCRIPT_CONFIRM"
    StaticPopupDialogs[dialogKey] = {
        text = string.format("确认删除脚本 '%s' 吗？\n\n该操作无法撤销。", script.name or "未命名"),
        button1 = "删除",
        button2 = "取消",
        OnAccept = function()
            ScriptRunner.Storage:DeleteScript(script.id)
            print(string.format("|cff00ff00ScriptRunner|r: 脚本 '%s' 已删除", script.name or "未命名"))
            UIState.selectedScriptID = nil
            self:RefreshScriptList()
            if UIState.editorContainer then
                self:CreateEditorPanel(UIState.editorContainer)
            end
        end,
        timeout = 0,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(dialogKey)
end

function UI:ExecuteCurrentScript()
    if not UIState.selectedScriptID or not ScriptRunner.Executor then
        return
    end

    local success, result = ScriptRunner.Executor:ExecuteManualScript(UIState.selectedScriptID)
    if success then
        print("|cff00ff00ScriptRunner|r: 脚本执行成功")
    else
        print("|cffff0000ScriptRunner|r: 脚本执行失败: " .. tostring(result))
    end
end

ScriptRunner.UI = UI
