using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Threading;
using System.Web.Script.Serialization;

// Evidence-only helper. Never executes Nyx, changes policy, or forces shutdown.
public static class Qa26NativeEvidence {
    const string VmId = "275a191c-cf8a-4929-9849-b9a293e9149d";
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = Int32.MaxValue };
    static readonly string[] ObserverNames = { "NyxQA26Geometry", "NyxQA26InstalledScanObserver", "NyxQA26InstalledScanObserverV5", "NyxQA26NativeDpi" };
    static readonly string[] DataNames = { "scans", "reports", "logs" };
    static ManagementScope Scope;
    static string Out;
    [StructLayout(LayoutKind.Sequential)] struct StorageType { public uint DeviceId; public Guid VendorId; }
    [StructLayout(LayoutKind.Sequential)] struct OpenParameters { public uint Version; public uint RWDepth; }
    [StructLayout(LayoutKind.Sequential)] struct AttachParameters { public uint Version; public uint Reserved; }
    [DllImport("virtdisk.dll", CharSet=CharSet.Unicode)] static extern uint OpenVirtualDisk(ref StorageType type, string path, uint access, uint flags, ref OpenParameters parameters, out IntPtr handle);
    [DllImport("virtdisk.dll")] static extern uint AttachVirtualDisk(IntPtr handle, IntPtr security, uint flags, uint providerFlags, ref AttachParameters parameters, IntPtr overlapped);
    [DllImport("virtdisk.dll")] static extern uint DetachVirtualDisk(IntPtr handle, uint flags, uint providerFlags);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    static void Save(string name, object value) { File.WriteAllText(Path.Combine(Out,name), Json.Serialize(value)); }
    static string Hash(string path) { using(var stream=File.OpenRead(path)) using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "").ToLowerInvariant(); }
    static void CopyTree(string source, string destination) {
        if ((File.GetAttributes(source) & FileAttributes.ReparsePoint) != 0) throw new IOException("Reparse point excluded: " + source);
        Directory.CreateDirectory(destination);
        foreach(var file in Directory.GetFiles(source)) {
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) throw new IOException("Reparse file excluded: " + file);
            File.Copy(file,Path.Combine(destination,Path.GetFileName(file)),false);
        }
        foreach(var dir in Directory.GetDirectories(source)) CopyTree(dir,Path.Combine(destination,Path.GetFileName(dir)));
    }
    static IEnumerable<string> Files(string root) {
        foreach(var file in Directory.GetFiles(root)) {
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) throw new IOException("Reparse file excluded");
            yield return file;
        }
        foreach(var dir in Directory.GetDirectories(root)) {
            if ((File.GetAttributes(dir) & FileAttributes.ReparsePoint) != 0) throw new IOException("Reparse directory excluded");
            foreach(var file in Files(dir)) yield return file;
        }
    }
    static object[] Manifest(string root) { return Files(root).Select(p=>(object)new { Path=p.Substring(root.Length).TrimStart('\\').Replace('\\','/'),Length=new FileInfo(p).Length,SHA256=Hash(p) }).ToArray(); }
    static List<ManagementObject> Query(string sql) { using(var search=new ManagementObjectSearcher(Scope,new ObjectQuery(sql))) return search.Get().Cast<ManagementObject>().ToList(); }
    static ManagementObject One(string sql) { var objects=Query(sql); if(objects.Count!=1) throw new InvalidOperationException("Expected one WMI object: "+sql); return objects[0]; }
    static ManagementObject Vm() { var vm=One("SELECT * FROM Msvm_ComputerSystem WHERE Name='"+VmId+"'"); if((string)vm["ElementName"]!="Nyx") throw new InvalidOperationException("VM identity mismatch"); return vm; }
    static void Job(ManagementBaseObject result) {
        uint code=Convert.ToUInt32(result["ReturnValue"]);
        if(code==0) return;
        if(code!=4096) throw new InvalidOperationException("WMI return "+code);
        var job=new ManagementObject(Scope,new ManagementPath((string)result["Job"]),null);
        var deadline=DateTime.UtcNow.AddMinutes(3);
        while(DateTime.UtcNow<deadline) {
            job.Get(); var state=Convert.ToUInt16(job["JobState"]);
            if(state==7) { if(Convert.ToUInt16(job["ErrorCode"])!=0) throw new IOException("Job error: "+job["ErrorDescription"]); return; }
            if(state>=8) throw new IOException("Job failed: "+job["ErrorDescription"]);
            Thread.Sleep(500);
        }
        throw new TimeoutException("WMI job deadline; no forced termination");
    }
    static void Inventory(ManagementObject vm) {
        var settings=vm.GetRelated("Msvm_VirtualSystemSettingData").Cast<ManagementObject>().Select(x=>new {Path=x.Path.Path,InstanceID=x["InstanceID"],ElementName=x["ElementName"],VirtualSystemType=x["VirtualSystemType"],CreationTime=x["CreationTime"]}).ToArray();
        Save("VM_INVENTORY.json",new {Id=VmId,Name=vm["ElementName"],EnabledState=vm["EnabledState"],Settings=settings});
    }
    static void Checkpoint(ManagementObject vm) {
        var service=One("SELECT * FROM Msvm_VirtualSystemSnapshotService");
        var input=service.GetMethodParameters("CreateSnapshot"); input["AffectedSystem"]=vm.Path.Path; input["SnapshotSettings"]=""; input["SnapshotType"]=(ushort)2;
        var result=service.InvokeMethod("CreateSnapshot",input,null); Job(result);
        Save("CHECKPOINT_CREATED.json",new {ResultingSnapshot=result["ResultingSnapshot"],VmId=VmId,Kind="PRESERVATION_ONLY_NOT_CLEAN_DESTRUCTIVE_FIXTURE",RestorationProof="NOT_ESTABLISHED"});
        Inventory(vm);
    }
    static void Collect(ManagementObject vm) {
        var active=vm.GetRelated("Msvm_VirtualSystemSettingData").Cast<ManagementObject>().Where(x=>Convert.ToString(x["VirtualSystemType"])=="Microsoft:Hyper-V:System:Realized").ToArray();
        if(active.Length!=1) throw new IOException("Ambiguous current VM settings");
        var disks=active[0].GetRelated("Msvm_StorageAllocationSettingData").Cast<ManagementObject>().Where(x=>Convert.ToString(x["ResourceSubType"])=="Microsoft:Hyper-V:Virtual Hard Disk").ToArray();
        if(disks.Length!=1) throw new IOException("Expected exactly one current guest disk");
        var paths=(string[])disks[0]["HostResource"]; if(paths.Length!=1 || !File.Exists(paths[0])) throw new IOException("Ambiguous backing file");
        IntPtr handle=IntPtr.Zero; bool mounted=false; bool shutdown=false;
        try {
            vm.Get();
            if(Convert.ToUInt16(vm["EnabledState"])!=3) {
                if(Convert.ToUInt16(vm["EnabledState"])!=2) throw new IOException("VM must be running or off; no saved-state operations");
                var component=One("SELECT * FROM Msvm_ShutdownComponent WHERE SystemName='"+VmId+"'");
                var input=component.GetMethodParameters("InitiateShutdown"); input["Force"]=false; input["Reason"]="QA26 read-only evidence collection";
                Job(component.InvokeMethod("InitiateShutdown",input,null)); shutdown=true;
                var deadline=DateTime.UtcNow.AddMinutes(3);
                do { vm.Get(); if(Convert.ToUInt16(vm["EnabledState"])==3) break; if(DateTime.UtcNow>deadline) throw new TimeoutException("Normal shutdown timeout; no force"); Thread.Sleep(1000); } while(true);
            }
            var type=new StorageType {DeviceId=3,VendorId=new Guid("EC984AEC-A0F9-47E9-901F-71415A66345B")};
            var open=new OpenParameters {Version=1,RWDepth=1};
            uint code=OpenVirtualDisk(ref type,paths[0],0x000D0000,0,ref open,out handle); if(code!=0) throw new IOException("OpenVirtualDisk Win32="+code);
            string[] priorVolumes;
            using(var before=new ManagementObjectSearcher("root\\Microsoft\\Windows\\Storage","SELECT Path FROM MSFT_Volume")) priorVolumes=before.Get().Cast<ManagementObject>().Select(x=>Convert.ToString(x["Path"])).ToArray();
            var attach=new AttachParameters {Version=1,Reserved=0}; code=AttachVirtualDisk(handle,IntPtr.Zero,3,0,ref attach,IntPtr.Zero); if(code!=0) throw new IOException("AttachVirtualDisk Win32="+code); mounted=true;
            string root=null;
            Thread.Sleep(2000);
            using(var search=new ManagementObjectSearcher("root\\Microsoft\\Windows\\Storage","SELECT Path FROM MSFT_Volume")) {
                var candidates=search.Get().Cast<ManagementObject>().Select(x=>Convert.ToString(x["Path"])).Where(p=>!String.IsNullOrEmpty(p)).ToArray();
                Save("VOLUME_SELECTION_DIAGNOSTIC.json",candidates.Select(p=>new {Path=p,PresentBeforeAttach=priorVolumes.Contains(p,StringComparer.OrdinalIgnoreCase),InstallStateExists=File.Exists(Path.Combine(p,"Users\\Nyx\\AppData\\Local\\Programs\\Dietrich AI Labs\\Nyx PC Checkup\\install-state.json"))}).ToArray());
                var roots=candidates.Where(p=>!priorVolumes.Contains(p,StringComparer.OrdinalIgnoreCase) && File.Exists(Path.Combine(p,"Users\\Nyx\\AppData\\Local\\Programs\\Dietrich AI Labs\\Nyx PC Checkup\\install-state.json"))).ToArray();
                if(roots.Length!=1) throw new IOException("Guest volume selection ambiguous"); root=roots[0];
            }
            string local=Path.Combine(root,"Users\\Nyx\\AppData\\Local"); string install=Path.Combine(local,"Programs\\Dietrich AI Labs\\Nyx PC Checkup");
            File.Copy(Path.Combine(install,"install-state.json"),Path.Combine(Out,"INSTALL_STATE_RAW.json"),false);
            foreach(var name in ObserverNames) { string source=Path.Combine(local,name); if(Directory.Exists(source)) CopyTree(source,Path.Combine(Out,name)); }
            string data=Path.Combine(local,"Dietrich AI Labs\\Nyx PC Checkup");
            foreach(var name in DataNames) { string source=Path.Combine(data,name); if(Directory.Exists(source)) CopyTree(source,Path.Combine(Out,name)); }
            Save("INSTALLED_HASHES.json",Manifest(install));
            Save("COLLECTION_PROVENANCE.json",new {VmId=VmId,BackingFile=paths[0],ReadOnlyAttachFlags=3,ProductModified=false,ForcedShutdown=false,PolicyChanged=false,NativeDpi="Only exact copied guest observer measurements qualify; not measured by host",WorkerCleanup="Requires pre-shutdown guest observer proof; offline copy is not live proof"});
        } finally {
            if(mounted) { uint code=DetachVirtualDisk(handle,0,0); if(code!=0) { CloseHandle(handle); handle=IntPtr.Zero; throw new IOException("Detach failed; no restart until release: "+code); } }
            if(handle!=IntPtr.Zero) CloseHandle(handle);
            vm.Get(); if(shutdown && Convert.ToUInt16(vm["EnabledState"])==3) { var input=vm.GetMethodParameters("RequestStateChange"); input["RequestedState"]=(ushort)2; Job(vm.InvokeMethod("RequestStateChange",input,null)); }
        }
        Save("STATUS.json",new {Status="COLLECTED_READ_ONLY",Utc=DateTime.UtcNow.ToString("o"),ProductModified=false,VhdMountedReadOnly=true,NativeAndLiveProof="Pending exact observer reconciliation"});
    }
    static void Fixture(string source) {
        source=Path.GetFullPath(source).TrimEnd('\\');
        if(!File.Exists(Path.Combine(source,"STATUS.json")) || !File.Exists(Path.Combine(source,"INSTALLED_HASHES.json"))) throw new IOException("Known fixture identity missing");
        foreach(var name in ObserverNames.Concat(DataNames)) { var path=Path.Combine(source,name); if(Directory.Exists(path)) CopyTree(path,Path.Combine(Out,name)); }
        foreach(var name in new[]{"INSTALL_STATE_RAW.json","INSTALLED_HASHES.json"}) File.Copy(Path.Combine(source,name),Path.Combine(Out,name),false);
        var compared=new List<object>();
        foreach(var file in Files(Out).ToArray()) { var relative=file.Substring(Out.Length).TrimStart('\\');if(relative=="HELPER_PROVENANCE.json") continue;var original=Path.Combine(source,relative);if(Hash(file)!=Hash(original)) throw new IOException("Fixture mismatch: "+relative);compared.Add(new {Path=relative,SHA256=Hash(file)}); }
        Save("FIXTURE_EQUIVALENCE.json",new {Status="PASS_HARNESS_COPY_EQUIVALENCE_ONLY",Source=source,Compared=compared,GuestCollectionExecuted=false,NativeDpiNewCredit=false});
    }
    public static int Main(string[] args) {
        AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling",false);
        AppContext.SetSwitch("Switch.System.IO.BlockLongPaths",false);
        if(args.Length<2) { Console.Error.WriteLine("inventory|checkpoint|collect|fixture OUTPUT [KNOWN_FIXTURE]");return 2; }
        Out=Path.GetFullPath(args[1]).TrimEnd('\\'); if(Directory.Exists(Out)) { Console.Error.WriteLine("Refuse existing output directory"); return 2; } Directory.CreateDirectory(Out);
        try {
            Save("HELPER_PROVENANCE.json",new {Utc=DateTime.UtcNow.ToString("o"),BinarySHA256=Hash(System.Reflection.Assembly.GetExecutingAssembly().Location),FrozenSource="0303a78a06f67252c86634cd73f1e4bda32dd3cc",Build="2026.10.02-eng-qa26",Harness="QA26-F023-PS51-26",Mode=args[0]});
            if(args[0]=="fixture") { if(args.Length!=3) throw new ArgumentException("Fixture path required");Fixture(args[2]); }
            else { Scope=new ManagementScope("\\\\.\\root\\virtualization\\v2"); Scope.Connect();var vm=Vm();Inventory(vm);if(args[0]=="collect") Collect(vm);else if(args[0]=="checkpoint") Checkpoint(vm);else if(args[0]!="inventory") throw new ArgumentException("Unsupported mode"); }
            return 0;
        } catch(Exception error) { File.WriteAllText(Path.Combine(Out,"ERROR.txt"),error.ToString());Console.Error.WriteLine(error.Message);return 1; }
    }
}
