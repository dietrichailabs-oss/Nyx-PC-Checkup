import pathlib,json,hashlib,datetime
O=pathlib.Path(__file__).parent;OLD=O.parent/'functional-exports-20261018T192122Z'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
before=OLD/'installed_export_txt_filename_setup_20261018T1924315664584Z_e289314744d1447e9266b1cb2070a1f9.json'
after=OLD/'installed_export_txt_abort_prior_output_20261018T1925130094582Z_0dc27aaba8ef428ab7928409f642848e.json'
b=read(before);a=read(after)
assert b['WindowHandle']==394700 and b['WindowTitle']=='Export privacy-safe Nyx PC Checkup report'
assert b['Command']=='filename' and b['Arguments'][-1]=='report-native-txt.txt'
assert a['Command']=='key' and a['Arguments'][0]=='394700' and a['Arguments'][-1]=='ESC'
assert a['WindowHandle']==66444 and a['WindowTitle']=='Nyx PC Checkup'
assert a['Pid']==b['Pid']==11392 and a['SessionId']==b['SessionId']==1
assert a['TargetElevated'] is False and a['HelperElevated'] is False
assert a['FocusedElement']['Name']=='Export report'
for r in [a,b]:assert sha(pathlib.Path(r['Screenshot']))==r['ScreenshotSHA256'].upper() and r['ScreenshotReused'] is False
events=[json.loads(v) for v in (OLD/'CASE_EXECUTIONS.jsonl').read_text(encoding='utf-8-sig').splitlines() if v.strip()]
e=[e for e in events if e['Event']=='ABORTED_BEFORE_SAVE_PRIOR_EXECUTION_DISCOVERED'];assert len(e)==1 and e[0]['NewTXTOutputWritten'] is False
assert not read(OLD/'INTEGRITY_POSTCHECK.json')['UnexpectedTxtOutputExists']
assert not (OLD/'report-native-txt.txt').exists()
newid='native_export_save_dialog_cancel_20261018'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
q=dict(Schema='QA26-RECOVERED-NATIVE-SAVE-CANCEL-1',Utc=now,PredicateId=newid,Status='PASS_ENGINEERING_NATIVE_QUALIFIED',Predicate='Escape from the native export Save dialog creates no output and restores the idle main app/Export action',ExecutionSourceCase='installed_gui_export_txt_missing_20261018',OriginalExecutionUtc=a['CaptureStartedUtc'],BeforeReceipt=str(before),AfterReceipt=str(after),BeforeImageSHA256=b['ScreenshotSHA256'],AfterImageSHA256=a['ScreenshotSHA256'],OutputNotWritten=True,OriginalEvent=e[0],PriorQualificationForThisCancelPredicate=False,PreviouslyExecutedBehaviorNotRepeated=True,NewExecutions=0,NewAssertionCredit=1,NoCreditForTxtExport=True,NoCreditForSharedPreview=True,NoDpiOrMatrixCredit=True,Build='2026.10.02-eng-qa26',FrozenSource='0303a78a06f67252c86634cd73f1e4bda32dd3cc',Harness='QA26-F023-PS51-26',PriorIntegrity='..\\functional-exports-20261018T192122Z\\INTEGRITY_POSTCHECK.json',CurrentFilePreflight='FILE_PREFLIGHT.json',OriginalPDFailureRetained=True,EngineeringPASSAfter=328,EngineeringFAIL=1,Scope='One previously uncredited native Save-dialog cancellation assertion from the preserved actual execution. Not a TXT export, whole privacy suite or final acceptance verdict.')
target=O/'CANCEL_RECOVERY_QUALIFICATION.json'
if target.exists():raise RuntimeError('Cancel already qualified')
target.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
score=read(O/'BASE_SCOREBOARD_CURRENT.json');assert score['testedAssertionScoreboard']['PASS']==327 and score['testedAssertionScoreboard']['FAIL']==1
score['testedAssertionScoreboard'].update(PASS=328,previousPASS=327,newEligibleAssertions=1,newEligibleFailures=0,batch='CANCEL_RECOVERY_QUALIFICATION.json')
score['latestQualifiedBatch']={'record':'CANCEL_RECOVERY_QUALIFICATION.json','newEligibleAssertions':1,'newEligibleFailures':0,'fullCellsAdded':0,'repeatedTests':0}
score['campaignStatus']='CONTINUING_UNRELATED_TESTS_USER_FIRST_FAILURE_OVERRIDE'
score['updatedUtc']=now
(O/'SCOREBOARD_AFTER_CANCEL_RECOVERY.json').write_text(json.dumps(score,indent=2)+'\n',encoding='utf-8')
with (O/'DELTA.jsonl').open('x',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=now,Event='EXISTING_NATIVE_CANCEL_QUALIFIED_NO_RERUN',PredicateId=newid,NewPASS=1,NewFAIL=0,EngineeringPASS=328,EngineeringFAIL=1,NewExecutions=0,MatrixCredit=0))+'\n')
print(json.dumps(dict(RecoveredCancel='PASS',EngineeringPASS=328,EngineeringFAIL=1,TestReruns=0)))
