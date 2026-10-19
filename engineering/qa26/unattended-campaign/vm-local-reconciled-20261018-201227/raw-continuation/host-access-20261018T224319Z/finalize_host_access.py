import pathlib,json,hashlib,datetime
O=pathlib.Path(__file__).parent;ROOT=O.parent.parent;PREV=O.parent/'route-baseline-audit-20261018T200140Z'
def rd(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def put(n,v):
 with (O/n).open('x',encoding='utf-8') as f:json.dump(v,f,indent=2);f.write('\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
for e in rd(PREV/'MANIFEST.json')['Files']:assert sha(PREV/e['Path'])==e['SHA256']
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup');assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
for e in rd(inst/'PAYLOAD_MANIFEST.json')['files']:assert sha(inst/e['path'])==e['sha256'].upper() and (inst/e['path']).stat().st_size==e['size']
raw=[]
for e in rd(PREV/'INTEGRITY_POSTCHECK.json')['PreservedData']:
 p=pathlib.Path(e['Path']);assert sha(p)==e['SHA256'];raw.append(dict(Path=str(p),SHA256=sha(p),Unchanged=True))
put('INTEGRITY_POSTCHECK.json',dict(Utc=now,FrozenArtifactsMatched=60,PreviousEvidenceManifestFilesMatched=27,PreservedData=raw,NoProductWrites=True,NoSecurityOrExecutionPolicyChanges=True,OriginalVmAccessed=False,DisputedMetadataInspected=False,NewTestExecutions=0,RepeatedTests=0,NoDpiTesting=True))
put('HOST_ACCESS_DISPOSITION.json',dict(Utc=now,Host='MARK',HostResolvedAndReachable=True,ResolvedHostAddresses=rd(O/'HOST_MANAGEMENT_REACHABILITY.json')['ResolvedAddresses'],SmbPort445Reachable=True,ShareEnumeration='Access denied using current identity',KnownQaShareRoot='Unavailable as exposed to current identity; no inference of host filesystem contents',ExistingDcomPort135Reachable=True,DcomManagement='Access denied HRESULT0x80070005 using current identity',SshPort22='No response within bounded probe',WinrmPorts5985_5986='No response within bounded probe',NewCredentialsSupplied=False,CredentialsReadOrStored=False,SecurityConfigurationChanged=False,HostConnectionCreated=False,BaselineAccessed=False,OriginalVmAccessed=False,AvailableCodexExecutionHosts=['local guest only'],Decision='BLOCKED_AUTHENTICATED_HOST_EXECUTOR_REQUIRED',NecessaryInput='Name or endpoint of an existing authenticated host-side execution connection. No password or policy change requested.',Evidence=['HOST_DNS.json','HOST_MANAGEMENT_REACHABILITY.json','HOST_SHARE_ACCESS.json','KNOWN_HOST_QA_PATH_ACCESS.json','HOST_WMI_REACHABILITY.json','HOST_DCOM_ACCESS.json']))
put('HOST_EXECUTOR_RESUME_REQUIREMENTS.json',dict(Utc=now,RunNow=False,InputsNeeded=['Existing authorized authenticated execution connection to MARK or approved independent baseline','Read-only current baseline identity and policy preflight','Independent QA approval/provenance for untouched compatible pre-existing nativePS5.1 baseline'],Preserve=['OriginalVM275a191c-cf8a-4929-9849-b9a293e9149d Saved/unmodified','FrozenSource0303a78a06f67252c86634cd73f1e4bda32dd3cc build2026.10.02-eng-qa26 harnessQA26-F023-PS51-26','All Windows security, authentication, execution, trust and VPN policies','Imported ledgers and preserved scans; disputed install-state excluded'],NoRepeatInputs=[str(PREV/'ELIGIBILITY_AND_RESUME_REQUIREMENTS.json'),str(PREV/'PINNED_RESUME_ARTIFACTS.json'),str(ROOT/'authoritative-ledgers/STATE.json')],NoWholePhaseRerun=True,NoDpiTests=True,ExistingPdfFailureRetained=True,PermissionToChangePolicies=False))
score=rd(PREV/'SCOREBOARD_CURRENT.json');assert score['testedAssertionScoreboard']['PASS']==328 and score['testedAssertionScoreboard']['FAIL']==1
score.update(updatedUtc=now,campaignStatus='BLOCKED_HOST_AUTHENTICATED_ACCESS_DENIED',campaignComplete=False)
score['latestHostAccessAudit']='HOST_ACCESS_DISPOSITION.json';score['continuationDelta']={'PriorLocalScoreboard':str(PREV/'SCOREBOARD_CURRENT.json'),'NewPASS':0,'NewFAIL':0,'NewTests':0,'RepeatedTests':0,'HostLedgersUnmodified':True,'NeedsSeparateHostReconciliation':True}
put('SCOREBOARD_CURRENT.json',score)
put('HUMAN_ACTION_QUEUE_DELTA.json',dict(Utc=now,QueueKey='ACCESSIBLE_APPROVED_EXISTING_NATIVE_PS51_BASELINE',SupersedesLocalQueueRequirementDescriptionOnly=True,Status='HOST_REACHABLE_CURRENT_IDENTITY_DENIED',RoutinePermissionRequests=0,EssentialConnectionInformationRequested=True,Requirement='Existing authenticated authorized host-side executor or baseline connection endpoint; no passwords, security changes or new services requested.'))
put('STATE_DELTA.json',dict(Utc=now,EngineeringPASS=328,EngineeringFAIL=1,NewTests=0,RepeatedTests=0,MatrixPASS=83,MatrixTotal=132,HostReachabilityBlockerResolved=True,HostAuthenticationAuthorizationBlockerRemains=True,BaselineNotAccessed=True,OriginalVmNotAccessed=True,DpiSkipped=True,CampaignComplete=False))
with (O/'DELTA.jsonl').open('x',encoding='utf-8') as f:
 for event in ['HOST_MARK_RESOLVED_SMB_AND_DCOM_REACHABLE','CURRENT_IDENTITY_SHARE_AND_DCOM_ACCESS_DENIED','NO_BASELINE_OR_TEST_EXECUTION_SECURITY_UNCHANGED']:
  f.write(json.dumps(dict(Utc=now,Event=event,NewTestExecutions=0,RepeatedTests=0,EngineeringPASS=328,EngineeringFAIL=1))+'\n')
report='''QA26 host access attempt
MARK resolves to Hyper-V host addresses. SMB445 and DCOM135 are reachable. Existing SSH22 and WinRM5985/5986 did not respond to bounded connection probes.
Host share enumeration and WMI/DCOM management denied the current Windows identity (DCOM HRESULT0x80070005). The known G$ QA handoff path/root is not accessible as exposed to this identity. No host/baseline filesystem contents inferred from that result.
Only a guest-local Codex execution host is connected. No authenticated host-side execution route was obtained. An existing authenticated authorized executor/connection endpoint is required; its name/address was requested without asking for passwords or security-policy changes.
No new credentials read, supplied or stored. No firewall, authentication, trust, execution-policy, VPN, product, VM state, service, bridge or scheduled-task changes. Original VM and approved baselines unaccessed.
No test repeated or newly executed. All DPI testing remains skipped. Engineering score unchanged328PASS/1FAIL; PDF failure remains open. All60 frozen artifacts and27 prior evidence-manifest files match; live scan/config/history unchanged. QA remains incomplete.
'''
with (O/'CONTINUATION_REPORT.txt').open('x',encoding='utf-8') as f:f.write(report)
entries=[dict(Path=str(p.relative_to(O)).replace('\\','/'),Bytes=p.stat().st_size,SHA256=sha(p)) for p in sorted(O.rglob('*')) if p.is_file() and p.name!='MANIFEST.json']
put('MANIFEST.json',dict(Utc=now,Files=entries,Count=len(entries)))
for e in rd(O/'MANIFEST.json')['Files']:assert sha(O/e['Path'])==e['SHA256']
print(json.dumps(dict(HostReachable=True,HostManagementAccessDenied=True,ManifestFiles=len(entries),FrozenArtifactsMatched=60,EngineeringPASS=328,EngineeringFAIL=1,NewTests=0,RepeatedTests=0,PoliciesChanged=False)))
