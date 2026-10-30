"""Record the two integration address repairs without broadening runtime or Wiki implementation scope."""
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
before=(R/'baseline/test_infrastructure-before-launch-repair.py').read_text()
after=(Q/'tools/common/test_infrastructure.py').read_text()
assert after==before.replace('"PYTHONPATH": str(ROOT / "tools")}', '"PYTHONPATH": str(ROOT)}',1).replace(
 '"from test_shore_kit import ShoreKitTests; "', '"from tools.qa.world.test_shore_kit import ShoreKitTests; "',1)
record={'modules':{'tools/common/test_infrastructure.py':{
 'before_SHA256':hashlib.sha256(before.encode()).hexdigest(),'after_SHA256':hashlib.sha256(after.encode()).hexdigest(),
 'change':'same actual Shore child and foreign Git/index/config assertions; qualified module and package root PYTHONPATH',
 'test_methods_removed':0,'all_other_bytes_equal':True}},
 'failed_full_gate':'gates-01/architecture.txt','targeted_green':'infrastructure-launch-green.txt',
 'wiki_link_repair':{'before':'README basename resolved to the unrelated Wiki README guide',
 'after':'direct full-plan-coverage.json and after-profile.json downloads; exact exported bytes checked',
 'failed_catalog_check':'catalog-attempt01.txt','Wiki_implementation_changed':False}}
(R/'integration-repairs.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ['scope.json','source-freeze.json']:
 target=R/name.replace('.json','-attempt01.json');assert not target.exists();shutil.copy2(R/name,target)
with (R/'README.md').open('a') as stream:
 stream.write('\nПервый полный architecture остановился в common.test_infrastructure: embedded child import ещё называл старый root-модуль test_shore_kit. [Поправка](integration-repairs.json) меняет только квалифицированный import/PYTHONPATH, прежние13 сценариев и config/index assertions сохранены; адресный повтор13/0. Wiki145/0 прошла, но отдельный catalog audit нашёл ошибочную ссылку README-basename: теперь статья даёт прямые JSON с проверкой actual export bytes. Первый source freeze сохранён отдельно. Авторитетная полная серия после этих исправлений — gates-02; gates-01/raw не заменяются.\n')
shutil.copy2(__file__,R/'record-integration-repairs.py')
print(json.dumps({'integration_module_repairs':1,'runtime_changes':0,'Wiki_implementation_changes':0}))
