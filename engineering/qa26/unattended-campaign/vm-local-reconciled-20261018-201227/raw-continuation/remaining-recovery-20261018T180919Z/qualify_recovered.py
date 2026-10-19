import json,datetime,pathlib,hashlib
O=pathlib.Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(n,v):
 p=O/n
 if p.exists():raise RuntimeError('Refuse overwrite '+str(p))
 p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
b=read(O/'inputs/ledgers/FOLLOWWINDOWS150_CLEANUP_CONFIRM_CANCEL_BATCH_20261018.json')
n=read(O/'NATIVE_BINDINGS.json')
assert len(n['Bindings'])==4 and n['EarlierObserverPrefixMatchesPreservedReadOnlyExport']
assert read(O/'inputs/historical-config.json')['theme']=='FollowWindows'
observations=[
 'One selected item / 0 B summary and review action readable; candidate identity supported by the preserved checked BITFB98.tmp frame.',
 'Destructive confirmation visibly states 1 item / 0 B and Windows Recycle Bin consequence with Yes/No; no acceptance recorded.',
 'Supporting fresh frame shows dotted focus on No; subsequent primary frame has no modal, retains 1 item / 0 B and Ready.',
 'Supporting frame retains checked BITFB98.tmp after No. Final primary frame shows 0 items / 0 B, focused review action, Ready.'
]
cases=[]
for c,bind,obs in zip(b['cases'],n['Bindings'],observations):
 assert c['id']==bind['PredicateId']
 r={**c,'status':'PASS_ENGINEERING_NATIVE_QUALIFIED','assertionCredit':1,'fullCellCredit':0,'qualification':'FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json','visualReview':obs,'nativeBinding':bind,'originalExecutionUtc':c['utc'],'qualifiedUtc':now,'rerun':False}
 cases.append(r)
q=dict(Schema='QA26-HISTORICAL-SAFETY-RECOVERY-QUALIFICATION-1',Utc=now,Status='FOUR_EXISTING_EXECUTIONS_NATIVE_QUALIFIED',FrozenSource='0303a78a06f67252c86634cd73f1e4bda32dd3cc',Build='2026.10.02-eng-qa26',Harness='QA26-F023-PS51-26',Cases=cases,NativeContext=dict(Pid=1800,NativeDpi=144,Scale=150,Theme='FollowWindows',OriginalExecutionInterval=[b['startedUtc'],b['completedExecutionUtc']]),Collection='COLLECTION_RECEIPT.json',NativeBindings='NATIVE_BINDINGS.json',PayloadAudit='PAYLOAD_AUDIT.json',SourceProvenance=dict(Route='Original contemporaneous raw inherited from independent checkpoint clone; ordinary local read-only copy and hash, no source VM access',CheckpointId='a61b38f3-d4b8-4563-962e-e19552283f8b',CheckpointUtc='2026-10-18T15:29:53.0217130Z',OriginalVMId='275a191c-cf8a-4929-9849-b9a293e9149d',CollectionCloneVMId='068a8dc7-f5e1-4e0e-a941-e0a3955e5a29',ObserverFilenameBoundByOriginalSetupCapture=True,OriginalObserverPrefixComparedToEarlierReadOnlyExport=True),NewEligibleAssertionCredit=4,EngineeringPASSBefore=320,EngineeringPASSAfter=324,EngineeringFAIL=0,FullCellsAdded=0,MatrixPASS=83,MatrixTotal=132,NewTestsExecuted=0,TestsRepeated=0,ScansExecuted=0,CleanupExecuted=0,ProductChanged=False,SecurityOrExecutionPolicyChanged=False,OriginalVMAccessed=False,MetadataExcludedAndUninspected=True,CampaignComplete=False,FinalDecisionOwner='Independent QA',Limitations=['Partial functional assertions only; no whole-cell or focused-gate completion','Recovery qualifies the exact original 13:35–13:37Z executions from their contemporaneous raw; current clone DPI, theme or OS is not applied retrospectively','The copied raw is preserved evidence, not fresh execution on the updated clone','Independent QA/security and old screenshot/native gaps remain reserved'])
write('FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json',q)
score=read(O/'inputs/prior-continuation/SCOREBOARD_CURRENT.json')
assert score['testedAssertionScoreboard']['PASS']==320
score['testedAssertionScoreboard'].update(PASS=324,FAIL=0,previousPASS=320,newEligibleAssertions=4,batch='FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json')
score['latestQualifiedBatch']={'record':'FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json','newEligibleAssertions':4,'fullCellsAdded':0}
score['updatedUtc']=now
score['continuationDelta']={'HostLedgerUnmodified':True,'NeedsSeparateHostReconciliation':True,'BaseHostScoreboardSHA256':sha(O/'inputs/ledgers/SCOREBOARD_CURRENT.json'),'PriorLocalScoreboard':'../dark150-native144-20261018T175251Z/SCOREBOARD_CURRENT.json','ThisBatchScope':'Four original FollowWindows150 safety executions, recovered contemporaneous evidence; no reruns'}
write('SCOREBOARD_AFTER_RECOVERY.json',score)
write('STATE_RECOVERY_DELTA.json',dict(Utc=now,HostStateUnmodified=True,ExistingPredicateStatusUpdates=cases,CompletedPredicateIdsAdded=[],EngineeringPASS=324,EngineeringFAIL=0,MatrixCellsAdded=0,CampaignComplete=False))
write('HUMAN_ACTION_QUEUE_RECOVERY_DELTA.json',dict(Utc=now,followWindows150CleanupSafety20261018=dict(status='FOUR_EXISTING_EXECUTIONS_NATIVE_QUALIFIED',qualification='FOLLOWWINDOWS150_CLEANUP_SAFETY_RECOVERED_QUALIFICATION.json',additionalHumanActionRequired=False,testsRepeated=0),OtherHistoricalReservationsUnchanged=True))
with (O/'DELTA.jsonl').open('x',encoding='utf-8') as f:
 for i,c in enumerate(cases):f.write(json.dumps(dict(Utc=now,Event='ORIGINAL_EXECUTION_QUALIFIED',PredicateId=c['id'],OriginalExecutionUtc=c['utc'],NewCredit=1,EngineeringPASS=321+i,EngineeringFAIL=0,FullCellsAdded=0,TestsExecutedNow=0,Qualification=q['Cases'][i]['qualification']))+'\n')
print(json.dumps({'RecoveredPASS':4,'EngineeringPASS':324,'FAIL':0,'NewExecutions':0,'RepeatedTests':0}))
