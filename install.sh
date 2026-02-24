#!/bin/bash
set -e

REPO="https://raw.githubusercontent.com/Anionex/claude-code-wsl-notify/main"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# Check dependencies
for cmd in jq powershell.exe curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found"
        exit 1
    fi
done

# Download and install hook scripts
mkdir -p "$HOOK_DIR"
curl -fsSL "$REPO/stop-notify.sh" -o "$HOOK_DIR/stop-notify.sh"
curl -fsSL "$REPO/save-tab-index.sh" -o "$HOOK_DIR/save-tab-index.sh"
chmod +x "$HOOK_DIR/stop-notify.sh" "$HOOK_DIR/save-tab-index.sh"

# Add tab index saving + dynamic refresh to bashrc
if ! grep -qF "save-tab-index.sh" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'BASHEOF'

# claude-code-wsl-notify: save tab index on shell startup & keep it fresh
if [ -n "$WT_SESSION" ] && [ -f ~/.claude/hooks/save-tab-index.sh ]; then
    bash ~/.claude/hooks/save-tab-index.sh &>/dev/null
    _cc_refresh_tab() {
        local now; now=$(date +%s)
        local last; last=$(cat "/tmp/cc-tab-ts-$WT_SESSION" 2>/dev/null || echo 0)
        (( now - last < 10 )) && return
        echo "$now" > "/tmp/cc-tab-ts-$WT_SESSION"
        bash ~/.claude/hooks/save-tab-index.sh &>/dev/null &
    }
    PROMPT_COMMAND="_cc_refresh_tab;${PROMPT_COMMAND}"
fi
BASHEOF
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

echo "Installed successfully! Restart Claude Code and open a new terminal tab to activate."
