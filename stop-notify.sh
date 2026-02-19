#!/bin/bash
# Set a unique marker on this tab for identification
MARKER="CC-$$"
echo -ne "\033]0;${MARKER}\007"

INPUT=$(cat)

# Extract summary
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // "Claude Code 已完成"' 2>/dev/null)
[ -z "$SUMMARY" ] && SUMMARY="Claude Code 已完成"
SUMMARY="${SUMMARY:0:300}"
B64=$(echo -n "$SUMMARY" | base64 -w 0)

# Find tab index matching our marker
TAB_INDEX=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
\$ts=\$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc);\$i=0
foreach(\$t in \$ts){if(\$t.Current.Name -like '*${MARKER}*'){Write-Output \$i;exit}\$i++}}
Write-Output -1
" 2>/dev/null | tr -d '\r')
TAB_INDEX=${TAB_INDEX:--1}

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
\$p=Get-Process -Name WindowsTerminal -EA 0
if(\$p){[W32]::ShowWindow(\$p[0].MainWindowHandle,9);[W32]::SetForegroundWindow(\$p[0].MainWindowHandle)
if($TAB_INDEX -ge 0){Start-Process wt.exe -ArgumentList '-w 0 focus-tab --index $TAB_INDEX' -WindowStyle Hidden -EA 0}}
\$f.Close()}
\$f.Add_Click(\$click)
\$title.Add_Click(\$click)
\$body.Add_Click(\$click)
\$bar.Add_Click(\$click)

[Media.SystemSounds]::Asterisk.Play()
\$f.ShowDialog()
" &>/dev/null &
