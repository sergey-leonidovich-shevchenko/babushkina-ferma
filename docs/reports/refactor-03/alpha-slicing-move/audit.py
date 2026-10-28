"""Проверяет полную границу связанного переноса и сохранность исторических контрактов/UID."""
import ast
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(ROOT), *arguments], env=git_environment())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_methods(text):
    return {n.name: n for n in ast.walk(ast.parse(text)) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_')}


def assertions(node):
    return Counter(ast.dump(n) for n in ast.walk(node) if isinstance(n, ast.Call)
        and isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
        and n.func.value.id == 'self' and n.func.attr.startswith('assert'))


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text());base=baseline['base']
    mapping = {n:r['target'] for n,r in baseline['assignments'].items()}
    source_after=set(baseline['consumers'])|set(mapping.values())|{
        'tools/assets/slicing/__init__.py','tools/assets/alpha/test_street_consumer.py'}
    allowed=set(baseline['sources'])|source_after
    changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))
    untracked=set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
    prefix=str(REPORT.relative_to(ROOT))+'/'
    assert all(n in allowed or n.startswith(prefix) for n in changed|untracked),(changed|untracked)-allowed
    assert allowed <= changed|untracked,allowed-(changed|untracked)
    for old,row in baseline['sources'].items():
        raw=gzip.decompress((REPORT/'baseline'/(old.replace('/','--')+'.gz')).read_bytes())
        assert raw==git('show',base+':'+old) and hashlib.sha256(raw).hexdigest()==row['sha256'],old
        current=ROOT/mapping.get(old,old)
        assert current.stat().st_mode&0o777==row['mode'],old
    for old,new in mapping.items():assert not(ROOT/old).exists() and (ROOT/new).is_file(),old
    assert len(mapping)==19
    expected_attributes=git('show',base+':.gitattributes').decode()+(
        '# Preserve the rejected fresh-QA import log, including its final blank line.\n'
        'docs/reports/refactor-03/alpha-slicing-prepare/gates-01/architecture.txt -whitespace\n'
        '# Cancelled CI raw keeps timestamp-only lines and package-manager output verbatim.\n'
        'docs/reports/refactor-03/alpha-slicing-move/baseline/cancelled-linux123020343023.txt -whitespace\n')
    assert (ROOT/'.gitattributes').read_text()==expected_attributes
    old_arch=git('show',base+':tools/quality/check_architecture.sh').decode()
    expected=old_arch.replace('python3 tools/run.py assets.alpha.test_processing_history\n',
        'python3 tools/run.py assets.alpha.test_processing_history\npython3 tools/run.py assets.alpha.test_street_consumer\n')
    for old,new in mapping.items():
        if old.endswith('.py'):expected=expected.replace('python3 '+old,'python3 tools/run.py '+new.removeprefix('tools/').removesuffix('.py').replace('/','.'))
    assert expected==(ROOT/'tools/quality/check_architecture.sh').read_text()
    cards='docs/epics/refactoring-2026-10/TASKS.md'
    before=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+cards).decode(),flags=re.M)
    after=re.split(r'(?=^## REFACTOR-)',(ROOT/cards).read_text(),flags=re.M)
    assert len(before)==len(after)==8
    assert all(a==b for a,b in zip(before,after) if not a.startswith('## REFACTOR-03 '))
    for n in ['AGENTS.md','docs/backlog/README.md','wiki/planning/sources.json']:
        assert git('show',base+':'+n)==(ROOT/n).read_bytes(),n
    backlog='docs/epics/visual-overhaul-2026-10/backlog.json'
    expected=git('show',base+':'+backlog).decode()
    for old,new in mapping.items():expected=expected.replace(old,new)
    assert json.loads(expected)==json.loads((ROOT/backlog).read_text())
    prior={}
    for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move']:
        prior.update({r['old_path']:r['target'] for r in json.loads((REPORT.parent/phase/'migration.json').read_text())['moves']})
    prior.update(mapping)
    contracts=REPORT.parent/'baseline/source-contracts.json'
    assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    child=ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent/'snapshot-contracts.py').read_text()).body
        if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='CHILD' for t in n.targets)))
    fields=0
    for row in json.loads(contracts.read_text())['modules'].values():
        module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
        result=subprocess.run([sys.executable,'-c',child,str(ROOT),module],cwd=ROOT,env=git_environment(),capture_output=True,text=True,timeout=30)
        assert result.returncode==0 and not result.stderr,(module,result.stderr)
        assert json.loads(result.stdout)==row['fields'],module
        fields+=len(row['fields'])
    assert fields==37
    tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
    root_count=sum(n.startswith('tools/') and n.count('/')==1 and Path(n).suffix in
        {'.py','.gd','.mjs','.swift','.sh','.gdshader'} for n in tracked)
    assert root_count==403
    uid=json.loads((REPORT.parent/'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        paths=[ROOT/n for n in [row['old_path'],row['target']] if(ROOT/n).is_file()]
        assert len(paths)==1 and paths[0].read_text().strip()==row['value']
        name=str(paths[0].relative_to(ROOT));assert name not in tracked and git('check-ignore','--',name).strip()
    assert len(uid['local_only_UID'])==85
    anchor=uid['retained_anchor_local_UID'];assert sha(ROOT/anchor['path'])==anchor['sha256']
    method_count=0;rename={'test_table_matches_accepted71_and_actual_files':'test_table_matches_accepted_plan_and_actual_files'}
    tests=[n for n in baseline['sources'] if Path(n).name.startswith('test_')]
    for old in tests:
        previous=test_methods(git('show',base+':'+old));current=test_methods((ROOT/mapping.get(old,old)).read_text())
        assert set(current)=={rename.get(n,n) for n in previous},old
        for name,node in previous.items():
            if name=='test_table_matches_accepted71_and_actual_files':
                for n in ast.walk(node):
                    if isinstance(n,ast.Constant) and n.value==71:n.value=90
            assert not(assertions(node)-assertions(current[rename.get(name,name)])),(old,name)
        method_count+=len(current)
    profile=json.loads((REPORT/'profile.json').read_text())
    assert profile['all5603_frame_signatures_and_RGBA_PNG_equal_before']
    assert len(profile['actual_after_export']['frames'])==5603
    assert len(profile['actual_control_files_equal_before'])==9 and not profile['GPU_FPS_admission']
    assert sha(ROOT/'tools/assets/alpha/alpha_metrics.py')==baseline['sources']['tools/alpha_metrics.py']['sha256']
    assert sha(ROOT/'tools/assets/slicing/slice_metrics.py')==baseline['sources']['tools/slice_metrics.py']['sha256']
    regression=json.loads((REPORT/'street-regression.json').read_text())
    assert regression['same_test_source'] and regression['red_exit']==1 and regression['green_exit']==0
    assert regression['test_sha256']==sha(ROOT/'tools/assets/alpha/test_street_consumer.py')
    assert regression['green_producer_sha256']==sha(ROOT/'tools/village_street_verify.py')
    before_source=gzip.decompress((REPORT/'village-git-red-source.py.gz').read_bytes()).decode()
    expected=before_source.replace('from tools.assets.alpha.alpha_audit import inspect as inspect_alpha',
        'from tools.assets.alpha.alpha_audit import inspect as inspect_alpha\nfrom tools.common.git import git_environment')
    expected=expected.replace('cwd=ROOT,capture_output=True','cwd=ROOT,env=git_environment(),capture_output=True')
    assert expected==(ROOT/'tools/village_street_verify.py').read_text()
    result={'base':base,'version':'0.0.368','root_sources':root_count,'physical_source_moves':17,'JSON_moves':2,
        'ignored_UID_moves':6,'historical_fields':fields,'all_ignored_UID_preserved':85,'anchor_preserved':True,
        'old_test_methods_preserved_with_one_explicit_table_rename':method_count,'new_real_consumer_cases':2,
        'other_six_refactor_cards_unchanged':True,'parallel07_excluded_from_QA':True,
        'old_reports_runtime_artwork_plans_GD_UID_policies_unchanged_except_declared_moves':True,
        'full_task03_accepted':False,'source_paths_after':sorted(source_after),'removed_source_paths':sorted(mapping)}
    (REPORT/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    migration={'base':base,'root_sources_after_moves':403,'physical_source_moves':17,'JSON_moves':2,'ignored_UID_moves':6,
        'moves':[{'old_path':old,'target':new,'before_sha256':baseline['sources'][old]['sha256'],
        'after_sha256':sha(ROOT/new),'mode':baseline['sources'][old]['mode']}for old,new in mapping.items()]}
    (REPORT/'migration.json').write_text(json.dumps(migration,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'root':root_count,'source_paths_after':len(source_after),'fields':fields,'UID':85,'old_methods':method_count}))


if __name__=='__main__':main()
