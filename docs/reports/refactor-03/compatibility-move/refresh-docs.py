"""Repair only the live article policy/counter; retain the exact full-gate source tree."""
import gzip,hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT=ROOT/'docs/reports/refactor-03/compatibility-move'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
freeze=json.loads((REPORT/'source-freeze.json').read_text())
assert all(sha(ROOT/n)==h for n,h in freeze['source_SHA256'].items())
assert all(r['exit']==0 for r in json.loads((REPORT/'gates-02/gate-exits.json').read_text()))
p=ROOT/'wiki/articles/project-refactoring.md';raw=p.read_bytes()
(REPORT/'post-gates02-article.md.gz').write_bytes(gzip.compress(raw,mtime=0))
(REPORT/'source-freeze.json').rename(REPORT/'source-freeze-after-gates02.json')
s=raw.decode();old='В текущем кандидате корень tools составляет481 исходник';assert s.count(old)==1;s=s.replace(old,'В текущем кандидате корень tools составляет314 исходников')
old='По актуальному указанию28.10.2026 после полного завершения03 останавливаемся;06 требует новой прямой команды.';assert s.count(old)==1;s=s.replace(old,'По последней прямой команде пользователя после полной приёмки03 продолжаем07 →06 → обычный маршрут первой overworld до VMAP-003 без дополнительных подтверждений владельца.')
p.write_text(s);current={n:sha(ROOT/n)for n in freeze['source_SHA256']};changed=[n for n,h in current.items()if freeze['source_SHA256'][n]!=h];assert changed==['wiki/articles/project-refactoring.md']
delta={'changed_source_paths':changed,'before_article_sha256':freeze['source_SHA256'][str(p.relative_to(ROOT))],'after_article_sha256':sha(p),'before_article_gzip_SHA256':sha(REPORT/'post-gates02-article.md.gz'),'all_runtime_tool_test_UID_version_paths_unchanged':True,'unchanged_paths':177,'new_Game_run_claimed':False,'required_refresh':['documentation','wiki','browser']}
(REPORT/'docs-refresh.json').write_text(json.dumps(delta,ensure_ascii=False,indent=2)+'\n')
freeze['source_SHA256']=current;(REPORT/'source-freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2)+'\n')
for source,target in [('/private/tmp/refactor03-move369.py','move.py'),('/private/tmp/refactor03-seal369.py','seal.py'),('/private/tmp/refactor03-catalog369.mjs','catalog-check.mjs'),('/private/tmp/refactor03-readme369.md','README.md'),(__file__,'refresh-docs.py'),('/private/tmp/refactor369-browser-rejected01.json','browser-rejected-01.json')]:shutil.copyfile(source,REPORT/target)
(REPORT/'browser-rejected-01.txt.gz').write_bytes(gzip.compress(Path('/private/tmp/refactor369-browser-rejected01.txt').read_bytes(),mtime=0))
print(json.dumps(delta))
