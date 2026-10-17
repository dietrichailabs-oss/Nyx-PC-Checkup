using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Web.Script.Serialization;
using Microsoft.Win32;
class Qa26BaselineQualification {
 static List<string> errors=new List<string>();
 static List<Dictionary<string,object>> uninstalls=new List<Dictionary<string,object>>();
 static List<Dictionary<string,object>> startup=new List<Dictionary<string,object>>();
 static bool Nyx(string value){return value!=null&&value.IndexOf("Nyx",StringComparison.OrdinalIgnoreCase)>=0;}
 static void RegistryInventory(RegistryHive hive,RegistryView view) {
  try {using(var root=RegistryKey.OpenBaseKey(hive,view)){
   using(var key=root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall")){
    if(key!=null)foreach(var name in key.GetSubKeyNames())using(var sub=key.OpenSubKey(name)){
     if(sub==null)continue;
     var display=Convert.ToString(sub.GetValue("DisplayName"));
     if(Nyx(display))uninstalls.Add(new Dictionary<string,object>{{"Hive",hive.ToString()},{"View",view.ToString()},{"Key",name},{"DisplayName",display},{"InstallLocation",Convert.ToString(sub.GetValue("InstallLocation"))}});
    }
   }
   using(var key=root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")){
    if(key!=null)foreach(var name in key.GetValueNames()){
     var value=Convert.ToString(key.GetValue(name));
     if(Nyx(name)||Nyx(value))startup.Add(new Dictionary<string,object>{{"Hive",hive.ToString()},{"View",view.ToString()},{"Name",name},{"Value",value}});
    }
   }
  }}catch(Exception e){errors.Add(hive+"/"+view+": "+e.GetType().Name+": "+e.Message);}
 }
 static void Main(){
  var dirs=new List<string>();
  foreach(var baseDir in new[]{Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs"),Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)}){
   try{if(Directory.Exists(baseDir))dirs.AddRange(Directory.GetDirectories(baseDir).Where(p=>Nyx(Path.GetFileName(p))));}catch(Exception e){errors.Add(baseDir+": "+e.GetType().Name+": "+e.Message);}
  }
  RegistryInventory(RegistryHive.CurrentUser,RegistryView.Registry64);
  RegistryInventory(RegistryHive.CurrentUser,RegistryView.Registry32);
  RegistryInventory(RegistryHive.LocalMachine,RegistryView.Registry64);
  RegistryInventory(RegistryHive.LocalMachine,RegistryView.Registry32);
  var identity=WindowsIdentity.GetCurrent();
  var processes=new List<Dictionary<string,object>>();
  foreach(var process in Process.GetProcesses()){
   try{if(Nyx(process.ProcessName)||Nyx(process.MainWindowTitle))processes.Add(new Dictionary<string,object>{{"Pid",process.Id},{"Name",process.ProcessName},{"Title",process.MainWindowTitle}});}catch{}
  }
  var outputDir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NyxQA26BaselineQualification");
  Directory.CreateDirectory(outputDir);
  var output=Path.Combine(outputDir,"baseline_"+DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fffffff")+".json");
  var record=new Dictionary<string,object>{{"Schema","qa26-read-only-baseline-inventory.v1"},{"Utc",DateTime.UtcNow.ToString("o")},{"Computer",Environment.MachineName},{"User",identity.Name},{"Sid",identity.User.Value},{"IsAdministrator",new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator)},{"Os",Environment.OSVersion.ToString()},{"UninstallRecords",uninstalls},{"StartupRecords",startup},{"NyxDirectories",dirs},{"NyxProcesses",processes},{"CollectionErrors",errors},{"CleanQualified",false},{"Note","Read-only observations only. Independent qualification and snapshot mapping still required."},{"ProductModified",false},{"TestsExecuted",false}};
  File.WriteAllText(output,new JavaScriptSerializer().Serialize(record),new UTF8Encoding(false));
  Console.WriteLine("Read-only baseline evidence saved: "+output);
 }
}
