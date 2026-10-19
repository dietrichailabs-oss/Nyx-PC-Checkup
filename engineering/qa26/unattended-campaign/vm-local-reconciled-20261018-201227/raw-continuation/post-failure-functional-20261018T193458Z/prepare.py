import pathlib,json,hashlib,datetime,shutil
O=pathlib.Path(__file__).parent;ROOT=O.parent.parent
OLD=O.parent/'functional-exports-20261018T192122Z'
SRC=O/'pinned-source-data/Nyx_PC_Checkup_1.0.0_Source'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(name,value):
 p=O/name
 if p.exists():raise RuntimeError('Refuse overwrite '+str(p))
 p.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
archive=pathlib.Path(r'C:\Q26F023\Nyx_PC_Checkup_1.0.0_Source.zip')
assert sha(archive)=='4BDAC6FD0E071A100550CFCEEA59C5CED0180C36C05873981D623147F02B9C25'
identity=read(SRC/'SOURCE_TREE_IDENTITY.json');assert len(identity['files'])==145
for e in identity['files']:
 p=SRC/e['path'];assert p.stat().st_size==e['size'] and sha(p)==e['sha256'].upper()
fm=read(SRC/'tests/fixtures/qa2/QA2_FIXTURE_MANIFEST.json')
for e in fm['fixtures']:
 p=SRC/'tests/fixtures/qa2'/e['path'];assert p.stat().st_size==e['size'] and sha(p)==e['sha256'].upper()
write('PINNED_SOURCE_RECOVERY.json',dict(Utc=now,SourceArchive=str(archive),SHA256=sha(archive),Bytes=archive.stat().st_size,DataExtractionOnly=True,ScriptsExecuted=0,FrozenBuild=read(SRC/'VERSION.json')['build'],SourceFilesCompared=145,SourceTreeSHA256=identity['treeSha256'],Qa2FixturesMatched=2,Correction='Prior blanket statement that frozen runners and fixtures were unavailable is superseded. Exact archive is staged at C:\\Q26F023. Policy/baseline restrictions remain.',NoProductBuildOrInstall=True))
for f in read(OLD/'MANIFEST.json')['Files']:assert sha(OLD/f['Path'])==f['SHA256']
historical=OLD/'historical-native-txt-20261016_174520.txt'
fixture=O/'protected-export-existing.txt';shutil.copy2(historical,fixture)
assert sha(fixture)=='347DA4DFCC8A8B70AF881F47799F9A43F93CA7512AA3B605B501D46BC5AEAC03'
write('PROTECTED_FIXTURE.json',dict(Utc=now,Path=str(fixture),SHA256=sha(fixture),Bytes=fixture.stat().st_size,Purpose='User-authorized isolated native overwrite-decline test; copy of existing privacy-safe TXT report. No source or original output mutation.',OverwriteAcceptanceForbidden=True))
data=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup')
raw=[]
for rel,name in [('scans/last-scan.json','scan_before.json'),('config.json','config_before.json'),('actions/history.jsonl','history_before.jsonl')]:
 p=data/rel;shutil.copy2(p,O/name);assert sha(p)==sha(OLD/name);raw.append({'Live':str(p),'Copy':name,'SHA256':sha(p)})
inst=pathlib.Path(r'C:\Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup')
assert sha(inst/'PAYLOAD_MANIFEST.json')=='B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B'
m=read(inst/'PAYLOAD_MANIFEST.json')
for f in m['files']:assert sha(inst/f['path'])==f['sha256'].upper() and (inst/f['path']).stat().st_size==f['size']
write('FILE_PREFLIGHT.json',dict(Utc=now,FrozenArtifactsMatched=60,PreservedData=raw,PriorEvidenceManifestVerified=67,NoProductOrSecurityPolicyChange=True,OriginalVMAccessed=False,MetadataExcludedAndUninspected=True))
# The helper remains one-shot native GUI input, never a product/script runner.
s=(OLD/'NyxExportProbe.cs').read_text(encoding='utf-8-sig').replace('functional-exports-20261018T192122Z','post-failure-functional-20261018T193458Z')
s=s.replace('bool owned=GetWindow(h,4).ToInt64()==66444;', 'bool owned=GetWindow(h,4).ToInt64()==66444;var owner=GetWindow(h,4);bool nested=owner!=IntPtr.Zero&&GetWindow(owner,4).ToInt64()==66444;')
s=s.replace('bool modal=owned&&cl=="#32770"&&title=="Nyx PC Checkup";','bool modal=owned&&cl=="#32770"&&title=="Nyx PC Checkup";bool overwrite=nested&&cl=="#32770"&&title=="Confirm Save As";')
s=s.replace('(!main&&!preview&&!save&&!modal)','(!main&&!preview&&!save&&!modal&&!overwrite)')
s=s.replace('if(name!="report-native-txt.txt"&&name!="report-native-pdf.pdf")','if(name!="protected-export-existing.txt")')
s=s.replace('if(File.Exists(path))throw new Exception("Export overwrite refused");','if(!File.Exists(path)||Hash(path)!="347DA4DFCC8A8B70AF881F47799F9A43F93CA7512AA3B605B501D46BC5AEAC03")throw new Exception("Exact protected test-fixture hash failed");')
needle='    else if(cmd=="key")'
assert s.count(needle)==1
branch='''    else if(cmd=="no"){if(Class(h)!="#32770"||Text(h)!="Confirm Save As")throw new Exception("Only native overwrite-decline confirmation is allowed");if(Hash(Path.Combine(Root,"protected-export-existing.txt"))!="347DA4DFCC8A8B70AF881F47799F9A43F93CA7512AA3B605B501D46BC5AEAC03")throw new Exception("Protected fixture changed before No");var noRoot=AutomationElement.FromHandle(h);var noButtons=noRoot.FindAll(TreeScope.Descendants,new AndCondition(new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Button),new PropertyCondition(AutomationElement.NameProperty,"No")));if(noButtons.Count!=1)throw new Exception("Exact No button is not unique");object noPattern;if(!noButtons[0].TryGetCurrentPattern(InvokePattern.Pattern,out noPattern))throw new Exception("No button lacks invoke pattern");((InvokePattern)noPattern).Invoke();}
    else if(cmd=="key")'''
s=s.replace(needle,branch)
(O/'NyxSaveGuardProbe.cs').write_text(s,encoding='utf-8')
shutil.copy2(OLD/'NyxWindowInventory.exe',O/'NyxWindowInventory.exe')
shutil.copy2(OLD/'NyxWindowInventory.cs',O/'NyxWindowInventory.cs')
write('PLAN.json',dict(Schema='QA26-UNRELATED-FUNCTIONAL-CONTINUATION-1',Utc=now,UserOverride='First-failure stop waived for unrelated tests; PDF failure retained',DpiTesting='SKIPPED_BY_OWNER_NO_DISPLAY_CHANGES',ExistingExecutionToQualify=dict(PredicateId='native_export_save_dialog_cancel_20261018',SourceCase='installed_gui_export_txt_missing_20261018',ExecutionEvidence='../functional-exports-20261018T192122Z/installed_export_txt_abort_prior_output_20261018T1925130094582Z_0dc27aaba8ef428ab7928409f642848e.json',Scope='Already executed Escape from native Save dialog; expected no output and return to idle main. No rerun.'),NewCase=dict(PredicateId='native_export_overwrite_decline_preserves_file_20261018',Predicate='Native TXT Save As existing isolated fixture -> Confirm Save As -> No leaves fixture bytes unchanged and returns to Save dialog; Cancel exits without serialization or export',NoYesOrOverwrite=True,Fixture='protected-export-existing.txt',FreshOutputScope='This session folder only',NoTestRepeat=True),UnrelatedToPdfFailure='Decline/cancel exits before ReportExport/PdfWriter serialization. No PDF save or failed case repeated.',FrozenBuild='2026.10.02-eng-qa26',NoScans=True,NoCleanup=True,NoPrivacySettingChange=True,NoWholeSuiteOrMatrixCredit=True,EngineeringPASSBefore=327,EngineeringFAILBefore=1))
print(json.dumps(dict(SourceArchivePinned=True,SourceFilesMatched=145,Qa2FixturesMatched=2,FrozenArtifactsMatched=60,ProtectedFixtureSHA256=sha(fixture),NoTestsExecuted=True)))
