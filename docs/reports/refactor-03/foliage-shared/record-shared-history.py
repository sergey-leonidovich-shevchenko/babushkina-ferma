"""Record explicit same-commit aliases for non-overlay shared inputs; preserve the special helper guard."""
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
record=json.loads((R/'integration-repairs.json').read_text())
items=[('tools/qa/ground/ground_layers.py','ground_layers-before-shared-history.py'),
       ('tools/qa/foliage/grass_methods.py','grass_methods-before-shared-history.py')]
for name,baseline in items:
 before=(R/'baseline'/baseline).read_text();after=(Q/name).read_text()
 normalized=after.replace('from tools.qa.world.source_inputs import historical_bytes\n','',1)
 if name.endswith('ground_layers.py'):
  normalized=normalized.replace('    if name != LEGACY_HELPER:\n        return historical_bytes(ROOT,commit,name)\n','',1)
 else:
  old="""            physical = historical_helper(ROOT,source['base_commit']) if name == LEGACY_HELPER else name
            require(hashlib.sha256(subprocess.check_output(['git','--no-replace-objects','show',source['base_commit']+':'+physical],cwd=ROOT,env=git_environment())).hexdigest()==digest,'production/reference differs from Git base: '+name)"""
  new="""            if name == LEGACY_HELPER:
                physical = historical_helper(ROOT,source['base_commit'])
                raw = subprocess.check_output(['git','--no-replace-objects','show',source['base_commit']+':'+physical],cwd=ROOT,env=git_environment())
            else:
                raw = historical_bytes(ROOT,source['base_commit'],name)
            require(hashlib.sha256(raw).hexdigest()==digest,'production/reference differs from Git base: '+name)"""
  assert normalized.count(new)==1;normalized=normalized.replace(new,old,1)
 assert normalized==before,name
 record['modules'][name]={'before_SHA256':hashlib.sha256(before.encode()).hexdigest(),'after_SHA256':hashlib.sha256(after.encode()).hexdigest(),
  'change':'non-helper current Git bases use one known alias in the same pinned commit; special LEGACY_HELPER resolution and every digest/coverage/assertion preserved',
  'failed_full_gate':'gates-03/architecture.txt','tests':'surface-shared-history-green.txt','old_cases_retained':9,
  'all_other_bytes_equal_after_exact_history_resolution_normalization':True}
(R/'integration-repairs.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ['scope.json','source-freeze.json']:
 target=R/name.replace('.json','-attempt03.json');assert not target.exists();shutil.copy2(R/name,target)
with (R/'README.md').open('a') as stream:
 stream.write('\nВ gates-03 старые9 actual surface-producer случаев обнаружили четыре ошибки чтения shared-файлов из свежей canonical Git-истории. Ground/Grass теперь используют исторический resolver только для non-helper входов: один известный old/new alias из того же full commit, без live fallback. Специальный LEGACY_HELPER guard сохранён. Все coverage/digest/overlay assertions и9 прежних сценариев остаются. Отдельный повтор проверяет actual producer/reader; изменённый исторический Grass CLI сравнивается с прежним stdout дополнительно. Финальная обязательная серия после этой поправки — gates-04.\n')
shutil.copy2(__file__,R/'record-shared-history.py')
print(json.dumps({'history_adapter_modules':2,'old_surface_cases_retained':9,'frozen_fields_changed':0}))
