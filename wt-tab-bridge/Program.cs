using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows.Automation;

internal static class Program
{
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    private const int SW_RESTORE = 9;

    private static string MappingPath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "wt-tab-bridge", "mapping.json");

    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Length < 3 || args[1] != "--session")
            return Usage();

        var cmd = args[0].ToLowerInvariant();
        var session = args[2];

        try
        {
            return cmd switch
            {
                "register" => Register(session),
                "focus" => Focus(session),
                _ => Usage()
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 2;
        }
    }

    private static int Usage()
    {
        Console.Error.WriteLine("Usage: wt-tab-bridge register|focus --session <WT_SESSION>");
        return 1;
    }

    private static int Register(string session)
    {
        var (wtWindow, selectedTab) = FindSelectedTabInAnyWtWindow();
        if (wtWindow == null || selectedTab == null)
        {
            Console.Error.WriteLine("No selected TabItem found in any Windows Terminal window.");
            return 3;
        }

        var map = ReadMapping();
        map[session] = new TabEntry
        {
            RuntimeId = selectedTab.GetRuntimeId(),
            WindowHandle = wtWindow.Current.NativeWindowHandle
        };
        WriteMapping(map);
        return 0;
    }

    private static int Focus(string session)
    {
        var map = ReadMapping();
        if (!map.TryGetValue(session, out var entry))
        {
            Console.Error.WriteLine("No mapping for this session.");
            return 5;
        }

        var hwnd = (IntPtr)entry.WindowHandle;
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);

        AutomationElement? wtWindow = null;
        try { wtWindow = AutomationElement.FromHandle(hwnd); } catch { }

        if (wtWindow == null)
        {
            Console.Error.WriteLine("Window handle invalid.");
            return 6;
        }

        var target = FindTabByRuntimeId(wtWindow, entry.RuntimeId);
        if (target == null)
        {
            Console.Error.WriteLine("Tab not found by RuntimeId.");
            return 7;
        }

        if (target.TryGetCurrentPattern(SelectionItemPattern.Pattern, out var p)
            && p is SelectionItemPattern sel)
        {
            sel.Select();
            SetForegroundWindow(hwnd);
            return 0;
        }

        Console.Error.WriteLine("SelectionItemPattern unavailable.");
        return 8;
    }

    private static (AutomationElement? window, AutomationElement? tab) FindSelectedTabInAnyWtWindow()
    {
        var fgHwnd = GetForegroundWindow();
        var cond = new PropertyCondition(AutomationElement.ClassNameProperty, "CASCADIA_HOSTING_WINDOW_CLASS");
        var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, cond);

        // Prefer the foreground WT window
        AutomationElement? fgWindow = null;
        foreach (AutomationElement w in windows)
        {
            if ((IntPtr)w.Current.NativeWindowHandle == fgHwnd)
            { fgWindow = w; break; }
        }

        // Search foreground window first, then others
        var ordered = new List<AutomationElement>();
        if (fgWindow != null) ordered.Add(fgWindow);
        foreach (AutomationElement w in windows)
            if (w != fgWindow) ordered.Add(w);

        foreach (var w in ordered)
        {
            var tab = FindSelectedTab(w);
            if (tab != null) return (w, tab);
        }
        return (null, null);
    }

    private static AutomationElement? FindSelectedTab(AutomationElement window)
    {
        var cond = new AndCondition(
            new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem),
            new PropertyCondition(SelectionItemPattern.IsSelectedProperty, true));
        return window.FindFirst(TreeScope.Descendants, cond);
    }

    private static AutomationElement? FindTabByRuntimeId(AutomationElement window, int[] runtimeId)
    {
        var cond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
        var tabs = window.FindAll(TreeScope.Descendants, cond);
        foreach (AutomationElement tab in tabs)
        {
            try
            {
                if (tab.GetRuntimeId().AsSpan().SequenceEqual(runtimeId))
                    return tab;
            }
            catch { }
        }
        return null;
    }

    private static Dictionary<string, TabEntry> ReadMapping()
    {
        try
        {
            if (!File.Exists(MappingPath)) return new();
            var json = File.ReadAllText(MappingPath);
            return JsonSerializer.Deserialize<Dictionary<string, TabEntry>>(json) ?? new();
        }
        catch { return new(); }
    }

    private static void WriteMapping(Dictionary<string, TabEntry> map)
    {
        var dir = Path.GetDirectoryName(MappingPath)!;
        Directory.CreateDirectory(dir);
        var tmp = MappingPath + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(map));
        File.Move(tmp, MappingPath, overwrite: true);
    }
}

internal class TabEntry
{
    public int[] RuntimeId { get; set; } = Array.Empty<int>();
    public int WindowHandle { get; set; }
}