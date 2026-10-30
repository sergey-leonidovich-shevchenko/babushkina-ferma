"""Repair only surface producer input reads/rechecks and helper history; archive logical names remain unchanged."""
import ast,hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-review-1'
changes={}
def edit(name,transform):
 before=(ROOT/name).read_text();after=transform(before);assert before!=after,name;compile(after,name,'exec')if name.endswith('.py')else None
 changes[name]={'before':before,'after':after,'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest()}
edit('tools/assets/contracts/source_paths.py',lambda s:s.replace('# Принятый пакет71 и связанный перенос alpha/slicing19; metadata не выбирает таблицу.',
 '# Принятые asset71/alpha-slicing19 и один перенесённый performance helper; metadata не выбирает таблицу.').replace(
 "MOVED_PATHS = MappingProxyType({", "MOVED_PATHS = MappingProxyType({'tools/perf_contract_collect.py': 'tools/qa/performance/perf_contract_collect.py',\n ",1))
edit('tools/assets/contracts/test_source_paths.py',lambda s:s.replace("        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(expected), 90)",
 "        self.assertEqual(len(expected), 90)\n        expected['tools/perf_contract_collect.py'] = 'tools/qa/performance/perf_contract_collect.py'\n        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 91)"))
def producer(s):
 s=s.replace('from tools.qa.performance.perf_contract_collect import ROOT,','from tools.assets.contracts.source_paths import current_source\nfrom tools.qa.performance.perf_contract_collect import ROOT,',1)
 return s.replace('sha(ROOT/name)','sha(current_source(ROOT,name))').replace('sha(ROOT/p)','sha(current_source(ROOT,p))').replace('shutil.copyfile(ROOT/name,target)','shutil.copyfile(current_source(ROOT,name),target)')
edit('tools/grass_compare_collect.py',producer)
def ground(s):
 s=producer(s)
 s=s.replace('from tools.assets.contracts.source_paths import current_source','from tools.common.git import git_environment\nfrom tools.qa.performance.source_history import LEGACY_HELPER, historical_helper\nfrom tools.assets.contracts.source_paths import current_source')
 old="    return subprocess.check_output(['git','show',commit+':'+name],cwd=ROOT)"
 new="    physical = historical_helper(ROOT,commit) if name == LEGACY_HELPER else name\n    return subprocess.check_output(['git','--no-replace-objects','show',commit+':'+physical],cwd=ROOT,env=git_environment())"
 assert s.count(old)==1;s=s.replace(old,new)
 old="cwd=ROOT,capture_output=True).returncode==0,'native proof absent from Git index')"
 assert s.count(old)==1;s=s.replace(old,"cwd=ROOT,capture_output=True,env=git_environment()).returncode==0,'native proof absent from Git index')")
 return s
edit('tools/ground_layers.py',ground)
def reader(s):
 s=s.replace('from grass_compare_collect import ROOT,FROZEN,schedule,sha','from tools.common.git import git_environment\nfrom tools.qa.performance.source_history import LEGACY_HELPER, historical_helper\nfrom grass_compare_collect import ROOT,FROZEN,schedule,sha')
 s=s.replace('cwd=ROOT,capture_output=True)', 'cwd=ROOT,capture_output=True,env=git_environment())')
 old="            require(hashlib.sha256(subprocess.check_output(['git','show',source['base_commit']+':'+name],cwd=ROOT)).hexdigest()==digest,'production/reference differs from Git base: '+name)"
 new="            physical = historical_helper(ROOT,source['base_commit']) if name == LEGACY_HELPER else name\n            require(hashlib.sha256(subprocess.check_output(['git','--no-replace-objects','show',source['base_commit']+':'+physical],cwd=ROOT,env=git_environment())).hexdigest()==digest,'production/reference differs from Git base: '+name)"
 assert s.count(old)==1;s=s.replace(old,new)
 s=s.replace("['git','show',source['base_commit']+':'+original],cwd=ROOT)","['git','show',source['base_commit']+':'+original],cwd=ROOT,env=git_environment())")
 return s
edit('tools/grass_methods.py',reader)
new='''"""Resolve the one moved surface-collector helper inside its recorded Git commit."""
from pathlib import Path
import re
import subprocess

from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS, historical_source

LEGACY_HELPER = 'tools/perf_contract_collect.py'


def historical_helper(root: Path, commit: str) -> str:
    """Choose a unique old/new helper from the same commit; never fall back to a live file."""
    if not isinstance(commit, str) or not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('full historical helper commit required')
    aliases = [LEGACY_HELPER, MOVED_PATHS[LEGACY_HELPER]]
    names = subprocess.check_output(['git', '--no-replace-objects', '-C', str(root),
        'ls-tree', '-r', '--name-only', '-z', commit, '--', *aliases], env=git_environment())
    available = set(filter(None, names.decode().split('\\0')))
    return historical_source(available, LEGACY_HELPER)
'''
compile(new,'source_history.py','exec');changes['tools/qa/performance/source_history.py']={'before':None,'after':new,'after_sha256':hashlib.sha256(new.encode()).hexdigest()}
(R/'adaptation-plan.json').write_text(json.dumps({'base':'f134dd9b7f2cf0741a0ace939d26fc247178cbad','changes':changes},ensure_ascii=False,indent=2)+'\n')
for name,row in changes.items():(ROOT/name).write_text(row['after'])
shutil.copyfile(__file__,R/'apply.py')
print(json.dumps({'old_source_files_changed':5,'new_helper':1,'known_source_map_entries':91,'physical_moves':0,'root':285,'logical_fields_unchanged':True}))
