#!/bin/bash
set -e

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# Check dependencies
for cmd in jq powershell.exe; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found"
        exit 1
    fi
done

# Install hook scripts
mkdir -p "$HOOK_DIR"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SRCDIR/stop-notify.sh" "$HOOK_DIR/"
cp "$SRCDIR/save-tab-index.sh" "$HOOK_DIR/"
chmod +x "$HOOK_DIR/stop-notify.sh" "$HOOK_DIR/save-tab-index.sh"

# Add tab index saving to bashrc
BASHRC_LINE='[ -n "$WT_SESSION" ] && bash ~/.claude/hooks/save-tab-index.sh &>/dev/null &'
if ! grep -qF "save-tab-index.sh" "$HOME/.bashrc" 2>/dev/null; then
    echo -e "\n# Save Windows Terminal tab index for claude-code-wsl-notify\n$BASHRC_LINE" >> "$HOME/.bashrc"
fi

# Update settings.json
if [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq '.hooks.Stop = [{"matcher":"","hooks":[{"type":"command","command":"bash ~/.claude/hooks/stop-notify.sh"}]}]' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
else
    mkdir -p "$(dirname "$SETTINGS")"
    cat > "$SETTINGS" <<'EOF'
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
EOF
fi

echo "Installed successfully!"
echo "Restart Claude Code to activate."
