import pathlib,json,hashlib,datetime,shutil,collections
O=pathlib.Path(__file__).parent;ROOT=O.parent.parent; PREV=O.parent/'post-failure-functional-20261018T193458Z'; SRC=PREV/'pinned-source-data/Nyx_PC_Checkup_1.0.0_Source'
H=pathlib.Path(r'C:\Users\Nyx\AppData\Local\NyxQA26Evidence\native_20261006_175317')
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def put(name,value):
 with (O/name).open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
# Every historical file copied here is on a fixed allowlist; disputed INSTALL_STATE is excluded.
REC=O/'recovered-original-full';REC.mkdir()
source=H/'app-data-at-end/scans/last-scan.json'; assert sha(source)=='3CF7EE8D2CF1A5203912377C5D8794988B31F6B441336A1654811DBC148CA88A'
provenance=[]
for src,name in [(source,'original-full-20261006T014211Z.json'),(H/'CANDIDATE.json','CANDIDATE.json'),(H/'INSTALLED_PAYLOAD_HASHES.json','INSTALLED_PAYLOAD_HASHES.json'),(H/'END.json','END.json')]:
 dst=REC/name;shutil.copy2(src,dst);assert sha(src)==sha(dst);provenance.append(dict(Source=str(src),Copy=str(dst.relative_to(O)),SHA256=sha(dst),Bytes=dst.stat().st_size))
candidate=read(REC/'CANDIDATE.json');assert candidate['sourceCommit']=='0303a78a06f67252c86634cd73f1e4bda32dd3cc' and candidate['harness']=='QA26-F023-PS51-26'
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup');manifest=read(inst/'PAYLOAD_MANIFEST.json')
expected={f['path'].replace('\\','/').lower():(f['size'],f['sha256'].upper()) for f in manifest['files']}
expected['payload_manifest.json']=((inst/'PAYLOAD_MANIFEST.json').stat().st_size,sha(inst/'PAYLOAD_MANIFEST.json'))
historical=read(REC/'INSTALLED_PAYLOAD_HASHES.json');bound=[]
for f in historical:
 key=f['Path'].replace('\\','/').lower()
 if key in expected:assert (f['Bytes'],f['SHA256'])==expected[key];bound.append(key)
assert len(set(bound))==60
r=read(source);res=r['Results']; summary=r['Summary'];counts=collections.Counter(x['Status'] for x in res)
required=['CheckId','Category','Name','Status','Severity','Finding','Reason','Recommendation','Complete']
ids=[x['CheckId'] for x in res]
checks=dict(jsonObjectAndResults=r['Schema']=='dietrich-ai-labs.nyx-pc-checkup.scan.v1' and isinstance(res,list) and bool(res),validTimestampOrder=datetime.datetime.fromisoformat(r['StartedUtc'].replace('Z','+00:00'))<datetime.datetime.fromisoformat(r['CompletedUtc'].replace('Z','+00:00')),uniqueCheckIds=len(set(ids))==len(ids),requiredResultFields=all(all(k in x for k in required) and isinstance(x['Complete'],bool) for x in res),statusVocabulary=set(counts)<=set(['Good','NeedsAttention','Optional','Unknown']),summaryMatchesCounts=all(summary[k]==counts[k] for k in ['Good','NeedsAttention','Optional','Unknown']) and summary['Total']==len(res),modePopulation=r['Mode']=='Full' and len(res)==21 and {'apps.inventory','storage.user-folders','cleanup.preview','startup.entries','downloads.analysis'}<=set(ids),readOnlyCompletion=r['ReadOnly'] is True and r['Cancelled'] is False)
assert all(checks.values())
state=read(ROOT/'authoritative-ledgers/STATE.json');pending=[p for p in state['pendingAuthoritativeRuns'] if p.get('id')=='Light125AppsFull20261005_2142'];assert len(pending)==1 and pending[0]['status']=='PENDING_COLLECTION'
ui=[p for p in state['completedPredicates'] if p.get('id')=='light125_apps_full_completed_1791250956325_a40c7d90'];assert len(ui)==1
# Historical execution evidence remains in its original scope; do not count the same raw checks twice.
put('RECOVERED_FULL_CONTRACT_COMPONENT.json',dict(Schema='QA26-HISTORICAL-RAW-COLLECTION-ONLY-1',Utc=now,PredicateReference='Light125AppsFull20261005_2142',ImportedStatus='PENDING_COLLECTION',LocalStatus='RAW_COLLECTED_CONTRACT_COMPONENT_RECONCILED',RawSHA256=sha(source),OriginalStartedUtc=r['StartedUtc'],OriginalCompletedUtc=r['CompletedUtc'],PreservedFiles=provenance,HistoricalPayloadHashesMatched=60,Checks=checks,WorkerErrorCheckIdPresent=any('workererror' in x.lower() for x in ids),HistoricalUiRecord=ui[0],NewTestExecutions=0,RepeatedTests=0,EngineeringPASSAdded=0,MatrixCredit=0,Scope='Exact inherited historical raw data recovered as data and independently contract-checked. Current clone data is not fresh execution evidence. No new installed-function test or full F010/F016 gate claimed.',Remaining=['Original activation-to-worker process binding and complete lifecycle/cancellation proof are not supplied by the later snapshot.','No historical DPI, theme qualification, grid, cell or current security-health inference.','Original source VM remains unaccessed; inherited copied baseline does not supersede the original raw.'],ImportedLedgersModified=False))
put('ROUTE_CAPABILITY_AUDIT.json',dict(Utc=now,Guest=read(O/'VM_GUEST_IDENTITY.json'),NativeX64=read(O/'NATIVE_X64_ROUTE.json'),NativeX86=read(O/'NATIVE_X86_ROUTE.json'),PowerShell7=read(O/'POWERSHELL7_ROUTE.json'),LocalHyperV=dict(CommandGetVMAvailable=False,VirtualizationNamespaceQuery='Invalid namespace'),ExistingPSSessions=0,SmbMappings=0,SmbConnectionInventory='Access is denied; not retried with elevation',DriveD='Read-only Windows installation DVD, not an approved pre-existing runnable baseline',FilesystemRoots=['C:\\','D:\\'],HostDrivesFromImportedRecords=['G:\\','I:\\'],HostName='MARK',HostDrivesAccessibleAsLocalFiles=False,PermittedRemoteExecutionToolExposed=False,SecurityOrPolicyChanges=0,NoAuthenticationOrCredentialAutomation=True,Interpretation='No existing permitted native PS5.1 route or accessible approved untouched VM baseline identified here. This does not prove all external baselines incompatible.'))
print(json.dumps(dict(HistoricalFullRawRecovered=True,ContractChecksPassed=sum(checks.values()),HistoricalPayloadHashesMatched=60,NewTests=0,RepeatedTests=0,ScoreboardCredit=0,NativeX64Policy=read(O/'NATIVE_X64_ROUTE.json')['EffectivePolicy'],NativeX86Policy=read(O/'NATIVE_X86_ROUTE.json')['EffectivePolicy'])))
