using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

// Separate QA harness. Reads native window DPI; never writes product or OS settings.
internal static class Qa26ReadOnlyDpiObserver
{
    private delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr window, out Rect bounds);
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    private static string Quote(string value)
    {
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n") + "\"";
    }
    private static int Main(string[] args)
    {
        if (args.Length != 1 || !Path.IsPathRooted(args[0])) return 2;
        string output = Path.GetFullPath(args[0]);
        if (File.Exists(output)) return 3;
        IntPtr previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        bool aware = previous != IntPtr.Zero;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            using (StreamWriter writer = new StreamWriter(new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.Read), new UTF8Encoding(false)))
            {
                for (int sample = 0; sample < 120; sample++)
                {
                    string utc = DateTime.UtcNow.ToString("o");
                    EnumWindows(delegate(IntPtr window, IntPtr parameter)
                    {
                        if (!IsWindowVisible(window)) return true;
                        StringBuilder title = new StringBuilder(512);
                        GetWindowText(window, title, title.Capacity);
                        if (!String.Equals(title.ToString(), "Nyx PC Checkup", StringComparison.Ordinal)) return true;
                        uint pid;
                        GetWindowThreadProcessId(window, out pid);
                        string process = "unknown";
                        try { process = Process.GetProcessById((int)pid).ProcessName; } catch (ArgumentException) { }
                        Rect bounds;
                        if (!GetWindowRect(window, out bounds)) return true;
                        writer.WriteLine("{\"Schema\":\"QA26-NATIVE-DPI-READONLY-1\",\"Utc\":" + Quote(utc) + ",\"Computer\":" + Quote(Environment.MachineName) + ",\"Title\":" + Quote(title.ToString()) + ",\"Process\":" + Quote(process) + ",\"Pid\":" + pid + ",\"NativeDpi\":" + GetDpiForWindow(window) + ",\"ObserverPerMonitorV2\":" + (aware ? "true" : "false") + ",\"WindowBounds\":{\"Left\":" + bounds.Left + ",\"Top\":" + bounds.Top + ",\"Right\":" + bounds.Right + ",\"Bottom\":" + bounds.Bottom + "},\"ProductModified\":false}");
                        return true;
                    }, IntPtr.Zero);
                    writer.Flush();
                    Thread.Sleep(5000);
                }
            }
            return 0;
        }
        finally
        {
            if (aware) SetThreadDpiAwarenessContext(previous);
        }
    }
}
