#include "win_types.hpp"
extern "C" void __stdcall wWinMainCRTStartup(void){
    static WCHAR exe[1024],root[1024],script[1400],systemRoot[512],ps[1024],cmd[4096];
    exe[0]=root[0]=script[0]=systemRoot[0]=ps[0]=cmd[0]=0;
    if(!GetModuleFileNameW(0,exe,1024)){MessageBoxW(0,L"Nyx PC Checkup could not locate its installed files.",L"Nyx PC Checkup",MB_OK|MB_ICONERROR);ExitProcess(1);}
    nyx_copy_dir(root,exe,1024);
    nyx_wcopy(script,root,1400);nyx_wcat(script,L"\\app\\NyxPCCheckup.ps1",1400);
    if(!GetEnvironmentVariableW(L"SystemRoot",systemRoot,512)){MessageBoxW(0,L"Nyx PC Checkup could not locate Windows PowerShell.",L"Nyx PC Checkup",MB_OK|MB_ICONERROR);ExitProcess(2);}
    nyx_wcopy(ps,systemRoot,1024);nyx_wcat(ps,L"\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",1024);
    nyx_wcat(cmd,L"\"",4096);nyx_wcat(cmd,ps,4096);nyx_wcat(cmd,L"\" -NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File \"",4096);nyx_wcat(cmd,script,4096);nyx_wcat(cmd,L"\"",4096);
    DWORD code=nyx_run_gui_child_no_console(ps,cmd,root);
    if(code==0xFFFFFFFFUL){MessageBoxW(0,L"Nyx PC Checkup could not start Windows PowerShell. No changes were made.",L"Nyx PC Checkup",MB_OK|MB_ICONERROR);ExitProcess(3);}
    ExitProcess(code);
}
