#!/bin/bash
INPUT=$(cat)

# Extract summary
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // "Claude Code 已完成"' 2>/dev/null)
[ -z "$SUMMARY" ] && SUMMARY="Claude Code 已完成"
SUMMARY="${SUMMARY:0:300}"
B64=$(echo -n "$SUMMARY" | base64 -w 0)

# Read saved tab index, validate against current tab count
TAB_NUM=$(cat "/tmp/cc-tab-$WT_SESSION" 2>/dev/null)
TAB_NUM=${TAB_NUM:-0}
if [ "$TAB_NUM" -gt 0 ] 2>/dev/null; then
    CUR_COUNT=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
Write-Output \$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc).Count}
" 2>/dev/null | tr -d '\r')
    [ "$CUR_COUNT" -lt "$TAB_NUM" ] 2>/dev/null && TAB_NUM=0
fi

# Build tab switch command
TAB_SWITCH=""
if [ "$TAB_NUM" -gt 0 ] 2>/dev/null && [ "$TAB_NUM" -le 9 ] 2>/dev/null; then
    TAB_SWITCH="Start-Sleep -Milliseconds 300;[System.Windows.Forms.SendKeys]::SendWait('^(%${TAB_NUM})')"
fi

# Write notification popup as .ps1 file
cat > /tmp/cc-notify.ps1 << PSEOF
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class W32{
[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
[DllImport("dwmapi.dll")]public static extern int DwmSetWindowAttribute(IntPtr h,int a,ref int v,int s);
}
"@

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

\$pref=2;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,33,[ref]\$pref,4)
\$dark=1;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,20,[ref]\$dark,4)

\$bar=New-Object Windows.Forms.Panel
\$bar.Size='4,110'
\$bar.Location=[Drawing.Point]::new(0,0)
\$bar.BackColor=[Drawing.Color]::FromArgb(197,124,94)
\$f.Controls.Add(\$bar)

\$title=New-Object Windows.Forms.Label
\$title.Text='Claude Code'
\$title.Location=[Drawing.Point]::new(18,14)
\$title.Size='360,22'
\$title.Font=New-Object Drawing.Font('Segoe UI',10.5,[Drawing.FontStyle]::Bold)
\$title.ForeColor=[Drawing.Color]::FromArgb(197,124,94)
\$title.BackColor=[Drawing.Color]::Transparent
\$f.Controls.Add(\$title)

\$body=New-Object Windows.Forms.Label
\$body.Text=\$text
\$body.Location=[Drawing.Point]::new(18,40)
\$body.Size='368,60'
\$body.Font=New-Object Drawing.Font('Segoe UI',9)
\$body.ForeColor=[Drawing.Color]::FromArgb(220,220,220)
\$body.BackColor=[Drawing.Color]::Transparent
\$f.Controls.Add(\$body)

\$t=New-Object Windows.Forms.Timer
\$t.Interval=10000
\$t.Add_Tick({\$f.Close()})
\$t.Start()

\$script:clicked=\$false
\$click={\$script:clicked=\$true;\$f.Close()}
\$f.Add_Click(\$click)
\$title.Add_Click(\$click)
\$body.Add_Click(\$click)
\$bar.Add_Click(\$click)

[Media.SystemSounds]::Asterisk.Play()
\$f.ShowDialog()

if(\$script:clicked){\$p=Get-Process -Name WindowsTerminal -EA 0
if(\$p){[W32]::ShowWindow(\$p[0].MainWindowHandle,9);\$null=[W32]::SetForegroundWindow(\$p[0].MainWindowHandle)
$TAB_SWITCH}}
PSEOF

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w /tmp/cc-notify.ps1)" &>/dev/null &
