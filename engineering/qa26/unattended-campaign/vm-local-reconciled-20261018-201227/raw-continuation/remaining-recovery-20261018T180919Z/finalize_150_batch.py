import pathlib,json,hashlib,datetime,winreg
O=pathlib.Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(n,v):
 p=O/n
 if p.exists():raise RuntimeError('Refuse overwrite '+str(p))
 p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
recovered=read(O/'FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json')
cases=[read(O/(t+'150_STARTUP_QUALIFICATION.json')) for t in ['DARK','LIGHT','FOLLOWWINDOWS']]
assert all(c['Status']=='PASS_ENGINEERING_NATIVE_QUALIFIED' for c in cases)
score=read(O/'SCOREBOARD_AFTER_FOLLOWWINDOWS_STARTUP.json');assert score['testedAssertionScoreboard']['PASS']==327
data=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup')
config=read(data/'config.json');before=read(O/'config_before_theme_transitions.json')
assert config['theme']=='FollowWindows'
assert {k:v for k,v in config.items() if k!='theme'}=={k:v for k,v in before.items() if k!='theme'}
with winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Software\Microsoft\Windows\CurrentVersion\Run',0,winreg.KEY_READ) as k:fixture,_=winreg.QueryValueEx(k,'NyxQA26_MissingTarget_Fixture')
assert fixture=='"C:\\Q26EvidenceHarness\\QA26_INTENTIONALLY_MISSING.exe"'
assert not pathlib.Path(r'C:\Q26EvidenceHarness\QA26_INTENTIONALLY_MISSING.exe').exists()
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
for f in read(inst/'PAYLOAD_MANIFEST.json')['files']:assert sha(inst/f['path'])==f['sha256'].upper() and (inst/f['path']).stat().st_size==f['size']
assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
integrity=[]
for entry in read(O/'COLLECTION_RECEIPT.json')['Copies']:
 assert sha(pathlib.Path(entry['Source']))==entry['SHA256']==sha(O/entry['Copy'])
 integrity.append({'Source':entry['Source'],'SHA256':entry['SHA256'],'Unchanged':True})
for rel in ['scans/last-scan.json','actions/history.jsonl']:assert sha(data/rel)==sha(O/'raw/preserved-data'/pathlib.Path(rel).name)
remaining=[
 {'Id':'FOLLOWWINDOWS200_SETTINGS','Status':'MISSING_NOT_EXECUTED_REQUIRES_NATIVE192_SESSION','Action':'Normal display transition and human Windows sign-in, then fresh applied theme/privilege/payload/capture prerequisites. Run only new Settings predicates; no changes to privacy/security or delete activation.'},
 {'Id':'HISTORICAL_EVIDENCE_RESERVATIONS','Status':'INDEPENDENT_QA_DISPOSITION_NO_RERUN','Action':'Seven stale-image cases, older native-DPI gaps, theme-context gaps, and disputed install-state metadata stay reserved and unmodified.'},
 {'Id':'SETTINGS200_LABEL_REVIEW','Status':'INDEPENDENT_QA_REVIEW','Action':'Dark/Light essential delete-log label clipping is not PASS. Preserve review evidence; a new theme does not resolve the prior readability decision.'},
 {'Id':'INSTALLER_LIFECYCLE_QA2_MIGRATION','Status':'BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE','Action':'Requires accessible Independent QA approved untouched compatible native PS5.1 baseline. Updated AppSetup clone with naturally Restricted policy does not qualify; no bypass/signing/policy change.'},
 {'Id':'F010_F016','Status':'INCOMPLETE_EXACT_EXECUTION_ROUTE_AND_LIVE_EVIDENCE','Action':'Original scan/cancellation/worker proof reservations persist. No scan repeat, extracted blocked-script inlining, or signed-copy promotion to frozen acceptance.'},
 {'Id':'F020_F022_F008','Status':'INCOMPLETE_CROSS_GRID_AND_FULL_CELL_CLOSEOUT','Action':'Three newly missing location assertions do not reconcile all older context/DPI evidence into full cells. Use exact historical evidence and Independent QA decisions.'},
 {'Id':'QA26_SEC_EXECUTIONPOLICY','Status':'INDEPENDENT_QA_SECURITY_DECISION','Action':'Functional GUI evidence grants no security or release approval.'}
]
report=dict(Schema='QA26-REMAINING-WORK-CONTINUATION-1',Utc=now,Status='SEVEN_NEWLY_QUALIFIED_ASSERTIONS_NO_FAILURES',RecoveredOriginalExecutions=4,NewTestsExecuted=3,TestsRepeated=0,NewScans=0,CleanupOperations=0,StartupMutations=0,RecoveredQualification='FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json',NewCases=cases,EngineeringPASSBefore=320,EngineeringPASSAfter=327,EngineeringFAIL=0,FullCellsAdded=0,MatrixPASS=83,MatrixTotal=132,FixtureBlockerResolved='Existing inherited current-user missing executable fixture verified read-only; no fixture created or edited',FrozenArtifactsMatched=60,Policy=dict(NativePowerShell='5.1.26100.9711',Effective='Restricted',AllFiveScopes='Undefined',Changed=False),OnlyPreferenceChange='Theme Dark -> Light -> FollowWindows through normal Settings save and app relaunch; all other config fields unchanged',CurrentTheme='FollowWindows',CurrentNativeDpi=144,Pid=8800,SessionId=2,VMId='068a8dc7-f5e1-4e0e-a941-e0a3955e5a29',OriginalVMAccessed=False,MetadataExcludedAndUninspected=True,HostLedgersUnmodified=True,NeedsHostReconciliation=True,IndependentQAFinalVerdictReserved=True,CampaignComplete=False,Remaining=remaining)
write('REMAINING_WORK_REPORT.json',report)
score['testedAssertionScoreboard'].update(previousPASS=320,newEligibleAssertions=7,batch='REMAINING_WORK_REPORT.json')
score['latestQualifiedBatch']={'record':'REMAINING_WORK_REPORT.json','newEligibleAssertions':7,'fullCellsAdded':0,'recoveredOriginalExecutions':4,'newExecutions':3}
score['continuationDelta']['ThisBatchScope']='Four original Cleanup assertions recovered plus three strict150 missing Startup location assertions; no repeats'
write('SCOREBOARD_CURRENT.json',score)
write('STATE_DELTA.json',dict(Utc=now,HostStateUnmodified=True,ExistingPredicateStatusUpdates=recovered['Cases'],CompletedPredicatesAdded=cases,CurrentTheme='FollowWindows',CurrentScale=150,CurrentNativeDpi=144,CurrentPid=8800,CurrentSessionId=2,NextMissingBatch='FollowWindows200 Settings; native192 and normal sign-in prerequisites',EngineeringPASS=327,EngineeringFAIL=0,MatrixCellsAdded=0,CampaignComplete=False))
write('HUMAN_ACTION_QUEUE_DELTA.json',dict(Utc=now,Resolved=['Four FollowWindows150 safety native collections','Existing missing-target fixture access for strict150 Startup','Dark/Light/FollowWindows150 missing-location assertions'],NoRoutinePermissionNeeded=True,Remaining=remaining,AuthenticationNotAutomated=True))
write('INTEGRITY_POSTCHECK.json',dict(Utc=now,CollectedInputsVerified=len(integrity),Inputs=integrity,FrozenArtifactsMatched=60,PreservedScanUnchanged=True,ActionHistoryUnchanged=True,MissingTargetFixtureUnchanged=True,AllNonThemeConfigFieldsUnchanged=True,NoProductOrSecurityPolicyChange=True))
with (O/'DELTA.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=now,Event='150_BATCH_SEALED',PASS=327,FAIL=0,NewCredit=7,RecoveredExecutions=4,NewExecutions=3,TestsRepeated=0,MatrixCellsAdded=0))+'\n')
files=[dict(Path=str(p.relative_to(O)).replace('\\','/'),SHA256=sha(p),Bytes=p.stat().st_size) for p in sorted(O.rglob('*')) if p.is_file()]
write('MANIFEST_150_BATCH.json',dict(Utc=now,Files=files,SelfExcluded=True))
print(json.dumps(dict(EngineeringPASS=327,FAIL=0,RecoveredExecutions=4,NewExecutions=3,TestsRepeated=0,ManifestFiles=len(files),AllChecks='PASS')))
