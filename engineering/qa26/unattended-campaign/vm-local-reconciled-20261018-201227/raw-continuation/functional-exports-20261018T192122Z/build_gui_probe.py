"""Rebind the previously authorized one-shot Nyx instrument to this session.
Adds only the product's owned export preview/save windows and two fixed output
filenames. It never imports or executes product modules, scripts, or suites.
"""
from pathlib import Path
O=Path(__file__).parent
old=O.parent/'remaining-recovery-20261018T180919Z/NyxGuiProbe.cs'
s=old.read_text(encoding='utf-8-sig')
s=s.replace('const int Pid=7504;','const int Pid=11392;')
s=s.replace('remaining-recovery-20261018T180919Z','functional-exports-20261018T192122Z')
s=s.replace('459616','66444').replace('p.SessionId!=2','p.SessionId!=1').replace('{"SessionId",2}','{"SessionId",1}')
lines=s.splitlines()
for i,line in enumerate(lines):
 if line.strip().startswith('static void Validate('):
  lines[i]='''  static void Validate(IntPtr h){uint pid;GetWindowThreadProcessId(h,out pid);var p=Process.GetProcessById(Pid);string title=Text(h),cl=Class(h);bool main=h.ToInt64()==66444&&cl.StartsWith("WindowsForms10.Window")&&title=="Nyx PC Checkup";bool owned=GetWindow(h,4).ToInt64()==66444;bool preview=owned&&cl.StartsWith("WindowsForms10.Window")&&title=="Review report before export";bool save=owned&&cl=="#32770"&&title=="Export privacy-safe Nyx PC Checkup report";bool modal=owned&&cl=="#32770"&&title=="Nyx PC Checkup";if(pid!=Pid||p.SessionId!=1||(!main&&!preview&&!save&&!modal))throw new Exception("Exact Nyx export/main/owned-message guard failed");if(!String.Equals(p.MainModule.FileName,@"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",StringComparison.OrdinalIgnoreCase))throw new Exception("Host identity changed");if(Elevated(p)||Elevated(Process.GetCurrentProcess()))throw new Exception("Non-elevated execution prerequisite failed");}'''
  break
else:raise RuntimeError('Validator not found')
s='\n'.join(lines)+'\n'
needle='    if(cmd=="key")'
assert s.count(needle)==1
branch='''    if(cmd=="filename"){if(args.Length!=4||Class(h)!="#32770"||Text(h)!="Export privacy-safe Nyx PC Checkup report")throw new Exception("Filename requires exact Nyx save dialog");string name=args[3];if(name!="report-native-txt.txt"&&name!="report-native-pdf.pdf")throw new Exception("Filename outside fixed test outputs");string path=Path.Combine(Root,name);if(File.Exists(path))throw new Exception("Export overwrite refused");var root=AutomationElement.FromHandle(h);var matches=root.FindAll(TreeScope.Descendants,new AndCondition(new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Edit),new PropertyCondition(AutomationElement.AutomationIdProperty,"1001")));if(matches.Count!=1)throw new Exception("Exact filename edit not unique");var edit=matches[0];if(edit.Current.ProcessId!=Pid||!edit.Current.IsEnabled)throw new Exception("Filename edit identity failed");edit.SetFocus();object pattern;if(!edit.TryGetCurrentPattern(ValuePattern.Pattern,out pattern))throw new Exception("Filename edit lacks value pattern");((ValuePattern)pattern).SetValue(path);}
    else if(cmd=="key")'''
s=s.replace(needle,branch)
p=O/'NyxExportProbe.cs'
if p.exists():raise RuntimeError('Refuse overwrite')
p.write_text(s,encoding='utf-8')
print(p)
