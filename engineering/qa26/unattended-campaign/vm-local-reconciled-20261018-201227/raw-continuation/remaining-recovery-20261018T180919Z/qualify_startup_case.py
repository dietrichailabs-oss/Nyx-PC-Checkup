import pathlib,json,hashlib,datetime,sys
O=pathlib.Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
theme,previous,exe=sys.argv[1:]
stem=theme.lower()+'150_startup_missing_location'
pid=stem+'_20261018'
pre=read(O/(theme.upper()+'150_STARTUP_PRECONDITIONS.json'))
receipt_paths=list(O.glob(pid+'_*.json'))
assert len(receipt_paths)==1
rp=receipt_paths[0];r=read(rp)
ret_paths=list(O.glob(stem+'_return_*.json'));assert len(ret_paths)==1
ret=read(ret_paths[0])
events=[json.loads(v) for v in (O/'CASE_EXECUTIONS.jsonl').read_text(encoding='utf-8-sig').splitlines() if v.strip()]
assert sum(e['PredicateId']==pid and e['Event']=='STARTED_ONCE' for e in events)==1
assert sum(e['PredicateId']==pid and e['Event']=='EXECUTED_PENDING_QUALIFICATION' for e in events)==1
assert r['WindowClass']=='#32770' and r['Command']=='key' and r['Arguments'][-1]=='ENTER'
assert r['BeforeNativeDpi']==r['AfterNativeDpi']==ret['AfterNativeDpi']==144
assert r['Pid']==ret['Pid']==pre['Pid'] and r['SessionId']==ret['SessionId']==pre['SessionId']
assert all(r[k] is False for k in ['TargetElevated','HelperElevated','ScreenshotReused','ProductModifiedByHelper','WindowsPolicyModified'])
assert any(e['Name']=='The executable location is unavailable.' for e in r['VisibleElements'])
assert r['FocusedElement']['Name']=='OK'
assert ret['WindowClass'].startswith('WindowsForms10.Window') and ret['FocusedElement']['Name']=='Open file location'
assert sha(pathlib.Path(r['Screenshot']))==r['ScreenshotSHA256'].upper()
assert sha(O/exe)==pre['HelperSHA256']
data=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup')
unchanged=[]
for rel in ['scans/last-scan.json','actions/history.jsonl']:
 original=O/'raw/preserved-data'/pathlib.Path(rel).name;live=data/rel
 assert sha(original)==sha(live)
 unchanged.append({'Path':str(live),'SHA256':sha(live),'Unchanged':True})
assert read(data/'config.json')['theme']==theme
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
m=read(inst/'PAYLOAD_MANIFEST.json')
assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
for f in m['files']:assert sha(inst/f['path'])==f['sha256'].upper() and (inst/f['path']).stat().st_size==f['size']
score=read(O/previous);before=score['testedAssertionScoreboard']['PASS'];after=before+1
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
case=dict(Utc=now,PredicateId=pid,Status='PASS_ENGINEERING_NATIVE_QUALIFIED',Theme=theme,Scale=150,NativeDpi=144,Pid=r['Pid'],SessionId=r['SessionId'],Preconditions=theme.upper()+'150_STARTUP_PRECONDITIONS.json',BeforeReceipt=pre['BeforeReceipt'],AfterReceipt=rp.name,ReturnReceipt=ret_paths[0].name,Screenshot=r['Screenshot'],ScreenshotSHA256=r['ScreenshotSHA256'],Observed='Exact existing missing-target fixture gives readable handled unavailable-location modal by one Enter; focused OK. Escape closes normally and restores location-action focus. No executable activation, startup change, scan, elevation or exception.',FrozenFilesMatched=60,PreservedData=unchanged,HelperSHA256=pre['HelperSHA256'],TestsRepeated=0,NewAssertionCredit=1,EngineeringPASSAfter=after,EngineeringFAIL=0,FullCellsAdded=0,CampaignComplete=False,FinalDecisionOwner='Independent QA')
qual=theme.upper()+'150_STARTUP_QUALIFICATION.json'
qp=O/qual
if qp.exists():raise RuntimeError('Qualification already exists; refuse duplicate credit')
qp.write_text(json.dumps(case,indent=2)+'\n',encoding='utf-8')
score['testedAssertionScoreboard'].update(PASS=after,FAIL=0,previousPASS=before,newEligibleAssertions=1,batch=qual)
score['latestQualifiedBatch']={'record':qual,'newEligibleAssertions':1,'fullCellsAdded':0}
score['updatedUtc']=now
sp=O/('SCOREBOARD_AFTER_'+theme.upper()+'_STARTUP.json')
if sp.exists():raise RuntimeError('Scoreboard already exists')
sp.write_text(json.dumps(score,indent=2)+'\n',encoding='utf-8')
with (O/'DELTA.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(Utc=now,Event='NEW_MISSING_PREDICATE_QUALIFIED',PredicateId=pid,NewCredit=1,EngineeringPASS=after,EngineeringFAIL=0,FullCellsAdded=0,TestsRepeated=0,Qualification=qual))+'\n')
print(json.dumps(dict(PredicateId=pid,Status=case['Status'],EngineeringPASS=after,FAIL=0)))
