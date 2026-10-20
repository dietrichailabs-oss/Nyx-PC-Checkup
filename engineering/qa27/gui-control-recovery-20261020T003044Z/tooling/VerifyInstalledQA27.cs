using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using Microsoft.Win32;
class Entry { public string Path; public long Size; public string SHA256; }
class VerifyInstalledQA27 {
static Entry[] expected = new Entry[] {
new Entry { Path = @"app/actions/CleanupActions.psm1", Size = 7698L, SHA256 = "3D2763691EA91E945F111834850D753DE03786D3567BC7C19F302309D580E818" },
new Entry { Path = @"app/actions/StartupActions.psm1", Size = 23593L, SHA256 = "FB5CA080DF4DB55B4B1E66A776C0A042949BC1AD05EF26C9FC034230090E9BA7" },
new Entry { Path = @"app/assets/brand_banner.png", Size = 4630L, SHA256 = "838733D426505D0A62A5700FC8E3CA0386B3D79AE2B5BDE3B6B1C4E8EEBC0831" },
new Entry { Path = @"app/assets/nyx_pc_checkup.ico", Size = 25277L, SHA256 = "2070830BFC4B9ABE31263E129F1B27EAEF7A468DF0D0CC4739A06B55FEA20DB5" },
new Entry { Path = @"app/assets/nyx_pc_checkup.png", Size = 3315L, SHA256 = "6DC3691C601AB6DABF65EC7C954CF1E1D90DC7EA92F0BE06042920F7D9C91DD0" },
new Entry { Path = @"app/checks/BackupStatus.psm1", Size = 4361L, SHA256 = "A819904D6C1CE7B60E6E88D61F56EF0A411ACDE1D1AA0D519E116FE6B18C5439" },
new Entry { Path = @"app/checks/BatteryHealth.psm1", Size = 3040L, SHA256 = "4013F5E2E4E253959710E9CFE925F0C298C57E5669439FA43B9E3E27AC524964" },
new Entry { Path = @"app/checks/CleanupScan.psm1", Size = 11430L, SHA256 = "8015C91F003E65A2233C61FF5C9E293D8DCF52FFFC177A8192B47F89BAB45B80" },
new Entry { Path = @"app/checks/DownloadsAnalysis.psm1", Size = 7880L, SHA256 = "58FE4E8F62C036CD5D9C407F527DD3E6C6BD120279895372BF092C19E4438575" },
new Entry { Path = @"app/checks/DriveHealth.psm1", Size = 3404L, SHA256 = "471D2D08D7BA622C34E493EE316B9456AB9A0D64433236F1FAC9F888D43A8380" },
new Entry { Path = @"app/checks/InstalledApps.psm1", Size = 4246L, SHA256 = "A9EE906E9745B66C78CB484AA61BA2E927A9AF98FCB24A68644E2106C7773088" },
new Entry { Path = @"app/checks/NetworkBasics.psm1", Size = 4637L, SHA256 = "4CC80A052A05B339612785B0CC273750F753C11069C7C9DDBABBEADAEC81CACA" },
new Entry { Path = @"app/checks/PerformanceSnapshot.psm1", Size = 3321L, SHA256 = "954AC20704AF707298C09D01FC6F7A3ABE2DFE86922B53D809EB553B557B94C9" },
new Entry { Path = @"app/checks/SecurityStatus.psm1", Size = 9901L, SHA256 = "A7E53FC347B20BD072B3D8BB476D5869CD4EFEDDA4F150334D921C3014F8ABD2" },
new Entry { Path = @"app/checks/StartupApps.psm1", Size = 7975L, SHA256 = "A3BF1C9C2A2B0194D1AA9BB2B3E3646B98AAE3531D40CAFC7343B5BEEE6CA5E0" },
new Entry { Path = @"app/checks/StorageHealth.psm1", Size = 1276L, SHA256 = "9DBA9F34B28861BE6D362FCE54CEBC6876D44DEB2C295A8CFA126E8A43C27544" },
new Entry { Path = @"app/checks/StorageScan.psm1", Size = 6839L, SHA256 = "47DA18FCD8DE236F5211672A3B6AA987459415D24DC4FEDB93D058F5B8F7BCD2" },
new Entry { Path = @"app/checks/SystemInfo.psm1", Size = 2636L, SHA256 = "8383172EDD03D90162A56D1EAB53A1D3A3198303FA75BD24299CAD76C3CE5F08" },
new Entry { Path = @"app/checks/Uptime.psm1", Size = 1131L, SHA256 = "E270CA39621131056962C15E75C11B8A24F6D502A5D59FFB36A9DE1E04DECAF5" },
new Entry { Path = @"app/checks/WindowsUpdates.psm1", Size = 4838L, SHA256 = "D42F6D7AAF32ABE8BC4DFB5BC8ECACE1CC100790E91208203F9872F55C03C05C" },
new Entry { Path = @"app/config/defaults.json", Size = 441L, SHA256 = "EA3D505979D4792D6FE3D32B0B75834211574C248515097A8E1A4C6CBA66501D" },
new Entry { Path = @"app/core/ActionHistory.psm1", Size = 24323L, SHA256 = "181843C2A529DE3B9FC06EC64A93BA3DA9DC49C1A39168886AC3EF21448DF817" },
new Entry { Path = @"app/core/CheckupEngine.psm1", Size = 7493L, SHA256 = "BCBDC2725733460205F80DF585B164C2F01F71E59FDACD8D1B2726C3F5CB7C67" },
new Entry { Path = @"app/core/Configuration.psm1", Size = 7186L, SHA256 = "9EFD47D4407553F75B3A30543A49D309B29C046494334B3FB25828B3A107AF97" },
new Entry { Path = @"app/core/Diagnostics.psm1", Size = 1887L, SHA256 = "CB0AF8AF0360C8A2CE731E30A366BCF4CA39B210B777F12819B0B36263A99BEC" },
new Entry { Path = @"app/core/Models.psm1", Size = 4239L, SHA256 = "8119E0EDD20E5161EDF5CE6C0B3AFFC914A9CEDE62AD638060F4000EAAC04824" },
new Entry { Path = @"app/core/Paths.psm1", Size = 5169L, SHA256 = "0CED0B71630EDF87032A7DA7619C313D740B426CAE50DEE9C1B5B2358ABB54B0" },
new Entry { Path = @"app/core/Privacy.psm1", Size = 6541L, SHA256 = "52FAA40B26D7C35714709B09BEA50ACC031F2163595607F08BFFBCBC663067BE" },
new Entry { Path = @"app/core/RuntimeComposition.psm1", Size = 14901L, SHA256 = "5E89BFBC6A70E7514D8CD85079B4040348329EC0D993CD6FE440E4D29FA4865B" },
new Entry { Path = @"app/health_rules/HealthRules.psm1", Size = 4696L, SHA256 = "B3C3F55DCE4502B32C9247BF6B7FA78DFB80447DB3E23B40DAF96902C5EFE592" },
new Entry { Path = @"app/health_rules/rules.json", Size = 751L, SHA256 = "A0003C4D2977C7F464F522C5A15F08942091FB840028D523689FB8CF34B1401C" },
new Entry { Path = @"app/NyxPCCheckup.ps1", Size = 6371L, SHA256 = "129D38D8E1EE6C7FFF964B6AC698C1443A82B9856257BCB162C3157ACDDF394A" },
new Entry { Path = @"app/platform/windows/WindowsHelpers.psm1", Size = 6557L, SHA256 = "6D053601785204A09679683E0232F83FFD596D78CFA20649E01E2EBE8DFA4689" },
new Entry { Path = @"app/reports/PdfWriter.psm1", Size = 4231L, SHA256 = "6A8D4BC8BCC3D967B1C9D7C7B6391CE958CE45AC2E1C9F1656C0F2CB72AFC2A0" },
new Entry { Path = @"app/reports/ReportExport.psm1", Size = 6588L, SHA256 = "0A1E6B993B3F2FD0AEDD02577C6FB287DD8B3A562CB40B6F944795418AAEC7C0" },
new Entry { Path = @"app/ui/Controls.psm1", Size = 14664L, SHA256 = "9319FDA87F200AA3EF68B3317CBE267B7DB67FCCB0BC5D4383A56E47322F6D15" },
new Entry { Path = @"app/ui/Dialogs.psm1", Size = 5837L, SHA256 = "1D31559BEBEC544C8CF665DCFAA1FEA53B11A90D077FBC1373825707322E0F5A" },
new Entry { Path = @"app/ui/MainWindow.psm1", Size = 72099L, SHA256 = "EDFB18A824FB6CA771FDCB3521172F49E3EEB356924ED1D8EF3F0CADD99BDA24" },
new Entry { Path = @"app/ui/Theme.psm1", Size = 2715L, SHA256 = "CE1BB75D8971936FFB6868FD5D02A3A7A8B762F85987C8DF7A6002CBC0511ECE" },
new Entry { Path = @"app/updates/Manifest.psm1", Size = 6298L, SHA256 = "22709914366DA8E77A80BE3F6DE0D85F51A8E918D00E25D9A6D8497662D5D3A9" },
new Entry { Path = @"app/updates/Preferences.psm1", Size = 1141L, SHA256 = "6043B33394DC200CB6540546D8907F7AEBC75A6E21094D977C46577BD86D49AD" },
new Entry { Path = @"app/updates/UpdateChecker.psm1", Size = 6066L, SHA256 = "46CF76DE6547CEEE821CEA6B0D4B11E6A40EBD51F0071C1701E4469034290C67" },
new Entry { Path = @"app/updates/Versioning.psm1", Size = 2769L, SHA256 = "780CA587E4B99C791F18137A05392A36AF681ACCC761B39C8652FC6D52BEFD7B" },
new Entry { Path = @"app/workers/ActionWorker.ps1", Size = 5226L, SHA256 = "06549072100A92F5FB69BEE583672EFDDFF92BC55B93C54ABC06ECE95B57CBB5" },
new Entry { Path = @"app/workers/InstallWorker.ps1", Size = 9588L, SHA256 = "A72299DA0293C774359C9E88A09A816D85114CA21E89831DA4938703E6381496" },
new Entry { Path = @"app/workers/ScanWorker.ps1", Size = 8950L, SHA256 = "9AD1CBFDB62432135E9226F4855D29D4279054E3093D7152C0A2C8971B7DEC36" },
new Entry { Path = @"app/workers/UninstallWorker.ps1", Size = 8377L, SHA256 = "E0948EEA0757DD42E820E82BE31B89B3A5A146CB278C4F61227FFDC012EF8FA2" },
new Entry { Path = @"app/workers/UpdateCheckWorker.ps1", Size = 2426L, SHA256 = "2ED15D184412C8644CB31A654B52C405ABD09D32F52B6A17779FEC9ACE1F79C5" },
new Entry { Path = @"docs/INSTALL_UPGRADE_UNINSTALL.md", Size = 4807L, SHA256 = "1877AD1B7C55E309BDE508C49853F3DAA67F73A35A19E4CB30EC8CA88A88A814" },
new Entry { Path = @"docs/KNOWN_LIMITATIONS.md", Size = 1949L, SHA256 = "F40ED51F5C7CD836F1CC2CD87F224A0AB75E336D47F07E5D5D8DC3B1907DD050" },
new Entry { Path = @"docs/PRIVACY_AND_SECURITY.md", Size = 5804L, SHA256 = "17917D54E889D6457AB3AFAA430C4AD390C4F05D8D3B61D7CE5B693B6A9D762A" },
new Entry { Path = @"docs/USER_GUIDE.md", Size = 5028L, SHA256 = "EEEB22BEFD6E3A1321F086902A04A4840DDB185A5E5D4A839BDFE0D4753B0D9A" },
new Entry { Path = @"LICENSE.txt", Size = 480L, SHA256 = "50719D42D0EB72DBB801F2FCB9C9DF0AB1623F8FA409656ED2ABCE8985FF51E0" },
new Entry { Path = @"Nyx PC Checkup.exe", Size = 33280L, SHA256 = "190253A8413FEBAD7163076ACA8DBEAB159F2E3B3E645FDCC95C3252292BE517" },
new Entry { Path = @"README_FIRST.md", Size = 1930L, SHA256 = "6A90F92BE8C13E6F5774E366AB39B364F4651A157344C9AC1B6CA3D1B3ACEC30" },
new Entry { Path = @"SBOM.json", Size = 3096L, SHA256 = "FD12BB98120B39F78869302EE6FCEFC90E7E0FE2CF762E155B787441C4BD8692" },
new Entry { Path = @"THIRD_PARTY_NOTICES.txt", Size = 562L, SHA256 = "17C334F0C09680A6E41572F086F6DC520972239CD0EAEC0B472233570DD2EF49" },
new Entry { Path = @"Uninstall Nyx PC Checkup.exe", Size = 35328L, SHA256 = "A18A832251383CA88AFCEDA57D2713269F8082DD8B13D3D83FDC15C1206CD127" },
new Entry { Path = @"VERSION.json", Size = 305L, SHA256 = "73D245FA794DC1B6EE4514DEFC3437E4D815670472BC4D8EA150FC727FCD5CFF" }
};
static string Hash(string path) { using(var stream=File.OpenRead(path)) using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-",""); }
[STAThread] static void Main() {
Application.EnableVisualStyles();
var report=new Dictionary<string,object>(); var results=new List<object>(); bool all=true; string output=null;
try {
string install=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),@"Programs\Dietrich AI Labs\Nyx PC Checkup");
string media=AppDomain.CurrentDomain.BaseDirectory;
output=Path.Combine(media,"evidence",DateTime.UtcNow.ToString("yyyyMMddTHHmmssfffZ")+"-"+Guid.NewGuid().ToString("N")); Directory.CreateDirectory(output);
report["Schema"]="QA27_INSTALLED_PAYLOAD_READONLY_PREFLIGHT_1"; report["Utc"]=DateTime.UtcNow.ToString("o");
report["Machine"]=Environment.MachineName; report["User"]=Environment.UserName; report["OS"]=Environment.OSVersion.ToString(); report["InstallRoot"]=install; report["ExpectedBuild"]="2026.10.19-eng-qa27"; report["ExpectedHarness"]="QA27-F024-PS51-27"; report["SourceCommit"]="ee357ca33dbb87653924c6def90ff29a38898fdb";
string manifest=Path.Combine(install,"PAYLOAD_MANIFEST.json"); string mh=File.Exists(manifest)?Hash(manifest):"MISSING";
report["ManifestSHA256"]=mh; all=mh=="5DCD0BBAA3F5BE1AE853B5A3D43C72D88586AB6E1A8C346BBC11827457A52F89";
foreach(var entry in expected) { string path=Path.GetFullPath(Path.Combine(install,entry.Path.Replace('/',Path.DirectorySeparatorChar))); bool exists=File.Exists(path); string actual=exists?Hash(path):"MISSING"; long size=exists?new FileInfo(path).Length:0; bool match=exists&&size==entry.Size&&actual==entry.SHA256; all=all&&match; results.Add(new {path=entry.Path,bytes=size,sha256=actual,expectedSHA256=entry.SHA256,matches=match}); }
report["Files"]=results; report["InstalledPayloadMatches"]=all;
string fixture=Path.Combine(media,"preserved-full-scan.json"); report["FixtureSHA256"]=File.Exists(fixture)?Hash(fixture):"MISSING";
string data=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),@"Dietrich AI Labs\Nyx PC Checkup"); string scan=Path.Combine(data,@"scans\last-scan.json"); report["InstalledCurrentReportExists"]=File.Exists(scan); report["InstalledCurrentReportSHA256"]=File.Exists(scan)?Hash(scan):"MISSING";
report["PolicyReads"]=new {CurrentUser=Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell","ExecutionPolicy",null),LocalMachine=Registry.GetValue(@"HKEY_LOCAL_MACHINE\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell","ExecutionPolicy",null)};
report["AppLaunchPerformed"]=false; report["ScriptsOrModulesExecuted"]=false; report["ProductOrSecurityWrites"]=false; report["OutputDirectory"]=output;
} catch(Exception error) {all=false; report["Error"]=error.ToString();}
report["CompletedUtc"]=DateTime.UtcNow.ToString("o"); report["VerificationSucceeded"]=all; var json=new JavaScriptSerializer().Serialize(report);
if(output!=null) { using(var stream=new FileStream(Path.Combine(output,"INSTALLED_IDENTITY.json"),FileMode.CreateNew)) using(var writer=new StreamWriter(stream,new UTF8Encoding(false))) writer.Write(json); }
var form=new Form {Text="QA27 read-only installed identity verification",Width=850,Height=600}; var text=new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,Text=(all?"INSTALLED PAYLOAD MATCHES":"PRECONDITION FAILED - DO NOT LAUNCH PRODUCT")+Environment.NewLine+"No application launch, module execution or security/product change."+Environment.NewLine+json};form.Controls.Add(text); Application.Run(form);
}
}
