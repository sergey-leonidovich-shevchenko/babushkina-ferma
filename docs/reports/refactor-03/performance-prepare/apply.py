"""Apply the bounded performance context preparation after its real before profile."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

REPORT = Path(__file__).resolve().parent
ROOT = next(parent for parent in REPORT.parents if (parent / 'project.godot').is_file())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    plan = json.loads((REPORT / 'baseline/adaptation-plan.json').read_text())
    assert (REPORT / 'before-profile.json').is_file()
    assert (REPORT / 'before-isolated-smoke.json').is_file()
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == baseline['base']
    for name, row in baseline['sources'].items():
        assert digest(ROOT / name) == row['sha256'], name
    for name, row in plan['changes'].items():
        assert (ROOT / name).read_text() == row['before'], name
        (ROOT / name).write_text(row['after'])
    directory = ROOT / 'tools/qa/performance'
    assert not (directory / '__init__.py').exists()
    assert not (directory / 'test_performance_context.py').exists()
    directory.mkdir(parents=True, exist_ok=True)
    (directory / '__init__.py').write_text('"""Проверки производительности и контекста их инструментов."""\n')
    shutil.copyfile(REPORT / 'baseline/performance-context-test.py', directory / 'test_performance_context.py')
    path = ROOT / '.gitignore'
    path.write_text(path.read_text() + '\n# REFACTOR-03: performance preparation only; the legacy producer files have not moved.\n'
        '!tools/qa/performance/\ntools/qa/performance/*\n!tools/qa/performance/__init__.py\n'
        '!tools/qa/performance/test_performance_context.py\n')
    path = ROOT / 'tools/quality/check_architecture.sh'
    source = path.read_text()
    marker = 'python3 tools/run.py qa.compatibility.test_compatibility_cli\n'
    assert source.count(marker) == 1
    path.write_text(source.replace(marker, marker + 'python3 tools/run.py qa.performance.test_performance_context\n'))
    summary = (
        'Подготовка0.0.370 performance исправляет8 source-root sites,9 Git-read sites и2 публичных shell-root. '
        'Пять настоящих context-тестов проверяют чужие cwd/GIT/index/config: до правки4fail/1error, '
        'после требуется5/0 на неизменном test source. Shell smoke в этих тестах использует только fake-engine свидетель argv/cwd. '
        'Физических переносов/UID-перемещений нет, root314. '
    )
    path = ROOT / 'tools/README.md'
    path.write_text(path.read_text().replace('# Инструменты проекта\n', '# Инструменты проекта\n\n' + summary +
        'Команда: `python3 tools/run.py qa.performance.test_performance_context`. '
        '[Профиль подготовки](../docs/reports/refactor-03/performance-prepare/after-profile.json) '
        'сравнивает реальные CLI/неизменные данные,14 собственных headless SIGKILL checkpoints и smoke180; '
        'старые native FPS-данные лишь перепроверяются offline, новый GPU/FPS-допуск не заявляется. '
        'Пакет369 headc6f323d8 принят review5690215352/Team и CI8/8; всей03 это не завершает.\n', 1))
    path = ROOT / 'wiki/articles/project-refactoring.md'
    source = path.read_text()
    marker = 'Пакет0.0.369 переносит89'
    assert source.count(marker) == 1
    paragraph = summary + '[Профиль подготовки370](../../docs/reports/refactor-03/performance-prepare/after-profile.json) '
    paragraph += ('сохраняет реальные before/after CLI,14 isolated save workers и smoke180. '
        'Исторические показатели и бюджеты не ослабляются; новый FPS-допуск не заявлен. '
        '369 headc6f323d8 принят независимым review5690215352/Team и CI8/8. '
        '370 требует собственных gates/CI/review;03in_progress, финального merge нет.\n\n')
    path.write_text(source.replace(marker, paragraph + marker, 1))
    path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
    source = path.read_text()
    start, end = source.index('## REFACTOR-03 '), source.index('## REFACTOR-04 ')
    section = source[start:end].rstrip() + ' ' + paragraph.replace('../../docs/reports/', '../../reports/') + '\n'
    path.write_text(source[:start] + section + source[end:])
    for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md']:
        path = ROOT / name
        prefix = ('REFACTOR-03 performance0.0.370: `python3 tools/run.py qa.performance.test_performance_context` '
            'проверяет5 реальных Git/CLI случаев без игрового окна. Source-root и Git-контекст привязаны к коду/явному project; '
            'shell-входы сохраняют args/stdout/exit, worker/gate budgets и все прежние тесты. '
            'Before/after CLI и14 headless save checkpoints/smoke180 — в performance-prepare; '
            'полные architecture/Game/Wiki и независимое ревью нового SHA обязательны. '
            'Пока ничего не переносится, root314,03in_progress.\n\n')
        path.write_text(prefix + path.read_text())
    subprocess.run(['python3', 'tools/run.py', 'planning.bump_version', '--set', '0.0.370'], cwd=ROOT, check=True)
    print(json.dumps({'source_files_changed': len(plan['changes']), 'source_root_sites': 8,
        'Git_read_sites': 9, 'shell_roots': 2, 'new_real_cases': 5, 'root_sources': 314, 'moves': 0}))


if __name__ == '__main__':
    main()
