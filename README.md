# ScriptRunner - In-Game Lua Script Executor (游戏内Lua脚本执行器)

## Overview (概述)

ScriptRunner is a powerful World of Warcraft addon that allows you to create, edit, and execute custom Lua scripts directly within the game. This version features a standalone architectural design, providing a lightweight and high-performance script management experience. (ScriptRunner是一个强大的魔兽世界插件，允许你在游戏内创建、编辑和执行自定义Lua脚本。本版本采用独立架构设计，提供轻量级、高性能的脚本管理体验。)

## Core Features (核心特性)

### 📝 Script Management (脚本管理)
- **Create Scripts**: Quickly create new Lua scripts with a default template. (快速创建新的Lua脚本，提供默认模板)
- **Edit Scripts**: Built-in code editor with syntax highlighting and real-time editing. (内置代码编辑器，支持语法高亮和实时编辑)
- **Delete Scripts**: Safely delete unnecessary scripts. (安全删除不需要的脚本)
- **Script List**: Clearly display all scripts, including status and mode indicators. (清晰展示所有脚本，包含状态和模式标识)

### ⚡ Execution Modes (执行模式)
- **Manual Mode**: Requires manual triggering, suitable for scripts needing precise control. (需要手动触发执行，适用于需要精确控制的脚本)
- **Auto Mode**: Automatically executes once after addon loads, ideal for initialization scripts. (插件加载后自动执行一次，适用于启动时运行的初始化脚本)
- **Delay Mode**: Executes once after a specified delay after addon loads, suitable for scripts requiring delayed startup. (插件加载后延迟指定秒数执行一次，适用于需要延迟启动的脚本)

### 🎨 User Interface (用户界面)
- **Modern Interface**: Clean and intuitive graphical interface design. (简洁直观的图形界面设计)
- **Dual Tab Layout**: Separate script management and settings pages. (脚本管理和设置页面分离)
- **Real-time Status Display**: Real-time toggling of script enabled/disabled status. (脚本启用/禁用状态实时切换)
- **Unsaved Changes Reminder**: Intelligently detects and prompts for unsaved modifications. (智能检测并提示未保存的修改)

### 🔧 Advanced Features (高级功能)
- **Script Validation**: Built-in syntax check to ensure code correctness. (内置语法检查，确保代码正确性)
- **Data Import**: Supports importing scripts from serialized data. (支持从序列化数据导入脚本)
- **Statistics**: Detailed script usage statistics. (详细的脚本使用统计)
- **Execution Statistics**: Records script execution count and success rate (internal tracking). (记录脚本执行次数和成功率（内部统计）)

## Installation Instructions (安装说明)

1.  Copy the ScriptRunner folder into the `World of Warcraft\_retail_\Interface\AddOns\` directory. (将ScriptRunner文件夹复制到 `World of Warcraft\_retail_\Interface\AddOns\` 目录)
2.  Restart the game or reload the UI. (重启游戏或重新加载界面)
3.  The addon will automatically initialize and display a loading message. (插件将自动初始化并显示加载消息)

## Usage (使用方法)

### Available Commands (可用命令)
```
/sr or /scriptrunner        - Opens the management interface. (打开管理界面)
/sr help                    - Displays help information. (显示帮助信息)
/sr list                    - Lists all scripts. (列出所有脚本)
/sr stats                   - Shows statistics. (显示统计信息)
/sr create <name>           - Creates a new script. (创建新脚本)
/sr delete <ID or name>     - Deletes a script. (删除脚本)
/sr run <ID or name>        - Executes a script. (执行脚本)
/sr import <data>           - Imports script data. (导入脚本数据)
/sr validate                - Validates syntax for all scripts. (验证所有脚本语法)
/sr test                    - Runs test scripts. (运行测试脚本)
```

## UI Introduction (界面介绍)

### Script Management Page (脚本管理页面)
- **Left List**: Displays all scripts, including mode indicators and status. (显示所有脚本，包含模式标识和状态)
  - `[M]` Manual Mode (手动模式)，`[A]` Auto Mode (自动模式)，`[D]` Delay Mode (延迟模式)
  - `[ON]` Enabled (已启用)，`[OFF]` Disabled (已禁用)
- **Right Editor**: Edit script name, code, execution mode, and other properties. (编辑脚本名称、代码、执行模式等属性)
- **Action Buttons**: Save, Execute, Delete, New Script. (保存、执行、删除、新建脚本)

### Editor Features (编辑器功能)
- **Name Editing**: Modify script display name. (修改脚本显示名称)
- **Code Editing**: Built-in code editor, supports multi-line editing. (内置代码编辑器，支持多行编辑)
- **Mode Selection**: Dropdown menu to select execution mode. (下拉菜单选择执行模式)
- **Delay Setting**: Dedicated for Delay Mode, sets delay in seconds. (延迟模式专用，设置延迟秒数)
- **Real-time Save Status**: Displays "Unsaved Changes" prompt. (显示"修改未保存"提示)

### Settings Page (设置页面)
- **UI Reload**: Quickly reloads the game UI. (快速重载游戏界面)
- **More Settings**: Reserved for extended functionalities. (预留扩展功能)

## Detailed Execution Modes (执行模式详解)

### Manual Mode (手动模式)
- **Trigger Method**: Via the "Execute" button in the UI or the `/sr run` command. (通过界面"执行"按钮或 `/sr run` 命令)
- **Use Case**: Scripts requiring precise control over execution timing. (需要精确控制执行时机的脚本)
- **Characteristics**: Safe and controllable, does not execute automatically. (安全可控，不会自动执行)

### Auto Mode (自动模式)
- **Trigger Method**: Executes automatically once after the addon loads. (插件加载后自动执行一次)
- **Use Case**: Initialization scripts that need to run automatically upon game startup. (需要在游戏启动时自动运行的初始化脚本)
- **Characteristics**: Executes on startup, no manual intervention required. (启动即执行，无需手动干预)

### Delay Mode (延迟模式)
- **Trigger Method**: Executes once after a specified delay after the addon loads. (插件加载后延迟指定秒数执行一次)
- **Use Case**: Initialization scripts that need to execute after the game has stabilized. (需要在游戏稳定后执行的初始化脚本)
- **Characteristics**: Delayed startup, executes once then stops. (延迟启动，执行一次后停止)

## Script Examples (脚本示例)

### Basic Greeting Script (基础问候脚本)
```lua
-- A simple greeting script (简单的问候脚本)
print("Hello from ScriptRunner!")
```

### Character Info Script (角色信息脚本)
```lua
-- Displays current character information (显示当前角色信息)
local playerName = UnitName("player")
local level = UnitLevel("player")
local class, classFile = UnitClass("player")

print(string.format("Character: %s, Level: %d, Class: %s", playerName, level, class))
```

### Bag Space Check (背包空间检查)
```lua
-- Displays bag space usage (显示背包空间使用情况)
local totalSlots = 0
local freeSlots = 0

for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag)
    if slots > 0 then
        totalSlots = totalSlots + slots
        for slot = 1, slots do
            if not GetContainerItemLink(bag, slot) then
                freeSlots = freeSlots + 1
            end
        end
    end
end

print(string.format("Bag Space: %d/%d (%.1f%%)", freeSlots, totalSlots, 
    freeSlots / totalSlots * 100))
```

### System Info Script (系统信息脚本)
```lua
-- Displays game system information (显示游戏系统信息)
print("=== System Information ===") (-- === 系统信息 ===)
print("Client Version:", GetBuildInfo()) (-- 客户端版本:)
print("Current Time:", date("%Y-%m-%d %H:%M:%S")) (-- 当前时间:)
print("Framerate:", GetFramerate()) (-- 帧率:)
print("Latency:", select(4, GetNetStats()) .. "ms") (-- 延迟:)
```

## Data Storage (数据存储)

- **SavedVariables**: `ScriptRunnerDB`
- **Storage Structure**: Global script data, supports sharing across multiple characters. (全局脚本数据，支持多角色共享)
- **Data Migration**: Automatically migrates older version data to new format. (自动迁移旧版本数据到新格式)
- **Backup Recommendation**: Regularly back up SavedVariables files. (定期备份SavedVariables文件)

## Technical Architecture (技术架构)

### Core Modules (核心模块)
- **ScriptRunner.lua**: Main addon file, responsible for module management and command handling. (主插件文件，负责模块管理和命令处理)
- **Core/Storage.lua**: Data storage module, handles script persistence. (数据存储模块，处理脚本的持久化)
- **Core/Executor.lua**: Script execution engine, provides a secure execution environment. (脚本执行引擎，提供安全的执行环境)
- **Core/UI.lua**: User interface module, manages graphical UI interactions. (用户界面模块，管理图形界面交互)
- **Core/Editor.lua**: Code editor module, provides editing functionality. (代码编辑器模块，提供编辑功能)

### Architectural Highlights (架构特点)
- **Modular Design**: Clear module separation, easy to maintain and extend. (清晰的模块分离，易于维护和扩展)
- **Standalone Framework**: No dependency on third-party libraries, reduces compatibility issues. (不依赖第三方库，减少兼容性问题)
- **Event-Driven**: Efficient execution mechanism based on the game's event system. (基于游戏事件系统的高效执行机制)
- **Secure Execution**: Provides a controlled script execution environment. (提供受控的脚本执行环境)

## Troubleshooting (故障排除)

### Common Issues (常见问题)

1.  **Addon Fails to Load**: (插件无法加载)
    -   Check if the file path is correct. (检查文件路径是否正确)
    -   Ensure all files are complete and intact. (确保所有文件完整无缺)
    -   Check game error logs. (查看游戏错误日志)

2.  **Script Execution Fails**: (脚本执行失败)
    -   Check if script syntax is correct. (检查脚本语法是否正确)
    -   Confirm script is enabled. (确认脚本已启用)
    -   Check console error messages. (查看控制台错误信息)

3.  **UI Display Anomalies**: (界面显示异常)
    -   Try reloading the UI (`/reload`). (尝试重新加载界面 (`/reload`))
    -   Check if UI files are intact. (检查UI文件是否完整)

4.  **Data Loss**: (数据丢失)
    -   Check if SavedVariables file is corrupted. (检查SavedVariables文件是否损坏)
    -   Restore data from backup. (从备份中恢复数据)

### Debugging Tips (调试技巧)

1.  **Enable Detailed Output**: Use `/sr validate` to check syntax for all scripts. (使用 `/sr validate` 检查所有脚本语法)
2.  **Run Test Scripts**: Use `/sr test` to verify addon functionality. (使用 `/sr test` 验证插件功能)
3.  **View Execution Statistics**: Use `/sr stats` to understand script usage. (使用 `/sr stats` 了解脚本使用情况)
4.  **Check Console**: Pay attention to error messages in the in-game console. (关注游戏内控制台的错误信息)

## Version Information (版本信息)

### Current Version: 2.0.0 (Standalone) (当前版本: 2.0.0 (Standalone))
- **Architectural Refactoring**: Adopted a standalone modular architecture. (采用独立模块化架构)
- **UI Optimization**: Redesigned user interface to enhance user experience. (重新设计用户界面，提升用户体验)
- **Performance Improvement**: Optimized script execution and data storage performance. (优化脚本执行和数据存储性能)
- **Feature Enhancement**: Added advanced features like script validation and statistics. (新增脚本验证、统计等高级功能)
- **Compatibility**: Supports the latest World of Warcraft version. (支持最新魔兽世界版本)

### Update Highlights (更新亮点)
- Removed Ace3 framework dependency, adopted a lightweight standalone architecture. (移除对Ace3框架的依赖，采用轻量级独立架构)
- Redesigned UI to provide a more intuitive user experience. (重新设计UI界面，提供更直观的操作体验)
- Enhanced script editor features, supports real-time status prompts. (增强脚本编辑器功能，支持实时状态提示)
- Optimized data storage structure, improved performance and stability. (优化数据存储结构，提升性能和稳定性)
- Added script validation and statistics features. (新增脚本验证和统计功能)

## Development Information (开发信息)

- **Author**: Abel Liu (作者: Abel Liu)
- **Version**: 2.0.0 (版本: 2.0.0)
- **Game Version**: 11.2.5 (The War Within) (游戏版本: 11.2.5 (地心之战))
- **License**: Open-source license, allows free use and modification. (开源许可，允许自由使用和修改)

## Contribution and Feedback (贡献与反馈)

Welcome bug reports, feature suggestions, and code contributions. If you have questions or suggestions, please contact via the following methods: (欢迎提交bug报告、功能建议和代码贡献。如有问题或建议，请通过以下方式联系：)
- In-game feedback (游戏内反馈)
- Addon comments section (插件评论区)
- Technical support forum (技术支持论坛)

---

**Notes**: (注意事项)
- When using this addon to execute scripts, please abide by the game's terms of service. (使用本插件执行脚本时，请遵守游戏服务条款)
- Avoid using scripts that may affect game fairness. (避免使用可能影响游戏公平性的脚本)
- It is recommended to regularly back up important script data. (建议定期备份重要的脚本数据)
- Fully test script functionality before using in a production environment. (在生产环境中使用前，请充分测试脚本功能)
