#!/bin/bash
INPUT=$(cat)

# Extract summary
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // "Claude Code 已完成"' 2>/dev/null)
[ -z "$SUMMARY" ] && SUMMARY="Claude Code 已完成"
SUMMARY="${SUMMARY:0:300}"
B64=$(echo -n "$SUMMARY" | base64 -w 0)

# Get selected tab title via UI Automation (Claude's tab is still selected at hook time)
TAB_TITLE=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
\$tabs = \$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc)
for(\$i=0;\$i -lt \$tabs.Count;\$i++){\$sp = \$tabs[\$i].GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern)
if(\$sp.Current.IsSelected){Write-Output \$tabs[\$i].Current.Name;break}}}
" 2>/dev/null | tr -d '\r')
TITLE_B64=$(echo -n "$TAB_TITLE" | base64 -w 0)

# Write notification popup as .ps1 file
cat > /tmp/cc-notify.ps1 << PSEOF
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class W32{
[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
[DllImport("user32.dll")]public static extern int GetWindowLong(IntPtr h,int i);
[DllImport("user32.dll")]public static extern int SetWindowLong(IntPtr h,int i,int v);
[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
[DllImport("dwmapi.dll")]public static extern int DwmSetWindowAttribute(IntPtr h,int a,ref int v,int s);
}
"@

\$text=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('$B64'))

\$f=New-Object Windows.Forms.Form
\$f.FormBorderStyle='None'
\$f.Size='400,110'
\$f.TopMost=\$false
\$f.StartPosition='Manual'
\$f.ShowInTaskbar=\$false
\$wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
\$f.Location=[Drawing.Point]::new(\$wa.Right-416,\$wa.Bottom-126)
\$f.BackColor=[Drawing.Color]::FromArgb(44,44,46)

\$pref=2;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,33,[ref]\$pref,4)
\$dark=1;\$null=[W32]::DwmSetWindowAttribute(\$f.Handle,20,[ref]\$dark,4)
\$ex=[W32]::GetWindowLong(\$f.Handle,-20);\$null=[W32]::SetWindowLong(\$f.Handle,-20,\$ex -bor 0x08000000)
\$null=[W32]::SetWindowPos(\$f.Handle,[IntPtr]::new(-1),\$f.Left,\$f.Top,\$f.Width,\$f.Height,0x0010)

\$bar=New-Object Windows.Forms.Panel
\$bar.Size='4,110'
\$bar.Location=[Drawing.Point]::new(0,0)
\$bar.BackColor=[Drawing.Color]::FromArgb(197,124,94)
\$f.Controls.Add(\$bar)

\$title=New-Object Windows.Forms.Label
\$title.Text='Claude Code - $TAB_TITLE'
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
[W32]::ShowWindow(\$f.Handle,8)
\$f.Add_FormClosed({[System.Windows.Forms.Application]::ExitThread()})
[System.Windows.Forms.Application]::Run()

if(\$script:clicked){
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$tgt=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('$TITLE_B64'))
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
\$tabs = \$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc)
\$idx=0
for(\$i=0;\$i -lt \$tabs.Count;\$i++){if(\$tabs[\$i].Current.Name -eq \$tgt){\$idx=\$i+1;break}}
\$p=Get-Process -Name WindowsTerminal -EA 0
if(\$p){[W32]::ShowWindow(\$p[0].MainWindowHandle,9);\$null=[W32]::SetForegroundWindow(\$p[0].MainWindowHandle)
if(\$idx -gt 0 -and \$idx -le 9){Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("^(%\$idx)")}}}}
PSEOF

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w /tmp/cc-notify.ps1)" &>/dev/null &
