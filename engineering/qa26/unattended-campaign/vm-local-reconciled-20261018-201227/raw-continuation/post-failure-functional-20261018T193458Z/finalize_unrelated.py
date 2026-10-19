import pathlib,json,hashlib,datetime,shutil
O=pathlib.Path(__file__).parent; ROOT=O.parent.parent; OLD=O.parent/'functional-exports-20261018T192122Z'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(n,v):
 p=O/n
 with p.open('x',encoding='utf-8') as f:json.dump(v,f,indent=2);f.write('\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
fixture=O/'protected-export-existing.txt';assert sha(fixture)=='347DA4DFCC8A8B70AF881F47799F9A43F93CA7512AA3B605B501D46BC5AEAC03'
# Preserve the accidentally emitted new output in this session, without changing old manifest-listed bytes.
emitted=OLD/'Nyx_PC_Checkup_Report_20261018_153811.txt'; target=O/'unexpected-native-txt-output.txt'
meta=read(O/'UNEXPECTED_TXT_OUTPUT_PROVENANCE.json');assert not emitted.exists() and sha(target)==meta['SHA256']
for e in read(OLD/'MANIFEST.json')['Files']:assert sha(OLD/e['Path'])==e['SHA256']
pre=read(O/'FILE_PREFLIGHT.json'); raw=[]
for e in pre['PreservedData']:
 p=pathlib.Path(e['Live']);assert sha(p)==e['SHA256'];raw.append(dict(Path=str(p),SHA256=sha(p),Unchanged=True))
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
for e in read(inst/'PAYLOAD_MANIFEST.json')['files']:
 p=inst/e['path'];assert sha(p)==e['sha256'].upper() and p.stat().st_size==e['size']
policy=read(O/'WINDOWS_PS51_POLICY_POSTCHECK.json');assert policy['EffectivePolicy']=='Restricted' and len(policy['Scopes'])==5 and all(s['Policy']=='Undefined' for s in policy['Scopes'])
windows=read(O/'FINAL_WINDOW_INVENTORY.json');assert [w['Handle'] for w in windows if w['Visible']]==[66444]
for p in O.glob('*.json'):
 r=read(p)
 if isinstance(r,dict) and r.get('Schema')=='QA26-ONE-SHOT-NYX-GUI-1':assert sha(pathlib.Path(r['Screenshot']))==r['ScreenshotSHA256'] and not r['ScreenshotReused']
check=dict(Utc=now,FrozenArtifactsMatched=60,PayloadManifestSHA256=sha(inst/'PAYLOAD_MANIFEST.json'),PreservedData=raw,ProtectedFixtureSHA256=sha(fixture),ProtectedFixtureUnchanged=True,PriorManifestFilesMatched=67,OldManifestListedFilesUnmodified=True,NativePolicy=policy,VisibleMainHandle=66444,NewScans=0,CleanupOperations=0,StartupMutations=0,OriginalVMAccessed=False,MetadataExcludedAndUninspected=True,ResolutionScalingThemeChanged=False)
write('INTEGRITY_POSTCHECK.json',check)
unq=dict(Schema='QA26-UNQUALIFIED-EXACT-ONCE-ATTEMPT-1',Utc=now,PredicateId='native_export_overwrite_decline_preserves_file_20261018',Status='EXECUTED_SETUP_INVALID_NO_CREDIT_NO_RETRY',AttemptCount=1,OverwritePromptObserved=False,DeclineActionDispatched=False,ProtectedFixtureUnchanged=True,NewPASS=0,NewFAIL=0,Outcome='Filename UIA edit appeared visually but did not establish the intended existing-file target. Save emitted the suggested TXT filename. Exact cause is not proven; no frozen product failure inferred.',Receipt='unexpected_native_txt_outcome_bound_20261018T1939583001179Z_d41bae956ffb45e4943f4739e9fcb80f.json',UnexpectedOutput=meta,RepeatAccounting='One unintended TXT export repeated an already-executed export behavior while attempting a distinct missing overwrite-decline case. No TXT credit and no retry.',CaptureError='After Continue, helper returned Visible window bounds unavailable; read-only inventory confirmed Save dialog opened. Continue was not repeated.',PDFImpact='Original PDF serialization failure remains documented. Its requested output-path evidence is not a proven committed path; selected PDF format and observed Lines binding failure remain direct evidence.',NoFrozenBytesChanged=True)
write('OVERWRITE_DECLINE_UNQUALIFIED.json',unq)
with (O/'CASE_EXECUTIONS.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=now,PredicateId=unq['PredicateId'],Event='CLOSED_UNQUALIFIED_NO_RETRY',Qualification='OVERWRITE_DECLINE_UNQUALIFIED.json',NewPASS=0,NewFAIL=0,UnintendedRepeatedTxtExport=1))+'\n')
remaining=[
 dict(Id='DPI_SCALING_LAYOUT',Status='SKIPPED_BY_OWNER',Action='No display/theme/resolution changes or testing; no credit.'),
 dict(Id='EXACT_FROZEN_SOURCE_AND_QA2_FIXTURES',Status='RECOVERED_VERIFIED_DATA_ONLY',Evidence='PINNED_SOURCE_RECOVERY.json',Action='Prior unavailable-files claim superseded; 145 source file and 2 fixture hashes match.'),
 dict(Id='NATIVE_SAVE_CANCEL',Status='QUALIFIED_EXISTING_EXECUTION_NO_RERUN',Evidence='CANCEL_RECOVERY_QUALIFICATION.json',Credit=1),
 dict(Id='NATIVE_TXT_JSON_EXPORT',Status='PREVIOUSLY_EXECUTED_NO_ADDITIONAL_CREDIT',Action='Existing reports/ledger executions retained. One unintended TXT output is quarantined as evidence, with no score credit.'),
 dict(Id='NATIVE_PDF_EXPORT',Status='FAIL_PRESERVED_NO_RETEST',Evidence='PRESERVED_PDF_FAILURE.json',Action='Frozen product unchanged; failure remains open. Owner waives first-failure stop only for unrelated work.'),
 dict(Id='NATIVE_OVERWRITE_DECLINE',Status='EXECUTED_SETUP_INVALID_NO_RETRY',Evidence='OVERWRITE_DECLINE_UNQUALIFIED.json',Action='Do not repeat this attempt or claim a decline/overwrite PASS.'),
 dict(Id='STANDARD_F010_F016_PRIVACY_SUITE_REMAINDER',Status='BLOCKED_UNCHANGED_EXECUTION_POLICY',Action='Exact unsigned runners now available, but Restricted native PS5.1 does not permit unchanged execution. No policy change, signing, inlining or product-launcher workaround.'),
 dict(Id='WINDOWS_GATE_ORCHESTRATOR',Status='BLOCKED_ROUTE_AND_FULL_MASTER_DEPENDENCY',Action='Pinned orchestrator constructs prohibited QA ExecutionPolicy Bypass; MASTER_MANIFEST.json is not in recovered source archive. Not executed.'),
 dict(Id='ELEVATED_STARTUP_ROLLBACK',Status='BLOCKED_ISOLATED_BASELINE_AND_EXECUTION_ROUTE',Action='Requires qualified disposable native baseline and permitted exact runner route; updated in-use clone not treated as destructive-suite baseline.'),
 dict(Id='INSTALLER_LIFECYCLE_QA2_MIGRATION',Status='BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE',Action='Exact fixtures recovered, but Independent QA approved untouched compatible baseline remains unavailable here. Original VM stays Saved/unaccessed.'),
 dict(Id='PREVIOUS_SUITE_EXECUTIONS',Status='NO_REPEATS',Action='Python224/lint2/nativeF023116, signed-copy Smoke122/Settings17/privilege10 and F01139 already executed. No rerun or signed-copy promotion to frozen acceptance.'),
 dict(Id='HISTORICAL_EVIDENCE_RESERVATIONS_AND_FINAL_DECISION',Status='INDEPENDENT_QA_ONLY',Action='Stale images, older context/DPI gaps, Settings200 label and disputed metadata are reserved; no retrospective credit or security/release verdict.'),
]
write('REMAINING_WORK_DISPOSITION.json',dict(Utc=now,FirstFailureStopRule='OVERRIDDEN_BY_USER_FOR_UNRELATED_TESTS',Items=remaining,NoCurrentlyRunnableMissingCaseIdentifiedUnderCurrentConstraints=True,CampaignComplete=False))
write('HUMAN_ACTION_QUEUE_DELTA.json',dict(Utc=now,RoutinePermissionsRequested=0,OwnerActionRequiredNow=False,Pending=[r for r in remaining if r['Status'].startswith('BLOCKED') or r['Status']=='INDEPENDENT_QA_ONLY'],NoPolicyChangeRequested=True,NoDpiActionRequested=True))
score=read(O/'SCOREBOARD_AFTER_CANCEL_RECOVERY.json');assert score['testedAssertionScoreboard']['PASS']==328 and score['testedAssertionScoreboard']['FAIL']==1
score['updatedUtc']=now;score['campaignStatus']='NO_FURTHER_ELIGIBLE_RUNNABLE_CASE_IDENTIFIED_UNDER_CURRENT_CONSTRAINTS';score['campaignComplete']=False
score['testedAssertionScoreboard'].update(previousFAIL=1,scope='Local Engineering aggregate including149 historical signed-copy assertions; one existing native Save-cancel execution newly qualified in this batch. Not frozen-candidate acceptance or release/security approval.')
score['continuationDelta'].update(NewPASS=1,NewFAIL=0,PriorLocalScoreboard='../functional-exports-20261018T192122Z/SCOREBOARD_CURRENT.json',UnintendedRepeatedTxtExport=1,UnqualifiedOverwriteAttempt=1)
write('SCOREBOARD_CURRENT.json',score)
write('STATE_DELTA.json',dict(Utc=now,EngineeringPASS=328,EngineeringFAIL=1,NewQualifiedPASS=1,NewQualifiedFAIL=0,QualifiedExecution='Existing native Save dialog cancel; no rerun',NewAttempt='Overwrite-decline setup invalid, no credit/no retry',UnintendedRepeatedBehavior='TXT export once; no credit',FullCellsAdded=0,MatrixPASS=83,MatrixTotal=132,DpiTestingSkipped=True,ProductModified=False,SecurityPolicyChanged=False,OriginalVmAccessed=False,ImportedHostLedgersModified=False,NeedsSeparateHostReconciliation=True,CampaignComplete=False,Disposition='REMAINING_WORK_DISPOSITION.json'))
with (O/'DELTA.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=now,Event='UNRELATED_WORK_CLOSED_WITH_EXACT_DISPOSITIONS',NewPASS=0,NewFAIL=0,EngineeringPASS=328,EngineeringFAIL=1,UnqualifiedAttempts=1,UnintendedRepeatedTxtExport=1,OriginalPdfFailureRetained=True,FirstFailureRuleOverrideApplied=True,NoFurtherRunnableCaseIdentified=True))+'\n')
report='''QA26 unrelated functional continuation
Local Engineering score: 328 PASS, 1 FAIL. Matrix remains 83/132; no matrix credit.
One previously executed native Save-dialog cancellation newly qualified from existing evidence, without rerunning it.
The existing PDF Lines binding failure remains documented and open. Frozen product bytes are unchanged.
One new overwrite-decline attempt was invalid: the native dialog saved its suggested TXT filename despite the helper filename edit. The intended overwrite prompt never appeared. This inadvertently repeated TXT export once; no credit, no product failure inferred, no retry. New output was moved into this continuation folder with provenance; protected fixture and old manifest-listed evidence remain unchanged.
Pinned source and QA2 fixtures recovered and hash verified. Previous missing-files claims are superseded. No blocked script was executed.
All DPI/scaling/layout testing skipped by owner. No resolution, scaling, theme, Windows security or execution-policy change.
Remaining scripts require a permitted exact execution route; native PS5.1 remains Restricted with all five scopes Undefined. Lifecycle/migration also require the approved untouched compatible baseline. Historical evidence reservations and security/release decisions remain Independent QA work. See REMAINING_WORK_DISPOSITION.json.
First-failure stop overridden for unrelated tests. No routine permission questions. No further eligible runnable missing case identified under current constraints. Campaign is incomplete, not approved for release.
All 60 frozen artifacts match; preserved scan/config/history and protected fixture are unchanged. Original VM unaccessed. Imported host ledgers unchanged; local delta needs separate reconciliation.
'''
with (O/'CONTINUATION_REPORT.txt').open('x',encoding='utf-8') as f:f.write(report)
files=[dict(Path=str(p.relative_to(O)).replace('\\','/'),Bytes=p.stat().st_size,SHA256=sha(p)) for p in sorted(O.rglob('*')) if p.is_file() and p.name!='MANIFEST.json']
write('MANIFEST.json',dict(Schema='QA26-CONTINUATION-MANIFEST-1',Utc=now,Files=files,Count=len(files)))
for e in read(O/'MANIFEST.json')['Files']:assert sha(O/e['Path'])==e['SHA256']
print(json.dumps(dict(EngineeringPASS=328,EngineeringFAIL=1,ManifestFiles=len(files),FrozenArtifactsMatched=60,PreservedDataUnchanged=True,ProtectedFixtureUnchanged=True,PriorManifestMatched=67,CampaignComplete=False,UnintendedRepeatedTxtExport=1)))
