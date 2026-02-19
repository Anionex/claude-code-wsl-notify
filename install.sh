#!/bin/bash
set -e

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_NAME="stop-notify.sh"
SOURCE="$(cd "$(dirname "$0")" && pwd)/$SCRIPT_NAME"

# Check dependencies
for cmd in jq powershell.exe; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found"
        exit 1
    fi
done

# Install hook script
mkdir -p "$HOOK_DIR"
cp "$SOURCE" "$HOOK_DIR/$SCRIPT_NAME"
chmod +x "$HOOK_DIR/$SCRIPT_NAME"

# Update settings.json
if [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq '.hooks.Stop = [{"matcher":"","hooks":[{"type":"command","command":"bash ~/.claude/hooks/'"$SCRIPT_NAME"'"}]}]' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
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
