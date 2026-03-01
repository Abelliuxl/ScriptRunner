-- Core/Editor.lua
local ADDON_NAME = "ScriptRunner"
local ScriptRunner = _G[ADDON_NAME]

local Editor = {}
ScriptRunner.Editor = Editor

local F = {} -- Frame container

local HIGHLIGHT_COLORS = {
    keyword = "ff569cd6",
    builtin = "ff4ec9b0",
    call = "ffdcdcaa",
    string = "ffce9178",
    number = "ffb5cea8",
    comment = "ff6a9955",
}

local LUA_KEYWORDS = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

local LUA_BUILTINS = {
    ["_G"] = true,
    ["_VERSION"] = true,
    ["assert"] = true,
    ["collectgarbage"] = true,
    ["dofile"] = true,
    ["error"] = true,
    ["getfenv"] = true,
    ["getmetatable"] = true,
    ["ipairs"] = true,
    ["load"] = true,
    ["loadstring"] = true,
    ["module"] = true,
    ["next"] = true,
    ["pairs"] = true,
    ["pcall"] = true,
    ["print"] = true,
    ["rawequal"] = true,
    ["rawget"] = true,
    ["rawlen"] = true,
    ["rawset"] = true,
    ["require"] = true,
    ["select"] = true,
    ["self"] = true,
    ["setfenv"] = true,
    ["setmetatable"] = true,
    ["tonumber"] = true,
    ["tostring"] = true,
    ["type"] = true,
    ["unpack"] = true,
    ["xpcall"] = true,
}

local LUA_LIBRARIES = {
    ["bit"] = true,
    ["coroutine"] = true,
    ["io"] = true,
    ["debug"] = true,
    ["math"] = true,
    ["os"] = true,
    ["package"] = true,
    ["string"] = true,
    ["table"] = true,
    ["utf8"] = true,
}

local LUA_LIBRARY_MEMBERS = {
    ["abs"] = true,
    ["acos"] = true,
    ["asin"] = true,
    ["atan"] = true,
    ["atan2"] = true,
    ["byte"] = true,
    ["ceil"] = true,
    ["char"] = true,
    ["clock"] = true,
    ["close"] = true,
    ["concat"] = true,
    ["config"] = true,
    ["cos"] = true,
    ["create"] = true,
    ["date"] = true,
    ["deg"] = true,
    ["dump"] = true,
    ["execute"] = true,
    ["exit"] = true,
    ["exp"] = true,
    ["find"] = true,
    ["floor"] = true,
    ["flush"] = true,
    ["format"] = true,
    ["frexp"] = true,
    ["gmatch"] = true,
    ["gsub"] = true,
    ["insert"] = true,
    ["len"] = true,
    ["lines"] = true,
    ["log"] = true,
    ["lower"] = true,
    ["match"] = true,
    ["max"] = true,
    ["min"] = true,
    ["modf"] = true,
    ["open"] = true,
    ["pack"] = true,
    ["pow"] = true,
    ["rad"] = true,
    ["random"] = true,
    ["read"] = true,
    ["remove"] = true,
    ["rep"] = true,
    ["resume"] = true,
    ["reverse"] = true,
    ["seek"] = true,
    ["sin"] = true,
    ["sort"] = true,
    ["sqrt"] = true,
    ["status"] = true,
    ["sub"] = true,
    ["time"] = true,
    ["tmpfile"] = true,
    ["traceback"] = true,
    ["type"] = true,
    ["unpack"] = true,
    ["upper"] = true,
    ["wrap"] = true,
    ["write"] = true,
    ["yield"] = true,
}

local function EscapeDisplayPipes(text)
    if not text or text == "" then
        return ""
    end

    return (text:gsub("|", "||"))
end

local function CollapseDisplayPipes(text)
    if not text or text == "" then
        return ""
    end

    local parts = {}
    local index = 1
    local textLength = #text

    while index <= textLength do
        local current = text:sub(index, index)
        if current == "|" and text:sub(index + 1, index + 1) == "|" then
            parts[#parts + 1] = "|"
            index = index + 2
        else
            parts[#parts + 1] = current
            index = index + 1
        end
    end

    return table.concat(parts)
end

local function GetRawCursorPosition(displayText, displayPosition)
    if not displayText or displayText == "" or not displayPosition or displayPosition <= 0 then
        return 0
    end

    return #CollapseDisplayPipes(displayText:sub(1, displayPosition))
end

local function GetDisplayCursorPosition(rawText, rawPosition)
    if not rawText or rawText == "" or not rawPosition or rawPosition <= 0 then
        return 0
    end

    return #EscapeDisplayPipes(rawText:sub(1, rawPosition))
end

local function AppendToken(parts, text, color)
    if not text or text == "" then
        return
    end

    text = EscapeDisplayPipes(text)
    if color then
        parts[#parts + 1] = "|c" .. color .. text .. "|r"
    else
        parts[#parts + 1] = text
    end
end

local function IsDigit(char)
    return char >= "0" and char <= "9"
end

local function IsIdentifierStart(char)
    if char == "_" then
        return true
    end

    local byte = char and char:byte()
    return byte and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)) or false
end

local function IsIdentifierPart(char)
    if char == "_" then
        return true
    end

    local byte = char and char:byte()
    if not byte then
        return false
    end

    return (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
end

local function FindNextNonSpace(text, startIndex, textLength)
    local index = startIndex
    while index <= textLength do
        local current = text:sub(index, index)
        if current ~= " " and current ~= "\t" and current ~= "\r" and current ~= "\n" then
            return current, index
        end
        index = index + 1
    end
    return nil, nil
end

local function FindPreviousNonSpace(text, startIndex)
    local index = startIndex
    while index >= 1 do
        local current = text:sub(index, index)
        if current ~= " " and current ~= "\t" and current ~= "\r" and current ~= "\n" then
            return current, index
        end
        index = index - 1
    end
    return nil, nil
end

local function ConsumeNumber(text, startIndex, textLength)
    local index = startIndex
    local firstChar = text:sub(index, index)

    if firstChar == "0" then
        local prefix = text:sub(index + 1, index + 1)
        if prefix == "x" or prefix == "X" then
            index = index + 2
            while index <= textLength do
                local current = text:sub(index, index)
                if current:match("[%da-fA-F]") then
                    index = index + 1
                else
                    break
                end
            end
            return index
        end
    end

    local sawDot = (firstChar == ".")
    index = index + 1

    while index <= textLength do
        local current = text:sub(index, index)
        if IsDigit(current) then
            index = index + 1
        elseif current == "." and not sawDot and IsDigit(text:sub(index + 1, index + 1)) then
            sawDot = true
            index = index + 1
        else
            break
        end
    end

    local exponent = text:sub(index, index)
    if exponent == "e" or exponent == "E" then
        local rollback = index
        index = index + 1

        local sign = text:sub(index, index)
        if sign == "+" or sign == "-" then
            index = index + 1
        end

        local digitStart = index
        while index <= textLength and IsDigit(text:sub(index, index)) do
            index = index + 1
        end

        if digitStart == index then
            index = rollback
        end
    end

    return index
end

local function GetLongBracketEquals(text, startIndex, textLength)
    if text:sub(startIndex, startIndex) ~= "[" then
        return nil
    end

    local index = startIndex + 1
    while index <= textLength and text:sub(index, index) == "=" do
        index = index + 1
    end

    if text:sub(index, index) ~= "[" then
        return nil
    end

    return index - startIndex - 1, index + 1
end

local function FindLongBracketEnd(text, searchFrom, equalsCount)
    local closing = "]" .. string.rep("=", equalsCount) .. "]"
    return text:find(closing, searchFrom, true)
end

function Editor:Initialize(mainAddon)
    -- This module is initialized by UI.lua
end

function Editor:Create(parent)
    local frame = CreateFrame("Frame", "ScriptRunnerEditorFrameInstance", parent, "ScriptRunnerEditorFrame")
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    frame:Show()

    F.scroll = _G[frame:GetName() .. "Scroll"]
    if F.scroll then
        F.code = F.scroll:GetScrollChild()

        F.scroll:Show()
        if F.code then
            F.code:Show()
            F.code:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
    end

    self:Configure(F.code, F.scroll)

    return F.code
end

function Editor:Configure(editBox, scrollFrame)
    if not editBox or not scrollFrame then
        return
    end

    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(0.82, 0.82, 0.82, 0.05)
    if editBox.SetCursorColor then
        editBox:SetCursorColor(1, 1, 1)
    end
    editBox._configured = true

    if not self.highlight then
        local highlight = editBox:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
        highlight:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
        highlight:SetJustifyH("LEFT")
        highlight:SetJustifyV("TOP")
        highlight:SetWordWrap(true)
        highlight:SetTextColor(1, 1, 1, 1)
        self.highlight = highlight
    end
    self.highlight:SetDrawLayer("ARTWORK", 0)
    self.highlight:SetAlpha(1)
    self.highlight:SetWidth(math.max(editBox:GetWidth(), 1))
    self.highlight:Show()

    if not self.caret then
        local caret = editBox:CreateTexture(nil, "OVERLAY")
        caret:SetColorTexture(1, 1, 1, 0.9)
        caret:SetWidth(2)
        caret:Hide()
        self.caret = caret
    end

    if not self.measure then
        local measure = scrollFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        measure:SetJustifyH("LEFT")
        measure:SetJustifyV("TOP")
        measure:Hide()
        self.measure = measure
    end

    self.resizeTimer = nil
    self.pendingResize = false

    scrollFrame:HookScript("OnSizeChanged", function()
        self:ScheduleResize()
    end)

    editBox:HookScript("OnCursorChanged", function(_, x, y, width, height)
        self._caretMetrics = {
            x = x or 0,
            y = y or 0,
            width = width or 0,
            height = height or 0,
        }
        self:UpdateCaret(x, y, width, height)
    end)

    editBox:HookScript("OnEditFocusGained", function()
        self:_SetCaretVisible(true)
        self:RefreshCaret()
    end)

    editBox:HookScript("OnEditFocusLost", function()
        self:_SetCaretVisible(false)
    end)

    editBox:HookScript("OnHide", function()
        self:_SetCaretVisible(false)
    end)

    editBox:HookScript("OnTextChanged", function()
        self:NormalizeDisplayedCode()
        self:UpdateHighlight()
        self:RefreshCaret()
        self:ScheduleResize()
    end)

    self:UpdateHighlight()
    self:RefreshCaret()
    self:Resize()
end

function Editor:_SetCaretVisible(visible)
    if not self.caret then
        return
    end

    if visible then
        self.caret:Show()
    else
        self.caret:Hide()
    end
end

function Editor:UpdateCaret(x, y, width, height)
    if not F.code or not self.caret then
        return
    end

    if not F.code:HasFocus() then
        self:_SetCaretVisible(false)
        return
    end

    local caretHeight = math.max(height or 0, 12)
    self.caret:ClearAllPoints()
    self.caret:SetPoint("TOPLEFT", F.code, "TOPLEFT", x or 0, y or 0)
    self.caret:SetHeight(caretHeight)
    self:_SetCaretVisible(true)
end

function Editor:RefreshCaret()
    if not F.code or not self.caret then
        return
    end

    if not F.code:HasFocus() then
        self:_SetCaretVisible(false)
        return
    end

    if self._caretMetrics then
        self:UpdateCaret(
            self._caretMetrics.x,
            self._caretMetrics.y,
            self._caretMetrics.width,
            self._caretMetrics.height
        )
    else
        local _, fontHeight = F.code:GetFont()
        self:UpdateCaret(0, 0, 0, fontHeight or 14)
    end
end

function Editor:NormalizeDisplayedCode()
    if not F.code or self._isUpdatingDisplayText then
        return
    end

    local displayText = F.code:GetText() or ""
    local rawText = CollapseDisplayPipes(displayText)
    local normalizedDisplayText = EscapeDisplayPipes(rawText)

    if normalizedDisplayText == displayText then
        return
    end

    local rawCursor = GetRawCursorPosition(displayText, F.code:GetCursorPosition())

    self._isUpdatingDisplayText = true
    F.code:SetText(normalizedDisplayText)
    F.code:SetCursorPosition(GetDisplayCursorPosition(rawText, rawCursor))
    self._isUpdatingDisplayText = false
end

function Editor:BuildHighlightedText(text)
    if not text or text == "" then
        return ""
    end

    local parts = {}
    local textLength = #text
    local index = 1

    while index <= textLength do
        local current = text:sub(index, index)
        local nextChar = text:sub(index + 1, index + 1)

        if current == "-" and nextChar == "-" then
            local equalsCount, contentStart = GetLongBracketEquals(text, index + 2, textLength)
            if equalsCount ~= nil then
                local _, commentEnd = FindLongBracketEnd(text, contentStart, equalsCount)
                if commentEnd then
                    AppendToken(parts, text:sub(index, commentEnd), HIGHLIGHT_COLORS.comment)
                    index = commentEnd + 1
                else
                    AppendToken(parts, text:sub(index), HIGHLIGHT_COLORS.comment)
                    break
                end
            else
                local lineBreak = text:find("\n", index, true)
                if lineBreak then
                    AppendToken(parts, text:sub(index, lineBreak - 1), HIGHLIGHT_COLORS.comment)
                    AppendToken(parts, "\n")
                    index = lineBreak + 1
                else
                    AppendToken(parts, text:sub(index), HIGHLIGHT_COLORS.comment)
                    break
                end
            end
        elseif current == "'" or current == "\"" then
            local quote = current
            local cursor = index + 1

            while cursor <= textLength do
                local char = text:sub(cursor, cursor)
                if char == "\\" then
                    cursor = cursor + 2
                else
                    cursor = cursor + 1
                    if char == quote then
                        break
                    end
                end
            end

            AppendToken(parts, text:sub(index, math.min(cursor - 1, textLength)), HIGHLIGHT_COLORS.string)
            index = cursor
        elseif current == "[" then
            local equalsCount, contentStart = GetLongBracketEquals(text, index, textLength)
            if equalsCount ~= nil then
                local _, stringEnd = FindLongBracketEnd(text, contentStart, equalsCount)
                if stringEnd then
                    AppendToken(parts, text:sub(index, stringEnd), HIGHLIGHT_COLORS.string)
                    index = stringEnd + 1
                else
                    AppendToken(parts, text:sub(index), HIGHLIGHT_COLORS.string)
                    break
                end
            else
                AppendToken(parts, current)
                index = index + 1
            end
        elseif IsIdentifierStart(current) then
            local cursor = index + 1
            while cursor <= textLength and IsIdentifierPart(text:sub(cursor, cursor)) do
                cursor = cursor + 1
            end

            local word = text:sub(index, cursor - 1)
            local nextNonSpace = FindNextNonSpace(text, cursor, textLength)
            local prevNonSpace = FindPreviousNonSpace(text, index - 1)
            if LUA_KEYWORDS[word] then
                AppendToken(parts, word, HIGHLIGHT_COLORS.keyword)
            elseif LUA_BUILTINS[word] then
                AppendToken(parts, word, HIGHLIGHT_COLORS.builtin)
            elseif LUA_LIBRARIES[word] then
                AppendToken(parts, word, HIGHLIGHT_COLORS.builtin)
            elseif (prevNonSpace == "." or prevNonSpace == ":") and LUA_LIBRARY_MEMBERS[word] then
                if nextNonSpace == "(" then
                    AppendToken(parts, word, HIGHLIGHT_COLORS.call)
                else
                    AppendToken(parts, word, HIGHLIGHT_COLORS.builtin)
                end
            elseif nextNonSpace == "(" then
                AppendToken(parts, word, HIGHLIGHT_COLORS.call)
            else
                AppendToken(parts, word)
            end

            index = cursor
        elseif IsDigit(current) or (current == "." and IsDigit(nextChar)) then
            local cursor = ConsumeNumber(text, index, textLength)
            AppendToken(parts, text:sub(index, cursor - 1), HIGHLIGHT_COLORS.number)
            index = cursor
        else
            AppendToken(parts, current)
            index = index + 1
        end
    end

    return table.concat(parts)
end

function Editor:UpdateHighlight()
    if not F.code or not self.highlight then
        return
    end

    self.highlight:SetFontObject(F.code:GetFontObject())
    self.highlight:SetWidth(math.max(F.code:GetWidth(), 1))
    self.highlight:SetText(self:BuildHighlightedText(self:GetCodeText()))
end

function Editor:Resize()
    if not F.code or not F.scroll then
        return
    end

    local parent = F.scroll:GetParent()
    if not parent then
        return
    end

    F.scroll:ClearAllPoints()
    F.scroll:SetAllPoints(parent)

    local scrollWidth = F.scroll:GetWidth()
    local scrollHeight = F.scroll:GetHeight()

    if scrollWidth <= 0 then
        return
    end

    F.code:SetWidth(scrollWidth)
    self:UpdateHighlight()

    local textHeight
    if self.measure then
        self.measure:SetFontObject(F.code:GetFontObject())
        self.measure:SetWidth(scrollWidth)
        self.measure:SetText(F.code:GetText() or "")
        textHeight = self.measure:GetStringHeight()
    else
        local _, fontHeight = F.code:GetFont()
        textHeight = (fontHeight or 14) * 4
    end

    local contentHeight = textHeight + 20
    if contentHeight < scrollHeight then
        contentHeight = scrollHeight
    end

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

function Editor:SetCodeText(text)
    if not F.code then
        return
    end

    self._isUpdatingDisplayText = true
    F.code:SetText(EscapeDisplayPipes(text or ""))
    self._isUpdatingDisplayText = false
    self:UpdateHighlight()
end

function Editor:GetCodeText()
    if not F.code then
        return ""
    end

    return CollapseDisplayPipes(F.code:GetText() or "")
end
