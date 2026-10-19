"""Read-only QA evidence recovery. No product execution or GUI input."""
import json, hashlib, shutil, datetime, pathlib

ROOT = pathlib.Path(r'C:\Users\Nyx\Desktop\Nyx-QA26-Codex-20261018_121140')
OUT = pathlib.Path(__file__).parent
CAMP = ROOT / 'preserved-context/engineering/qa26/unattended-campaign'
INST = pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
LOCAL = pathlib.Path(r'C:\Users\Nyx\AppData\Local')
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(name, obj):
    p = OUT / name
    if p.exists(): raise RuntimeError('Refusing overwrite: ' + str(p))
    p.write_text(json.dumps(obj, indent=2) + '\n', encoding='utf-8')
copies=[]
def copy(p, dest):
    p=pathlib.Path(p); target=OUT/dest
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists(): raise RuntimeError('Refusing overwrite: '+str(target))
    before=sha(p); shutil.copy2(p,target); after=sha(p)
    assert before==after==sha(target)
    copies.append(dict(Source=str(p),Copy=dest,SHA256=before,Bytes=p.stat().st_size,SourceLastWriteUtc=datetime.datetime.fromtimestamp(p.stat().st_mtime,datetime.timezone.utc).isoformat()))
    return target
batch=read(ROOT/'authoritative-ledgers/FOLLOWWINDOWS150_CLEANUP_CONFIRM_CANCEL_BATCH_20261018.json')
state=read(ROOT/'authoritative-ledgers/STATE.json')
for p in (ROOT/'authoritative-ledgers').glob('*.json'): copy(p,'inputs/ledgers/'+p.name)
prior=ROOT/'continuation/dark150-native144-20261018T175251Z'
for f in ['SCOREBOARD_CURRENT.json','STATE_DELTA.json','DARK150_CLEANUP_HORIZONTAL_NATIVE_QUALIFICATION.json','MANIFEST.json']: copy(prior/f,'inputs/prior-continuation/'+f)
for f in ['PRESERVATION_CLONE_RECEIPT.json','CLONE_READY_RECEIPT.json']:
    copy(ROOT/'preserved-context/clone-provenance'/f,'inputs/provenance/'+f)
copy(CAMP/'FOLLOWWINDOWS150_CLEANUP6_NATIVE_QUALIFICATION_20261018.json','inputs/historical-qualification.json')
copy(CAMP/'collected-native-followwindows150-cleanup6-20261018/data/config.json','inputs/historical-config.json')
for f in ['live_20261018_130330_2511799.jsonl','live_20261018_133421_7897661.jsonl']:
    copy(LOCAL/'NyxQA26NativeDpi'/f,'raw/observer/'+f)
old=copy(CAMP/'collected-native-followwindows150-cleanup6-20261018/observer/live_20261018_130330_2511799.jsonl','inputs/earlier-collected-observer.jsonl')
assert (OUT/'raw/observer/live_20261018_130330_2511799.jsonl').read_bytes().startswith(old.read_bytes())
all_images={batch['appliedThemeEvidence'],batch['observerSetup']['evidence']}
for case in batch['cases']:
    for k,v in case.items():
        if isinstance(v,str) and v.startswith('screenshots/') and v.endswith(('.jpg','.png','.capture.json')): all_images.add(v)
for im in sorted(all_images):
    copy(CAMP/im,'inputs/'+im)
    rp=CAMP/(im+'.capture.json')
    if not im.endswith('.capture.json') and rp.exists() and str(rp.relative_to(CAMP)) .replace('\\','/') not in all_images:
        copy(rp,'inputs/'+im+'.capture.json')
def utc(v): return datetime.datetime.fromisoformat(v.replace('Z','+00:00'))
raw=[json.loads(line) for line in (OUT/'raw/observer/live_20261018_133421_7897661.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
assert len(raw)>2 and all(r['Pid']==1800 and r['NativeDpi']==144 and r['ProductModified'] is False for r in raw)
bindings=[]
for case in batch['cases']:
    receipt=read(CAMP/case['captureReceipt'])
    assert receipt['predicateId']==case['id'] and receipt['freshQueryPerformed'] and receipt['cachedGlobalImageUsed'] is False
    assert sha(CAMP/case['evidence'])==case['sha256'].upper()==receipt['image']['sha256'].upper()
    assert (CAMP/case['evidence']).stat().st_size==receipt['image']['bytes']
    begin=utc(receipt['captureRequestedUtc']); end=utc(receipt['captureReturnedUtc'])
    before=max((r for r in raw if utc(r['Utc'])<=begin),key=lambda r:utc(r['Utc']))
    after=min((r for r in raw if utc(r['Utc'])>=end),key=lambda r:utc(r['Utc']))
    gap=(utc(after['Utc'])-utc(before['Utc'])).total_seconds()
    assert gap<11 and before['WindowBounds']==after['WindowBounds']
    matches=[p for p in state['completedPredicates'] if p.get('id')==case['id']]
    assert len(matches)==1 and matches[0]['assertionCredit']==0 and 'PENDING' in matches[0]['status']
    bindings.append(dict(PredicateId=case['id'],Receipt=case['captureReceipt'],Screenshot=case['evidence'],SHA256=sha(CAMP/case['evidence']),CaptureStart=receipt['captureRequestedUtc'],CaptureEnd=receipt['captureReturnedUtc'],NativeBefore=before,NativeAfter=after,BracketSeconds=gap,HistoricalRecordCount=1,HistoricalCredit=0))
assert len({b['SHA256'] for b in bindings})==4
write('NATIVE_BINDINGS.json',dict(Utc=NOW,Source='Copied original pre-clone observer bytes inherited from the preserved 15:29Z source checkpoint; not a new clone measurement or execution',EarlierObserverPrefixMatchesPreservedReadOnlyExport=True,FullRawSamples=len(raw),FirstUtc=raw[0]['Utc'],LastUtc=raw[-1]['Utc'],MaxGapSeconds=max((utc(b['Utc'])-utc(a['Utc'])).total_seconds() for a,b in zip(raw,raw[1:])),Bindings=bindings,NoTestsExecuted=True))
manifest=INST/'PAYLOAD_MANIFEST.json'
assert sha(manifest)=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
pm=read(manifest); assert pm['fileCount']==59 and len(pm['files'])==59
payload=[]
historical=CAMP/'collected-native-followwindows150-cleanup6-20261018/installed'
for item in pm['files']:
    for base,scope in [(INST,'current-clone'),(historical,'historical-source-collected')]:
        p=base/item['path']; h=sha(p)
        assert h==item['sha256'].upper() and p.stat().st_size==item['size']
        payload.append(dict(Scope=scope,Path=str(p),SHA256=h,Bytes=item['size']))
assert sha(historical/'PAYLOAD_MANIFEST.json')==sha(manifest)
write('PAYLOAD_AUDIT.json',dict(Utc=NOW,PinnedManifestSHA256=sha(manifest),MatchedArtifactsPerScope=60,MetadataExcludedAndUninspected=True,Files=payload))
for p in [LOCAL/'Dietrich AI Labs/Nyx PC Checkup/scans/last-scan.json',LOCAL/'Dietrich AI Labs/Nyx PC Checkup/actions/history.jsonl']:
    copy(p,'raw/preserved-data/'+p.name)
write('COLLECTION_RECEIPT.json',dict(Utc=NOW,SourceVMAccessed=False,OriginalVMRemainsUnmodified=True,ProductExecuted=False,TestsExecuted=0,ScansExecuted=0,HistoricalEvidenceOnly=True,MetadataExcludedAndUninspected=True,Copies=copies))
# Gather exact status-bearing records, excluding embedded image/automation trees and disputed metadata.
skip={'snapshot','screenshots','accessibility','rawManifest','installedHashes','Files','files','elements','children'}
records=[]
def walk(obj,source,location=''):
    if isinstance(obj,dict):
        identity=obj.get('id',obj.get('predicateId',obj.get('PredicateId')))
        status=obj.get('status',obj.get('Status'))
        if identity and (status or 'predicate' in obj):
            small={k:obj[k] for k in ['id','predicateId','PredicateId','theme','scale','page','key','status','Status','predicate','details','reason','requiredPrerequisite','assertionCredit'] if k in obj}
            records.append(dict(Source=source,Location=location,Record=small))
        for k,v in obj.items():
            if k not in skip: walk(v,source,location+'/'+k)
    elif isinstance(obj,list):
        for i,v in enumerate(obj): walk(v,source,location+'/'+str(i))
scanned=[]
for p in sorted(CAMP.glob('*.json')):
    if p.name.startswith('STATE_') or 'INSTALL_STATE' in p.name: continue
    walk(read(p),p.name); scanned.append(dict(Name=p.name,SHA256=sha(p)))
write('RECORD_STATUS_INVENTORY.json',dict(Utc=NOW,TopLevelDocuments=scanned,Records=records,Note='Historical records may be superseded by later qualifications. This inventory grants no credit and no rerun authorization.'))
write('DELTA.jsonl.start.json',dict(Utc=NOW,Event='READ_ONLY_RECOVERY_COLLECTED',TestsExecuted=0,ScoreboardCredit=0,PendingQualification=4))
print(json.dumps(dict(Output=str(OUT),CopiedFiles=len(copies),NativeSamples=len(raw),NativeCaseBindings=len(bindings),FrozenArtifactsMatchedPerScope=60,StatusRecords=len(records)),indent=2))
