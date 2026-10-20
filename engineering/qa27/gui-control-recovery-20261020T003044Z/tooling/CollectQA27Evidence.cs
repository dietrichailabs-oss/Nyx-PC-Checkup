using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Web.Script.Serialization;
class CollectQA27Evidence {
 static string Hash(string p) { using(var s=File.OpenRead(p)) using(var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(s)).Replace("-",""); }
 [STAThread] static void Main() {
  Application.EnableVisualStyles();
  string media=AppDomain.CurrentDomain.BaseDirectory;
  string root=Path.Combine(media,"evidence",DateTime.UtcNow.ToString("yyyyMMddTHHmmssfffZ")+"-collector-"+Guid.NewGuid().ToString("N"));
  Directory.CreateDirectory(root);
  var result=new Dictionary<string,object>(); var files=new List<object>();
  result["Schema"]="QA27_POST_GUI_READONLY_COLLECTION_1"; result["Utc"]=DateTime.UtcNow.ToString("o"); result["Machine"]=Environment.MachineName;
  try {
   string appdata=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),@"Dietrich AI Labs\Nyx PC Checkup");
   var sources=new List<string>();
   foreach(string relative in new string[]{@"scans\last-scan.json","config.json",@"actions\history.jsonl"}) { string p=Path.Combine(appdata,relative); if(File.Exists(p)) sources.Add(p); }
   string logs=Path.Combine(appdata,"logs"); if(Directory.Exists(logs)) sources.AddRange(Directory.GetFiles(logs,"*",SearchOption.TopDirectoryOnly));
   string copyRoot=Path.Combine(root,"appdata"); Directory.CreateDirectory(copyRoot);
   foreach(string source in sources) {
    string relative=source.Substring(appdata.Length+1); string dest=Path.Combine(copyRoot,relative); Directory.CreateDirectory(Path.GetDirectoryName(dest));
    File.Copy(source,dest,false); files.Add(new {relativePath=relative,bytes=new FileInfo(source).Length,sha256=Hash(source),copiedSHA256=Hash(dest)});
   }
   result["AppDataCopies"]=files;
   string pdf=Path.Combine(media,@"EXPORT\F024_QA27_GUI.pdf"); result["PdfPath"]=pdf; result["PdfExists"]=File.Exists(pdf);
   if(File.Exists(pdf)) { byte[] bytes=File.ReadAllBytes(pdf); result["PdfBytes"]=bytes.Length; result["PdfSHA256"]=Hash(pdf); result["PdfHeader"]=Encoding.ASCII.GetString(bytes,0,Math.Min(16,bytes.Length)); }
   result["ProductLaunchPerformed"]=false; result["ScriptOrModuleExecution"]=false; result["ProductOrSecurityWrites"]=false;
   result["Collected"]=true;
  } catch(Exception e) { result["Collected"]=false; result["Error"]=e.ToString(); }
  result["CompletedUtc"]=DateTime.UtcNow.ToString("o");
  string json=new JavaScriptSerializer().Serialize(result);
  using(var stream=new FileStream(Path.Combine(root,"COLLECTION.json"),FileMode.CreateNew)) using(var writer=new StreamWriter(stream,new UTF8Encoding(false))) writer.Write(json);
  var form=new Form {Text="QA27 read-only evidence collection",Width=850,Height=600};
  form.Controls.Add(new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,Text=json}); Application.Run(form);
 }
}
