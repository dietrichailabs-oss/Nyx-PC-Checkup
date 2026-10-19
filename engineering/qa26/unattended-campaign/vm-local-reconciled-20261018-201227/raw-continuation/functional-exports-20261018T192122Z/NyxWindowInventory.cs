using System;using System.Text;using System.Runtime.InteropServices;using System.Collections.Generic;using System.Web.Script.Serialization;
class NyxWindowInventory {
 delegate bool Callback(IntPtr h,IntPtr p);
 [DllImport("user32.dll")]static extern bool EnumWindows(Callback c,IntPtr p);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")]static extern IntPtr GetWindow(IntPtr h,uint k);
 [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr h,out RECT r);
 [StructLayout(LayoutKind.Sequential)]struct RECT{public int L,T,R,B;}
 static void Main(){var rows=new List<object>();EnumWindows(delegate(IntPtr h,IntPtr unused){uint p;GetWindowThreadProcessId(h,out p);if(p==11392){var t=new StringBuilder(512);var c=new StringBuilder(256);GetWindowText(h,t,512);GetClassName(h,c,256);RECT r;GetWindowRect(h,out r);rows.Add(new{Handle=h.ToInt64(),Pid=p,Title=t.ToString(),Class=c.ToString(),Visible=IsWindowVisible(h),Owner=GetWindow(h,4).ToInt64(),Bounds=new[]{r.L,r.T,r.R,r.B}});}return true;},IntPtr.Zero);Console.WriteLine(new JavaScriptSerializer().Serialize(rows));}
}
