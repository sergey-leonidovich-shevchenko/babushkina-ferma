"""Проверяет точную границу подготовки364 и прежние логические descriptors/UID."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(ROOT), *arguments], env=git_environment())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    base = baseline['base']
    documents = ['QA_CHECKLIST.md', 'TESTING.md', 'tools/README.md',
                 'wiki/articles/project-refactoring.md', 'docs/epics/refactoring-2026-10/TASKS.md']
    added = ['tools/assets/migration/__init__.py', 'tools/assets/migration/test_scanner_history.py']
    allowed = set(baseline['sources']) | set(documents) | set(added) | {
        '.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
        'tools/quality/check_architecture.sh',
    }
    changed = set(filter(None, git('diff', '--no-renames', base, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    assert allowed == ((changed | untracked) & allowed), allowed - (changed | untracked)
    assert git('show', base + ':AGENTS.md') == (ROOT / 'AGENTS.md').read_bytes()
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_count = sum(p.startswith('tools/') and p.count('/') == 1 and Path(p).suffix in
                     {'.py', '.gd', '.mjs', '.swift', '.sh', '.gdshader'} for p in tracked)
    assert root_count == 481
    old_architecture = git('show', base + ':tools/quality/check_architecture.sh').decode()
    new_architecture = (ROOT / 'tools/quality/check_architecture.sh').read_text()
    assert new_architecture == old_architecture.replace('python3 tools/run.py qa.art.test_current_paths\n',
        'python3 tools/run.py qa.art.test_current_paths\npython3 tools/run.py assets.migration.test_scanner_history\n')
    for name in documents:
        archived = gzip.decompress((REPORT / 'inputs' / (name.replace('/', '--') + '.gz')).read_bytes())
        assert archived == git('show', base + ':' + name)
    old_cards = re.split(r'(?=^## REFACTOR-)', git('show', base + ':' + documents[-1]).decode(), flags=re.M)
    new_cards = re.split(r'(?=^## REFACTOR-)', (ROOT / documents[-1]).read_text(), flags=re.M)
    assert len(old_cards) == len(new_cards)
    assert all(a == b for a, b in zip(old_cards, new_cards) if not a.startswith('## REFACTOR-03 '))
    hold = next(p for p in new_cards if p.startswith('## REFACTOR-06 '))
    assert '**Статус:** blocked' in hold and 'новая прямая команда' in hold
    profile = json.loads((REPORT / 'profile.json').read_text())
    assert profile['version'] == '0.0.364'
    assert len(profile['source_modules']) == 16
    for row in profile['source_modules']:
        assert sha(ROOT / row['path']) == row['after_sha256']
        assert (ROOT / row['path']).stat().st_mode & 0o777 == row['mode']
    mapping = {}
    for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move']:
        mapping.update({r['old_path']: r['target'] for r in
                        json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
    contracts_path = REPORT.parent / 'baseline/source-contracts.json'
    assert sha(contracts_path) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    contracts = json.loads(contracts_path.read_text())
    child = ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body
                                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CHILD' for t in n.targets)))
    fields = 0
    for row in contracts['modules'].values():
        module = mapping.get(row['source'], row['source']).removesuffix('.py').replace('/', '.')
        run = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
                             env=git_environment(), capture_output=True, text=True, timeout=30)
        assert run.returncode == 0 and not run.stderr, (module, run.stderr)
        assert json.loads(run.stdout) == row['fields'], module
        fields += len(row['fields'])
    assert fields == 37
    uid = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        paths = [ROOT / p for p in [row['old_path'], row['target']] if (ROOT / p).is_file()]
        assert len(paths) == 1 and paths[0].read_text().strip() == row['value']
        name = str(paths[0].relative_to(ROOT))
        assert name not in tracked and git('check-ignore', '--', name).strip()
    assert len(uid['local_only_UID']) == 85
    anchor = uid['retained_anchor_local_UID']
    assert sha(ROOT / anchor['path']) == anchor['sha256']
    result = {'base': base, 'version': '0.0.364', 'root_sources': root_count,
              'changed_Python': 16, 'physical_moves': 0, 'historical_fields': fields,
              'all_ignored_UID_preserved': 85, 'anchor_preserved': True,
              'previous86_architecture_suites_preserved': True, 'new_scanner_cases': 12,
              'other_refactor_cards_and06_hold_unchanged': True,
              'old_reports_runtime_artwork_GD_UID_policies_unchanged_by_Git_scope': True,
              'full_task03_accepted': False, 'REFACTOR06_started': False,
              'source_paths': sorted(allowed)}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_count, 'historical_fields': fields, 'ignored_UID': 85, 'sources': len(allowed)}))


if __name__ == '__main__':
    main()
