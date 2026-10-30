"""Retain the first full-gate failure and add an actual frozen import-graph regression."""
import gzip,hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/qa/performance/test_performance_layout.py';old=p.read_text()
(R/'baseline/layout-before-frozen-graph.py.gz').write_bytes(gzip.compress(old.encode(),mtime=0))
marker="\n\nif __name__ == '__main__':"
method='''

    def test_frozen_executable_import_graph_still_works_without_rewriting_archive(self):
        """Actual archived consumers import the public protocol first as well as after the gate."""
        relative = [
            'docs/reports/visual-overhaul/vfoliage-006/redraw-scheduling/verify.py',
            'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/analysis/verify.py',
            'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation/causal_capture.py',
            'docs/reports/visual-overhaul/vfoliage-006/ci-performance/fixed-gate/instrumentation/performance_gate.py',
        ]
        with tempfile.TemporaryDirectory(prefix='performance frozen imports ') as directory:
            foreign = Path(directory).resolve()
            for name in relative:
                source = collector.ROOT / name
                before = source.read_bytes()
                child = ('import sys,runpy;sys.path.insert(0,' + repr(str(source.parent)) + ');'
                    + 'runpy.run_path(' + repr(str(source)) + ',run_name="qa_frozen_import");'
                    + 'import performance_protocol;from tools.qa.performance import performance_protocol as canonical;'
                    + 'assert performance_protocol is canonical;print("FROZEN_IMPORT_OK")')
                process = subprocess.run([sys.executable, '-c', child], cwd=foreign,
                    env=dict(git_environment(), PYTHONPATH=str(foreign)), capture_output=True, text=True, timeout=30)
                self.assertEqual(process.returncode, 0, name + ': ' + process.stderr)
                self.assertIn('FROZEN_IMPORT_OK', process.stdout)
                self.assertEqual(source.read_bytes(), before)
            self.assertEqual(list(foreign.iterdir()), [])
'''
assert old.count(marker)==1
new=old.replace(marker,method+marker)
anchor='        self.assertIs(public, canonical_gate)\n';assert new.count(anchor)==1
new=new.replace(anchor,anchor+"        protocol = importlib.import_module('performance_protocol')\n        self.assertIs(protocol, importlib.import_module('tools.qa.performance.performance_protocol'))\n")
p.write_text(new)
(R/'baseline/layout-frozen-graph-test.py').write_text(new)
shutil.copyfile(R/'source-freeze.json',R/'source-freeze-before-legacy-facade.json')
shutil.copyfile(__file__,R/'prepare-frozen-regression.py')
print(json.dumps({'new_test_SHA256':hashlib.sha256(new.encode()).hexdigest(),'cases':8,'facade_not_yet_added':not(ROOT/'tools/performance_protocol.py').exists()}))
