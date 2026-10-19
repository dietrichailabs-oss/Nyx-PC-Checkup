import pathlib,json,hashlib,datetime,sys,winreg
O=pathlib.Path(__file__).parent
theme,pid,handle,beforefile,exe,applied=sys.argv[1:]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
before=read(O/beforefile);cp=theme.lower()+'150_startup_missing_location_20261018'
assert before['Pid']==int(pid) and before['WindowHandle']==int(handle)
assert before['BeforeNativeDpi']==before['AfterNativeDpi']==144
assert before['FocusedElement']['Name']=='Open file location' and before['FocusedElement']['Focused'] and before['FocusedElement']['Enabled']
assert before['TargetElevated'] is False and before['HelperElevated'] is False
data=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup')
conf=read(data/'config.json');original=read(O/'config_before_theme_transitions.json')
assert conf['theme']==theme
assert {k:v for k,v in conf.items() if k!='theme'}=={k:v for k,v in original.items() if k!='theme'}
for rel in ['scans/last-scan.json','actions/history.jsonl']:assert sha(data/rel)==sha(O/'raw/preserved-data'/pathlib.Path(rel).name)
with winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Software\Microsoft\Windows\CurrentVersion\Run',0,winreg.KEY_READ) as k:fixture,kind=winreg.QueryValueEx(k,'NyxQA26_MissingTarget_Fixture')
assert fixture=='"C:\\Q26EvidenceHarness\\QA26_INTENTIONALLY_MISSING.exe"'
assert not pathlib.Path(r'C:\Q26EvidenceHarness\QA26_INTENTIONALLY_MISSING.exe').exists()
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
m=read(inst/'PAYLOAD_MANIFEST.json')
for f in m['files']:assert sha(inst/f['path'])==f['sha256'].upper() and (inst/f['path']).stat().st_size==f['size']
events=[json.loads(v) for v in (O/'CASE_EXECUTIONS.jsonl').read_text(encoding='utf-8-sig').splitlines() if v.strip()]
assert not any(e['PredicateId']==cp for e in events)
pre=dict(Utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),PredicateId=cp,Status='PREREQUISITES_QUALIFIED',Theme=theme,NativeDpi=144,Pid=int(pid),SessionId=before['SessionId'],NonElevated=True,BeforeReceipt=beforefile,AppliedThemeEvidence=applied,NormalRelaunchObserved=True,Fixture=fixture,FixtureTargetExists=False,FrozenFilesMatched=60,HelperSHA256=sha(O/exe),HelperSourceSHA256=sha(O/exe.replace('.exe','.cs')),NoScans=True,NoStartupMutation=True,NonThemeConfigUnchanged=True)
p=O/(theme.upper()+'150_STARTUP_PRECONDITIONS.json')
if p.exists():raise RuntimeError('Prerequisites already persisted; no duplicate activation')
p.write_text(json.dumps(pre,indent=2)+'\n',encoding='utf-8')
with (O/'CASE_EXECUTIONS.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=pre['Utc'],PredicateId=cp,Event='STARTED_ONCE',Preconditions=p.name))+'\n')
print(json.dumps({'PredicateId':cp,'Preconditions':'PASS','ActivationCount':0}))
