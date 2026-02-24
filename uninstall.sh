#!/bin/bash
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# Remove hook scripts
rm -f "$HOOK_DIR/stop-notify.sh" "$HOOK_DIR/save-tab-index.sh"

# Remove wt-tab-bridge from %LOCALAPPDATA%
WIN_LOCALAPPDATA=$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')
if [ -n "$WIN_LOCALAPPDATA" ]; then
    BRIDGE_DIR_WSL=$(wslpath "$WIN_LOCALAPPDATA")/wt-tab-bridge
    rm -rf "$BRIDGE_DIR_WSL"
fi

# Remove bashrc block
if [ -f "$HOME/.bashrc" ]; then
    sed -i '/# claude-code-wsl-notify/,/^fi$/d' "$HOME/.bashrc"
fi

# Remove Stop hook from settings.json
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq 'del(.hooks.Stop)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

# Clean up temp files
rm -f /tmp/cc-notify.ps1

echo "Uninstalled successfully! Restart Claude Code to take effect."
