#!/bin/bash
set -e

REPO="https://raw.githubusercontent.com/Anionex/claude-code-wsl-notify/main"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# Check dependencies
for cmd in jq powershell.exe curl dotnet.exe; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found"
        exit 1
    fi
done

# Download hook script
mkdir -p "$HOOK_DIR"
curl -fsSL "$REPO/stop-notify.sh" -o "$HOOK_DIR/stop-notify.sh"
chmod +x "$HOOK_DIR/stop-notify.sh"

# Build and install wt-tab-bridge.exe
WIN_LOCALAPPDATA=$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')
BRIDGE_DIR="$WIN_LOCALAPPDATA\\wt-tab-bridge"
BRIDGE_DIR_WSL=$(wslpath "$WIN_LOCALAPPDATA")/wt-tab-bridge
TMP_BUILD=$(mktemp -d)
curl -fsSL "$REPO/wt-tab-bridge/WtTabBridge.csproj" -o "$TMP_BUILD/WtTabBridge.csproj"
curl -fsSL "$REPO/wt-tab-bridge/Program.cs" -o "$TMP_BUILD/Program.cs"
echo "Building wt-tab-bridge.exe..."
dotnet.exe publish "$(wslpath -w "$TMP_BUILD/WtTabBridge.csproj")" \
    -c Release -o "$BRIDGE_DIR" --no-self-contained -v quiet 2>&1 | tr -d '\r'
rm -rf "$TMP_BUILD"
BRIDGE_EXE_WSL="$BRIDGE_DIR_WSL/wt-tab-bridge.exe"
[ -f "$BRIDGE_EXE_WSL" ] || { echo "Error: build failed"; exit 1; }

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
