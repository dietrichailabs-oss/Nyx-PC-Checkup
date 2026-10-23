#pragma once
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef long LONG;
typedef unsigned int UINT;
typedef int BOOL;
typedef wchar_t WCHAR;
typedef void* HANDLE;
typedef void* HWND;
typedef void* HINSTANCE;
typedef void* LPVOID;
typedef const void* LPCVOID;
typedef WCHAR* LPWSTR;
typedef const WCHAR* LPCWSTR;
typedef BYTE* LPBYTE;
typedef unsigned long* LPDWORD;
#define TRUE 1
#define FALSE 0
#define MAX_PATH 260
#define INVALID_HANDLE_VALUE ((HANDLE)(-1LL))
#define INFINITE 0xFFFFFFFFUL
#define WAIT_OBJECT_0 0
#define CREATE_NO_WINDOW 0x08000000UL
#define STARTF_USESHOWWINDOW 0x00000001UL
#define SW_HIDE 0
#define MB_OK 0x00000000UL
#define MB_ICONERROR 0x00000010UL
#define MB_ICONQUESTION 0x00000020UL
#define MB_ICONWARNING 0x00000030UL
#define MB_ICONINFORMATION 0x00000040UL
#define MB_YESNO 0x00000004UL
#define MB_YESNOCANCEL 0x00000003UL
#define IDYES 6
#define IDNO 7
#define IDCANCEL 2
#define GENERIC_WRITE 0x40000000UL
#define CREATE_NEW 1UL
#define CREATE_ALWAYS 2UL
#define FILE_ATTRIBUTE_NORMAL 0x00000080UL
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010UL
#define FILE_ATTRIBUTE_REPARSE_POINT 0x00000400UL
#define INVALID_FILE_ATTRIBUTES 0xFFFFFFFFUL
#define MOVEFILE_REPLACE_EXISTING 0x00000001UL
#define MOVEFILE_WRITE_THROUGH 0x00000008UL
#define SYNCHRONIZE 0x00100000UL

extern "C" void* memset(void* destination,int value,unsigned long long count){
    BYTE* out=(BYTE*)destination; for(unsigned long long i=0;i<count;i++)out[i]=(BYTE)value; return destination;
}
extern "C" void* memcpy(void* destination,const void* source,unsigned long long count){
    BYTE* out=(BYTE*)destination; const BYTE* in=(const BYTE*)source; for(unsigned long long i=0;i<count;i++)out[i]=in[i]; return destination;
}

typedef struct _STARTUPINFOW {
    DWORD cb; LPWSTR lpReserved; LPWSTR lpDesktop; LPWSTR lpTitle;
    DWORD dwX; DWORD dwY; DWORD dwXSize; DWORD dwYSize; DWORD dwXCountChars; DWORD dwYCountChars;
    DWORD dwFillAttribute; DWORD dwFlags; WORD wShowWindow; WORD cbReserved2; LPBYTE lpReserved2;
    HANDLE hStdInput; HANDLE hStdOutput; HANDLE hStdError;
} STARTUPINFOW;
typedef struct _PROCESS_INFORMATION { HANDLE hProcess; HANDLE hThread; DWORD dwProcessId; DWORD dwThreadId; } PROCESS_INFORMATION;

extern "C" {
__declspec(dllimport) DWORD __stdcall GetModuleFileNameW(HINSTANCE,LPWSTR,DWORD);
__declspec(dllimport) DWORD __stdcall GetEnvironmentVariableW(LPCWSTR,LPWSTR,DWORD);
__declspec(dllimport) BOOL __stdcall CreateProcessW(LPCWSTR,LPWSTR,LPVOID,LPVOID,BOOL,DWORD,LPVOID,LPCWSTR,STARTUPINFOW*,PROCESS_INFORMATION*);
__declspec(dllimport) DWORD __stdcall WaitForSingleObject(HANDLE,DWORD);
__declspec(dllimport) BOOL __stdcall GetExitCodeProcess(HANDLE,LPDWORD);
__declspec(dllimport) BOOL __stdcall CloseHandle(HANDLE);
__declspec(dllimport) void __stdcall ExitProcess(UINT);
__declspec(dllimport) DWORD __stdcall GetLastError(void);
__declspec(dllimport) HANDLE __stdcall CreateFileW(LPCWSTR,DWORD,DWORD,LPVOID,DWORD,DWORD,HANDLE);
__declspec(dllimport) BOOL __stdcall WriteFile(HANDLE,LPCVOID,DWORD,LPDWORD,LPVOID);
__declspec(dllimport) DWORD __stdcall GetFileAttributesW(LPCWSTR);
__declspec(dllimport) BOOL __stdcall MoveFileExW(LPCWSTR,LPCWSTR,DWORD);
__declspec(dllimport) BOOL __stdcall DeleteFileW(LPCWSTR);
__declspec(dllimport) DWORD __stdcall GetCurrentProcessId(void);
__declspec(dllimport) LPWSTR __stdcall GetCommandLineW(void);
__declspec(dllimport) DWORD __stdcall GetFullPathNameW(LPCWSTR,DWORD,LPWSTR,LPWSTR*);
__declspec(dllimport) HANDLE __stdcall OpenMutexW(DWORD,BOOL,LPCWSTR);
__declspec(dllimport) int __stdcall MessageBoxW(HWND,LPCWSTR,LPCWSTR,UINT);
__declspec(dllimport) int __stdcall SHCreateDirectoryExW(HWND,LPCWSTR,LPVOID);
}

static unsigned long nyx_wlen(const WCHAR* s){unsigned long n=0;if(!s)return 0;while(s[n])n++;return n;}
static void nyx_wcopy(WCHAR* d,const WCHAR* s,unsigned long cap){unsigned long i=0;if(!cap)return;while(s&&s[i]&&i+1<cap){d[i]=s[i];i++;}d[i]=0;}
static void nyx_wcat(WCHAR* d,const WCHAR* s,unsigned long cap){unsigned long n=nyx_wlen(d),i=0;if(n>=cap)return;while(s&&s[i]&&n+i+1<cap){d[n+i]=s[i];i++;}d[n+i]=0;}
static void nyx_copy_dir(WCHAR* out,const WCHAR* full,unsigned long cap){nyx_wcopy(out,full,cap);unsigned long n=nyx_wlen(out);while(n>0){if(out[n-1]==L'\\'||out[n-1]==L'/'){out[n-1]=0;return;}n--;}out[0]=0;}
static void nyx_parent_dir(WCHAR* out,const WCHAR* full,unsigned long cap){nyx_wcopy(out,full,cap);unsigned long n=nyx_wlen(out);while(n>0){if(out[n-1]==L'\\'||out[n-1]==L'/'){out[n-1]=0;return;}n--;}out[0]=0;}
static WCHAR nyx_lower(WCHAR c){if(c>=L'A'&&c<=L'Z')return (WCHAR)(c+32);return c;}
static BOOL nyx_contains_i(const WCHAR* text,const WCHAR* term){unsigned long a=nyx_wlen(text),b=nyx_wlen(term);if(!b)return TRUE;for(unsigned long i=0;i+b<=a;i++){BOOL ok=TRUE;for(unsigned long j=0;j<b;j++){if(nyx_lower(text[i+j])!=nyx_lower(term[j])){ok=FALSE;break;}}if(ok)return TRUE;}return FALSE;}
static void nyx_append_uint(WCHAR* d,DWORD v,unsigned long cap){WCHAR tmp[16];unsigned long n=0;if(v==0){nyx_wcat(d,L"0",cap);return;}while(v&&n<15){tmp[n++]=(WCHAR)(L'0'+(v%10));v/=10;}while(n){WCHAR one[2]={tmp[--n],0};nyx_wcat(d,one,cap);}}
static DWORD nyx_run_process(const WCHAR* app,WCHAR* command,const WCHAR* cwd,DWORD creationFlags,BOOL hideFirstWindow){STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);if(hideFirstWindow){si.dwFlags=STARTF_USESHOWWINDOW;si.wShowWindow=SW_HIDE;}if(!CreateProcessW(app,command,0,0,FALSE,creationFlags,0,cwd,&si,&pi))return 0xFFFFFFFFUL;WaitForSingleObject(pi.hProcess,INFINITE);DWORD code=1;GetExitCodeProcess(pi.hProcess,&code);CloseHandle(pi.hThread);CloseHandle(pi.hProcess);return code;}
static DWORD nyx_run_hidden_worker(const WCHAR* app,WCHAR* command,const WCHAR* cwd){return nyx_run_process(app,command,cwd,CREATE_NO_WINDOW,TRUE);}
static DWORD nyx_run_gui_child_no_console(const WCHAR* app,WCHAR* command,const WCHAR* cwd){return nyx_run_process(app,command,cwd,CREATE_NO_WINDOW,FALSE);}
