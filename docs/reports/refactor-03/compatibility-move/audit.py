"""Audit exact move scope, frozen fields, UID and untouched neighboring cards."""
import ast,gzip,hashlib,json,re,subprocess,sys
from pathlib import Path
REPORT=Path(__file__).resolve().parent
ROOT=next(p for p in REPORT.parents if(p/'project.godot').is_file())
sys.path.insert(0,str(ROOT))
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 baseline=json.loads((REPORT/'baseline/inventory.json').read_text());base=baseline['base'];mapping={n:r['target']for n,r in baseline['assignments'].items()}
 source_after=set(mapping.values())|set(baseline['consumers'])|{'tools/qa/compatibility/__init__.py','tools/qa/compatibility/test_compatibility_cli.py'}
 allowed=set(baseline['sources'])|source_after;prefix=REPORT.relative_to(ROOT).as_posix()+'/'
 changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))
 untracked=set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
 assert all(n in allowed or n.startswith(prefix)for n in changed|untracked),(changed|untracked)-allowed
 for n,row in baseline['sources'].items():
  raw=gzip.decompress((REPORT/'baseline'/(n.replace('/','--')+'.gz')).read_bytes())
  assert raw==git('show',base+':'+n)and hashlib.sha256(raw).hexdigest()==row['sha256'],n
  assert(ROOT/mapping.get(n,n)).stat().st_mode&0o777==row['mode'],n
 for old,new in mapping.items():assert not(ROOT/old).exists()and(ROOT/new).is_file(),old
 for n in ['tools/assets/slicing/slice_review.gd','tools/water_fishing_review.gd','tools/water_navigation_review.gd','tools/water_topology_review.gd']:
  expected=git('show',base+':'+n).decode()
  for old,new in mapping.items():expected=expected.replace('"res://'+old+'"','"res://'+new+'"')
  assert(ROOT/n).read_text()==expected,n
 card='docs/epics/refactoring-2026-10/TASKS.md';before=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);after=re.split(r'(?=^## REFACTOR-)',(ROOT/card).read_text(),flags=re.M)
 assert len(before)==len(after)==8
 assert all(a==b for a,b in zip(before,after)if not a.startswith('## REFACTOR-03 '))
 for n in ['AGENTS.md','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','docs/epics/visual-overhaul-2026-10/backlog.json']:
  assert git('show',base+':'+n)==(ROOT/n).read_bytes(),n
 raw_paths=json.loads((REPORT/'raw-whitespace-paths.json').read_text())
 assert raw_paths==[prefix+'after-%03d.txt'%i for i in range(2,93)]
 expected=git('show',base+':.gitattributes')+b'# Preserve only these exact native parse raw logs, including Godot\'s final blank line.\n'+''.join(n+' -whitespace\n'for n in raw_paths).encode()
 assert(ROOT/'.gitattributes').read_bytes()==expected
 assert all((ROOT/n).is_file()and(ROOT/n).read_bytes().endswith(b'\n\n')for n in raw_paths)
 old=git('show',base+':tools/quality/check_architecture.sh').decode()
 assert(ROOT/'tools/quality/check_architecture.sh').read_text()==old.replace('python3 tools/run.py assets.alpha.test_street_consumer\n','python3 tools/run.py assets.alpha.test_street_consumer\npython3 tools/run.py qa.compatibility.test_compatibility_cli\n')
 prior={}
 for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move']:
  prior.update({r['old_path']:r['target']for r in json.loads((REPORT.parent/phase/'migration.json').read_text())['moves']})
 prior.update(mapping);contracts=REPORT.parent/'baseline/source-contracts.json'
 assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
 child=ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
 fields=0
 for row in json.loads(contracts.read_text())['modules'].values():
  module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
  result=subprocess.run([sys.executable,'-c',child,str(ROOT),module],cwd=ROOT,env=git_environment(),capture_output=True,text=True,timeout=30)
  assert result.returncode==0 and not result.stderr,(module,result.stderr)
  assert json.loads(result.stdout)==row['fields'],module
  fields+=len(row['fields'])
 assert fields==37
 tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
 root_count=sum(n.startswith('tools/')and n.count('/')==1 and Path(n).suffix in{'.py','.gd','.mjs','.swift','.sh','.gdshader'}for n in tracked)
 assert root_count==314,root_count
 uid=json.loads((REPORT.parent/'baseline/local-uids.json').read_text())
 for row in uid['local_only_UID']:
  paths=[ROOT/n for n in [row['old_path'],row['target']]if(ROOT/n).is_file()];assert len(paths)==1 and paths[0].read_text().strip()==row['value'],row
  name=str(paths[0].relative_to(ROOT));assert name not in tracked and git('check-ignore','--',name).strip()
 assert len(uid['local_only_UID'])==85
 anchor=uid['retained_anchor_local_UID'];assert sha(ROOT/anchor['path'])==anchor['sha256']
 for row in baseline['local_UID']:
  assert sha(ROOT/row['target'])==row['sha256']and(ROOT/row['target']).stat().st_mode&0o777==row['mode']
 profile=json.loads((REPORT/'after-profile.json').read_text());assert profile['actual_before_after_equal']and not profile['GPU_FPS_admission']
 assert len(profile['source_comparison'])==153
 result={'base':base,'version':'0.0.369','root_sources':root_count,'physical_source_moves':89,'tracked_UID_moves':64,'ignored_UID_moves':23,
  'historical_fields':37,'all_ignored_UID_preserved':85,'anchor_preserved':True,'other_six_refactor_cards_unchanged':True,'parallel07_excluded_from_QA':True,
  'old_reports_runtime_artwork_plans_unchanged':True,'full_task03_accepted':False,'source_paths_after':sorted(source_after),'removed_source_paths':sorted(mapping)}
 (REPORT/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 migration={'base':base,'root_sources_after_moves':314,'physical_source_moves':89,'tracked_UID_moves':64,'ignored_UID_moves':23,
  'moves':[{'old_path':old,'target':new,'before_sha256':baseline['sources'][old]['sha256'],'after_sha256':sha(ROOT/new),'mode':baseline['sources'][old]['mode']}for old,new in mapping.items()]}
 (REPORT/'migration.json').write_text(json.dumps(migration,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'source_after':len(source_after),'root':314,'fields':37,'UID':85}))
if __name__=='__main__':main()
