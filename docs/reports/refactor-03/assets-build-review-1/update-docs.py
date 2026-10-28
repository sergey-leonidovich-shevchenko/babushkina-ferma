"""Фиксирует текущую доработку03 в живых инструкциях, не меняя остальные карточки."""
import hashlib
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    text = ('REFACTOR-03, P2 producer0.0.366: `python3 tools/run.py assets.migration.test_migration_fixture` '
        'упражняет настоящий create из live/Git, прежний `res://tools/migration_capture.gd` внутри внешнего проекта, '
        'probe/project/case/draft и пять фаз, отказ существующей/внутренней цели и неизвестной фазы, чужой GIT/index/config. '
        'Proof-тесты сохранены отдельно: они не заменяют producer. '
        '[Доработка](docs/reports/refactor-03/assets-build-review-1/README.md) сохраняет red3/3 и green3/0; '
        'требует свежего внешнего Godot import/parse/headless capture, полных gates и повторного независимого ревью нового SHA.\n\n')
    path = ROOT / 'TESTING.md'
    path.write_text(text + path.read_text())
    path = ROOT / 'wiki/articles/project-refactoring.md'
    text = ('Доработка P2 0.0.366 восстанавливает настоящий producer внешнего стенда: '
        'исходный collector остаётся в assets/migration, внутри проекта он записывается по прежнему `tools/migration_capture.gd`. '
        'Head365 `48ac944b` получил [CHANGES REQUESTED](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5676955759); '
        'его CI8/8 не снимает дефект producer. Три новых случая проверяют реальный create, пять фаз и отказы; '
        '[профиль доработки366](../../docs/reports/refactor-03/assets-build-review-1/profile.json) содержит фактические old/new файлы и пять headless фаз. '
        'Пакет требует собственных gates/CI и повторного независимого ревью;03in_progress/root420, merge не разрешён.\n\n')
    current = path.read_text()
    assert '\nКандидат0.0.365' in current
    path.write_text(current.replace('\nКандидат0.0.365', '\n' + text + 'Кандидат0.0.365', 1))
    path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
    current = path.read_text()
    begin, end = current.index('## REFACTOR-03 '), current.index('## REFACTOR-04 ')
    card = current[begin:end].rstrip()
    card += (' Доработка P2 0.0.366 после review5676955759 возвращает legacy namespace настоящего внешнего create; '
        '[профиль366](../../reports/refactor-03/assets-build-review-1/profile.json) и три реальных producer-контроля сохраняют '
        'probe/project/draft, пять фаз и отказы. Head365 не принят, новый366 требует собственного полного gate/CI/review.\n\n')
    path.write_text(current[:begin] + card + current[end:])
    names = ['TESTING.md', 'wiki/articles/project-refactoring.md', 'docs/epics/refactoring-2026-10/TASKS.md']
    rows = [{'path': name, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()} for name in names]
    (REPORT / 'live-documents.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'live_documents': len(rows)}))


if __name__ == '__main__':
    main()
