"""Remove one completed shared-move exception from the real missing-canonical Camera fixture."""
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
name='tools/qa/camera/test_camera_layout.py'
before=(R/'baseline/test_camera_layout-before-shared-fixture.py').read_text();after=(Q/name).read_text()
assert after==before.replace("                if name == 'tools/visual_camera_points.gd':\n                    physical = name\n",'',1)
record=json.loads((R/'integration-repairs.json').read_text())
record['modules'][name]={'before_SHA256':hashlib.sha256(before.encode()).hexdigest(),'after_SHA256':hashlib.sha256(after.encode()).hexdigest(),
 'change':'remove completed shared-points deferral only in file fixture; exact missing-canonical filename and no-child assertions retained',
 'failed_full_gate':'gates-04/architecture.txt','tests':'camera-shared-fixture-green.txt','old_cases_retained':3,'test_assertions_changed':0}
(R/'integration-repairs.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ['scope.json','source-freeze.json']:
 target=R/name.replace('.json','-attempt04.json');assert not target.exists();shutil.copy2(R/name,target)
with (R/'README.md').open('a') as stream:
 stream.write('\nGates-04 выявил ещё одну отложенную строку Camera fixture: points намеренно оставлялись в root, поэтому actual collector отказывал раньше проверяемого отсутствующего visual_camera.py. Удалены только две строки этой завершённой отсрочки; все3 случая, конкретный ожидаемый filename, stale-old-file и no-child assertions сохранены. Адресный повтор3/0, сырой отказ сохранён. Окончательная полная серия — gates-05.\n')
shutil.copy2(__file__,R/'record-camera-fixture.py')
print(json.dumps({'fixture_deferrals_removed':1,'old_cases_retained':3,'assertions_changed':0}))
