import pathlib,json,hashlib,datetime,shutil
O=pathlib.Path(__file__).parent
ROOT=O.parent.parent
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(n,v):
 p=O/n
 if p.exists():raise RuntimeError('Refuse overwrite '+str(p))
 p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
caseid='installed_gui_export_pdf_missing_20261018'
events=[json.loads(v) for v in (O/'CASE_EXECUTIONS.jsonl').read_text(encoding='utf-8-sig').splitlines() if v.strip()]
for name in ['STARTED_ONCE','SAVE_DISPATCHED_ONCE','EXECUTED_PRODUCT_FAILURE_STOP']:
 assert sum(e['PredicateId']==caseid and e['Event']==name for e in events)==1
assert sum(e['Event']=='ABORTED_BEFORE_SAVE_PRIOR_EXECUTION_DISCOVERED' for e in events)==1
assert not (O/'report-native-pdf.pdf').exists() and not (O/'report-native-txt.txt').exists()
errpath=O/'installed_export_pdf_outcome_bound_20261018T1927120209670Z_bcddaff394f442788d20cc32f74b5a6e.json'
r=read(errpath)
error="The report could not be exported.\r\nCannot bind argument to parameter 'Lines' because it is an empty string."
assert any(e['Name']==error for e in r['VisibleElements'])
assert r['WindowHandle']==590658 and r['WindowClass']=='#32770' and r['WindowTitle']=='Nyx PC Checkup'
assert r['Pid']==11392 and r['SessionId']==1 and r['HelperElevated'] is False and r['TargetElevated'] is False
assert sha(pathlib.Path(r['Screenshot']))==r['ScreenshotSHA256'].upper() and r['ScreenshotReused'] is False
assert read(O/'INTEGRITY_POSTCHECK.json')['FrozenArtifactsMatched']==60
pre=read(O/'PRECONDITIONS.json');assert sha(O/'NyxExportProbe.exe')==pre['HelperSHA256']
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
sources=[]
for rel in ['app/reports/PdfWriter.psm1','app/reports/ReportExport.psm1','app/ui/MainWindow.psm1','PAYLOAD_MANIFEST.json']:
 p=inst/rel;dest=O/'frozen-source-evidence'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(p,dest);assert sha(p)==sha(dest)
 sources.append(dict(Path=rel,SHA256=sha(p),Copy=str(dest.relative_to(O)).replace('\\','/')))
sourcehashes={s['Path']:s['SHA256'] for s in sources}
qualification=dict(Schema='QA26-INSTALLED-PDF-EXPORT-FAILURE-1',Utc=now,PredicateId=caseid,Status='FAIL_ENGINEERING_NATIVE_QUALIFIED',Build='2026.10.02-eng-qa26',FrozenSource='0303a78a06f67252c86634cd73f1e4bda32dd3cc',Harness='QA26-F023-PS51-26',VMId='068a8dc7-f5e1-4e0e-a941-e0a3955e5a29',Pid=11392,SessionId=1,MainWindow=66444,SaveDialog=525122,OwnedErrorDialog=590658,NonElevated=True,Preconditions='PRECONDITIONS.json',SelectedFormatReceipt='installed_export_pdf_type_selected_20261018T1926339243586Z_853321a45d8e4c18bccc83f61e6bb634.json',SaveDispatchReceipt='installed_gui_export_pdf_missing_20261018_20261018T1926490388348Z_a7cc1836bc4d466085f7f40abfbb23f8.json',ErrorReceipt=errpath.name,ErrorScreenshot=pathlib.Path(r['Screenshot']).name,ErrorScreenshotSHA256=r['ScreenshotSHA256'],ExactError=error,Expected='Native Export report -> Continue to save -> PDF summary (*.pdf) -> fresh destination produces a valid readable PDF of the preserved Full scan',Actual='Handled export error. No PDF file created.',Output='report-native-pdf.pdf',OutputExists=False,SaveDispatchedExactlyOnce=True,ScanSHA256='9EBD0A3DD3933AB3161AE1629E9E010A0805C4A177CC440E560BB1B67A4295DE',ScanCompletedUtc='2026-10-08T23:05:25.6882604Z',FrozenSourceEvidence=sources,RootCauseAssessment=dict(Classification='STATIC_SOURCE_CORRELATION_NOT_REEXECUTED',Finding='ReportExport.psm1 deliberately adds empty separator lines at lines57/61 and other locations; line84 passes the split report text into Write-NyxSimplePdf. PdfWriter.psm1 line30 declares mandatory string[] Lines without AllowEmptyString. This matches the observed argument-binding error before output is written.',ProductEdited=False,NoBindingReproOrTestRerun=True),DpiTestingSkippedByOwner=True,DpiOrMatrixCredit=0,NoDisplayOrThemeChangeDuringBatch=True,NewEngineeringFailureCredit=1,EngineeringPASS=327,EngineeringFAIL=1,TestsRepeated=0,NewScan=False,Cleanup=False,PolicyChanged=False,MetadataExcludedAndUninspected=True,OriginalVMAccessed=False,Integrity='INTEGRITY_POSTCHECK.json',FurtherTestsStopped=True,StopRule='AGENTS.md: Stop on a first genuine product failure with evidence; do not change frozen bytes.',IndependentQAFinalVerdictReserved=True,CampaignComplete=False)
write('PDF_EXPORT_FAILURE_QUALIFICATION.json',qualification)
score=read(O/'BASE_SCOREBOARD_CURRENT.json')
assert score['testedAssertionScoreboard']['PASS']==327 and score['testedAssertionScoreboard']['FAIL']==0
score['testedAssertionScoreboard'].update(PASS=327,FAIL=1,previousPASS=327,previousFAIL=0,newEligibleAssertions=0,newEligibleFailures=1,batch='PDF_EXPORT_FAILURE_QUALIFICATION.json')
score['latestQualifiedBatch']={'record':'PDF_EXPORT_FAILURE_QUALIFICATION.json','newEligibleAssertions':0,'newEligibleFailures':1,'fullCellsAdded':0,'scope':'One new installed functional GUI PDF-export failure, independent of DPI testing'}
score['updatedUtc']=now
score['campaignComplete']=False
score['campaignStatus']='STOPPED_FIRST_GENUINE_PRODUCT_FAILURE_INDEPENDENT_QA_DISPOSITION_REQUIRED'
score['continuationDelta']={'HostLedgerUnmodified':True,'NeedsSeparateHostReconciliation':True,'PriorLocalScoreboard':'../remaining-recovery-20261018T180919Z/SCOREBOARD_CURRENT.json','DpiTestingSkippedByOwner':True,'NewPASS':0,'NewFAIL':1,'NoMatrixCredit':True}
write('SCOREBOARD_CURRENT.json',score)
write('STATE_DELTA.json',dict(Utc=now,HostStateUnmodified=True,CompletedPredicatesAdded=[qualification],PriorLocalEngineeringPASS=327,EngineeringPASS=327,EngineeringFAIL=1,TestsRepeated=0,NewScans=0,CompletedDpiCasesRepeated=0,AllRemainingDpiTesting='SKIPPED_BY_OWNER_NO_CREDIT',TxtCase='Prospective duplicate aborted before save after historical native TXT output discovered; no credit',NextAction='Independent QA disposition of documented frozen-candidate PDF export failure. No further case execution or product edit under first-failure stop rule.',CampaignComplete=False))
remaining=[
 {'Work':'All DPI/scaling/layout matrix testing','Status':'SKIPPED_BY_OWNER','Credit':0,'Action':'Owner takes DPI issue to QA. No more display changes or testing.'},
 {'Work':'Native TXT export','Status':'PREVIOUSLY_EXECUTED_OUTPUT_DISCOVERED_NO_RETEST','Credit':0,'Evidence':'historical-native-txt-20261016_174520.txt'},
 {'Work':'Native PDF export','Status':'FAIL_ENGINEERING_NATIVE_QUALIFIED','Credit':0,'FailureCredit':1,'Evidence':'PDF_EXPORT_FAILURE_QUALIFICATION.json'},
 {'Work':'InstallerLifecycle and QA2Migration','Status':'BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE','Action':'Independent QA approved accessible untouched compatible native PS5.1 baseline required. Updated AppSetup clone is ineligible. No policy bypass, re-signing or product mutation.'},
 {'Work':'Standard / F010 malformed / F016 concurrency / elevated rollback / privacy safety suite closeout','Status':'NOT_COMPLETED_EXECUTION_AND_FIXTURE_PREREQUISITES_PLUS_FIRST_FAILURE_STOP','Action':'Exact frozen test source/fixtures are host-only dependencies, not included in this handoff; current native PS5.1 Restricted/allUndefined also blocks script execution. Previously executed signed-copy Smoke122, Settings17 and standard-privilege10 assertions are not rerun or promoted to frozen acceptance. No extraction/inlining workaround.'},
 {'Work':'Seven stale-image cases, old native/context gaps, Settings200 label and disputed metadata','Status':'INDEPENDENT_QA_RESERVED_NO_RETEST','Action':'Preserve prior evidence and scope; no retrospective acceptance or metadata inspection.'},
 {'Work':'QA26 security/release verdict','Status':'INDEPENDENT_QA_ONLY','Action':'No release or security approval issued.'}
]
write('HUMAN_ACTION_QUEUE_DELTA.json',dict(Utc=now,Status='NO_ROUTINE_PERMISSION_OR_AUTHENTICATION_REQUEST',Previous200SignInRequest='SUPERSEDED_OWNER_SKIPPED_ALL_DPI',CurrentStop='FIRST_GENUINE_PRODUCT_FAILURE',Failure='PDF_EXPORT_FAILURE_QUALIFICATION.json',Remaining=remaining,NoUserCredentialsRequested=True,NoPublicationOrMessageSent=True))
write('REMAINING_NON_DPI_WORK.json',dict(Utc=now,Scope='Eligible non-DPI continuation under frozen-product and unchanged-policy constraints',Results=remaining,CampaignComplete=False,NoAllTestsCompleteClaim=True))
with (O/'DELTA.jsonl').open('x',encoding='utf-8') as f:
 f.write(json.dumps(dict(Utc=now,Event='TXT_PRIOR_OUTPUT_DISCOVERED_NO_SAVE_NO_CREDIT',Credit=0,NoRepeat=True))+'\n')
 f.write(json.dumps(dict(Utc=now,Event='PDF_EXPORT_FAILURE_NATIVE_QUALIFIED',PredicateId=caseid,NewPASS=0,NewFAIL=1,EngineeringPASS=327,EngineeringFAIL=1,MatrixCellsAdded=0,FurtherTestExecutionStopped=True))+'\n')
bug="""QA26: installed PDF report export fails on a normal preserved Full report

Build: 2026.10.02-eng-qa26
Frozen source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc
Harness reference: QA26-F023-PS51-26
Engineering reproduction count: ONE; no repeat attempted.

Reproduction performed through the normal, non-elevated installed GUI:
1. Open the frozen installed Nyx PC Checkup with its preserved Full scan.
2. Choose Export report, then Continue to save in the preview.
3. In the native save dialog, choose PDF summary (*.pdf).
4. Select a new file in this continuation folder and choose Save once.

Expected: A valid readable PDF report is created.
Actual: No PDF is created. A Nyx error dialog says:
The report could not be exported.
Cannot bind argument to parameter 'Lines' because it is an empty string.

Primary evidence:
PDF_EXPORT_FAILURE_QUALIFICATION.json
installed_export_pdf_outcome_bound_20261018T1927120209670Z_bcddaff394f442788d20cc32f74b5a6e.png
CASE_EXECUTIONS.jsonl
INTEGRITY_POSTCHECK.json

Source correlation (read only; no repair or new binding experiment):
ReportExport.psm1 adds blank separator lines to the report text, then passes
the split text to Write-NyxSimplePdf at line84. PdfWriter.psm1 line30 declares
mandatory string[] Lines without allowing empty strings. This matches the
observed argument-binding failure. The prior signed-copy PDF-header check
does not establish that a full normal installed report can be exported.

All60 frozen artifacts match. Original scan, config and action history are
unchanged. No scan, cleanup, startup mutation, Windows/security/policy change,
original VM access, metadata inspection, or DPI test was performed here.

The prospective TXT save was cancelled before saving because an earlier
same-build native TXT report was discovered on Desktop. Its original bytes
were copied and hashed; no duplicate TXT export or new credit was taken.

Local Engineering scoreboard: 327 PASS / 1 FAIL. Matrix remains83/132.
Further testing stopped at the first genuine product failure as required by
AGENTS.md. Product remains frozen; Independent QA owns final disposition.
All remaining DPI testing is skipped by owner direction, without PASS credit.
"""
(O/'BUG_REPORT.txt').write_text(bug,encoding='utf-8')
manifest=[dict(Path=str(p.relative_to(O)).replace('\\','/'),Bytes=p.stat().st_size,SHA256=sha(p)) for p in sorted(O.rglob('*')) if p.is_file()]
write('MANIFEST.json',dict(Utc=now,Files=manifest,SelfExcluded=True))
for f in manifest:assert sha(O/f['Path'])==f['SHA256']
print(json.dumps(dict(EngineeringPASS=327,EngineeringFAIL=1,QualifiedNewFunctionalCases=1,SaveDispatchCount=1,TestsRepeated=0,TxtDuplicatePrevented=True,FrozenArtifactsMatched=60,ManifestFilesVerified=len(manifest),FurtherTestsStopped=True,AllEvidenceChecks='PASS')))
