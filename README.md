# claude-code-wsl-notify

WSL 环境下 Claude Code 停止输出时，向 Windows 发送桌面通知弹窗，显示回复摘要，点击可跳回对应终端 tab。

![Windows 11](https://img.shields.io/badge/Windows%2011-WSL2-blue)

## 功能

- Claude Code 停止输出时自动弹出 Windows 桌面通知
- 显示 Claude 最后回复的摘要内容
- 点击通知跳回 Windows Terminal 对应 tab
- Win11 风格深色圆角弹窗，Claude 品牌配色
- 10 秒后自动消失

## 依赖

- WSL2 + Windows Terminal
- WSL interop 已开启（默认开启）
- `jq`：`sudo apt install jq`
- `powershell.exe`：WSL 默认可访问

## 安装

```bash
git clone https://github.com/<your-username>/claude-code-wsl-notify.git
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
2. 通过 ANSI 转义序列给当前 tab 设置唯一标记
3. 调用 PowerShell + UI Automation 遍历 Windows Terminal 的所有 tab，找到标记对应的 tab 索引
4. 弹出 WinForms 无边框圆角窗口，显示摘要
5. 点击弹窗时，通过 `wt.exe focus-tab --index N` 切换到对应 tab

## 卸载

```bash
rm ~/.claude/hooks/stop-notify.sh
```

然后从 `~/.claude/settings.json` 中移除 `Stop` hook 配置。

## License

MIT
