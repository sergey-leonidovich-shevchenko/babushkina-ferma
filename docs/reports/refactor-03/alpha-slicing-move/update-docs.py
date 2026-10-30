"""Обновляет живые команды и evidence-ссылки, не переписывая frozen reports/логические ключи."""
import hashlib
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    mapping = {n: r['target'] for n, r in baseline['assignments'].items()}
    documents = ['QA_CHECKLIST.md', 'TESTING.md', 'docs/DEVELOPMENT.md',
        'docs/epics/visual-overhaul-2026-10/backlog.json', 'docs/epics/visual-overhaul-2026-10/epics/vpipeline.md',
        'wiki/articles/alpha-candidates.md', 'wiki/articles/alpha-edges.md', 'wiki/articles/sprite-slices.md']
    original_backlog = json.loads((ROOT / documents[3]).read_text())
    for name in documents:
        path = ROOT / name
        text = path.read_text()
        for old, new in mapping.items():
            if old.endswith('.py'):
                module = new.removeprefix('tools/').removesuffix('.py').replace('/', '.')
                text = text.replace('python3 ' + old, 'python3 tools/run.py ' + module)
            text = text.replace(old, new)
        path.write_text(text)
    # Evidence-адреса меняются, ID/статусы/зависимости и остальная спецификация сохраняются.
    expected = json.dumps(original_backlog, ensure_ascii=False)
    for old, new in mapping.items(): expected = expected.replace(old, new)
    assert json.loads(expected) == json.loads((ROOT / documents[3]).read_text())
    path = ROOT / 'TESTING.md'
    path.write_text('REFACTOR-03, alpha/slicing0.0.368: `python3 tools/run.py assets.alpha.alpha_audit`, '
        '`python3 tools/run.py assets.slicing.slice_audit` и прежние suites запускаются из canonical пакетов. '
        'Известная source-карта содержит90 назначений; legacy Git/SHA ключи не меняются. '
        'Настоящий after-export сравнивается с5603 before-signatures367; полный набор/gates/CI нового head обязательны. '
        'Raw первого367 отказа сохранён, его единственный точный путь отмечен в .gitattributes.\n\n' + path.read_text())
    path = ROOT / 'tools/README.md'
    text = path.read_text().replace('После полного завершения текущей REFACTOR-03 действует остановка пользователя28.10.2026:06 и другие новые задачи требуют новой прямой команды.',
        'Последняя команда пользователя28.10.2026 отменяет остановку: полная03 →07 →06 → обычный маршрут первой overworld до VMAP-003 по актуальным зависимостям, без дополнительных подтверждений владельца.')
    text = text.replace('# Инструменты проекта\n', '# Инструменты проекта\n\n'
        'Пакет0.0.368 переносит17 alpha/slicing source и2 JSON, сохраняет6 ignored UID; root420→403. '
        'Команды: `python3 tools/run.py assets.alpha.alpha_audit`, `python3 tools/run.py assets.slicing.slice_audit`, '
        '`python3 tools/run.py assets.alpha.alpha_fixtures /private/tmp/alpha-new-controls`. '
        'Нативные скрипты находятся в `res://tools/assets/alpha/` и `res://tools/assets/slicing/`; '
        'исходный namespace самостоятельных внешних стендов не переименовывается. '
        '[Профиль](../docs/reports/refactor-03/alpha-slicing-move/profile.json) проверяет настоящий exporter/публичный report, '
        'пиксели,9 controls, отказ перезаписи и сохранение старых proof. '
        '367 принят промежуточным source review5688074197/Team; это не финальная приёмка03.\n')
    path.write_text(text)
    path = ROOT / 'wiki/articles/project-refactoring.md'
    text = path.read_text().replace('После полного завершения03 — остановка;06 и возвращение к первой overworld требуют новой прямой команды.',
        'Последняя команда отменяет остановку: после полной03 —07,06 и актуальный маршрут первой overworld до VMAP-003.')
    marker='Подготовка0.0.367 alpha/slicing'
    assert marker in text
    paragraph=('Пакет0.0.368 переносит17 alpha/slicing source и2 JSON, сохраняя6 ignored UID: root420→403. '
        '[Профиль после переноса368](../../docs/reports/refactor-03/alpha-slicing-move/profile.json) '
        'сравнивает настоящий новый экспорт с5603 before-signatures367 и9 controls, проверяет публичный report/отказы и foreign CLI. '
        '367 принят промежуточным source review5688074197/Team, его CI дослеживается отдельно; '
        '368 требует собственных обязательных gates и независимого exact-head ревью. '
        '03 in_progress, конечный бюджет≤30 ещё не выполнен.\n\n')
    path.write_text(text.replace(marker, paragraph+marker, 1))
    path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
    text = path.read_text(); start, end = text.index('## REFACTOR-03 '), text.index('## REFACTOR-04 ')
    card=text[start:end].rstrip() + (' Подготовка367 head7dbd5b2c принята промежуточным source review5688074197/Team; '
        'CI367 дослеживается отдельно. Пакет0.0.368 переносит17 source/2 JSON и6 ignored UID alpha/slicing, root403. '
        '[After-профиль](../../reports/refactor-03/alpha-slicing-move/profile.json) сравнивает реальные5603 кадра/9 controls '
        'и публичные сценарии; собственные gates/CI/review нового head обязательны.03 in_progress, финального merge нет.\n\n')
    path.write_text(text[:start]+card+text[end:])
    documents += ['tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']
    (REPORT / 'live-documents.json').write_text(json.dumps([{'path':n,'sha256':hashlib.sha256((ROOT/n).read_bytes()).hexdigest()}
        for n in documents],ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'live_documents':len(documents),'backlog_only_evidence_paths_changed':True,'other_refactor_cards_preserved':True}))


if __name__ == '__main__': main()
