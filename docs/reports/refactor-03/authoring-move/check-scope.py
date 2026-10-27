"""Сверяет реальный перенос с Git и не позволяет переписать старые доказательства."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
PREPARED = '0352c5f286dc90c5fa324347b9ceadeb6a8e9350'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def main():
    """Проверяет полный принятый снимок, published prepare и все локальные UID."""
    baseline = json.loads(gzip.decompress((REPORT.parent / 'baseline/blobs.json.gz').read_bytes()))
    migration = json.loads((REPORT / 'migration.json').read_bytes())
    moves = {row['old_path']: row['target'] for row in migration['moves']}
    live = {
        '.gitignore', 'TESTING.md', 'VERSION', 'project.godot',
        'Бабушкина ферма.app/Contents/Info.plist', 'docs/DEVELOPMENT.md',
        'docs/epics/refactoring-2026-10/README.md', 'docs/epics/refactoring-2026-10/TASKS.md',
        'tools/README.md', 'tools/asset_report.py', 'tools/asset_provenance.json',
        'tools/quality/check_architecture.sh', 'wiki/articles/project-refactoring.md',
        'wiki/articles/visual-pilot.md',
    }
    # index.json changed only in published prepare, not in this move.
    prepared_changes = set(git('diff', '--name-only', '-z', baseline['base'], PREPARED).decode().split('\0')) - {''}
    checked = 0
    for name, entry in baseline['files'].items():
        if name in live or name in moves or name in prepared_changes:
            continue
        path = ROOT / name
        assert path.is_file() and blob(path.read_bytes()) == entry['blob'], name
        # Git records executable status, not local read/write permission bits.
        assert bool(path.stat().st_mode & 0o111) == (entry['mode'] == '100755'), name
        checked += 1
    old_reports = 0
    for line in git('ls-tree', '-rz', PREPARED, 'docs/reports').split(b'\0'):
        if not line:
            continue
        metadata, encoded = line.split(b'\t')
        mode, kind, expected = metadata.decode().split()
        name = encoded.decode()
        path = ROOT / name
        assert kind == 'blob' and blob(path.read_bytes()) == expected, name
        assert bool(path.stat().st_mode & 0o111) == (mode == '100755'), name
        old_reports += 1
    local = json.loads((REPORT.parent / 'baseline/local-uids.json').read_bytes())
    relocated = {row['old_path']: row['target'] for row in migration['local_ignored_UID']}
    for row in local['local_only_UID']:
        name = relocated.get(row['old_path'], row['old_path'])
        assert (ROOT / name).read_text().strip() == row['value'], name
        assert subprocess.run(['git', '-C', str(ROOT), 'check-ignore', '-q', name], env=git_environment()).returncode == 0, name
        assert not git('ls-files', '--', name).strip(), name
    anchor = local['retained_anchor_local_UID']
    assert (ROOT / anchor['path']).read_text().strip() == anchor['value']
    old_policy = json.loads(git('show', PREPARED + ':tools/asset_provenance.json'))
    current_policy = json.loads((ROOT / 'tools/asset_provenance.json').read_bytes())
    pins = current_policy.pop('evidence_history')
    assert old_policy == current_policy and len(pins) == 2
    for name, pin in pins.items():
        assert pin['commit'] == baseline['base']
        assert hashlib.sha256(git('show', pin['commit'] + ':' + name)).hexdigest() == pin['sha256']
    trees = [ast.parse(raw) for raw in (git('show', PREPARED + ':tools/asset_report.py'), (ROOT / 'tools/asset_report.py').read_bytes())]
    functions = [{node.name: ast.dump(node, include_attributes=False) for node in tree.body if isinstance(node, ast.FunctionDef)} for tree in trees]
    for name, old in functions[0].items():
        if name != 'current_inventory':
            assert functions[1][name] == old, name
    old_tasks = git('show', PREPARED + ':docs/epics/refactoring-2026-10/TASKS.md').decode()
    current_tasks = (ROOT / 'docs/epics/refactoring-2026-10/TASKS.md').read_text()
    def other_tasks(text):
        return text.split('## REFACTOR-03 —')[0] + text.split('## REFACTOR-04 —')[1]
    assert other_tasks(old_tasks) == other_tasks(current_tasks)
    # The accepted budget covers tracked sources, excluding ignored local probes/runtime.
    root_sources = [name for name in git('ls-files', 'tools/').decode().splitlines()
                    if Path(name).parent == Path('tools')
                    and Path(name).suffix in {'.py', '.gd', '.sh', '.mjs', '.swift'}]
    assert len(root_sources) == 513
    changed = set(git('diff', '--name-only', '-z', PREPARED).decode().split('\0')) - {''}
    new_files = {'tools/assets/__init__.py', 'tools/assets/authoring/__init__.py',
                 'tools/build/__init__.py', 'tools/build/test_asset_report_history.py'}
    assert changed <= live | set(moves) | set(moves.values()) | new_files, sorted(changed - live - set(moves) - set(moves.values()) - new_files)
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.358'
    result = {'base': baseline['base'], 'prepared': PREPARED, 'version': '0.0.358',
              'unchanged_accepted_files': checked, 'all_published_report_blobs_preserved': old_reports,
              'local_ignored_UID_preserved': len(local['local_only_UID']), 'retained_anchor_UID_preserved': True,
              'root_tools_sources': len(root_sources), 'moves': len(moves), 'historical_pins_verified': len(pins),
              'old_provenance_rules_and_algorithms_preserved': True, 'other_refactor_cards_unchanged': True,
              'Task_Complete_added': False, 'full_task03_accepted': False, 'changed_existing_paths': sorted(changed)}
    with (REPORT / 'scope.json').open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ['unchanged_accepted_files', 'all_published_report_blobs_preserved', 'root_tools_sources', 'moves']}))


if __name__ == '__main__':
    main()
