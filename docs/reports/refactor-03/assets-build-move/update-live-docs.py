"""Обновляет живые CLI/ссылки; сохраняет прежние документы и не трогает frozen reports/JSON keys."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
CLI_MODULES = {}
for old, new in mapping.items():
    if old.endswith('.py'):
        tree = ast.parse((ROOT / new).read_text())
        if any(isinstance(n, ast.If) and '__name__' in ast.unparse(n.test) for n in tree.body):
            CLI_MODULES[old] = new.removesuffix('.py').replace('/', '.').removeprefix('tools.')


def save_original(name, raw):
    path = REPORT / 'inputs' / (name.replace('/', '--') + '.gz')
    if path.exists():
        assert gzip.decompress(path.read_bytes()) == raw
    else:
        path.write_bytes(gzip.compress(raw, mtime=0))
    assert subprocess.check_output(['git', '-C', str(ROOT), 'show', baseline['base'] + ':' + name]) == raw


def current_commands(text):
    for old, new in mapping.items():
        if old.endswith('.py'):
            module = new.removesuffix('.py').replace('/', '.').removeprefix('tools.')
            text = re.sub(r'\b(python3?)\s+' + re.escape(old) + r'\b',
                          lambda m: m[1] + ' tools/run.py ' + module, text)
            value = 'python3 tools/run.py ' + module if old in CLI_MODULES else new
            text = re.sub(r'(?<!\[)`' + re.escape(old) + r'`', '`' + value + '`', text)
        else:
            text = re.sub(r'(?<!\[)`' + re.escape(old) + r'`', '`' + new + '`', text)
        # migration_capture внутри созданного внешнего fixture сохраняет свой старый namespace.
        if old != 'tools/migration_capture.gd':
            text = text.replace('res://' + old, 'res://' + new)
    def link(match):
        target = match[1]
        if '://' not in target:
            for old, new in mapping.items():
                target = target.replace(old, new)
        return '](' + target + ')'
    return re.sub(r'\]\(([^)]+)\)', link, text)


def main():
    names = subprocess.check_output(['rg', '--files', '-g', '*.md', '-g', '!docs/reports/**',
        '-g', '!docs/concepts/**', '-g', '!wiki/articles/tools-migration-map.md',
        '-g', '!wiki/public/**', '-g', '!wiki/dist/**', '-g', '!tmp/**'], cwd=ROOT, text=True).splitlines()
    names.append('docs/epics/visual-overhaul-2026-10/backlog.json')
    changes = []
    for name in names:
        path = ROOT / name
        raw = path.read_bytes()
        current = current_commands(raw.decode())
        if current != raw.decode():
            save_original(name, raw)
            path.write_text(current)
            changes.append({'path': name, 'before_sha256': hashlib.sha256(raw).hexdigest()})
    paragraphs = {
        'TESTING.md': ('REFACTOR-03, перенос assets/build0.0.365:61 source/8 tracked UID/2 JSON и18 ignored UID '
            'сохраняют mode/байты политик и UID. `python3 tools/run.py assets.contracts.test_source_paths` '
            'проверяет12 случаев canonical/Git-alias/metadata;4 новых Portability-контроля сохраняют все21 '
            'прежний. [Профиль](docs/reports/refactor-03/assets-build-move/profile.json) сравнивает35 Python AST, '
            '28 GD тел и реальный старый/новый fixed-input экспорт4 PNG. Полные gates и independent exact-head '
            'review обязательны; это не новая GPU/FPS-приёмка.\n\n'),
        'tools/README.md': ('\nКандидат0.0.365 переносит связанное assets/contracts, assets/migration и build:61 '
            'source/8 tracked UID/2 JSON,18 ignored UID; текущий root420. Команды запускаются через '
            '`python3 tools/run.py assets.contracts.visual_pipeline`, `python3 tools/run.py assets.migration.asset_migration`, '
            '`python3 tools/run.py build.artist_packet`. Godot использует новые `res://tools/assets/contracts/…` '
            'и `res://tools/build/…`. Старые логические имена в proofs/manifest сохраняются; current_source '
            'выбирает только canonical файл, historical_source — единственный alias из своего commit tree. '
            '[Профиль](../docs/reports/refactor-03/assets-build-move/profile.json) проверяет старый/новый настоящий '
            'экспорт и отрицательные metadata. Пакет364 head6af72 принят review5676273527/Team Lead и CI8/8; '
            'вся03 остаётся in_progress до полного root≤30/приёмки.\n'),
    }
    for name, paragraph in paragraphs.items():
        path = ROOT / name
        raw = path.read_bytes()
        if not any(r['path'] == name for r in changes):
            save_original(name, raw)
            changes.append({'path': name, 'before_sha256': hashlib.sha256(raw).hexdigest()})
        text = raw.decode()
        if name == 'tools/README.md':
            position = text.index('\n') + 1
            text = text[:position] + paragraph + text[position:]
        else:
            text = paragraph + text
        path.write_text(text)
    for name in ['wiki/articles/project-refactoring.md', 'wiki/articles/visual-pilot.md',
                 'docs/epics/refactoring-2026-10/README.md', 'docs/epics/refactoring-2026-10/TASKS.md']:
        path = ROOT / name
        raw = path.read_bytes()
        if not any(r['path'] == name for r in changes):
            save_original(name, raw)
            changes.append({'path': name, 'before_sha256': hashlib.sha256(raw).hexdigest()})
        text = raw.decode()
        if name.endswith('/project-refactoring.md'):
            text = text.replace('Кандидат0.0.364 готовит связанное семейство assets/build:',
                'Пакет0.0.364 head `6af72b44` принят промежуточным '
                '[ревью5676273527](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5676273527) '
                'и Team Lead; его CI8/8 подтверждён отдельно. Подготовка выполнила:')
            point = text.index('\n\nПакет0.0.364')
            paragraph = ('\n\nКандидат0.0.365 переносит61 исходник/8 tracked UID/2 JSON в assets/contracts, '
                'assets/migration и build;18 ignored UID сохраняются, текущий root420. '
                '[Профиль связанного переноса](../../docs/reports/refactor-03/assets-build-move/profile.json) '
                'сравнивает35 Python AST/28 GD тел и реальные старые/новые4 fixed-input PNG. Политики и старые '
                'proofs побайтно прежние; новый collector явно отмечает known source_paths, metadata не выбирает '
                'произвольный файл. Это промежуточная работа03, финальный бюджет≤30 и ревью ещё впереди.')
            text = text[:point] + paragraph + text[point:]
        elif name.endswith('/visual-pilot.md'):
            text = text.replace('сейчас481, прогноз', 'сейчас420, прогноз')
        elif name.endswith('/README.md'):
            text = text.replace('Нынешние 481 корневых исходников', 'Нынешние 420 корневых исходников')
        else:
            before = ' После полного принятия03 действует остановка пользователя28.10.2026.'
            assert text.count(before) == 1
            text = text.replace(before, ' Подготовка364 head6af72 принята review5676273527/Team Lead, CI8/8. '
                'Кандидат0.0.365 перемещает61 source/8 tracked UID/2 JSON и18 ignored UID; root420. '
                '[Профиль](../../reports/refactor-03/assets-build-move/profile.json) сохраняет35 AST/28 GD, '
                'реальный старый/новый fixed-input экспорт и negative metadata; собственные полные gates/review '
                'нового head ещё обязательны.' + before)
        path.write_text(text)
    for row in changes:
        row['after_sha256'] = hashlib.sha256((ROOT / row['path']).read_bytes()).hexdigest()
    (REPORT / 'live-documents.json').write_text(json.dumps(changes, indent=2) + '\n')
    print('Updated live documents:', len(changes), '; frozen reports and migration fixture URI unchanged')


if __name__ == '__main__':
    main()
