"""Repair one current fixture address after moving the analyzer, retaining the failed raw/source."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
name = 'tools/qa/world/test_world_source_history.py'
path = ROOT / name
old = path.read_text()
plan_path = Path('/private/tmp/refactor03-world-plan377.json')
plan = json.loads(plan_path.read_text())
assert plan['changes'][name]['after'] == old
assert 'FAILED (errors=1)' in (REPORT / 'history-green.txt').read_text()
assert 'test_water_folder_follows_nested_source_project' in (REPORT / 'history-green.txt').read_text()
backup = REPORT / 'baseline/history-test-before-water-fixture-repair.py.gz'
assert not backup.exists()
backup.write_bytes(gzip.compress(old.encode(), mtime=0))
(REPORT / 'baseline/plan-before-water-fixture-repair.json.gz').write_bytes(gzip.compress(plan_path.read_bytes(), mtime=0))
marker = 'from tools.assets.contracts.source_paths import MOVED_PATHS\n'
assert old.count(marker) == 1
new = old.replace(marker, 'from tools.assets.contracts.source_paths import MOVED_PATHS, current_source\n')
before = "(render_order.ROOT/'tools/analyze_water_audit.py').read_bytes()"
after = "current_source(render_order.ROOT,'tools/analyze_water_audit.py').read_bytes()"
assert new.count(before) == 1
new = new.replace(before, after)
compile(new, name, 'exec')
path.write_text(new)
row = plan['changes'][name]
row['after'] = new
row['after_SHA256'] = hashlib.sha256(new.encode()).hexdigest()
record = plan['external_control_test_source']['history13']
record['initial_after_SHA256'] = record['after_SHA256']
record['after_SHA256'] = row['after_SHA256']
record['same_methods_assertions_except_address_imports'] = False
record['same_methods_assertions_except_address_imports_and_fixture_current_read'] = True
plan['water_fixture_current_address_repaired'] = True
plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')
shutil.copyfile(plan_path, REPORT / 'baseline/move-plan.json')
repair = {'product_algorithms_changed': False, 'test_methods_assertions_removed': 0,
          'current_fixture_input_sites': 1, 'before_SHA256': hashlib.sha256(old.encode()).hexdigest(),
          'after_SHA256': row['after_SHA256'], 'failed_raw_retained': 'history-green.txt',
          'reason': 'water nested-source fixture still copied the moved analyzer from legacy root',
          'before_runtime_source': record['before_SHA256'],
          'before_after_comparison': 'identical non-import AST after normalizing exactly the fixture current-input address'}
(REPORT / 'water-fixture-address-repair.json').write_text(json.dumps(repair, indent=2) + '\n')
shutil.copyfile(__file__, REPORT / 'water-fixture-address-repair.py')
print(json.dumps(repair))
