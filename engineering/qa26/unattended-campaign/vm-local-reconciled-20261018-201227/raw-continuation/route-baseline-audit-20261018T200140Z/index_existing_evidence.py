import pathlib,json,hashlib,datetime
O=pathlib.Path(__file__).parent;ROOT=O.parent.parent
base=pathlib.Path(r'C:\Users\Nyx\AppData\Local')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
rows=[]
roots=[p for p in base.glob('NyxQA26*') if p.is_dir() and ('Evidence' in p.name or 'InstalledScanObserver' in p.name)]
roots += [ROOT/'preserved-context/engineering/qa26/unattended-campaign']
seen=set()
for root in roots:
 for p in root.rglob('*.json'):
  if p.name.lower().startswith('scan_') and p.name.lower().endswith('_raw.json') or p.name.lower()=='last-scan.json' or p.parent.name.lower()=='reports':
   if p in seen:continue
   seen.add(p)
   try:
    b=p.read_bytes(); r=json.loads(b.decode('utf-8-sig'))
    if not isinstance(r,dict):continue
    keys={k.lower():k for k in r}
    if not ('results' in keys and 'mode' in keys):continue
    rows.append(dict(Path=str(p),Bytes=len(b),SHA256=hashlib.sha256(b).hexdigest().upper(),Mode=r.get('Mode',r.get('mode')),StartedUtc=r.get('StartedUtc',r.get('startedUtc')),CompletedUtc=r.get('CompletedUtc',r.get('completedUtc')),Keys=list(r),Results=len(r.get('Results',r.get('results',[])))))
   except (ValueError,OSError):pass
(O/'EXISTING_SCAN_EVIDENCE_INDEX.json').write_text(json.dumps(dict(Utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),ReadOnly=True,NoMetadataInspected=True,Files=rows),indent=2)+'\n',encoding='utf-8')
unique={e['SHA256']:e for e in rows}
print(json.dumps(dict(Files=len(rows),UniqueRawHashes=len(unique),ScanHeaders=[{k:v for k,v in e.items() if k in ['SHA256','Mode','StartedUtc','CompletedUtc','Results']} for e in unique.values()]),indent=2))
