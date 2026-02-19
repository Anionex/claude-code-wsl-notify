#!/bin/bash
[ -z "$WT_SESSION" ] && exit 0
TAB_NUM=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
Write-Output \$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc).Count}
" 2>/dev/null | tr -d '\r')
[ "$TAB_NUM" -gt 0 ] 2>/dev/null && echo "$TAB_NUM" > "/tmp/cc-tab-$WT_SESSION"
