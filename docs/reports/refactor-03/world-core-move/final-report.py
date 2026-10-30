# -*- coding: utf-8 -*-
"""Retain actual browser cleanup and the finished gates without changing candidate source."""
from pathlib import Path
import json
import shutil

report = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm/docs/reports/refactor-03/world-core-move')
cleanup = json.loads(Path('/private/tmp/refactor03-browser377-stop.json').read_text())
cleanup.update(own_tab_closed=True, closed_tab_id='21', own_server_stop_confirmed=True,
               own_server_exit=143, viewport_reset=True)
(report / 'browser-cleanup.json').write_text(json.dumps(cleanup, ensure_ascii=False, indent=2) + '\n')
shutil.copyfile('/private/tmp/refactor03-browser377-cleanup.py', report / 'browser-cleanup.py')
path = report / 'README.md'
text = path.read_text()
old = ('167 source SHA заморожены перед полными gates. Требуются новые `tools/check_architecture.sh`, '
       '`./run_tests.sh`, normal/F10, `pnpm --dir wiki check`, проверка каталога/браузера и независимое '
       'exact-head review с решением Team Lead. Плановое количество архитектурных проверок —101 suites/1339 cases. '
       'До фактических результатов полный набор и CI нового SHA не заявляются. Root153 всё ещё выше конечного бюджета30.')
new = ('167 source SHA заморожены перед полными gates и остались прежними. '
       '[Фактические gates](gates-01/gate-exits.json): architecture 101 suites /1339 cases, Game53502/0, '
       'normal/F10 по90/0, Wiki145/0. Каталог source/public/dist и точное вложение profile проверены; '
       'браузер показывает0.0.377, актуальный root153, карточку03in_progress и mobile390 без переполнения. '
       'Первый мобильный кадр попал в переход меню и сохранён отдельно; окончательный кадр снят после его завершения. '
       'Своя вкладка21 закрыта, viewport reset, свой сервер23968 завершён143; пользовательский4175 не тронут. '
       'Дальше нужны собственные CI, независимое exact-head review и решение Team Lead. '
       'Root153 всё ещё выше конечного бюджета30, поэтому полная03 не принята.')
assert text.count(old) == 1
path.write_text(text.replace(old, new))
(report / 'final-report-write-attempt01.json').write_text(json.dumps({
    'phase': 'report-only preparation', 'first_stdin_writer_exit': 1,
    'reason': 'stdin source encoding rejection before any statement executed',
    'seal_before_cleanup_exit': 1, 'reason_seal': 'cleanup JSON was not yet created',
    'product_modified': False, 'gates_invalidated': False,
    'repair': 'UTF-8 saved script through the same known Python3.11 runtime',
}, indent=2) + '\n')
shutil.copyfile(__file__, report / 'final-report.py')
print('Actual full gates/browser/cleanup retained; source freeze unchanged')
