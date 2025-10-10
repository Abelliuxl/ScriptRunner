-- Core/Editor.lua
local ADDON_NAME = "ScriptRunner"
local ScriptRunner = _G[ADDON_NAME]

local Editor = {}
ScriptRunner.Editor = Editor

local F = {} -- Frame container

function Editor:Initialize(mainAddon)
    -- This module is initialized by UI.lua
end

function Editor:Create(parent)
    local frame = CreateFrame("Frame", "ScriptRunnerEditorFrameInstance", parent, "ScriptRunnerEditorFrame")
    frame:SetAllPoints(parent) -- Set all points to parent to ensure it fills the container.
    
    -- Set frame level to ensure it's above parent but still part of it
    frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    
    -- Ensure the frame itself is shown in case it was somehow hidden
    frame:Show()

    F.scroll = _G[frame:GetName() .. "Scroll"] -- This should find the ScrollFrame instance
    if F.scroll then
        F.code = F.scroll:GetScrollChild() -- Get the actual EditBox which is the ScrollChild
        
        -- Ensure the scroll frame and its child are shown
        F.scroll:Show()
        if F.code then
            F.code:Show()
            -- Set the edit box to be part of the parent's frame strata
            F.code:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
    end
    
    self:Configure(F.code, F.scroll)
    
    return F.code
end

function Editor:Configure(editBox, scrollFrame)
    if not editBox or not scrollFrame then return end

    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(1, 1, 1, 1) -- 白色文字，在深色背景上更清晰
    editBox._configured = true
    
    -- Create a string for measuring text height for resize calculations
    if not self.measure then
        local measure = scrollFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        measure:SetJustifyH("LEFT")
        measure:SetJustifyV("TOP")
        measure:Hide()
        self.measure = measure
    end
    
    -- Add a debounced resize function to prevent infinite loops
    self.resizeTimer = nil
    self.pendingResize = false
    
    scrollFrame:HookScript("OnSizeChanged", function() 
        self:ScheduleResize() 
    end)
    
    -- Override the OnTextChanged to use debounced resize
    editBox:HookScript("OnTextChanged", function()
        self:ScheduleResize()
    end)
    
    self:Resize()
end

function Editor:Resize()
    if not F.code or not F.scroll then return end
    
    -- Force the scroll frame to fill its parent frame
    local parent = F.scroll:GetParent()
    if not parent then return end
    F.scroll:ClearAllPoints()
    F.scroll:SetAllPoints(parent)
    
    -- Now that the scroll frame has a size, resize the EditBox within it
    local scrollWidth = F.scroll:GetWidth()
    local scrollHeight = F.scroll:GetHeight()

    if scrollWidth <= 0 then return end

    F.code:SetWidth(scrollWidth)
    
    local textHeight
    if self.measure then
        self.measure:SetFontObject(F.code:GetFontObject())
        self.measure:SetWidth(scrollWidth)
        self.measure:SetText(F.code:GetText() or "")
        textHeight = self.measure:GetStringHeight()
    else
        local _, fontHeight = F.code:GetFont()
        textHeight = (fontHeight or 14) * 4 -- Fallback
    end
    
    local contentHeight = textHeight + 20 -- Padding
    if contentHeight < scrollHeight then contentHeight = scrollHeight end
    
    F.code:SetHeight(contentHeight)
end

function Editor:ScheduleResize()
    if self.resizeTimer then
        self.pendingResize = true
        return
    end
    
    self.resizeTimer = C_Timer.NewTimer(0.1, function()
        self.resizeTimer = nil
        if self.pendingResize then
            self.pendingResize = false
            self:ScheduleResize()
        else
            self:Resize()
        end
    end)
end

function Editor:GetCode()
    return F.code
end
