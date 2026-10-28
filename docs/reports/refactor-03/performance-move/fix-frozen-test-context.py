"""Distinguish the three live frozen consumers from the fourth self-contained protocol snapshot."""
import gzip,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/qa/performance/test_performance_layout.py';before=p.read_text()
(R/'baseline/layout-before-local-snapshot-fix.py.gz').write_bytes(gzip.compress(before.encode(),mtime=0))
old="""                child = ('import sys,runpy;sys.path.insert(0,' + repr(str(source.parent)) + ');'
                    + 'runpy.run_path(' + repr(str(source)) + ',run_name="qa_frozen_import");'
                    + 'import performance_protocol;from tools.qa.performance import performance_protocol as canonical;'
                    + 'assert performance_protocol is canonical;print("FROZEN_IMPORT_OK")')"""
new="""                own_snapshot = source.parent / 'performance_protocol.py'
                if own_snapshot.is_file():
                    # This frozen copy intentionally owns its protocol; it never used the project root.
                    assertion = ('import performance_protocol;from pathlib import Path;'
                        + 'assert Path(performance_protocol.__file__).resolve() == Path(' + repr(str(own_snapshot)) + ');')
                else:
                    assertion = ('import performance_protocol;from tools.qa.performance import performance_protocol as canonical;'
                        + 'assert performance_protocol is canonical;')
                child = ('import sys,runpy;sys.path.insert(0,' + repr(str(source.parent)) + ');'
                    + 'runpy.run_path(' + repr(str(source)) + ',run_name="qa_frozen_import");'
                    + assertion + 'print("FROZEN_IMPORT_OK")')"""
assert before.count(old)==1;after=before.replace(old,new);p.write_text(after)
assert not(R/'frozen-graph-green-attempt01.txt').exists();shutil.copyfile(R/'frozen-graph-green.txt',R/'frozen-graph-green-attempt01.txt')
shutil.copyfile(R/'baseline/layout-frozen-graph-test.py',R/'baseline/layout-frozen-graph-test-attempt01.py')
(R/'baseline/layout-frozen-graph-test.py').write_text(after)
plan=json.loads((R/'adaptation-plan.json').read_text());plan['changes']['tools/qa/performance/test_performance_layout.py']=after
(R/'adaptation-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
exception=json.loads((R/'compatibility-exception.json').read_text());name=next(n for n in exception['frozen_consumers']if 'fixed-gate' in n)
exception['self_contained_snapshot_control']={name:exception['frozen_consumers'].pop(name)}
(R/'compatibility-exception.json').write_text(json.dumps(exception,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,R/'fix-frozen-test-context.py')
print(json.dumps({'final_test_sha256':hashlib.sha256(after.encode()).hexdigest(),'cases':8,'live_frozen_consumers':3,'self_contained_snapshot_control':1}))
