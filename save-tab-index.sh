#!/bin/bash
[ -z "$WT_SESSION" ] && exit 0
# Query selected tab index synchronously (tab is guaranteed selected at startup)
TAB_IDX=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
\$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'CASCADIA_HOSTING_WINDOW_CLASS')
\$w = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,\$c)
if(\$w){\$tc = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::TabItem)
\$tabs = \$w.FindAll([Windows.Automation.TreeScope]::Descendants,\$tc)
for(\$i=0;\$i -lt \$tabs.Count;\$i++){\$sp = \$tabs[\$i].GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern)
if(\$sp.Current.IsSelected){Write-Output(\$i+1);break}}}
" 2>/dev/null | tr -d '\r')
[ "$TAB_IDX" -gt 0 ] 2>/dev/null && echo "$TAB_IDX" > "/tmp/cc-tab-$WT_SESSION"
