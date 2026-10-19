using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Automation;

// One-shot local GUI instrument. No service, network, registry writes, scripts,
// terminal-window input, or product writes. Only the existing Nyx WinForms GUI.
class NyxGuiProbe {
  const int Pid=3288;
  const string Root=@"C:\Users\Nyx\Desktop\Nyx-QA26-Codex-20261018_121140\continuation\vm-local-20261018T161926Z";
  [StructLayout(LayoutKind.Sequential)] struct RECT {public int L,T,R,B;}
  [StructLayout(LayoutKind.Sequential)] struct KEY {public ushort vk,scan;public uint flags,time;public UIntPtr extra;}
  [StructLayout(LayoutKind.Sequential)] struct MOUSE {public int x,y;public uint data,flags,time;public UIntPtr extra;}
  [StructLayout(LayoutKind.Explicit)] struct UNION {[FieldOffset(0)]public KEY k;[FieldOffset(0)]public MOUSE m;}
  [StructLayout(LayoutKind.Sequential)] struct INPUT {public uint type;public UNION u;}
  [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr h,StringBuilder s,int n);
  [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr h,out RECT r);
  [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")]static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")]static extern bool ShowWindow(IntPtr h,int n);
  [DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")]static extern IntPtr SetThreadDpiAwarenessContext(IntPtr h);
  [DllImport("user32.dll")]static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")]static extern uint SendInput(uint count,INPUT[] inputs,int size);
  [DllImport("user32.dll")]static extern IntPtr WindowFromPoint(System.Drawing.Point p);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool OpenProcessToken(IntPtr h,uint a,out IntPtr token);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool GetTokenInformation(IntPtr h,int cls,out int value,int len,out int returned);
  [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
  static bool Elevated(Process p) {IntPtr t;if(!OpenProcessToken(p.Handle,8,out t))throw new Exception("Cannot read token elevation");try{int v,n;if(!GetTokenInformation(t,20,out v,4,out n))throw new Exception("Cannot qualify token");return v!=0;}finally{CloseHandle(t);}}
  static string Hash(string p){using(var s=File.OpenRead(p))using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(s)).Replace("-","");}
  static string Text(IntPtr h){var b=new StringBuilder(512);GetWindowText(h,b,512);return b.ToString();}
  static string Class(IntPtr h){var b=new StringBuilder(512);GetClassName(h,b,512);return b.ToString();}
  static void Validate(IntPtr h){uint pid;GetWindowThreadProcessId(h,out pid);var p=Process.GetProcessById(Pid);if(pid!=Pid||p.SessionId!=3||Text(h)!="Nyx PC Checkup"||!Class(h).StartsWith("WindowsForms10.Window"))throw new Exception("Exact Nyx WinForms target guard failed");if(!String.Equals(p.MainModule.FileName,@"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",StringComparison.OrdinalIgnoreCase))throw new Exception("Host identity changed");if(Elevated(p)||Elevated(Process.GetCurrentProcess()))throw new Exception("Non-elevated execution prerequisite failed");}
  static void Activate(IntPtr h){Validate(h);if(IsIconic(h))ShowWindow(h,9);SetForegroundWindow(h);Thread.Sleep(250);if(GetForegroundWindow()!=h)throw new Exception("Nyx foreground activation did not qualify");}
  static void Inputs(INPUT[] a){if(SendInput((uint)a.Length,a,Marshal.SizeOf(typeof(INPUT)))!=a.Length)throw new Exception("Native input did not complete");}
  static INPUT Key(ushort vk,bool up){return new INPUT{type=1,u=new UNION{k=new KEY{vk=vk,flags=up?2u:0u}}};}
  static void Keys(string s){ushort mod=0,key;switch(s){case "TAB":key=9;break;case "SHIFT+TAB":mod=16;key=9;break;case "CTRL+TAB":mod=17;key=9;break;case "DOWN":key=40;break;case "UP":key=38;break;case "LEFT":key=37;break;case "RIGHT":key=39;break;case "HOME":key=36;break;case "END":key=35;break;case "ESC":key=27;break;case "ENTER":key=13;break;case "SPACE":key=32;break;default:throw new Exception("Key is outside the limited navigation whitelist");}var a=new List<INPUT>();if(mod!=0)a.Add(Key(mod,false));a.Add(Key(key,false));a.Add(Key(key,true));if(mod!=0)a.Add(Key(mod,true));Inputs(a.ToArray());}
  static Dictionary<string,object> Element(AutomationElement e){var c=e.Current;var r=c.BoundingRectangle;return new Dictionary<string,object>{{"Name",c.Name},{"AutomationId",c.AutomationId},{"Type",c.ControlType.ProgrammaticName},{"Class",c.ClassName},{"Enabled",c.IsEnabled},{"Offscreen",c.IsOffscreen},{"Focused",c.HasKeyboardFocus},{"X",r.X},{"Y",r.Y},{"Width",r.Width},{"Height",r.Height}};}
  [STAThread] static int Main(string[] args){try{
    if(args.Length<3)throw new Exception("Expected window handle, command, capture label");
    SetThreadDpiAwarenessContext(new IntPtr(-4));var h=new IntPtr(long.Parse(args[0]));Validate(h);
    string cmd=args[1],label=args[2];if(!System.Text.RegularExpressions.Regex.IsMatch(label,@"^[a-zA-Z0-9_-]+$"))throw new Exception("Invalid evidence label");
    var started=DateTime.UtcNow;Activate(h);uint beforeDpi=GetDpiForWindow(h);
    if(cmd=="key"){if(args.Length!=4)throw new Exception("Missing key");Keys(args[3]);}
    else if(cmd=="click"){if(args.Length!=5)throw new Exception("Missing point");RECT r;GetWindowRect(h,out r);int x=r.L+int.Parse(args[3]),y=r.T+int.Parse(args[4]);uint pointPid;GetWindowThreadProcessId(WindowFromPoint(new Point(x,y)),out pointPid);if(pointPid!=Pid)throw new Exception("Click point is not on the exact Nyx process");SetCursorPos(x,y);Inputs(new INPUT[]{new INPUT{type=0,u=new UNION{m=new MOUSE{flags=2}}},new INPUT{type=0,u=new UNION{m=new MOUSE{flags=4}}}});}
    else if(cmd!="inspect")throw new Exception("Command is outside the one-shot GUI whitelist");
    Thread.Sleep(300);Validate(h);if(GetForegroundWindow()!=h)throw new Exception("Foreground changed; action not qualified");
    RECT bounds;if(!GetWindowRect(h,out bounds)||IsIconic(h)||!IsWindowVisible(h))throw new Exception("Visible window bounds unavailable");
    string stem=label+"_"+DateTime.UtcNow.ToString("yyyyMMddTHHmmssfffffffZ")+"_"+Guid.NewGuid().ToString("N");string png=Path.Combine(Root,stem+".png");if(File.Exists(png))throw new Exception("Capture overwrite refused");
    var captureStart=DateTime.UtcNow;using(var image=new Bitmap(bounds.R-bounds.L,bounds.B-bounds.T)){using(var g=Graphics.FromImage(image))g.CopyFromScreen(bounds.L,bounds.T,0,0,image.Size);image.Save(png,ImageFormat.Png);}var captureEnd=DateTime.UtcNow;
    var tree=new List<Dictionary<string,object>>();var root=AutomationElement.FromHandle(h);var elements=root.FindAll(TreeScope.Descendants,new PropertyCondition(AutomationElement.IsOffscreenProperty,false));for(int i=0;i<elements.Count&&i<650;i++){try{var row=Element(elements[i]);row["Index"]=i;tree.Add(row);}catch{}}
    object focus=null;try{var focused=AutomationElement.FocusedElement;if(focused!=null&&focused.Current.ProcessId==Pid)focus=Element(focused);}catch{}
    var receipt=new Dictionary<string,object>{{"Schema","QA26-ONE-SHOT-NYX-GUI-1"},{"StartedUtc",started.ToString("o")},{"CaptureStartedUtc",captureStart.ToString("o")},{"CaptureEndedUtc",captureEnd.ToString("o")},{"Pid",Pid},{"SessionId",3},{"WindowHandle",h.ToInt64()},{"WindowTitle",Text(h)},{"WindowClass",Class(h)},{"Command",cmd},{"Arguments",args},{"BeforeNativeDpi",beforeDpi},{"AfterNativeDpi",GetDpiForWindow(h)},{"Bounds",new[]{bounds.L,bounds.T,bounds.R,bounds.B}},{"IsMinimized",IsIconic(h)},{"TargetElevated",false},{"HelperElevated",false},{"ForegroundVerified",true},{"Screenshot",png},{"ScreenshotSHA256",Hash(png)},{"ScreenshotReused",false},{"FocusedElement",focus},{"VisibleElements",tree},{"ProductModifiedByHelper",false},{"WindowsPolicyModified",false}};
    string json=new JavaScriptSerializer{MaxJsonLength=2000000}.Serialize(receipt);string output=Path.Combine(Root,stem+".json");using(var stream=new FileStream(output,FileMode.CreateNew,FileAccess.Write))using(var writer=new StreamWriter(stream,new UTF8Encoding(false)))writer.Write(json);Console.WriteLine(output);return 0;
  }catch(Exception e){Console.Error.WriteLine(e.ToString());return 1;}}
}
