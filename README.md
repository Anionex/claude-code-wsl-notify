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

1. **Tab 定位**：通过 PowerShell 调用 Windows UI Automation API，遍历 `CASCADIA_HOSTING_WINDOW_CLASS` 窗口下所有 `TabItem` 元素，匹配当前工作目录名称来确定 tab 索引
2. **跨作用域调用**：WinForms 事件 scriptblock 无法访问外部 `Add-Type` 定义的 P/Invoke 类型，因此将窗口激活逻辑写入独立 `.ps1` 辅助脚本，点击时启动新 PowerShell 进程执行
3. **窗口激活**：通过 `user32.dll` 的 `ShowWindow` + `SetForegroundWindow` 将终端从最小化/后台恢复到前台
4. **Tab 切换**：`wt.exe focus-tab` 在此场景下不可靠，改用 `SendKeys` 发送 `Ctrl+Alt+N` 快捷键实现精准切换

## 依赖

- WSL2 + Windows Terminal
- WSL interop 已开启（默认开启）
- `jq`：`sudo apt install jq`
- `powershell.exe`：WSL 默认可访问

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

1. Claude Code 的 `Stop` hook 触发时，脚本从 stdin 读取 JSON，提取 `last_assistant_message` 作为摘要
2. 通过 UI Automation 遍历 Windows Terminal 所有 tab，匹配工作目录名定位 tab 索引
3. 生成 `.ps1` 辅助脚本，包含窗口激活和 tab 切换逻辑
4. 弹出 WinForms 无边框圆角窗口（DWM 圆角 + 深色模式），显示摘要
5. 点击弹窗时，启动独立 PowerShell 进程执行辅助脚本，通过 `SendKeys` 切换到对应 tab

## 卸载

```bash
rm ~/.claude/hooks/stop-notify.sh ~/.claude/hooks/save-tab-index.sh
```

然后从 `~/.claude/settings.json` 中移除 `Stop` hook 配置，从 `~/.bashrc` 中移除 `save-tab-index.sh` 相关行。

## License

MIT
