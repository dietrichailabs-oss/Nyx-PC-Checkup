#include "win_types.hpp"
extern "C" void __stdcall wWinMainCRTStartup(void){
    static WCHAR exe[1024],root[1024],script[1400],systemRoot[512],safeCwd[1024],ps[1024],cmd[4096];
    exe[0]=root[0]=script[0]=systemRoot[0]=safeCwd[0]=ps[0]=cmd[0]=0;
    if(!GetModuleFileNameW(0,exe,1024)){ExitProcess(1);}nyx_copy_dir(root,exe,1024);
    nyx_wcopy(script,root,1400);nyx_wcat(script,L"\\app\\workers\\UninstallWorker.ps1",1400);
    if(!GetEnvironmentVariableW(L"SystemRoot",systemRoot,512)){ExitProcess(2);}nyx_wcopy(safeCwd,systemRoot,1024);nyx_wcat(safeCwd,L"\\System32",1024);nyx_wcopy(ps,systemRoot,1024);nyx_wcat(ps,L"\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",1024);
    BOOL quiet=nyx_contains_i(GetCommandLineW(),L"/quiet");BOOL purge=nyx_contains_i(GetCommandLineW(),L"/purgedata");
    nyx_wcat(cmd,L"\"",4096);nyx_wcat(cmd,ps,4096);nyx_wcat(cmd,L"\" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"",4096);nyx_wcat(cmd,script,4096);nyx_wcat(cmd,L"\" -InstallRoot \"",4096);nyx_wcat(cmd,root,4096);nyx_wcat(cmd,L"\" -Quiet ",4096);nyx_wcat(cmd,quiet?L"1":L"0",4096);nyx_wcat(cmd,L" -PurgeData ",4096);nyx_wcat(cmd,purge?L"1":L"0",4096);
    DWORD code=nyx_run(ps,cmd,safeCwd,TRUE);if(code==0xFFFFFFFFUL){if(!quiet)MessageBoxW(0,L"The Nyx PC Checkup uninstaller could not start.",L"Nyx PC Checkup",MB_OK|MB_ICONERROR);ExitProcess(2);}ExitProcess(code);
}
