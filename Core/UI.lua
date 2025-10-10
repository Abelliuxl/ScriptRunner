-- Core/UI.lua
local ADDON_NAME = "ScriptRunner"
local ScriptRunner = _G[ADDON_NAME]

local UI = {}
ScriptRunner.UI = UI

local Storage, Executor, Editor

-- UI element references
local F

-- State
local isVisible = false
local currentTab = 1
local selectedScriptID = nil
local isDirty = false -- Track if current script has unsaved changes
local originalScriptData = {} -- Store original script data for comparison

local LIST_ENTRY_HEIGHT = 28
local LIST_ENTRY_GAP = 4

function UI:Initialize(mainAddon)
    Storage = mainAddon.Storage
    Executor = mainAddon.Executor
    Editor = mainAddon.Editor

    -- Frame references from UI.xml
    F = {
        main = ScriptRunnerFrame,
        title = ScriptRunnerFrameTitle,
        closeButton = ScriptRunnerFrameCloseButton,
        tabs = {
            [1] = ScriptRunnerFrameTab1,
            [2] = ScriptRunnerFrameTab2,
        },
        pages = {
            [1] = ScriptRunnerFrameScriptsPage,
            [2] = ScriptRunnerFrameSettingsPage,
        },
        scriptList = ScriptRunnerFrameScriptsPageList,
        scriptListContent = ScriptRunnerFrameScriptsPageListContent,
        scriptListButtons = {},
        editor = {
            name = ScriptRunnerFrameScriptsPageEditorName,
            editorContainer = ScriptRunnerFrameScriptsPageEditorEditorContainer,
            saveButton = ScriptRunnerFrameScriptsPageEditorSave,
            saveStatus = ScriptRunnerFrameScriptsPageEditorSaveStatus,
            deleteButton = ScriptRunnerFrameScriptsPageEditorDelete,
            newButton = ScriptRunnerFrameScriptsPageEditorNew,
            runButton = ScriptRunnerFrameScriptsPageEditorRun,
            modeDropdown = ScriptRunnerFrameScriptsPageEditorModeDropdown,
            delayInput = ScriptRunnerFrameScriptsPageEditorDelay,
        }
    }
    F.scriptListButtons = {}
    
    -- Create editor with proper parenting
    if F.editor.editorContainer then
        F.editor.code = Editor:Create(F.editor.editorContainer)
    else
        print("|cffff0000ScriptRunner|r: Editor container not found!")
    end

    if F.main and F.main.SetBackdrop then
        F.main:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    -- Register frame events
    F.main:SetScript("OnShow", function() self:OnShow() end)
    F.main:SetScript("OnHide", function() self:OnHide() end)
    F.main:SetMovable(true)
    F.main:RegisterForDrag("LeftButton")
    F.main:SetScript("OnDragStart", F.main.StartMoving)
    F.main:SetScript("OnDragStop", F.main.StopMovingOrSizing)


    -- Button logic
    if F.closeButton then
        F.closeButton:SetScript("OnClick", function() self:Hide() end)
    end
    if F.tabs[1] then
        F.tabs[1]:SetScript("OnClick", function() self:SelectTab(1) end)
    end
    if F.tabs[2] then
        F.tabs[2]:SetScript("OnClick", function() self:ReloadUI() end)
    end

    if F.editor.saveButton then
        F.editor.saveButton:SetScript("OnClick", function() self:SaveSelectedScript() end)
    end
    if F.editor.deleteButton then
        F.editor.deleteButton:SetScript("OnClick", function() self:DeleteSelectedScript() end)
    end
    if F.editor.newButton then
        F.editor.newButton:SetScript("OnClick", function() self:CreateNewScript() end)
    end
    if F.editor.runButton then
        F.editor.runButton:SetScript("OnClick", function() self:RunSelectedScript() end)
    end

    -- Initialize tabs
    PanelTemplates_SetNumTabs(F.main, 2)
    if F.editor.modeDropdown then
        UI_ModeDropDown_Initialize(F.editor.modeDropdown)
        UIDropDownMenu_SetWidth(F.editor.modeDropdown, 120)
        UIDropDownMenu_JustifyText(F.editor.modeDropdown, "LEFT")
    end

    self:SelectTab(1)
end

function UI:OnShow()
    isVisible = true
    self:Refresh()
end

function UI:OnHide()
    isVisible = false
end

function UI:Show()
    F.main:Show()
end

function UI:Hide()
    F.main:Hide()
end

function UI:Toggle()
    if F.main:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:SelectTab(tabIndex)
    currentTab = tabIndex

    for i, tab in pairs(F.tabs) do
        if i == tabIndex then
            tab:Disable()
        else
            tab:Enable()
        end
    end

    for i, page in pairs(F.pages) do
        if i == tabIndex then
            page:Show()
        else
            page:Hide()
        end
    end
    self:Refresh()
end

function UI:Refresh()
    if not F.main:IsShown() then return end

    if currentTab == 1 then
        self:RefreshScriptsPage()
    elseif currentTab == 2 then
        self:RefreshSettingsPage()
    end
end

function UI:RefreshScriptsPage()
    self:RefreshScriptList()
    self:RefreshEditor()
end

function UI:RefreshScriptList()
    local scrollFrame = F.scriptList
    local content = F.scriptListContent
    if not scrollFrame or not content then return end

    local scripts = Storage:GetAllScripts()
    local ordered = {}
    for id, script in pairs(scripts) do
        table.insert(ordered, { id = id, script = script })
    end

    table.sort(ordered, function(a, b)
        return (a.script.name or "") < (b.script.name or "")
    end)

    local selectedExists = false
    for _, entry in ipairs(ordered) do
        if entry.id == selectedScriptID then
            selectedExists = true
            break
        end
    end
    if not selectedExists then
        selectedScriptID = ordered[1] and ordered[1].id or nil
    end

    local buttons = F.scriptListButtons
    local totalHeight = 0

    local contentWidth = math.max(scrollFrame:GetWidth() - 20, 1)
    content:SetWidth(contentWidth)

    for index, entry in ipairs(ordered) do
        local button = buttons[index]
        if not button then
            button = CreateFrame("Button", content:GetName() .. "Button" .. index, content, "BackdropTemplate")
            button:SetHeight(LIST_ENTRY_HEIGHT)
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            button:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

            button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
            local highlight = button:GetHighlightTexture()
            if highlight then
                highlight:SetBlendMode("ADD")
                highlight:SetAlpha(0.5)
            end

            button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            button.text:SetJustifyH("LEFT")
            button.text:SetWordWrap(false)

            button.toggle = CreateFrame("CheckButton", button:GetName() .. "Toggle", button, "ChatConfigCheckButtonTemplate")
            button.toggle:SetPoint("RIGHT", button, "RIGHT", -6, 0)
            button.toggle:SetScale(0.9)
            button.toggle:SetHitRectInsets(0, -10, 0, 0)
            local label = _G[button.toggle:GetName() .. "Text"]
            if label then
                label:Hide()
            end
            button.toggle:SetScript("OnClick", function(toggle)
                local parent = toggle:GetParent()
                if parent and parent.scriptID then
                    UI:ToggleScriptEnabled(parent.scriptID, toggle:GetChecked())
                end
            end)

            button:SetScript("OnClick", function(b)
                UI:SelectScript(b.scriptID)
            end)

            buttons[index] = button
        end

        button:ClearAllPoints()
        button:SetPoint("LEFT", content, "LEFT", 0, 0)
        button:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        if index == 1 then
            button:SetPoint("TOP", content, "TOP", 0, 0)
        else
            button:SetPoint("TOP", buttons[index - 1], "BOTTOM", 0, -LIST_ENTRY_GAP)
        end

        button.scriptID = entry.id
        
        -- Create mode indicators
        local modeIndicator = ""
        if entry.script.mode == "auto" then
            modeIndicator = "|cff00ccff[A]|r"
        elseif entry.script.mode == "delay" then
            modeIndicator = "|cffffcc00[D]|r"
        else
            modeIndicator = "|cff888888[M]|r"
        end
        
        -- Create status indicators
        local statusText = entry.script.enabled and "|cff00ff00[ON]|r" or "|cffff2020[OFF]|r"
        
        -- Combine all indicators: Mode + Status + Name
        local displayText = string.format("%s %s %s", modeIndicator, statusText, entry.script.name or "Unnamed")
        button.text:SetText(displayText)
        button.text:SetFontObject(entry.script.enabled and GameFontHighlightSmall or GameFontDisableSmall)
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button, "LEFT", 12, 0)
        if button.toggle then
            button.text:SetPoint("RIGHT", button.toggle, "LEFT", -8, 0)
            button.toggle:SetChecked(entry.script.enabled)
        else
            button.text:SetPoint("RIGHT", button, "RIGHT", -12, 0)
        end

        if entry.id == selectedScriptID then
            button:SetBackdropColor(0.07, 0.18, 0.40, 0.95)
            button:SetBackdropBorderColor(0.25, 0.55, 0.95, 1)
        elseif entry.script.enabled then
            button:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
        else
            button:SetBackdropColor(0.04, 0.04, 0.04, 0.65)
            button:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
        end

        button:Show()

        totalHeight = totalHeight + LIST_ENTRY_HEIGHT
        if index > 1 then
            totalHeight = totalHeight + LIST_ENTRY_GAP
        end
    end

    for i = #ordered + 1, #buttons do
        buttons[i]:Hide()
    end

    if #ordered == 0 then
        if not content.emptyText then
            local emptyText = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
            emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            emptyText:SetPoint("RIGHT", content, "RIGHT", -8, 0)
            emptyText:SetJustifyH("LEFT")
            emptyText:SetText("No scripts available.")
            content.emptyText = emptyText
        end
        content.emptyText:Show()
        totalHeight = LIST_ENTRY_HEIGHT
    elseif content.emptyText then
        content.emptyText:Hide()
    end

    content:SetHeight(math.max(totalHeight, scrollFrame:GetHeight()))
    scrollFrame:UpdateScrollChildRect()
end

function UI:ToggleScriptEnabled(scriptID, shouldEnable)
    if not scriptID then return end

    local success = Storage:UpdateScript(scriptID, { enabled = shouldEnable })
    if scriptID == selectedScriptID and success then
        self:RefreshEditor()
    end
    self:RefreshScriptList()
end

function UI:SelectScript(scriptID)
    selectedScriptID = scriptID
    self:Refresh()
end

function UI:RefreshEditor()
    local script
    if selectedScriptID then
        script = Storage:GetScript(selectedScriptID)
    end

    if script then
        if F.editor.name then F.editor.name:SetText(script.name or "") end
        if F.editor.code then
            F.editor.code:SetText(script.code or "")
            F.editor.code:SetCursorPosition(0)
        end
        if F.editor.delayInput then F.editor.delayInput:SetText(tostring(script.delay or 5)) end
        if F.editor.modeDropdown then
            UIDropDownMenu_SetText(F.editor.modeDropdown, script.mode or "manual")
            if F.editor.delayInput then F.editor.delayInput:SetEnabled(script.mode == 'delay') end
        end

        if F.editor.saveButton then F.editor.saveButton:Enable() end
        if F.editor.deleteButton then F.editor.deleteButton:Enable() end
        if F.editor.runButton then F.editor.runButton:Enable() end
        
        -- Store original data for comparison
        originalScriptData = {
            name = script.name or "",
            code = script.code or "",
            delay = tostring(script.delay or 5),
            mode = script.mode or "manual"
        }
        isDirty = false
    else
        if F.editor.name then F.editor.name:SetText("") end
        if F.editor.code then F.editor.code:SetText("") end
        if F.editor.delayInput then F.editor.delayInput:SetText("5") end
        if F.editor.modeDropdown then UIDropDownMenu_SetText(F.editor.modeDropdown, "manual") end

        if F.editor.saveButton then F.editor.saveButton:Disable() end
        if F.editor.deleteButton then F.editor.deleteButton:Disable() end
        if F.editor.runButton then F.editor.runButton:Disable() end
        
        -- Clear original data for new script
        originalScriptData = {
            name = "",
            code = "",
            delay = "5",
            mode = "manual"
        }
        isDirty = false
    end
    
    -- Add change detection hooks
    self:HookEditorChanges()
    
    if Editor and Editor.Resize then
        Editor:Resize()
    end
    
    -- Update save status display
    self:UpdateSaveStatus()
end

function UI:HookEditorChanges()
    -- Hook name changes
    if F.editor.name then
        F.editor.name:SetScript("OnTextChanged", function()
            self:CheckForChanges()
        end)
    end
    
    -- Hook code changes
    if F.editor.code then
        F.editor.code:SetScript("OnTextChanged", function()
            self:CheckForChanges()
        end)
    end
    
    -- Hook delay changes
    if F.editor.delayInput then
        F.editor.delayInput:SetScript("OnTextChanged", function()
            self:CheckForChanges()
        end)
    end
end

function UI:CheckForChanges()
    if not selectedScriptID or not originalScriptData then return end
    
    local currentName = F.editor.name and F.editor.name:GetText() or ""
    local currentCode = F.editor.code and F.editor.code:GetText() or ""
    local currentDelay = F.editor.delayInput and F.editor.delayInput:GetText() or "5"
    local currentMode = F.editor.modeDropdown and UIDropDownMenu_GetText(F.editor.modeDropdown) or "manual"
    
    -- Check if any field has changed
    local hasChanges = (
        currentName ~= originalScriptData.name or
        currentCode ~= originalScriptData.code or
        currentDelay ~= originalScriptData.delay or
        currentMode ~= originalScriptData.mode
    )
    
    if hasChanges ~= isDirty then
        isDirty = hasChanges
        self:UpdateSaveStatus()
    end
end

function UI:UpdateSaveStatus()
    if F.editor.saveStatus then
        if isDirty then
            F.editor.saveStatus:SetText("修改未保存")
            F.editor.saveStatus:Show()
        else
            F.editor.saveStatus:SetText("")
            F.editor.saveStatus:Hide()
        end
    end
end

function UI:SaveSelectedScript()
    if not selectedScriptID then return end
    
    local code = ""
    if F.editor.code then
        code = F.editor.code:GetText()
    end

    local updates = {
        name = F.editor.name and F.editor.name:GetText() or "",
        code = code,
        delay = tonumber(F.editor.delayInput and F.editor.delayInput:GetText() or "5") or 5,
        mode = F.editor.modeDropdown and UIDropDownMenu_GetText(F.editor.modeDropdown) or "manual",
    }
    Storage:UpdateScript(selectedScriptID, updates)
    
    -- Update original data after successful save
    originalScriptData = {
        name = updates.name,
        code = updates.code,
        delay = tostring(updates.delay),
        mode = updates.mode
    }
    isDirty = false
    self:UpdateSaveStatus()
    
    -- Refresh script list to show updated name
    self:RefreshScriptList()
end

function UI:DeleteSelectedScript()
    if not selectedScriptID then return end
    Storage:DeleteScript(selectedScriptID)
    selectedScriptID = nil
    self:Refresh()
end

function UI:CreateNewScript()
    local newScript = Storage:CreateScript("New Script", "-- Your code here", "manual", 5)
    self:SelectScript(newScript.id)
end

function UI:RunSelectedScript()
    if not selectedScriptID then return end
    local script = Storage and Storage:GetScript(selectedScriptID)
    if not script then
        print(string.format("|cffff0000%s|r: Script data not found.", addonName or "ScriptRunner"))
        return
    end
    local success, message = Executor:ExecuteManualScript(selectedScriptID)
    local scriptName = script.name or selectedScriptID
    if success then
        print(string.format("|cff00ff00%s|r: '%s' executed.", addonName or "ScriptRunner", scriptName))
    else
        print(string.format("|cffff0000%s|r: '%s' failed: %s", addonName or "ScriptRunner", scriptName, tostring(message)))
    end
end

function UI:ReloadUI()
    ReloadUI()
end

function UI:RefreshSettingsPage()
end

function UI_ModeDropDown_Initialize(dropdown)
    UIDropDownMenu_Initialize(dropdown, function()
        local info = {}
        info.text = "manual"
        info.value = "manual"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "manual")
            F.editor.delayInput:SetEnabled(false)
            UI:CheckForChanges()
        end
        UIDropDownMenu_AddButton(info)

        info = {}
        info.text = "auto"
        info.value = "auto"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "auto")
            F.editor.delayInput:SetEnabled(false)
            UI:CheckForChanges()
        end
        UIDropDownMenu_AddButton(info)

        info = {}
        info.text = "delay"
        info.value = "delay"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "delay")
            F.editor.delayInput:SetEnabled(true)
            UI:CheckForChanges()
        end
        UIDropDownMenu_AddButton(info)
    end)
end
