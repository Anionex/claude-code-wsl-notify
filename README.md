# claude-code-wsl-notify

WSL 环境下 Claude Code 停止输出时，向 Windows 发送桌面通知弹窗，显示回复摘要，点击可跳回对应终端 tab。

![Windows 11](https://img.shields.io/badge/Windows%2011-WSL2-blue)


## 功能

- Claude Code 停止输出时自动弹出 Windows 桌面通知
- 显示 Claude 最后回复的摘要内容
- **点击通知精准跳回 Windows Terminal 对应 tab**（见下方技术亮点）
- Win11 风格深色圆角弹窗，Claude 品牌配色
- 10 秒后自动消失

<img width="400" alt="image" src="https://github.com/user-attachments/assets/ab32b5dd-8632-4db5-a94b-a746797351ab" />


## 技术亮点：点击跳回对应 Tab

从 WSL hook 子进程中精准定位并切换 Windows Terminal tab 是一个非平凡的问题，涉及多层跨系统交互：

1. **Tab 定位**：通过 C# 编写的 `wt-tab-bridge.exe` 桥接工具，利用 UI Automation 的 `RuntimeId`（元素实例级标识符）建立 `WT_SESSION → Tab` 映射。RuntimeId 在标签页存活期间稳定，不受拖动重排序或重名标签页影响
2. **Tab 注册**：每次打开新终端标签页时，`.bashrc` 中的 register 命令自动将当前 `WT_SESSION` 与选中 TabItem 的 RuntimeId 关联，写入本地映射文件
3. **Tab 切换**：点击通知时调用 `wt-tab-bridge.exe focus`，通过 RuntimeId 精确找到目标 TabItem，使用 `SelectionItemPattern.Select()` 直接切换，无需依赖 SendKeys 或位置索引
4. **窗口激活**：通过 `user32.dll` 的 `ShowWindow` + `SetForegroundWindow` 将终端从最小化/后台恢复到前台

## 依赖

- WSL2 + Windows Terminal
- WSL interop 已开启（默认开启）
- `jq`：`sudo apt install jq`
- `powershell.exe`：WSL 默认可访问
- `.NET 8 SDK`：需要在 Windows 侧安装，用于编译 `wt-tab-bridge.exe`（[下载](https://dotnet.microsoft.com/download/dotnet/8.0)）

## 安装

```bash
git clone https://github.com/Anionex/claude-code-wsl-notify.git
cd claude-code-wsl-notify
chmod +x install.sh
./install.sh
```

重启 Claude Code 即可生效。

## 手动安装

1. 复制 `stop-notify.sh` 到 `~/.claude/hooks/`
2. 在 `~/.claude/settings.json` 中添加：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/stop-notify.sh"
          }
        ]
      }
    ]
  }
}
```

## 工作原理

1. 每次打开新终端标签页时，`.bashrc` 中的命令调用 `wt-tab-bridge.exe register` 将 `WT_SESSION` 与当前 TabItem 的 RuntimeId 关联
2. Claude Code 的 `Stop` hook 触发时，脚本从 stdin 读取 JSON，提取 `last_assistant_message` 作为摘要
3. 弹出 WinForms 无边框圆角窗口（DWM 圆角 + 深色模式），显示摘要
4. 点击弹窗时，调用 `wt-tab-bridge.exe focus` 通过 RuntimeId 精确定位并切换到对应 tab

## 卸载

```bash
chmod +x uninstall.sh
./uninstall.sh
```

或手动清理：

```bash
rm ~/.claude/hooks/stop-notify.sh
```

然后从 `~/.claude/settings.json` 中移除 `Stop` hook 配置，从 `~/.bashrc` 中移除 `wt-tab-bridge` 相关行，删除 `%LOCALAPPDATA%\wt-tab-bridge\` 目录。

## License

MIT
