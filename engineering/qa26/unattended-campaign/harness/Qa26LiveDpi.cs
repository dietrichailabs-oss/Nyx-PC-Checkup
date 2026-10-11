using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Qa26LiveDpi {
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left,Top,Right,Bottom; }
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
  [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
  [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
  public static void Main() {
    SetThreadDpiAwarenessContext(new IntPtr(-4));
    string dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NyxQA26NativeDpi");
    Directory.CreateDirectory(dir);
    string path=Path.Combine(dir,"live_"+DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fffffff")+".jsonl");
    using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read))
    using(var writer=new StreamWriter(stream,new UTF8Encoding(false))) {
      Console.WriteLine("Read-only QA DPI observer: "+path);
      for(int i=0;i<240;i++) {
        EnumWindows(delegate(IntPtr h,IntPtr p) {
          var title=new StringBuilder(512);GetWindowText(h,title,title.Capacity);
          if(title.ToString()!="Nyx PC Checkup")return true;
          uint pid;GetWindowThreadProcessId(h,out pid);Rect r;
          if(!GetWindowRect(h,out r))return true;
          writer.WriteLine("{\"Schema\":\"QA26-LIVE-DPI-1\",\"Utc\":\""+DateTime.UtcNow.ToString("o")+"\",\"Pid\":"+pid+",\"NativeDpi\":"+GetDpiForWindow(h)+",\"WindowBounds\":{\"Left\":"+r.Left+",\"Top\":"+r.Top+",\"Right\":"+r.Right+",\"Bottom\":"+r.Bottom+"},\"ProductModified\":false}");
          return true;
        },IntPtr.Zero);
        writer.Flush();Thread.Sleep(5000);
      }
    }
  }
}
