"""Фиксирует прошлые живые документы и добавляет только подготовку364/P3 launcher."""
import gzip
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    for name in ['QA_CHECKLIST.md', 'TESTING.md', 'tools/README.md',
                 'wiki/articles/project-refactoring.md', 'docs/epics/refactoring-2026-10/TASKS.md']:
        target = REPORT / 'inputs' / (name.replace('/', '--') + '.gz')
        assert not target.exists()
        target.write_bytes(gzip.compress((ROOT / name).read_bytes(), mtime=0))

    path = ROOT / 'QA_CHECKLIST.md'
    text = path.read_text()
    before = 'Выполнить `tools/qa/art/visual_reuse.py` и `tools/qa/art/test_visual_reuse.py`'
    assert text.count(before) == 1
    path.write_text(text.replace(before, 'Выполнить `python3 tools/run.py qa.art.visual_reuse` и '
                                '`python3 tools/run.py qa.art.test_visual_reuse`'))

    path = ROOT / 'TESTING.md'
    text = path.read_text()
    path.write_text('REFACTOR-03, подготовка assets/build0.0.364: '
                    '`python3 tools/run.py assets.migration.test_scanner_history` исполняет12 настоящих '
                    'Git-сценариев старого и свежего scanner. Пятнадцать Python-входов получают source-root; '
                    'девять Git-read используют свой root и очищенное окружение. Старый inventory без режима '
                    'сверяется с точным Git/SHA прежнего инструмента, свежий явно отмечает current и SHA реально '
                    'исполняемого файла. Неизвестный режим и недоступная история отклоняются без fallback. '
                    '[Профиль](docs/reports/refactor-03/assets-history-prepare/profile.json) сохраняет16 AST,12 '
                    'foreign CLI, реальный прежний producer и явный отказ capture. Физических переносов/GD/UID/'
                    'policy изменений нет; полные gates и independent exact-head review обязательны.\n\n' + text)

    path = ROOT / 'tools/README.md'
    text = path.read_text()
    position = text.index('\n') + 1
    paragraph = ('\nПодготовка assets/build0.0.364 внутри текущей REFACTOR-03:15 Python source-root,9 '
                 'изолированных Git-read и отдельная граница старого/свежего scanner. '
                 '`python3 tools/run.py assets.migration.test_scanner_history` выполняет12 настоящих контролей. '
                 'Физического переноса ещё нет, текущий root481,03 in_progress; '
                 '[профиль](../docs/reports/refactor-03/assets-history-prepare/profile.json) и старые inventory '
                 'не переподписываются. Пакет363 принят промежуточным review5675903250/Team Lead; '
                 'это не merge всей03.\n')
    path.write_text(text[:position] + paragraph + text[position:])

    path = ROOT / 'wiki/articles/project-refactoring.md'
    text = path.read_text()
    before = 'Кандидат0.0.363 переносит23'
    assert text.count(before) == 1
    text = text.replace(before, 'Пакет0.0.363 head `8579b883` принят промежуточным '
                        '[ревью5675903250](https://github.com/sergey-leonidovich-shevchenko/'
                        'babushkina-ferma/pull/21#pullrequestreview-5675903250) и Team Lead. Он переносит23', 1)
    text = text.replace('Текущий перенос0.0.363 описан выше и требует отдельного exact-head ревью; '
                        'вся03 и VMAP ещё не приняты.',
                        'Промежуточная приёмка363 не завершает всю03 или VMAP.')
    position = text.index('\n\nПакет0.0.363')
    paragraph = ('\n\nКандидат0.0.364 готовит связанное семейство assets/build:15 source-root,9 Git-read '
                 'и явная граница legacy/current scanner. '
                 '[Профиль подготовки](../../docs/reports/refactor-03/assets-history-prepare/profile.json) '
                 'сравнивает16 AST,12 foreign CLI и настоящие12 scanner-контролей. Старый inventory читает '
                 'фиксированный Git/SHA инструмента из code checkout, а не из проверяемого внешнего проекта; '
                 'новый сохраняет SHA текущего файла. Физические исходники/GD/UID/политики ещё не перемещены, '
                 'root481. Подготовка требует собственных полных gates и независимого ревью.')
    path.write_text(text[:position] + paragraph + text[position:])

    path = ROOT / 'docs/epics/refactoring-2026-10/TASKS.md'
    text = path.read_text()
    before = ' После полного принятия03 действует остановка пользователя28.10.2026.'
    assert text.count(before) == 1
    paragraph = (' Пакет363 head `8579b883` принят промежуточным '
                 '[ревью5675903250](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/'
                 'pull/21#pullrequestreview-5675903250) и Team Lead. Кандидат0.0.364 готовит15 source-root/'
                 '9 Git-read и legacy/current scanner без перемещений; '
                 '[профиль](../../reports/refactor-03/assets-history-prepare/profile.json) сохраняет16 AST/'
                 '12 CLI/12 новых контролей, root481. Собственные полные gates/review364 ещё обязательны.')
    path.write_text(text.replace(before, paragraph + before, 1))
    print('Updated only live docs, P3 launcher commands and current03 result')


if __name__ == '__main__':
    main()
