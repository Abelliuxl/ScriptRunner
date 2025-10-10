-- ScriptRunner - In-game Lua Script Runner
-- Version: 2.0.0 (Standalone)

local ADDON_NAME = "ScriptRunner"
local ScriptRunner = {
    name = ADDON_NAME,
    version = "2.0.0",
    title = "ScriptRunner",
    notes = "In-game Lua script executor.",
    author = "Custom",
}
_G[ADDON_NAME] = ScriptRunner

local MANAGED_MODULES = { "Storage", "Executor", "UI" }

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        ScriptRunner:OnAddonLoaded()
        f:UnregisterEvent("ADDON_LOADED")
    end
end)

function ScriptRunner:OnAddonLoaded()
    -- Initialize saved variables
    ScriptRunnerDB = ScriptRunnerDB or {
        profile = {
            enabled = true,
            theme = "default",
            minimap = {
                hide = false,
                minRadius = 140,
                maxRadius = 200,
                angle = math.pi / 2,
            },
        },
        global = {
            scripts = {},
        },
    }

    self.db = ScriptRunnerDB

    self:EnsureModulesLoaded()
    self:RegisterSlashCommands()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    print(string.format("|cff00ff00%s|r: v%s loaded.", self.title, self.version))
    print(string.format("|cff00ff00%s|r: Use /sr to open the interface.", self.title))
end

function ScriptRunner:EnsureModulesLoaded()
    for _, moduleName in ipairs(MANAGED_MODULES) do
        local module = self[moduleName]
        if module and type(module.Initialize) == "function" then
            module:Initialize(self)
        else
            print(string.format("|cffff0000%s|r: Module '%s' not found or is invalid.", self.title, moduleName))
        end
    end
end

function ScriptRunner:OnPlayerEnteringWorld()
    C_Timer.After(2, function()
        if self.Executor then
            if self.Executor.ExecuteAutoScripts then
                self.Executor:ExecuteAutoScripts()
            end
            if self.Executor.ScheduleDelayedScripts then
                self.Executor:ScheduleDelayedScripts()
            end
        end
    end)
end

function ScriptRunner:RegisterEvent(event, method)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent(event)
    frame:SetScript("OnEvent", function(_, event, ...)
        if self[method] then
            self[method](self, event, ...)
        end
    end)
end

function ScriptRunner:RegisterSlashCommands()
    SLASH_SCRIPTRUNNER1 = "/scriptrunner"
    SLASH_SCRIPTRUNNER2 = "/sr"
    SlashCmdList["SCRIPTRUNNER"] = function(msg)
        ScriptRunner:HandleSlashCommand(msg)
    end
end

local function trim(str)
    if type(str) ~= "string" then
        return ""
    end
    return str:match("^%s*(.-)%s*$") or ""
end

local function findScriptByIdentifier(storage, identifier)
    if not storage or not identifier or identifier == "" then
        return nil, nil
    end

    local scripts = storage:GetAllScripts()
    if not scripts then
        return nil, nil
    end

    if scripts[identifier] then
        return identifier, scripts[identifier]
    end

    local lowered = identifier:lower()
    for id, script in pairs(scripts) do
        if script.name and script.name:lower():find(lowered, 1, true) then
            return id, script
        end
    end

    return nil, nil
end

function ScriptRunner:HandleSlashCommand(msg)
    if not msg or trim(msg) == "" then
        if self.UI and self.UI.Toggle then
            self.UI:Toggle()
        else
            print(string.format("|cffff0000%s|r: UI module is not loaded.", self.title))
        end
        return
    end

    local command, rest = msg:match("^(%S+)%s*(.*)$")
    command = (command and command:lower()) or ""
    rest = trim(rest)

    if command == "help" then
        self:ShowHelp()
    elseif command == "list" then
        self:ListScripts()
    elseif command == "run" and rest ~= "" then
        self:RunScript(rest)
    elseif command == "create" and rest ~= "" then
        self:CreateScript(rest)
    elseif command == "delete" and rest ~= "" then
        self:DeleteScript(rest)
    elseif command == "stats" then
        self:ShowStats()
    elseif command == "import" and rest ~= "" then
        self:ImportScripts(rest)
    elseif command == "validate" then
        self:ValidateAllScripts()
    elseif command == "test" then
        self:RunTestScript()
    else
        print(string.format("|cffff0000%s|r: Unknown command. Use /sr help for a list of commands.", self.title))
    end
end

function ScriptRunner:ShowHelp()
    print("|cff00ff00=== ScriptRunner Help ===|r")
    print("|cff00ccffGeneral Commands:|r")
    print("  /sr or /scriptrunner - open the main interface")
    print("  /sr help - show this help message")
    print("  /sr list - list all stored scripts")
    print("  /sr stats - show statistics")
    print("|cff00ccffScript Management:|r")
    print("  /sr create <name> - create a new script")
    print("  /sr delete <id or name> - delete a script")
    print("  /sr run <id or name> - execute a script in manual mode")
    print("  /sr import <table> - import scripts from serialized data")
    print("  /sr validate - syntax check all scripts")
    print("  /sr test - run the bundled test script")
end

function ScriptRunner:ListScripts()
    if not self.Storage then
        print(string.format("|cffff0000%s|r: Storage module is not loaded.", self.title))
        return
    end

    local scripts = self.Storage:GetAllScripts()
    local ordered = {}
    for id, script in pairs(scripts) do
        table.insert(ordered, { id = id, script = script })
    end

    table.sort(ordered, function(a, b)
        local at = a.script.updatedAt or 0
        local bt = b.script.updatedAt or 0
        if at == bt then
            return (a.script.name or "") < (b.script.name or "")
        end
        return at > bt
    end)

    print("|cff00ff00=== Stored Scripts ===|r")
    if #ordered == 0 then
        print("  |cff888888No scripts stored.|r")
        return
    end

    for _, entry in ipairs(ordered) do
        local script = entry.script
        local status = script.enabled and "|cff00ff00[ON]|r" or "|cffff0000[OFF]|r"
        local mode
        if script.mode == "auto" then
            mode = "|cff00ccff[AUTO]|r"
        elseif script.mode == "delay" then
            mode = string.format("|cffffcc00[DELAY %ss]|r", tostring(script.delay or 0))
        else
            mode = "|cffcccccc[MANUAL]|r"
        end

        local preview = ""
        if script.code and #script.code > 0 then
            preview = script.code:gsub("\n", " ")
            if #preview > 80 then
                preview = preview:sub(1, 77) .. "..."
            end
        else
            preview = "<empty>"
        end

        print(string.format("  %s %s %s |cff00ccff%s|r |cff888888%s|r",
            status, mode, script.name or "Unnamed", entry.id:sub(1, 8), preview))
    end
end

function ScriptRunner:ShowStats()
    if not self.Storage then
        print(string.format("|cffff0000%s|r: Storage module is not loaded.", self.title))
        return
    end

    local stats = self.Storage:GetStats()
    print("|cff00ff00=== Script Statistics ===|r")
    print(string.format("  Total: |cff00ccff%d|r", stats.total or 0))
    print(string.format("  Enabled: |cff00ff00%d|r", stats.enabled or 0))
    print(string.format("  Disabled: |cffff0000%d|r", stats.disabled or 0))
    print(string.format("  Auto: |cff00ccff%d|r", stats.auto or 0))
    print(string.format("  Delay: |cffffcc00%d|r", stats.delay or 0))
    print(string.format("  Manual: |cffcccccc%d|r", stats.manual or 0))
    if stats.averageCodeLength then
        print(string.format("  Average length: |cff00ccff%d|r characters", stats.averageCodeLength))
    end
end

function ScriptRunner:RunScript(identifier)
    if not self.Storage or not self.Executor then
        print(string.format("|cffff0000%s|r: Storage or Executor module is not loaded.", self.title))
        return
    end

    local id, script = findScriptByIdentifier(self.Storage, identifier)
    if not script then
        print(string.format("|cffff0000%s|r: Could not find script '%s'.", self.title, identifier))
        return
    end

    local success, result = self.Executor:ExecuteManualScript(id)
    if success then
        print(string.format("|cff00ff00%s|r: Script '%s' executed successfully.", self.title, script.name or id))
    else
        print(string.format("|cffff0000%s|r: Script '%s' failed: %s", self.title, script.name or id, tostring(result)))
    end
end

function ScriptRunner:CreateScript(name)
    if not self.Storage then
        print(string.format("|cffff0000%s|r: Storage module is not loaded.", self.title))
        return
    end

    name = trim(name)
    if name == "" then
        name = "New Script"
    end

    local template = string.format("-- %s\nprint(\"Hello from %s\")\n", name, name)
    local script = self.Storage:CreateScript(name, template, "manual", 5)
    print(string.format("|cff00ff00%s|r: Script '%s' created (id %s).", self.title, script.name, script.id))

    if self.UI and self.UI.SelectScript then
        self.UI:SelectScript(script.id)
        self.UI:Show()
    end
end

function ScriptRunner:DeleteScript(identifier)
    if not self.Storage then
        print(string.format("|cffff0000%s|r: Storage module is not loaded.", self.title))
        return
    end

    local id, script = findScriptByIdentifier(self.Storage, identifier)
    if not script then
        print(string.format("|cffff0000%s|r: Could not find script '%s'.", self.title, identifier))
        return
    end

    self.Storage:DeleteScript(id)
    print(string.format("|cff00ff00%s|r: Script '%s' deleted.", self.title, script.name or id))

    if self.UI and self.UI.RefreshScriptList then
        self.UI:RefreshScriptList()
    end
end

function ScriptRunner:ImportScripts(data)
    if not self.Storage then
        print(string.format("|cffff0000%s|r: Storage module is not loaded.", self.title))
        return
    end

    local importData = self:DeserializeTable(data)
    if not importData then
        print(string.format("|cffff0000%s|r: Invalid import data.", self.title))
        return
    end

    local success, count = self.Storage:ImportScripts(importData)
    if success then
        print(string.format("|cff00ff00%s|r: Imported %d scripts.", self.title, count or 0))
        if self.UI and self.UI.RefreshScriptList then
            self.UI:RefreshScriptList()
        end
    else
        print(string.format("|cffff0000%s|r: Import failed: %s", self.title, tostring(count)))
    end
end

function ScriptRunner:ValidateAllScripts()
    if not self.Storage or not self.Executor then
        print(string.format("|cffff0000%s|r: Storage or Executor module is not loaded.", self.title))
        return
    end

    local scripts = self.Storage:GetAllScripts()
    local validCount = 0
    local invalidCount = 0

    print("|cff00ff00=== Script Validation ===|r")
    for id, script in pairs(scripts) do
        local ok, message = self.Executor:ValidateScript(script.code)
        if ok then
            print(string.format("  |cff00ff00✓|r %s", script.name or id))
            validCount = validCount + 1
        else
            print(string.format("  |cffff0000✗|r %s: %s", script.name or id, message))
            invalidCount = invalidCount + 1
        end
    end

    print(string.format("|cff00ff00Finished: %d valid, %d invalid.|r", validCount, invalidCount))
end

function ScriptRunner:RunTestScript()
    if not self.Executor then
        print(string.format("|cffff0000%s|r: Executor module is not loaded.", self.title))
        return
    end

    local testCode = [[
print("=== ScriptRunner Test ===")
local t = {1, 2, 3}
print("Table test:", table.concat(t, ", "))
print("Random number:", math.random(1, 100))
print("Upper string:", string.upper("ScriptRunner"))
print("Current time:", date("%H:%M:%S"))
print("=== Test Complete ===")
]]

    local testScript = {
        id = "test",
        name = "Test Script",
        code = testCode,
        enabled = true,
        mode = "manual",
    }

    local success, result = self.Executor:ExecuteScript(testScript)
    if success then
        print(string.format("|cff00ff00%s|r: Test script executed successfully.", self.title))
    else
        print(string.format("|cffff0000%s|r: Test script failed: %s", self.title, tostring(result)))
    end
end

function ScriptRunner:ResetDatabase()
    print(string.format("|cffff0000%s|r: This will delete all stored script data.", self.title))

    StaticPopupDialogs["SCRIPTRUNNER_RESET_CONFIRM"] = {
        text = "Reset all ScriptRunner data?\n\nThis cannot be undone.",
        button1 = "Confirm",
        button2 = "Cancel",
        OnAccept = function()
            if self.Storage and self.Storage.ClearAllScripts then
                self.Storage:ClearAllScripts()
                print(string.format("|cff00ff00%s|r: All script data has been reset.", self.title))
            end
        end,
        OnCancel = function()
            print(string.format("|cff00ff00%s|r: Reset cancelled.", self.title))
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("SCRIPTRUNNER_RESET_CONFIRM")
end

function ScriptRunner:DeserializeTable(str)
    if type(str) ~= "string" or str == "" then
        return nil
    end

    local chunk, err
    if loadstring then
        chunk, err = loadstring("return " .. str, "ScriptRunnerImport")
    else
        chunk, err = load("return " .. str, "ScriptRunnerImport")
    end

    if not chunk then
        return nil
    end

    local sandbox = {}
    if setfenv then
        setfenv(chunk, sandbox)
    else
      -- Lua 5.2+ _ENV
      -- This is a very basic sandbox, not secure.
      -- For addon usage this is usually fine.
      local f, err = load("return " .. str, "ScriptRunnerImport", "t", sandbox)
      if not f then return nil, err end
      local ok, res = pcall(f)
      if ok then return res end
      return nil
    end


    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return nil
    end

    return result
end
