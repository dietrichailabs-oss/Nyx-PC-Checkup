#include "win_types.hpp"
#include "payload.h"

static WCHAR g_diagnostics_path[2048];
static WCHAR g_local_app_data[1024];
static WCHAR g_install_parent[1600];
static WCHAR g_install_target[1800];
static WCHAR g_resolved_parent[1800];
static WCHAR g_resolved_target[1800];
static WCHAR g_detail_path[2048];
static DWORD g_parent_attributes=INVALID_FILE_ATTRIBUTES;
static DWORD g_target_attributes=INVALID_FILE_ATTRIBUTES;
static DWORD g_parent_create_result=0;
static DWORD g_parent_write_error=0;
static DWORD g_payload_index=0xFFFFFFFFUL;
static DWORD g_child_exit_code=0;
static BOOL g_parent_write_attempted=FALSE;
static BOOL g_parent_write_succeeded=FALSE;

static BOOL nyx_exists(const WCHAR* p){return GetFileAttributesW(p)!=INVALID_FILE_ATTRIBUTES;}
static BOOL nyx_ordinary_dir(const WCHAR* p){DWORD a=GetFileAttributesW(p);return a!=INVALID_FILE_ATTRIBUTES&&(a&FILE_ATTRIBUTE_DIRECTORY)&&!(a&FILE_ATTRIBUTE_REPARSE_POINT);}
static BOOL nyx_reparse(const WCHAR* p){DWORD a=GetFileAttributesW(p);return a!=INVALID_FILE_ATTRIBUTES&&(a&FILE_ATTRIBUTE_REPARSE_POINT);}
static BOOL nyx_ends_i(const WCHAR* text,const WCHAR* suffix){unsigned long a=nyx_wlen(text),b=nyx_wlen(suffix);if(b>a)return FALSE;for(unsigned long i=0;i<b;i++){if(nyx_lower(text[a-b+i])!=nyx_lower(suffix[i]))return FALSE;}return TRUE;}
static BOOL nyx_get_option_value(const WCHAR* command,const WCHAR* option,WCHAR* out,unsigned long cap){
    out[0]=0;unsigned long a=nyx_wlen(command),b=nyx_wlen(option);
    for(unsigned long i=0;i+b<=a;i++){
        BOOL match=TRUE;for(unsigned long j=0;j<b;j++){if(nyx_lower(command[i+j])!=nyx_lower(option[j])){match=FALSE;break;}}
        if(!match)continue;
        unsigned long p=i+b,n=0;BOOL quoted=FALSE;
        if(command[p]==L'"'){quoted=TRUE;p++;}
        while(command[p]&&n+1<cap){WCHAR c=command[p++];if(quoted){if(c==L'"')break;}else if(c==L' '||c==L'\t')break;out[n++]=c;}
        out[n]=0;return n>0;
    }
    return FALSE;
}
static void nyx_json_string(WCHAR* out,const WCHAR* value,unsigned long cap){
    nyx_wcat(out,L"\"",cap);
    for(unsigned long i=0;value&&value[i];i++){
        WCHAR c=value[i];
        if(c==L'"'||c==L'\\'){WCHAR pair[3]={L'\\',c,0};nyx_wcat(out,pair,cap);}
        else if(c==L'\r'){nyx_wcat(out,L"\\r",cap);}
        else if(c==L'\n'){nyx_wcat(out,L"\\n",cap);}
        else if(c==L'\t'){nyx_wcat(out,L"\\t",cap);}
        else if(c<32){nyx_wcat(out,L"?",cap);}
        else{WCHAR one[2]={c,0};nyx_wcat(out,one,cap);}
    }
    nyx_wcat(out,L"\"",cap);
}
static void nyx_json_key(WCHAR* out,const WCHAR* key,unsigned long cap){nyx_json_string(out,key,cap);nyx_wcat(out,L":",cap);}
static void nyx_json_text_field(WCHAR* out,const WCHAR* key,const WCHAR* value,BOOL comma,unsigned long cap){nyx_json_key(out,key,cap);nyx_json_string(out,value?value:L"",cap);if(comma)nyx_wcat(out,L",",cap);}
static void nyx_json_uint_field(WCHAR* out,const WCHAR* key,DWORD value,BOOL comma,unsigned long cap){nyx_json_key(out,key,cap);nyx_append_uint(out,value,cap);if(comma)nyx_wcat(out,L",",cap);}
static void nyx_json_bool_field(WCHAR* out,const WCHAR* key,BOOL value,BOOL comma,unsigned long cap){nyx_json_key(out,key,cap);nyx_wcat(out,value?L"true":L"false",cap);if(comma)nyx_wcat(out,L",",cap);}
static void nyx_resolve_path(const WCHAR* input,WCHAR* output,DWORD cap){output[0]=0;if(!input||!input[0])return;DWORD result=GetFullPathNameW(input,cap,output,0);if(result==0||result>=cap)output[0]=0;}
static BOOL nyx_valid_diagnostics_destination(const WCHAR* path){
    if(!path||!path[0]||!nyx_ends_i(path,L".json")||!nyx_contains_i(path,L"Nyx_PC_Checkup_Setup_Diagnostics_"))return FALSE;
    static WCHAR parent[2048];parent[0]=0;nyx_parent_dir(parent,path,2048);return parent[0]&&nyx_ordinary_dir(parent)&&!nyx_exists(path);
}
static void nyx_write_diagnostics(const WCHAR* branch,const WCHAR* stage,const WCHAR* message,UINT exitCode,DWORD nativeError,BOOL success){
    if(!nyx_valid_diagnostics_destination(g_diagnostics_path))return;
    g_parent_attributes=g_install_parent[0]?GetFileAttributesW(g_install_parent):INVALID_FILE_ATTRIBUTES;
    g_target_attributes=g_install_target[0]?GetFileAttributesW(g_install_target):INVALID_FILE_ATTRIBUTES;
    nyx_resolve_path(g_install_parent,g_resolved_parent,1800);nyx_resolve_path(g_install_target,g_resolved_target,1800);
    static WCHAR json[32768];json[0]=0;nyx_wcat(json,L"{",32768);
    nyx_json_text_field(json,L"schema",L"dietrich-ai-labs.nyx-pc-checkup.setup-diagnostics.v1",TRUE,32768);
    nyx_json_text_field(json,L"product",L"nyx-pc-checkup",TRUE,32768);
    nyx_json_text_field(json,L"build",L"2026.09.26-eng-qa16",TRUE,32768);
    nyx_json_bool_field(json,L"success",success,TRUE,32768);
    nyx_json_uint_field(json,L"exitCode",exitCode,TRUE,32768);
    nyx_json_text_field(json,L"branchId",branch,TRUE,32768);
    nyx_json_text_field(json,L"stage",stage,TRUE,32768);
    nyx_json_text_field(json,L"message",message,TRUE,32768);
    nyx_json_uint_field(json,L"nativeError",nativeError,TRUE,32768);
    nyx_json_uint_field(json,L"childExitCode",g_child_exit_code,TRUE,32768);
    nyx_json_text_field(json,L"localAppData",g_local_app_data,TRUE,32768);
    nyx_json_text_field(json,L"installParent",g_install_parent,TRUE,32768);
    nyx_json_text_field(json,L"resolvedInstallParent",g_resolved_parent,TRUE,32768);
    nyx_json_text_field(json,L"installTarget",g_install_target,TRUE,32768);
    nyx_json_text_field(json,L"resolvedInstallTarget",g_resolved_target,TRUE,32768);
    nyx_json_bool_field(json,L"parentExists",g_parent_attributes!=INVALID_FILE_ATTRIBUTES,TRUE,32768);
    nyx_json_uint_field(json,L"parentAttributes",g_parent_attributes,TRUE,32768);
    nyx_json_bool_field(json,L"parentIsDirectory",g_parent_attributes!=INVALID_FILE_ATTRIBUTES&&(g_parent_attributes&FILE_ATTRIBUTE_DIRECTORY),TRUE,32768);
    nyx_json_bool_field(json,L"parentIsReparsePoint",g_parent_attributes!=INVALID_FILE_ATTRIBUTES&&(g_parent_attributes&FILE_ATTRIBUTE_REPARSE_POINT),TRUE,32768);
    nyx_json_uint_field(json,L"parentCreateResult",g_parent_create_result,TRUE,32768);
    nyx_json_bool_field(json,L"parentWriteProbeAttempted",g_parent_write_attempted,TRUE,32768);
    nyx_json_bool_field(json,L"parentWriteProbeSucceeded",g_parent_write_succeeded,TRUE,32768);
    nyx_json_uint_field(json,L"parentWriteProbeError",g_parent_write_error,TRUE,32768);
    nyx_json_bool_field(json,L"targetExists",g_target_attributes!=INVALID_FILE_ATTRIBUTES,TRUE,32768);
    nyx_json_uint_field(json,L"targetAttributes",g_target_attributes,TRUE,32768);
    nyx_json_bool_field(json,L"targetIsDirectory",g_target_attributes!=INVALID_FILE_ATTRIBUTES&&(g_target_attributes&FILE_ATTRIBUTE_DIRECTORY),TRUE,32768);
    nyx_json_bool_field(json,L"targetIsReparsePoint",g_target_attributes!=INVALID_FILE_ATTRIBUTES&&(g_target_attributes&FILE_ATTRIBUTE_REPARSE_POINT),TRUE,32768);
    nyx_json_uint_field(json,L"payloadIndex",g_payload_index,TRUE,32768);
    nyx_json_text_field(json,L"detailPath",g_detail_path,FALSE,32768);nyx_wcat(json,L"}",32768);
    HANDLE h=CreateFileW(g_diagnostics_path,GENERIC_WRITE,0,0,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,0);if(h==INVALID_HANDLE_VALUE)return;
    WORD bom=0xFEFF;DWORD written=0;BOOL ok=WriteFile(h,&bom,sizeof(bom),&written,0)&&written==sizeof(bom);DWORD bytes=nyx_wlen(json)*sizeof(WCHAR);if(ok){written=0;WriteFile(h,json,bytes,&written,0);}CloseHandle(h);
}
static void nyx_fail(BOOL quiet,const WCHAR* branch,const WCHAR* stage,const WCHAR* message,UINT code,DWORD nativeError){nyx_write_diagnostics(branch,stage,message,code,nativeError,FALSE);if(!quiet)MessageBoxW(0,message,L"Nyx PC Checkup Setup",MB_OK|MB_ICONERROR);ExitProcess(code);}
static void nyx_probe_parent_write(const WCHAR* parent){
    g_parent_write_attempted=TRUE;g_parent_write_succeeded=FALSE;g_parent_write_error=0;
    static WCHAR probe[2048];probe[0]=0;nyx_wcopy(probe,parent,2048);nyx_wcat(probe,L"\\Nyx PC Checkup.setup-write-probe.",2048);nyx_append_uint(probe,GetCurrentProcessId(),2048);nyx_wcat(probe,L".tmp",2048);
    HANDLE h=CreateFileW(probe,GENERIC_WRITE,0,0,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,0);if(h==INVALID_HANDLE_VALUE){g_parent_write_error=GetLastError();return;}
    BYTE marker=0x4E;DWORD written=0;if(WriteFile(h,&marker,1,&written,0)&&written==1){g_parent_write_succeeded=TRUE;}else{g_parent_write_error=GetLastError();}CloseHandle(h);if(!DeleteFileW(probe)&&g_parent_write_error==0)g_parent_write_error=GetLastError();
}
static BOOL nyx_write_payload(const WCHAR* root){
    static WCHAR full[2048],parent[2048];
    for(unsigned long i=0;i<NYX_PAYLOAD_COUNT;i++){
        g_payload_index=(DWORD)i;full[0]=parent[0]=0;
        nyx_wcopy(full,root,2048);nyx_wcat(full,L"\\",2048);nyx_wcat(full,NYX_PAYLOAD[i].path,2048);nyx_wcopy(g_detail_path,full,2048);
        nyx_parent_dir(parent,full,2048);if(parent[0]){SHCreateDirectoryExW(0,parent,0);if(!nyx_ordinary_dir(parent)){g_parent_write_error=GetLastError();return FALSE;}}
        if(nyx_exists(full)){g_parent_write_error=80;return FALSE;}
        HANDLE h=CreateFileW(full,GENERIC_WRITE,0,0,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,0);if(h==INVALID_HANDLE_VALUE){g_parent_write_error=GetLastError();return FALSE;}
        unsigned long long remaining=NYX_PAYLOAD[i].size,offset=0;
        while(remaining){DWORD chunk=(remaining>0x40000000ULL)?0x40000000UL:(DWORD)remaining,written=0;if(!WriteFile(h,NYX_PAYLOAD[i].data+offset,chunk,&written,0)||written!=chunk){g_parent_write_error=GetLastError();CloseHandle(h);return FALSE;}offset+=written;remaining-=written;}
        CloseHandle(h);
    }
    g_payload_index=0xFFFFFFFFUL;g_detail_path[0]=0;return TRUE;
}
static void nyx_schedule_remove(const WCHAR* dir){
    static WCHAR sys[512],cmdexe[1024],cmd[4096];sys[0]=cmdexe[0]=cmd[0]=0;GetEnvironmentVariableW(L"SystemRoot",sys,512);nyx_wcopy(cmdexe,sys,1024);nyx_wcat(cmdexe,L"\\System32\\cmd.exe",1024);
    nyx_wcat(cmd,L"\"",4096);nyx_wcat(cmd,cmdexe,4096);nyx_wcat(cmd,L"\" /d /c ping 127.0.0.1 -n 2 >nul & rmdir /s /q \"",4096);nyx_wcat(cmd,dir,4096);nyx_wcat(cmd,L"\"",4096);
    STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);si.dwFlags=STARTF_USESHOWWINDOW;si.wShowWindow=SW_HIDE;if(CreateProcessW(cmdexe,cmd,0,0,FALSE,CREATE_NO_WINDOW,0,0,&si,&pi)){CloseHandle(pi.hThread);CloseHandle(pi.hProcess);}
}
static DWORD nyx_finalize(const WCHAR* target,BOOL desktop,BOOL quiet){
    static WCHAR sys[512],ps[1024],worker[1600],cmd[4096];sys[0]=ps[0]=worker[0]=cmd[0]=0;GetEnvironmentVariableW(L"SystemRoot",sys,512);nyx_wcopy(ps,sys,1024);nyx_wcat(ps,L"\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",1024);
    nyx_wcopy(worker,target,1600);nyx_wcat(worker,L"\\app\\workers\\InstallWorker.ps1",1600);
    nyx_wcat(cmd,L"\"",4096);nyx_wcat(cmd,ps,4096);nyx_wcat(cmd,L"\" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"",4096);nyx_wcat(cmd,worker,4096);nyx_wcat(cmd,L"\" -InstallRoot \"",4096);nyx_wcat(cmd,target,4096);nyx_wcat(cmd,L"\" -CreateDesktop ",4096);nyx_wcat(cmd,desktop?L"1":L"0",4096);nyx_wcat(cmd,L" -Quiet ",4096);nyx_wcat(cmd,quiet?L"1":L"0",4096);return nyx_run_hidden_worker(ps,cmd,target);
}
static void nyx_launch(const WCHAR* target){static WCHAR exe[1400],cmd[1800];exe[0]=cmd[0]=0;nyx_wcopy(exe,target,1400);nyx_wcat(exe,L"\\Nyx PC Checkup.exe",1400);nyx_wcat(cmd,L"\"",1800);nyx_wcat(cmd,exe,1800);nyx_wcat(cmd,L"\"",1800);STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);if(CreateProcessW(exe,cmd,0,0,FALSE,0,0,target,&si,&pi)){CloseHandle(pi.hThread);CloseHandle(pi.hProcess);}}

extern "C" void __stdcall wWinMainCRTStartup(void){
    g_diagnostics_path[0]=g_local_app_data[0]=g_install_parent[0]=g_install_target[0]=g_resolved_parent[0]=g_resolved_target[0]=g_detail_path[0]=0;
    const WCHAR* command=GetCommandLineW();nyx_get_option_value(command,L"/diagnostics:",g_diagnostics_path,2048);BOOL quiet=nyx_contains_i(command,L"/quiet");BOOL desktop=nyx_contains_i(command,L"/desktop");BOOL noLaunch=quiet||nyx_contains_i(command,L"/nolaunch");
    HANDLE running=OpenMutexW(SYNCHRONIZE,FALSE,L"Local\\DietrichAI.NyxPCCheckup.v1");if(running){CloseHandle(running);nyx_fail(quiet,L"RUNNING_INSTANCE",L"preflight",L"Close Nyx PC Checkup before installing, upgrading, or repairing it.",10,0);}
    if(!quiet){
        int choice=MessageBoxW(0,L"Install Nyx PC Checkup 1.0.0 for the current Windows user?\n\nChoose Yes to also create a desktop shortcut.\nChoose No for a Start menu shortcut only.\nChoose Cancel to stop.\n\nThe app is local-first and installs no background service.",L"Nyx PC Checkup Setup",MB_YESNOCANCEL|MB_ICONQUESTION);
        if(choice==IDCANCEL){nyx_write_diagnostics(L"USER_CANCELLED",L"consent",L"The user cancelled setup.",0,0,FALSE);ExitProcess(0);}desktop=(choice==IDYES);
    }
    static WCHAR stage[1900],backup[1900],failed[1900];stage[0]=backup[0]=failed[0]=0;
    DWORD localResult=GetEnvironmentVariableW(L"LOCALAPPDATA",g_local_app_data,1024);if(localResult==0||localResult>=1024)nyx_fail(quiet,L"LOCALAPPDATA_MISSING",L"environment",L"Setup could not find the current user's Local AppData folder.",11,GetLastError());
    nyx_wcopy(g_install_parent,g_local_app_data,1600);nyx_wcat(g_install_parent,L"\\Programs\\Dietrich AI Labs",1600);g_parent_create_result=(DWORD)SHCreateDirectoryExW(0,g_install_parent,0);g_parent_attributes=GetFileAttributesW(g_install_parent);if(!nyx_ordinary_dir(g_install_parent))nyx_fail(quiet,L"INSTALL_PARENT_UNSAFE",L"install_parent_validation",L"Setup rejected an unsafe or reparse-backed installation parent directory.",11,g_parent_create_result);
    nyx_probe_parent_write(g_install_parent);
    nyx_wcopy(g_install_target,g_install_parent,1800);nyx_wcat(g_install_target,L"\\Nyx PC Checkup",1800);
    DWORD pid=GetCurrentProcessId();nyx_wcopy(stage,g_install_parent,1900);nyx_wcat(stage,L"\\Nyx PC Checkup.installing.",1900);nyx_append_uint(stage,pid,1900);
    nyx_wcopy(backup,g_install_parent,1900);nyx_wcat(backup,L"\\Nyx PC Checkup.rollback.",1900);nyx_append_uint(backup,pid,1900);
    nyx_wcopy(failed,g_install_parent,1900);nyx_wcat(failed,L"\\Nyx PC Checkup.failed.",1900);nyx_append_uint(failed,pid,1900);
    if(nyx_exists(stage)||nyx_exists(backup)||nyx_exists(failed)){nyx_wcopy(g_detail_path,stage,2048);nyx_fail(quiet,L"TEMP_PATH_COLLISION",L"staging_preflight",L"Setup found a colliding temporary installation path and stopped without changing the existing installation.",12,80);}
    g_parent_write_error=0;SHCreateDirectoryExW(0,stage,0);if(!nyx_ordinary_dir(stage)||!nyx_write_payload(stage)){DWORD error=g_parent_write_error?g_parent_write_error:GetLastError();nyx_schedule_remove(stage);nyx_fail(quiet,L"PAYLOAD_STAGE_WRITE_FAILED",L"payload_staging",L"Setup could not write the complete clean payload. The existing installation, if any, was not replaced.",12,error);}
    BOOL hadOld=nyx_exists(g_install_target);if(hadOld&&nyx_reparse(g_install_target)){nyx_schedule_remove(stage);nyx_fail(quiet,L"EXISTING_TARGET_REPARSE",L"upgrade_boundary",L"Setup rejected a reparse-backed existing installation directory.",13,0);}if(hadOld&&!nyx_ordinary_dir(g_install_target)){nyx_schedule_remove(stage);nyx_fail(quiet,L"EXISTING_TARGET_INVALID",L"upgrade_boundary",L"Setup rejected an invalid existing installation path.",13,0);}if(hadOld&&!MoveFileExW(g_install_target,backup,MOVEFILE_WRITE_THROUGH)){DWORD error=GetLastError();nyx_schedule_remove(stage);nyx_fail(quiet,L"ROLLBACK_BOUNDARY_FAILED",L"upgrade_boundary",L"Setup could not create the upgrade rollback boundary. Close any open Nyx files and try again.",13,error);}
    if(!MoveFileExW(stage,g_install_target,MOVEFILE_WRITE_THROUGH)){DWORD error=GetLastError();if(hadOld)MoveFileExW(backup,g_install_target,MOVEFILE_WRITE_THROUGH);nyx_schedule_remove(stage);nyx_fail(quiet,L"ACTIVATION_FAILED",L"payload_activation",L"Setup could not activate the new payload. The previous installation was restored.",14,error);}
    DWORD finalCode=nyx_finalize(g_install_target,desktop,quiet);if(finalCode!=0){g_child_exit_code=finalCode;MoveFileExW(g_install_target,failed,MOVEFILE_WRITE_THROUGH);if(hadOld)MoveFileExW(backup,g_install_target,MOVEFILE_WRITE_THROUGH);nyx_schedule_remove(failed);nyx_fail(quiet,L"FINALIZATION_FAILED",L"shortcut_registration",L"Setup finalization failed. The previous installation was restored when one existed.",15,0);}
    if(hadOld)nyx_schedule_remove(backup);
    nyx_write_diagnostics(L"SUCCESS",L"complete",hadOld?L"Nyx PC Checkup was upgraded or repaired successfully.":L"Nyx PC Checkup was installed successfully.",0,0,TRUE);
    if(!quiet){
        if(noLaunch){MessageBoxW(0,hadOld?L"Nyx PC Checkup was upgraded or repaired successfully.":L"Nyx PC Checkup was installed successfully.",L"Nyx PC Checkup Setup",MB_OK|MB_ICONINFORMATION);}
        else{int launch=MessageBoxW(0,hadOld?L"Nyx PC Checkup was upgraded or repaired successfully.\n\nOpen it now?":L"Nyx PC Checkup was installed successfully.\n\nOpen it now?",L"Nyx PC Checkup Setup",MB_YESNO|MB_ICONINFORMATION);if(launch==IDYES)nyx_launch(g_install_target);}
    }
    ExitProcess(0);
}
