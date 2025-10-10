-- ScriptRunner - UI module (Standalone)

local UI = {}
local addon, Storage, Executor

-- UI element references
local F

-- State
local isVisible = false
local currentTab = 1
local selectedScriptID = nil

local LIST_ENTRY_HEIGHT = 28
local LIST_ENTRY_GAP = 4

function UI:Initialize(mainAddon)
    addon = mainAddon
    Storage = addon.Storage
    Executor = addon.Executor

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
            codeScroll = ScriptRunnerFrameScriptsPageEditorCodeScroll,
            code = ScriptRunnerFrameScriptsPageEditorCodeScrollCode,
            saveButton = ScriptRunnerFrameScriptsPageEditorSave,
            deleteButton = ScriptRunnerFrameScriptsPageEditorDelete,
            newButton = ScriptRunnerFrameScriptsPageEditorNew,
            runButton = ScriptRunnerFrameScriptsPageEditorRun,
            modeDropdown = ScriptRunnerFrameScriptsPageEditorModeDropdown,
            delayInput = ScriptRunnerFrameScriptsPageEditorDelay,
        }
    }
    F.scriptListButtons = {}

    if F.main and F.main.SetBackdrop then
        F.main:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        F.main:SetBackdropColor(0, 0, 0, 0.8)
    end

    -- Register frame events
    F.main:SetScript("OnShow", function() self:OnShow() end)
    F.main:SetScript("OnHide", function() self:OnHide() end)
    F.main:SetMovable(true)
    F.main:EnableMouse(true)
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
        F.tabs[2]:SetScript("OnClick", function() self:SelectTab(2) end)
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

    self:ConfigureEditorWidgets()
    self:SelectTab(1)
end

function UI:OnShow()
    isVisible = true
    self:Refresh()
    self:ResizeCodeEditor()
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
        local statusText = entry.script.enabled and "|cff00ff00[ON]|r" or "|cffff2020[OFF]|r"
        button.text:SetText(statusText .. " " .. (entry.script.name or "Unnamed"))
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
    else
        if F.editor.name then F.editor.name:SetText("") end
        if F.editor.code then
            F.editor.code:SetText("")
        end
        if F.editor.delayInput then F.editor.delayInput:SetText("5") end
        if F.editor.modeDropdown then UIDropDownMenu_SetText(F.editor.modeDropdown, "manual") end

        if F.editor.saveButton then F.editor.saveButton:Disable() end
        if F.editor.deleteButton then F.editor.deleteButton:Disable() end
        if F.editor.runButton then F.editor.runButton:Disable() end
    end

    self:ResizeCodeEditor()
end

function UI:SaveSelectedScript()
    if not selectedScriptID then return end
    local updates = {
        name = F.editor.name and F.editor.name:GetText() or "",
        code = F.editor.code and F.editor.code:GetText() or "",
        delay = tonumber(F.editor.delayInput and F.editor.delayInput:GetText() or "5") or 5,
        mode = F.editor.modeDropdown and UIDropDownMenu_GetText(F.editor.modeDropdown) or "manual",
    }
    Storage:UpdateScript(selectedScriptID, updates)
    self:Refresh()
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
        print(string.format("|cffff0000%s|r: Script data not found.", addon and addon.title or "ScriptRunner"))
        return
    end
    local success, message = Executor:ExecuteManualScript(selectedScriptID)
    local scriptName = script.name or selectedScriptID
    if success then
        print(string.format("|cff00ff00%s|r: '%s' executed.", addon and addon.title or "ScriptRunner", scriptName))
    else
        print(string.format("|cffff0000%s|r: '%s' failed: %s", addon and addon.title or "ScriptRunner", scriptName, tostring(message)))
    end
end

function UI:RefreshSettingsPage()
end

function UI:ConfigureEditorWidgets()
    if not F.editor or not F.editor.code or not F.editor.codeScroll then return end
    local editBox = F.editor.code
    local scrollFrame = F.editor.codeScroll
    
    if editBox._configured then self:ResizeCodeEditor() return end
    editBox._configured = true
    
    -- 强制启用编辑框的基本属性
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetEnabled(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(8, 8, 8, 8)
    editBox:SetTextColor(1, 1, 1, 1)
    
    -- 设置文本选择高亮颜色
    editBox:SetHighlightColor(0.3, 0.5, 0.9, 0.5)
    
    -- 创建自定义光标 - 使用更高层级
    if not editBox.customCursor then
        local cursor = editBox:CreateTexture(nil, "HIGHLIGHT")
        cursor:SetColorTexture(1, 1, 1, 0.9)
        cursor:SetWidth(2)
        cursor:SetHeight(16)
        cursor:SetDrawLayer("HIGHLIGHT", 7)  -- 最高层级
        cursor:Hide()
        editBox.customCursor = cursor
        editBox.cursorBlinkTime = 0
        editBox.cursorVisible = true
    end
    
    -- 文本改变事件
    editBox:SetScript("OnTextChanged", function(self, userInput)
        ScrollingEdit_OnTextChanged(self, scrollFrame)
        UI:ResizeCodeEditor()
    end)
    
    -- 光标改变事件 - 更新自定义光标位置
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        ScrollingEdit_OnCursorChanged(self, x, y, w, h)
        -- 更新自定义光标位置
        if self.customCursor and self:HasFocus() then
            self.customCursor:ClearAllPoints()
            -- 使用传入的坐标直接定位
            self.customCursor:SetPoint("TOPLEFT", self, "TOPLEFT", x + 8, -(y + 8))
            self.customCursor:Show()
            self.cursorVisible = true
            self.cursorBlinkTime = 0
        end
    end)
    
    -- 更新循环 - 光标闪烁
    editBox:SetScript("OnUpdate", function(self, elapsed)
        if self:HasFocus() and self.customCursor then
            self.cursorBlinkTime = self.cursorBlinkTime + elapsed
            if self.cursorBlinkTime >= 0.5 then
                self.cursorBlinkTime = 0
                self.cursorVisible = not self.cursorVisible
                self.customCursor:SetAlpha(self.cursorVisible and 0.8 or 0.2)
            end
        end
    end)
    
    -- 焦点事件
    editBox:SetScript("OnEditFocusGained", function(self)
        -- 清除默认全选，显示光标
        self:HighlightText(0, 0)
        if self.customCursor then
            self.customCursor:Show()
            self.cursorVisible = true
            self.cursorBlinkTime = 0
        end
    end)
    
    editBox:SetScript("OnEditFocusLost", function(self)
        if self.customCursor then
            self.customCursor:Hide()
        end
    end)
    
    -- 鼠标拖动选择
    local isMouseDown = false
    local dragStartTextPos = nil
    local mouseStartX, mouseStartY = nil, nil
    local hasMoved = false
    
    editBox:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:SetFocus()
            isMouseDown = true
            hasMoved = false
            dragStartTextPos = self:GetCursorPosition()
            -- 记录鼠标屏幕坐标
            mouseStartX, mouseStartY = GetCursorPosition()
            -- 清除之前的选择
            self:HighlightText(0, 0)
        end
    end)
    
    editBox:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isMouseDown then
            -- 只有真正移动过鼠标才选择
            if hasMoved and dragStartTextPos then
                local endPos = self:GetCursorPosition()
                if dragStartTextPos ~= endPos then
                    local startSel = math.min(dragStartTextPos, endPos)
                    local endSel = math.max(dragStartTextPos, endPos)
                    self:HighlightText(startSel, endSel)
                end
            end
            isMouseDown = false
            hasMoved = false
            dragStartTextPos = nil
            mouseStartX, mouseStartY = nil, nil
        end
    end)
    
    -- 检测鼠标移动并实时更新选择
    local dragCheckTimer = 0
    editBox:HookScript("OnUpdate", function(self, elapsed)
        -- 拖动检测 - 检查鼠标坐标是否移动
        if isMouseDown and mouseStartX and dragStartTextPos then
            dragCheckTimer = dragCheckTimer + elapsed
            if dragCheckTimer >= 0.02 then  -- 每20ms检查一次
                dragCheckTimer = 0
                
                local currentX, currentY = GetCursorPosition()
                local threshold = 3  -- 移动阈值（像素）
                
                -- 检查鼠标是否真的移动了
                if math.abs(currentX - mouseStartX) > threshold or math.abs(currentY - mouseStartY) > threshold then
                    hasMoved = true
                    -- 获取当前光标文本位置并更新选择
                    local currentTextPos = self:GetCursorPosition()
                    if currentTextPos ~= dragStartTextPos then
                        local startSel = math.min(dragStartTextPos, currentTextPos)
                        local endSel = math.max(dragStartTextPos, currentTextPos)
                        self:HighlightText(startSel, endSel)
                    end
                end
            end
        end
    end)
    
    -- Tab和Enter键
    editBox:SetScript("OnTabPressed", function(self)
        self:Insert("    ")
    end)
    
    editBox:SetScript("OnEnterPressed", function(self)
        self:Insert("\n")
    end)
    
    -- Ctrl+A全选
    editBox:SetScript("OnKeyDown", function(self, key)
        if IsControlKeyDown() and key == "A" then
            self:HighlightText()
            self:SetCursorPosition(self:GetText():len())
        end
    end)

    -- 创建测量用的FontString
    if not F.editor.measure then
        local measure = scrollFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        measure:SetJustifyH("LEFT")
        measure:SetJustifyV("TOP")
        measure:Hide()
        F.editor.measure = measure
    end

    scrollFrame:HookScript("OnSizeChanged", function() UI:ResizeCodeEditor() end)
    self:ResizeCodeEditor()
end

function UI:ResizeCodeEditor()
    if not F.editor or not F.editor.code or not F.editor.codeScroll then return end
    local scrollFrame = F.editor.codeScroll
    local editBox = F.editor.code
    local scrollWidth = scrollFrame:GetWidth()
    if scrollWidth <= 0 then scrollWidth = 600 end
    local availableWidth = scrollWidth - 22
    if availableWidth < 200 then availableWidth = 200 end
    editBox:SetWidth(availableWidth)
    local minHeight = scrollFrame:GetHeight()
    if minHeight <= 0 then minHeight = 200 end
    local textHeight
    if F.editor.measure then
        local measure = F.editor.measure
        measure:SetFontObject(editBox:GetFontObject())
        measure:SetWidth(availableWidth)
        measure:SetText(editBox:GetText() or "")
        textHeight = measure:GetStringHeight()
    end
    if not textHeight or textHeight == 0 then
        local _, fontHeight = editBox:GetFont()
        textHeight = (fontHeight or 14) * 4
    end
    local contentHeight = textHeight + 18
    if contentHeight < minHeight then contentHeight = minHeight end
    editBox:SetHeight(contentHeight)
    scrollFrame:UpdateScrollChildRect()
end

function UI_ModeDropDown_Initialize(dropdown)
    UIDropDownMenu_Initialize(dropdown, function()
        local info = {}
        info.text = "manual"
        info.value = "manual"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "manual")
            F.editor.delayInput:SetEnabled(false) 
        end
        UIDropDownMenu_AddButton(info)

        info = {}
        info.text = "auto"
        info.value = "auto"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "auto")
            F.editor.delayInput:SetEnabled(false) 
        end
        UIDropDownMenu_AddButton(info)

        info = {}
        info.text = "delay"
        info.value = "delay"
        info.func = function() 
            UIDropDownMenu_SetSelectedValue(dropdown, "delay")
            F.editor.delayInput:SetEnabled(true)
        end
        UIDropDownMenu_AddButton(info)
    end)
end

ScriptRunner.UI = UI
