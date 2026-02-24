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

# Check .NET Desktop Runtime
if ! dotnet.exe --list-runtimes 2>/dev/null | tr -d '\r' | grep -q "Microsoft.WindowsDesktop.App 8\."; then
    echo "Error: .NET 8 Desktop Runtime not found on Windows."
    echo "Download from: https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 1
fi

# Download hook script
mkdir -p "$HOOK_DIR"
curl -fsSL "$REPO/stop-notify.sh" -o "$HOOK_DIR/stop-notify.sh"
chmod +x "$HOOK_DIR/stop-notify.sh"

# Download pre-built wt-tab-bridge.exe
WIN_LOCALAPPDATA=$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')
BRIDGE_DIR_WSL=$(wslpath "$WIN_LOCALAPPDATA")/wt-tab-bridge
mkdir -p "$BRIDGE_DIR_WSL"
BRIDGE_EXE_WSL="$BRIDGE_DIR_WSL/wt-tab-bridge.exe"
echo "Downloading wt-tab-bridge.exe..."
curl -fsSL "https://github.com/Anionex/claude-code-wsl-notify/releases/latest/download/wt-tab-bridge.exe" \
    -o "$BRIDGE_EXE_WSL"
[ -f "$BRIDGE_EXE_WSL" ] || { echo "Error: download failed"; exit 1; }

# Add tab registration to bashrc
if ! grep -qF "wt-tab-bridge" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << BASHEOF

# claude-code-wsl-notify: register tab mapping on shell startup
if [ -n "\$WT_SESSION" ]; then
    "$BRIDGE_EXE_WSL" register --session "\$WT_SESSION" &>/dev/null
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
