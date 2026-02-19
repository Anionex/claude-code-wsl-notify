#!/bin/bash
# Save active tab index on shell startup, keyed by WT_SESSION
[ -z "$WT_SESSION" ] && exit 0
TAB_NUM=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
\$ts=\$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc);\$i=1
foreach(\$t in \$ts){try{\$sp=\$t.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern)
if(\$sp.Current.IsSelected){Write-Output \$i;exit}}catch{}\$i++}}
Write-Output 0
" 2>/dev/null | tr -d '\r')
[ "$TAB_NUM" -gt 0 ] 2>/dev/null && echo "$TAB_NUM" > "/tmp/cc-tab-$WT_SESSION"
