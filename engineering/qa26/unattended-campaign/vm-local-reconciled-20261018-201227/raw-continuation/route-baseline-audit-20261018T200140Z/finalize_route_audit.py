import pathlib,json,hashlib,datetime
O=pathlib.Path(__file__).parent;ROOT=O.parent.parent;PREV=O.parent/'post-failure-functional-20261018T193458Z';SRC=PREV/'pinned-source-data/Nyx_PC_Checkup_1.0.0_Source'
def rd(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def put(n,v):
 with (O/n).open('x',encoding='utf-8') as f:json.dump(v,f,indent=2);f.write('\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
for e in rd(PREV/'MANIFEST.json')['Files']:assert sha(PREV/e['Path'])==e['SHA256']
previous_integrity=rd(PREV/'INTEGRITY_POSTCHECK.json');raw=[]
for e in previous_integrity['PreservedData']:
 p=pathlib.Path(e['Path']);assert sha(p)==e['SHA256'];raw.append(dict(Path=str(p),SHA256=sha(p),Unchanged=True))
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup');m=rd(inst/'PAYLOAD_MANIFEST.json');assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
for e in m['files']:assert sha(inst/e['path'])==e['sha256'].upper() and (inst/e['path']).stat().st_size==e['size']
for e in rd(SRC/'SOURCE_TREE_IDENTITY.json')['files']:assert sha(SRC/e['path'])==e['sha256'].upper()
ledgers=[]
prior_input=O.parent/'remaining-recovery-20261018T180919Z/inputs/ledgers'
for p in sorted((ROOT/'authoritative-ledgers').iterdir()):
 if p.is_file():
  match=prior_input/p.name
  if match.is_file():assert sha(p)==sha(match)
  ledgers.append(dict(Path=str(p),SHA256=sha(p),MatchesPriorCopiedInput=match.is_file() and sha(p)==sha(match)))
put('INTEGRITY_POSTCHECK.json',dict(Utc=now,FrozenArtifactsMatched=60,SourceTreeFilesMatched=145,PriorContinuationManifestFilesMatched=len(rd(PREV/'MANIFEST.json')['Files']),PreservedData=raw,ImportedLedgerFiles=ledgers,NoProductOrSecurityPolicyChange=True,OriginalVMAccessed=False,MetadataExcludedAndUninspected=True,NewTestsExecuted=0,RepeatedTests=0,DisplayThemeChanges=0))
# Map suite names to exact pinned files without executing any runner or creating a launcher.
files=['tests/powershell/RUN_QA15_WINDOWS_GATE.ps1','tests/powershell/Run-WindowsSmokeTests.ps1','tests/powershell/Run-WindowsSettingsThemeRegression.ps1','tests/powershell/Run-WindowsElevatedStartupRollback.ps1','tests/powershell/Run-WindowsInstallerLifecycle.ps1','tests/powershell/Run-WindowsQA2MigrationRegression.ps1','tests/powershell/Test-QA19ProgressConcurrency.ps1','tests/fixtures/qa2/Nyx_PC_Checkup_1.0.0_QA2_Setup.exe']
pins=[dict(Path=str(SRC/f),RelativePath=f,Bytes=(SRC/f).stat().st_size,SHA256=sha(SRC/f)) for f in files]
setup=pathlib.Path(r'C:\Q26F023\Nyx_PC_Checkup_1.0.0_Setup.exe');assert sha(setup)=='A2D3571A1C96FCD39A95E40376FE0861AAC27C58545C3842DE75EB19B2E9331C'
pins.append(dict(Path=str(setup),Bytes=setup.stat().st_size,SHA256=sha(setup)))
put('PINNED_RESUME_ARTIFACTS.json',dict(Utc=now,Files=pins,AllAvailable=True,Source='Existing verified QA26 source archive and staged candidate; no rebuild/re-sign/repackage',ExecuteNow=False))
hist=rd(ROOT/'preserved-context/engineering/qa26/unattended-campaign/BASELINE_NATIVE_RECONCILIATION_20261017.json')
put('BASELINE_DISPOSITION.json',dict(Utc=now,CurrentGuest=rd(O/'VM_GUEST_IDENTITY.json'),CurrentGuestEligibleForLifecycleMigration=False,HistoricalAudit=dict(Path='preserved-context/engineering/qa26/unattended-campaign/BASELINE_NATIVE_RECONCILIATION_20261017.json',SHA256=sha(ROOT/'preserved-context/engineering/qa26/unattended-campaign/BASELINE_NATIVE_RECONCILIATION_20261017.json'),AsOf=hist['utc'],QualifiedCompatibleBaselines=hist['qualifiedCompatibleBaselines'],InspectedScope=hist['inventoryScope'],NotALiveHostInventory=True),ActualLocalAccess='No Hyper-V command/provider, no mapped host drive and no active remote PowerShell session. Existing exposed execution tool is local guest only.',NoDiskOrVmStateMutated=True,NoCredentialsRequestedOrUsed=True,RemainingRequirement='An accessible Independent QA approved untouched pre-existing compatible Windows native PS5.1 baseline with an existing policy permitting exact frozen scripts/modules; no policy/trust/launcher changes.'))
items=[
 dict(Id='F016_NATIVE_CONCURRENCY',Status='BLOCKED_NATIVE_EXECUTION_ROUTE',Runner='Test-QA19ProgressConcurrency.ps1',Reason='Exact runner available; native PS5.1 Restricted. Script itself extracts functions, but no QA inlining or alternative-engine substitution has been executed.',Next='Qualify permitted native route and deduplicate exact assertions before running this missing leaf suite.'),
 dict(Id='F010_MALFORMED_AND_PRIVACY_REMAINDER',Status='BLOCKED_NATIVE_ROUTE_AND_NO_REPEAT_FILTER',Reason='No current native route. Source/static and signed-copy smoke assertions already executed; no whole-suite rerun or promotion to frozen acceptance.',Next='Identify only actually missing frozen predicates and a permitted existing leaf execution path; do not rerun Smoke122.'),
 dict(Id='ELEVATED_STARTUP_ROLLBACK',Status='BLOCKED_ISOLATED_BASELINE_AND_NATIVE_ROUTE',Reason='Destructive isolated ProgramData tests require qualified disposable baseline; standard privilege assertions already executed.',Next='Use only missing branch predicates on qualified baseline with ordinary security controls; no automatic phase rerun.'),
 dict(Id='INSTALLER_LIFECYCLE',Status='BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE',Reason='No accessible approved untouched compatible native baseline. Current clone must retain frozen install and data.',Next='Qualified external baseline plus pinned setup and unchanged exact runner.'),
 dict(Id='QA2_MIGRATION',Status='BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE',Reason='Both QA2 fixtures recovered/verified; baseline and permitted native route remain missing.',Next='Qualified external baseline plus pinned QA2 and candidate setups and unchanged runner.'),
 dict(Id='HISTORICAL_FULL_RAW_PENDING_COLLECTION',Status='COLLECTION_GAP_RESOLVED_CONTRACT_COMPONENT_ONLY',Evidence='RECOVERED_FULL_CONTRACT_COMPONENT.json',NewTestExecutions=0,EngineeringCredit=0),
 dict(Id='NATIVE_EXPORTS',Status='EXECUTED_NO_RETRY',Reason='TXT/JSON already executed, PDF genuine failure retained, overwrite-decline attempt invalid and not repeated.'),
 dict(Id='ALL_DPI_AND_LAYOUT',Status='SKIPPED_BY_OWNER',Reason='No display changes, matrix tests, historical DPI inference, or credit.'),
 dict(Id='HISTORICAL_RESERVED_EVIDENCE_AND_FINAL_VERDICT',Status='INDEPENDENT_QA_ONLY',Reason='No stale-image repairs by rerun, no disputed metadata inspection, no final acceptance/security/release verdict.'),
]
put('ELIGIBILITY_AND_RESUME_REQUIREMENTS.json',dict(Utc=now,ExactArtifactsAvailable=True,FirstFailureStopWaivedForUnrelatedWork=True,Items=items,FreshEligibleRunnableMissingTestsIdentified=0,NoWholePhaseDispatchAuthorizedByThisPlan=True,NoNewAutomationsOrServices=True,NoPolicyChangeRequested=True))
put('HUMAN_ACTION_QUEUE_DELTA.json',dict(Utc=now,PermissionQuestionsAsked=0,OrdinaryPermissionsPending=0,Items=[dict(Id='ACCESSIBLE_APPROVED_EXISTING_NATIVE_PS51_BASELINE',Status='BLOCKED_EXTERNAL_CAPABILITY_REQUIRED',Requirement='An accessible approved untouched compatible baseline and existing permitted native5.1 execution route. Current guest-only tools cannot access host Hyper-V baselines.',Evidence=['ROUTE_CAPABILITY_AUDIT.json','BASELINE_DISPOSITION.json'],NoPolicyOrTrustChangeRequested=True,NoImmediateUserQuestion=True)],DpiActionRequested=False))
score=rd(PREV/'SCOREBOARD_CURRENT.json');assert score['testedAssertionScoreboard']['PASS']==328 and score['testedAssertionScoreboard']['FAIL']==1
score.update(updatedUtc=now,campaignStatus='BLOCKED_EXTERNAL_BASELINE_AND_NATIVE_EXECUTION_ROUTE',campaignComplete=False)
score['latestQualifiedBatch']={'record':'RECOVERED_FULL_CONTRACT_COMPONENT.json','newEligibleAssertions':0,'newEligibleFailures':0,'historicalRawCollectionsRecovered':1,'fullCellsAdded':0,'repeatedTests':0}
score['continuationDelta']={'PriorLocalScoreboard':str(PREV/'SCOREBOARD_CURRENT.json'),'NewPASS':0,'NewFAIL':0,'HostLedgerUnmodified':True,'NeedsSeparateHostReconciliation':True,'DpiTestingSkippedByOwner':True,'NewTests':0,'RepeatedTests':0,'HistoricalRawContractComponentCollected':1}
put('SCOREBOARD_CURRENT.json',score)
put('STATE_DELTA.json',dict(Utc=now,EngineeringPASS=328,EngineeringFAIL=1,MatrixPASS=83,MatrixTotal=132,NewPASS=0,NewFAIL=0,NewTests=0,RepeatedTests=0,RawCollectionResolved='Light125AppsFull20261005_2142',ContractChecks=8,FullAcceptanceClaimed=False,DpiTestsSkipped=True,ProductModified=False,SecurityPolicyChanged=False,OriginalVMAccessed=False,CampaignComplete=False,Blocker='External approved compatible baseline and permitted native execution route unavailable to guest-local tools'))
with (O/'DELTA.jsonl').open('x',encoding='utf-8') as f:
 for event in ['READ_ONLY_LOCAL_NATIVE_ROUTE_AND_BASELINE_AUDIT_COMPLETE','HISTORICAL_FULL_RAW_RECOVERED_8_CONTRACT_CHECKS_NO_REEXECUTION','NO_NEW_RUNNABLE_ELIGIBLE_MISSING_TEST_IDENTIFIED']:
  f.write(json.dumps(dict(Utc=now,Event=event,EngineeringPASS=328,EngineeringFAIL=1,NewTestExecutions=0,RepeatedTests=0,ScoreboardDelta=0))+'\n')
report='''QA26 route and baseline audit
No new test or scan executed; no repeat. Engineering score remains 328 PASS, 1 FAIL. PDF failure remains open. All DPI testing skipped by owner.
Recovered exact historical Full raw from 2026-10-06T01:42:11Z (SHA256 3CF7EE8D2CF1A5203912377C5D8794988B31F6B441336A1654811DBC148CA88A), still marked pending collection in imported ledger. Eight contract checks pass and 60 historical payload hashes match. This closes a raw collection gap only; no added assertion or full-cell credit, no scan rerun, no current clone evidence substituted for original execution.
Both native Windows PowerShell5.1 x64 and x86 remain Restricted/all5 scopes Undefined. PowerShell7 has an existing different policy but does not supply the required native5.1 acceptance environment. No alternate host, inlining, signing, launcher trampoline, policy or trust-store change used.
The current AppSetup clone is not the approved untouched lifecycle/migration baseline. The guest has no Hyper-V provider, active PSSession, mapped host drive, or exposed remote execution tool. Host baseline inventory and disk chains remain outside this local tool boundary. No host credentials or original VM accessed. The prior host audit had zero qualified compatible baselines; it is preserved as historical, not represented as a new live host inspection.
Exact pinned source, candidate and QA2 artifacts are available. Missing files are no longer the blocker. PINNED_RESUME_ARTIFACTS.json and ELIGIBILITY_AND_RESUME_REQUIREMENTS.json identify exact hashes, leaf-scope restrictions and outstanding requirements. No full-suite rerun is scheduled or authorized by this packet.
No additional eligible runnable missing non-DPI test identified. QA is incomplete: it requires an accessible Independent QA approved pre-existing compatible baseline and existing permitted native execution route. This is an external capability dependency, not a request to weaken security or grant routine permission.
All 60 current frozen artifacts,145 source files and205 prior evidence-manifest files match. Live preserved scan/config/history and imported ledgers remain unchanged. No display, theme, security, policy, product or VM-state changes.
'''
with (O/'CONTINUATION_REPORT.txt').open('x',encoding='utf-8') as f:f.write(report)
entries=[dict(Path=str(p.relative_to(O)).replace('\\','/'),Bytes=p.stat().st_size,SHA256=sha(p)) for p in sorted(O.rglob('*')) if p.is_file() and p.name!='MANIFEST.json']
put('MANIFEST.json',dict(Schema='QA26-CONTINUATION-MANIFEST-1',Utc=now,Files=entries,Count=len(entries)))
for e in rd(O/'MANIFEST.json')['Files']:assert sha(O/e['Path'])==e['SHA256']
print(json.dumps(dict(Report=str(O/'CONTINUATION_REPORT.txt'),ManifestFiles=len(entries),HistoricalRawCollectionsRecovered=1,ContractChecksPassed=8,EngineeringPASS=328,EngineeringFAIL=1,NewTests=0,RepeatedTests=0,CampaignComplete=False)))
