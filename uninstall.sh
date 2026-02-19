#!/bin/bash
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# Remove hook scripts
rm -f "$HOOK_DIR/stop-notify.sh" "$HOOK_DIR/save-tab-index.sh"

# Remove bashrc line
if [ -f "$HOME/.bashrc" ]; then
    sed -i '/claude-code-wsl-notify/d;/save-tab-index\.sh/d' "$HOME/.bashrc"
fi

# Remove Stop hook from settings.json
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq 'del(.hooks.Stop)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

# Clean up temp files
rm -f /tmp/cc-tab-* /tmp/cc-notify-click.ps1

echo "Uninstalled successfully! Restart Claude Code to take effect."
