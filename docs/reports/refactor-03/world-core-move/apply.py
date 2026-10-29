"""Apply only the reviewed-plan World-core assignments after the complete real before profile."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

plan = json.loads((REPORT / 'baseline/move-plan.json').read_text())
baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
profile = json.loads((REPORT / 'before-profile.json').read_text())
assert len(profile['commands']) == 38 and len(profile['GD_parse']) == 46
assert all(row['exit'] == 0 for row in profile['commands'] + profile['GD_parse'])
assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], env=git_environment(), text=True).strip() == baseline['base']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


for name, row in baseline['sources'].items():
    path = ROOT / name
    assert sha(path) == row['sha256'] and path.stat().st_mode & 0o777 == row['mode'], name
for row in plan['moves'] + plan['local_UID']:
    assert not (ROOT / row['target']).exists(), row['target']
for row in plan['local_UID']:
    assert sha(ROOT / row['old_path']) == row['sha256']
assert not (REPORT / 'apply-journal.json').exists()
journal = []
for row in plan['moves'] + plan['local_UID']:
    old, target = ROOT / row['old_path'], ROOT / row['target']
    assert old.is_file() and not old.is_symlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    old.rename(target)
    journal.append({'old': row['old_path'], 'new': row['target'], 'sha256': sha(target),
                    'mode': target.stat().st_mode & 0o777})
    (REPORT / 'apply-journal.json').write_text(json.dumps(journal, indent=2) + '\n')
mapping = {row['old_path']: row['target'] for row in plan['moves']}
for name, row in plan['changes'].items():
    path = ROOT / mapping.get(name, name)
    assert path.read_text() == row['before'], name
    path.write_text(row['after'])
    assert sha(path) == row['after_SHA256'], name

path = ROOT / '.gitignore'
path.write_text(path.read_text() + '\n# REFACTOR-03: World-core92; Shore and shared render-order game remain for their consumer steps.\n'
    '!tools/qa/world/*.py\n!tools/qa/world/*.gd\n' +
    ''.join('!' + row['target'] + '\n' for row in plan['moves'] if row['target'].endswith('.uid')))
path = ROOT / 'tools/quality/check_architecture.sh'
text = path.read_text()
for name in mapping:
    if name.endswith('.py'):
        text = text.replace('python3 ' + name, 'python3 tools/run.py qa.world.' + Path(name).stem)
path.write_text(text)
for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md', 'tools/README.md']:
    path = ROOT / name
    text = path.read_text()
    for old, target in sorted(mapping.items(), key=lambda pair: -len(pair[0])):
        text = text.replace('python3 ' + old, 'python3 tools/run.py qa.world.' + Path(old).stem if old.endswith('.py') else 'python3 ' + target)
    path.write_text(text)

paragraph = ('Перенос World-core 0.0.377: 92 исходника и 42 отслеживаемых UID находятся в `tools/qa/world`; '
    'два локальных UID сохраняют байты и права доступа. В корне tools остаётся 153 исходника вместо 245. '
    'Текущая карта расширена ровно 134 принятыми назначениями до 267; отдельная карта art и 141 исторический World alias прежние. '
    'Обновлены импорты, пути запуска и загрузки Godot, адреса текущих фикстур. Логические списки источников и архивные имена сохранены. '
    'Внешний сборщик глубины растений читает унаследованные входы World по актуальным адресам и из истории своего Git. '
    'Его создание отчёта и чтение архива проверяются отдельно; эти фикстуры не дают новой игровой, native или FPS приёмки. '
    'Пять исходников shore-kit и общий render_order_game с UID остаются до следующих зависимых шагов той же REFACTOR-03. '
    'Общие camera points, encoder и water anchor сохранены. '
    'P3 из review 5695222063 исправлен удалением четырёх неиспользуемых импортов. '
    'Пакет 376 принят с CI 8/8; для 377 обязательны новые полные TESTING, Wiki, браузер, CI и независимое ревью точного SHA. '
    'REFACTOR-03 остаётся in_progress в draft PR21; полного merge и Task-Complete нет.')
for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md']:
    path = ROOT / name
    path.write_text('REFACTOR-03 World-core 0.0.377: CLI `python3 tools/run.py qa.world.<модуль>`, '
        'Godot URI `res://tools/qa/world/`. Перед публикацией выполнить 14 actual producer, 13 source-history, '
        '16 API и прежние 19 context cases; профиль 38 CLI, 46 compile-only GD и Water writer на своей копии raw '
        'хранится в `docs/reports/refactor-03/world-core-move/`. Эти фикстуры не дают игровой или GPU/FPS приёмки. '
        'Полные architecture/Game/normal/F10/Wiki, браузер и независимое ревью нового SHA обязательны.\n\n' + path.read_text())
path = ROOT / 'tools/README.md'
text = path.read_text()
marker = '# Инструменты проекта\n'
assert text.count(marker) == 1
path.write_text(text.replace(marker, marker + '\n' + paragraph +
    '\n\n[Профиль переноса World-core377](../docs/reports/refactor-03/world-core-move/after-profile.json).\n', 1))
path = ROOT / 'wiki/articles/project-refactoring.md'
text = path.read_text()
marker = 'Подготовка0.0.376 world-inputs отделяет37'
assert text.count(marker) == 1
old = 'В текущем кандидате корень tools составляет245 исходников'
assert text.count(old) == 1
text = text.replace(old, 'В текущем кандидате корень tools составляет153 исходников')
path.write_text(text.replace(marker, paragraph +
    '\n\n[Профиль переноса World-core377](../../docs/reports/refactor-03/world-core-move/after-profile.json).\n\n' + marker, 1))
path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
text = path.read_text()
start, end = text.index('## REFACTOR-03 '), text.index('## REFACTOR-04 ')
section = text[start:end].rstrip() + ' ' + paragraph + ' [Профиль377](../../reports/refactor-03/world-core-move/after-profile.json).\n\n'
path.write_text(text[:start] + section + text[end:])
for name, row in baseline['deferred_shared_anchors'].items():
    assert sha(ROOT / name) == row['sha256'] and (ROOT / name).stat().st_mode & 0o777 == row['mode'], name
subprocess.run([sys.executable, 'tools/run.py', 'planning.bump_version', '--set', '0.0.377'], cwd=ROOT, env=git_environment(), check=True)
shutil.copyfile(__file__, REPORT / 'apply.py')
shutil.copyfile('/private/tmp/refactor03-world-profile377.py', REPORT / 'profile.py')
(REPORT / 'migration.json').write_text(json.dumps({
    'base': baseline['base'], 'root_before': 245, 'root_sources_after_moves': 153,
    'moves': plan['moves'], 'local_UID': plan['local_UID'],
    'deferred_shared_anchors': baseline['deferred_shared_anchors'], 'final_task_complete': False,
}, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'source_moves': 92, 'tracked_UID': 42, 'ignored_UID': 2,
                  'root_after': 153, 'current_source_map': 267, 'Task_Complete': False}))
