#!/bin/bash
INPUT=$(cat)

# Extract summary
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // "Claude Code 已完成"' 2>/dev/null)
[ -z "$SUMMARY" ] && SUMMARY="Claude Code 已完成"
SUMMARY="${SUMMARY:0:300}"
B64=$(echo -n "$SUMMARY" | base64 -w 0)

# Read tab index saved at shell startup
TAB_NUM=$(cat "/tmp/cc-tab-$WT_SESSION" 2>/dev/null)
TAB_NUM=${TAB_NUM:-0}

# Write click helper script
CLICK_PS1=$(wslpath -w /tmp/cc-notify-click.ps1)
cat > /tmp/cc-notify-click.ps1 << 'PSEOF'
Add-Type @"
using System;using System.Runtime.InteropServices;
public class W{
[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
}
"@
Add-Type -AssemblyName System.Windows.Forms
$p=Get-Process -Name WindowsTerminal -EA 0
if($p){[W]::ShowWindow($p[0].MainWindowHandle,9);[W]::SetForegroundWindow($p[0].MainWindowHandle)
PSEOF
if [ "$TAB_NUM" -gt 0 ] 2>/dev/null && [ "$TAB_NUM" -le 9 ] 2>/dev/null; then
    echo "Start-Sleep -Milliseconds 200;[System.Windows.Forms.SendKeys]::SendWait('^(%${TAB_NUM})')}" >> /tmp/cc-notify-click.ps1
else
    echo "}" >> /tmp/cc-notify-click.ps1
fi

# Show notification popup
powershell.exe -NoProfile -Command "
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
using System.Drawing;using System.Drawing.Drawing2D;
public class W32{
[DllImport(\"user32.dll\")]public static extern bool SetForegroundWindow(IntPtr h);
[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr h,int c);
[DllImport(\"dwmapi.dll\")]public static extern int DwmSetWindowAttribute(IntPtr h,int a,ref int v,int s);
}
'@

\$text=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('$B64'))

\$f=New-Object Windows.Forms.Form
\$f.FormBorderStyle='None'
\$f.Size='400,110'
\$f.TopMost=\$true
\$f.StartPosition='Manual'
\$f.ShowInTaskbar=\$false
\$wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
\$f.Location=[Drawing.Point]::new(\$wa.Right-416,\$wa.Bottom-126)
\$f.BackColor=[Drawing.Color]::FromArgb(44,44,46)

# Win11 rounded corners
\$pref=2;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,33,[ref]\$pref,4)
# Dark mode title bar
\$dark=1;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,20,[ref]\$dark,4)

# Orange accent bar
\$bar=New-Object Windows.Forms.Panel
\$bar.Size='4,110'
\$bar.Location=[Drawing.Point]::new(0,0)
\$bar.BackColor=[Drawing.Color]::FromArgb(197,124,94)
\$f.Controls.Add(\$bar)

# Title
\$title=New-Object Windows.Forms.Label
\$title.Text='Claude Code'
\$title.Location=[Drawing.Point]::new(18,14)
\$title.Size='360,22'
\$title.Font=New-Object Drawing.Font('Segoe UI',10.5,[Drawing.FontStyle]::Bold)
\$title.ForeColor=[Drawing.Color]::FromArgb(197,124,94)
\$title.BackColor=[Drawing.Color]::Transparent
\$f.Controls.Add(\$title)

# Body
\$body=New-Object Windows.Forms.Label
\$body.Text=\$text
\$body.Location=[Drawing.Point]::new(18,40)
\$body.Size='368,60'
\$body.Font=New-Object Drawing.Font('Segoe UI',9)
\$body.ForeColor=[Drawing.Color]::FromArgb(220,220,220)
\$body.BackColor=[Drawing.Color]::Transparent
\$f.Controls.Add(\$body)

# Auto close
\$t=New-Object Windows.Forms.Timer
\$t.Interval=10000
\$t.Add_Tick({\$f.Close()})
\$t.Start()

# Click to focus terminal tab
\$click={
Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$CLICK_PS1' -WindowStyle Hidden -EA 0
\$f.Close()}
\$f.Add_Click(\$click)
\$title.Add_Click(\$click)
\$body.Add_Click(\$click)
\$bar.Add_Click(\$click)

[Media.SystemSounds]::Asterisk.Play()
\$f.ShowDialog()
" &>/dev/null &
