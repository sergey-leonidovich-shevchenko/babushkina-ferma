"""Document the bounded P2 repair and update only the live03 card and usage."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
old=ast.parse((R/'baseline/grass_methods.py').read_text());new=ast.parse((Q/'tools/qa/foliage/grass_methods.py').read_text())
def without_launch(tree):
 tree=copy.deepcopy(tree);tree.body=[n for n in tree.body if not isinstance(n,ast.FunctionDef) or n.name!='launch'];return ast.dump(tree,include_attributes=False)
assert without_launch(old)==without_launch(new)
old_profile=json.loads((Q/'docs/reports/refactor-03/foliage-shared/before-profile.json').read_text())
raw=(R/'historical-current.txt').read_bytes();expected=old_profile['commands'][8]['stdout_SHA256']
assert hashlib.sha256(raw).hexdigest()==expected
assert (R/'old-grass-controls.txt').read_text().rstrip().endswith('OK')
audit={'all_non_launch_AST_equal':True,'old_test_methods_unchanged':10,'added_test_methods':10,
 'same_red_green_test_SHA256':hashlib.sha256((Q/'tools/qa/foliage/test_relocation_provenance.py').read_bytes()).hexdigest(),
 'historical_Grass_stdout_byte_equal':True,'historical_stdout_SHA256':expected,
 'old_grass_controls_passed':18,'new_controls_passed':20,'production_scripts_artwork_changed':False}
(R/'bounded-change-audit.json').write_text(json.dumps(audit,indent=2)+'\n')

(R/'README.md').write_text('''# REFACTOR-03: P2, граница аргументов движка, кандидат381

Родитель2c856d7d3d0a185735f17bdc5fa3f8c258b836d8 получил CHANGES REQUESTED: Grass reader находил --script даже после --/++, то есть в пользовательских данных, которые Godot не использует как engine arguments. [Фактические три примера ревьюера](baseline/reviewer-launch-boundary.json) воспроизведены настоящим parent-reader из Git и текущим reader: [result.json](result.json). Frozen evidence не переписано.

`launch()` теперь отделяет engine-сегмент по первому -- или ++. Для macOS open учитывается единственный --args; аргументы wrapper не могут задавать engine script. Для прямого Godot пропускается имя binary. Протокол сохраняет обязательную длинную двухтокенную форму --script: требуется ровно один ожидаемый URI внутри engine-сегмента. Дубли, конкурирующие --script=/-s формы, нестроковые argv и engine --headless отклоняются. Пользовательские данные после разделителя, включая такие же строки флагов, не меняют выбор script или headless-проверку. Legacy/current URI по-прежнему задаются только закрытой известной source_paths.

Все остальные функции, imports и module constants reader побайтно/AST прежние: [ограниченный аудит](bounded-change-audit.json). Десять прежних test-методов сохранены с теми же AST/assertions; их helper теперь создаёт правильный open --args argv. Добавлены10 тестов с54 смысловыми подслучаями для legacy/current, двух/смешанных разделителей, payload-only script, конкурирующих engine forms, wrapper/direct положительных случаев и malformed argv. На родителе20 tests дают32 failed subtests/4 errors; после20/0 на том же test SHA. Первый exploratory17-test red сохранён отдельно и не подменяет авторитетный20-test red/green.

Прежние18 Grass controls проходят. Полный исторический `grass_methods all` даёт побайтно тот же stdout, что до перемещений; старые native архивы, их источник и scope остаются прежними. Это чтение существующего evidence и metadata fixtures, без игрового окна, новых native/GPU/FPS результатов. Закреплённый Godot4.7.1 --help сохраняет определение --/++ в baseline.

Полные architecture/Game/normal/F10/Wiki текущего кандидата обязательны и сохраняются в gates-01. Предыдущие380 gates не заменяют381. Карта779/root11, generic491,304 UID и37 логических полей21 модуля не меняются. Карточка03 остаётся in_progress/PR21draft; нужны новый exact-head CI, независимый Tech Lead review и решение Team Lead. До этого нет merge/done/Task-Complete. Незакоммиченный чужой план07 в primary сохраняется отдельно.
''')
paragraph=('P2 REFACTOR-03, кандидат0.0.381: `qa.foliage.test_relocation_provenance` проверяет20 случаев, '
 'включая10 новых тестов/54 подслучая границы engine/user argv. Parent2c856d7d дал32 failed subtests/4 errors, '
 'текущий reader20/0 на том же test SHA. Поиск script завершается на первом --/++; open --args и прямой '
 'Godot разделены, дубли/конфликтующие формы отклоняются, payload-флаги не влияют на engine. '
 'Все10 прежних test-методов и остальные функции reader сохранены;18 старых Grass controls и исторический '
 'stdout проходят без изменений. Parent380 не принят из-за P2;03 остаётся in_progress/PR21draft до новых '
 'полных TESTING, exact-head review/CI и решения Team Lead. Frozen evidence и runtime не переписаны.')
p=Q/'TESTING.md';p.write_text(paragraph+'\n\n'+p.read_text())
p=Q/'wiki/articles/project-refactoring.md';text=p.read_text();index=text.index('\n')+1
p.write_text(text[:index]+'\n'+paragraph+'\n\n[Проверка границы аргументов381](../../docs/reports/refactor-03/launch-boundary-review/result.json).\n'+text[index:])
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';text=p.read_text();a,b=text.index('## REFACTOR-03 '),text.index('## REFACTOR-04 ')
p.write_text(text[:b]+'**Доработка P2 0.0.381:** '+paragraph+' [Доказательства](../../reports/refactor-03/launch-boundary-review/README.md).\n\n'+text[b:])
shutil.copy2(__file__,R/'write-docs.py')
shutil.copy2('/private/tmp/refactor03-launch-record381.py',R/'record.py')
shutil.copy2(Q/'docs/reports/refactor-03/foliage-shared/run-gates.py',R/'run-gates.py')
print(json.dumps({'bounded_product_function':'launch','red':[32,4],'green':20,'old_tests':10,'old_controls':18,'old_stdout_equal':True}))
