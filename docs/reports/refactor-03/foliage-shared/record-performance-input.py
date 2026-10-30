"""Record the shared camera input missed by the performance collector's closed current-source table."""
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
name='tools/qa/performance/perf_contract_collect.py'
before=(R/'baseline/perf_contract_collect-before-shared-input.py').read_text();after=(Q/name).read_text()
line="    'tools/visual_camera_points.gd': 'tools/qa/camera/visual_camera_points.gd',\n"
assert after.count(line)==1 and after.replace(line,'')==before
record=json.loads((R/'integration-repairs.json').read_text())
record['modules'][name]={'before_SHA256':hashlib.sha256(before.encode()).hexdigest(),
 'after_SHA256':hashlib.sha256(after.encode()).hexdigest(),
 'change':'one exact original camera assignment added to current-only input table; FROZEN/archive namespace and all function bodies unchanged',
 'failed_full_gate':'gates-02/architecture.txt','existing_actual_producer_tests':'performance-shared-green.txt',
 'existing_cases_passed':8,'test_cases_removed_or_rewritten':0,'all_other_bytes_equal':True}
(R/'integration-repairs.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ['scope.json','source-freeze.json']:
 target=R/name.replace('.json','-attempt02.json');assert not target.exists();shutil.copy2(R/name,target)
with (R/'README.md').open('a') as stream:
 stream.write('\nВ gates-02 три из8 прежних performance-layout случаев обнаружили пропущенный current input общих camera points. Закрытая CURRENT_SOURCES расширена одной исходной строкой tools/visual_camera_points.gd→qa/camera: функции, FROZEN, архивные имена и все8 тестов неизменны. Адресный повтор8/0 вызывает настоящий collector/Git/copy/hash и fake-open свидетель. Источник и сырые ошибки сохранены; полный окончательный прогон — gates-03.\n')
shutil.copy2(__file__,R/'record-performance-input.py')
print(json.dumps({'current_input_rows_added':1,'function_bodies_changed':0,'old_cases_retained':8}))
