"""Фиксирует подготовку03 в её изолированном дереве без параллельного плана07."""
import hashlib
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    path = ROOT / 'TESTING.md'
    paragraph = ('REFACTOR-03, подготовка alpha/slicing0.0.367: `python3 tools/run.py assets.alpha.test_processing_history` '
        'проверяет8 настоящих Git/current-layout случаев. Три collector и два exporter старых proof закреплены за точными D609/SHA; '
        'текущие копии и runtime остаются проверяемыми. Реальные alpha fixtures и slice export сняты до перемещения, '
        '[профиль](docs/reports/refactor-03/alpha-slicing-prepare/profile.json) сохраняет5603 frame signatures и исходный inventory. '
        'Физических переносов пока нет, root420; обязательны новые общие gates и независимое ревью.\n\n')
    path.write_text(paragraph + path.read_text())
    path = ROOT / 'wiki/articles/project-refactoring.md'
    paragraph = ('Подготовка0.0.367 alpha/slicing сохраняет три collector и два exporter через точный Git/SHA старых proof, '
        'а текущий layout связывает с реальными файлами и полной known map. '
        '[Профиль до переноса367](../../docs/reports/refactor-03/alpha-slicing-prepare/profile.json) содержит настоящие alpha fixtures '
        'и5603 frame signatures свежего slice export;8 новых тестов защищают историю/metadata/symlink/GIT-контекст. '
        'Все17 source и2 JSON пока на прежних местах, root420. P2 на482ed19c принят review5683524122/Team и CI8/8; '
        'подготовка367 требует собственного exact-head CI и независимого ревью,03 остаётся in_progress.\n\n')
    current = path.read_text()
    assert '\nДоработка P2 0.0.366' in current
    current = current.replace('**После текущей задачи — остановка:** по прямому указанию пользователя28.10.2026 завершаем REFACTOR-03 в полном принятом объёме и останавливаемся.06, графика и другие новые задачи требуют новой прямой команды.',
        '**Текущая очередь:** последняя прямая команда пользователя28.10.2026 отменяет остановку: полное закрытие REFACTOR-03 → REFACTOR-07 → REFACTOR-06 → обычный маршрут первой overworld до VMAP-003 по актуальным зависимостям. Одновременно ведётся одна задача; у каждой свой PR, фактические проверки, независимое ревью точного head, решение Team Lead, merge и учёт без дополнительных подтверждений владельца. Новые механики/карты и обход ревью не разрешены. Параллельная постановка07 сохраняется отдельно от этого коммита подготовки03.')
    path.write_text(current.replace('\nДоработка P2 0.0.366', '\n' + paragraph + 'Доработка P2 0.0.366', 1))
    path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
    current = path.read_text()
    begin, end = current.index('## REFACTOR-03 '), current.index('## REFACTOR-04 ')
    card = current[begin:end].rstrip()
    card = card.replace('После полного принятия03 действует остановка пользователя28.10.2026.',
        'Последняя команда пользователя28.10.2026 отменяет остановку: полное закрытие03 →07 →06 → обычный маршрут первой overworld до VMAP-003; одновременно одна задача, отдельные PR, независимое exact-head ревью, решение Team Lead, merge и учёт без дополнительных подтверждений владельца.')
    card += (' P2 на482ed19c принят review5683524122/Team и CI8/8. Подготовка0.0.367 alpha/slicing '
        'добавляет5 точных source pins/8 layout-history случаев и8 ROOT/GIT-context адаптаций; '
        '[реальный before-профиль](../../reports/refactor-03/alpha-slicing-prepare/profile.json) сохраняет5603 frame signatures '
        'и alpha fixtures. Физических переносов нет,root420, собственные gates/review нового head обязательны.\n\n')
    path.write_text(current[:begin] + card + current[end:])
    names = ['TESTING.md', 'wiki/articles/project-refactoring.md', 'docs/epics/refactoring-2026-10/TASKS.md']
    (REPORT / 'live-documents.json').write_text(json.dumps([{'path': n, 'sha256': hashlib.sha256((ROOT / n).read_bytes()).hexdigest()}
        for n in names], ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'live_documents': len(names), 'parallel07_excluded': True}))


if __name__ == '__main__':
    main()
