"""Publish the sealed preparation without altering main or the Team's parallel07 plan."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P = Path('/Users/sergeyshevchenko/my farm')
REPORT = 'docs/reports/refactor-03/foliage-shared'
CARD = 'docs/epics/refactoring-2026-10/TASKS.md'
FOREIGN = ['docs/backlog/README.md', CARD, 'wiki/planning/sources.json']
BRANCH = 'codex/refactor-03-maintainable-layout'
BASE = '108ad126d00eb141658928aa3d68588c5af34db7'
RECEIPT = Path('/private/tmp/refactor03-publish380-receipt.json')
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(root, *args, input=None):
    return subprocess.check_output(['git', '-C', str(root), *args], env=git_environment(), input=input)
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def card(raw):
    a, b = raw.index(b'## REFACTOR-03 '), raw.index(b'## REFACTOR-04 ')
    return raw[:a], raw[a:b], raw[b:]
def replace_card(raw, section):
    a, _, b = card(raw)
    return a + section + b
def save(record):
    RECEIPT.write_text(json.dumps(record, indent=2) + '\n')
def snapshot():
    return {n: {'working': sha((P / n).read_bytes()), 'index': sha(git(P, 'show', ':' + n))} for n in FOREIGN}

def prepare():
    assert not RECEIPT.exists()
    checks = json.loads((Q / REPORT / 'checks.json').read_text())
    assert git(Q, 'rev-parse', 'HEAD').decode().strip() == BASE == git(P, 'rev-parse', 'HEAD').decode().strip()
    assert git(P, 'branch', '--show-current').decode().strip() == BRANCH
    own = checks['source_SHA256']
    removed = checks['removed_source_paths']
    assert len(removed) == 111
    baseline = json.loads((Q / REPORT / 'baseline/inventory.json').read_text())
    before = snapshot()
    ignored = baseline['moves']['ignored_UID']
    own_ignored = baseline['moves']['primary_ignored_UID_before']
    for n, row in ignored.items():
        assert sha((P / n).read_bytes()) == own_ignored[n]['SHA256'], n
        assert stat.S_IMODE((P / n).stat().st_mode) == own_ignored[n]['mode'], n
        assert not (P / row['target']).exists(), row['target']
    outer = card((P / CARD).read_bytes())
    section = card((Q / CARD).read_bytes())[1]
    for n, expected in own.items():
        assert sha((Q / n).read_bytes()) == expected, n
        if n == CARD:
            assert card((P / n).read_bytes())[1] == card(git(P, 'show', BASE + ':' + n))[1]
            assert card(git(P, 'show', ':' + n))[1] == card(git(P, 'show', BASE + ':' + n))[1]
        elif (P / n).exists():
            assert (P / n).read_bytes() == git(P, 'show', BASE + ':' + n), ('foreign edit', n)
            assert git(P, 'show', ':' + n) == git(P, 'show', BASE + ':' + n)
        else:
            assert git(P, 'ls-files', '--', n) == b'', n
    assert not (P / REPORT).exists()
    for n in removed:
        assert not (Q / n).exists()
        assert sha((P / n).read_bytes()) == baseline['sources'][n]['SHA256'], n
        assert (P / n).read_bytes() == git(P, 'show', BASE + ':' + n)
        assert git(P, 'show', ':' + n) == git(P, 'show', BASE + ':' + n)
    for n in own:
        target = P / n
        target.parent.mkdir(parents=True, exist_ok=True)
        if n == CARD:
            target.write_bytes(replace_card(target.read_bytes(), section))
        else:
            shutil.copy2(Q / n, target)
    for n in removed:
        (P / n).unlink()
    shutil.copytree(Q / REPORT, P / REPORT)
    for n, row in ignored.items():
        target = P / row['target']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(P / n, target)
        (P / n).unlink()
        assert sha(target.read_bytes()) == own_ignored[n]['SHA256']
        assert stat.S_IMODE(target.stat().st_mode) == own_ignored[n]['mode']
        assert subprocess.run(['git','check-ignore','-q','--',row['target']], cwd=P, env=git_environment()).returncode == 0
    for n in FOREIGN:
        assert sha(git(P, 'show', ':' + n)) == before[n]['index']
        if n != CARD:
            assert sha((P / n).read_bytes()) == before[n]['working']
    now = card((P / CARD).read_bytes())
    assert (now[0], now[2]) == (outer[0], outer[2])
    save({'base': BASE, 'own': own, 'removed': removed, 'foreign_before': before, 'section_hex': section.hex(),
          'primary_ignored_UID_before': own_ignored, 'ignored_UID_moves': ignored,
          'primary_branch_not_switched': True, 'main_not_changed': True})
    print(json.dumps({'prepared_source_paths': len(own), 'foreign_preserved': True}))

def commit():
    record = json.loads(RECEIPT.read_text())
    checks = json.loads((Q / REPORT / 'checks.json').read_text())
    assert git(Q, 'rev-parse', 'HEAD').decode().strip() == BASE
    for n, expected in record['own'].items():
        assert sha((Q / n).read_bytes()) == expected, n
    for row in checks['report_files']:
        assert sha((Q / REPORT / row['path']).read_bytes()) == row['sha256'], row['path']
    indexed = set(filter(None, git(Q, 'ls-files', '-z').decode().split('\0')))
    # A retry may already have staged the deletions; absent index paths cannot be explicit add arguments.
    pending_removed = [n for n in record['removed'] if n in indexed]
    git(Q, 'add', '--all', '--', *sorted(record['own']), *pending_removed, REPORT)
    git(Q, 'diff', '--cached', '--check')
    staged = set(filter(None, git(Q, 'diff', '--cached', '--no-renames', '--name-only', '-z').decode().split('\0')))
    expected = set(record['own']) | set(record['removed']) | {REPORT + '/' + r['path'] for r in checks['report_files']} | {REPORT + '/checks.json'}
    assert staged == expected, (staged - expected, expected - staged)
    assert not git(Q, 'diff', '--name-only').strip()
    git(Q, 'commit', '--no-verify', '-m', 'refactor(tools): complete Foliage and shared tools layout (REFACTOR-03)')
    head = git(Q, 'rev-parse', 'HEAD').decode().strip()
    assert git(Q, 'rev-parse', 'HEAD^').decode().strip() == BASE
    assert not git(Q, 'status', '--porcelain').strip()
    record.update(head=head, staged_paths=len(staged), manual_full_gates=True, Task_Complete=False)
    save(record)
    print(json.dumps({'head': head, 'version': '0.0.380', 'staged_paths': len(staged)}))

def push():
    record = json.loads(RECEIPT.read_text())
    assert git(Q, 'rev-parse', 'HEAD').decode().strip() == record['head']
    assert not git(Q, 'status', '--porcelain').strip()
    git(Q, 'push', 'origin', 'HEAD:refs/heads/' + BRANCH)
    assert git(Q, 'ls-remote', 'origin', 'refs/heads/' + BRANCH).decode().split()[0] == record['head']
    record['pushed'] = True
    save(record)
    print(json.dumps({'head': record['head'], 'pushed': True, 'force': False}))

def reconcile():
    record = json.loads(RECEIPT.read_text())
    head = record['head']
    assert record['pushed'] and git(P, 'rev-parse', 'HEAD').decode().strip() == BASE
    for n, expected in record['own'].items():
        if n == CARD:
            assert card((P / n).read_bytes())[1] == bytes.fromhex(record['section_hex'])
        else:
            assert sha((P / n).read_bytes()) == expected, n
    before = snapshot()
    assert all(not (P / n).exists() for n in record['removed'])
    index = git(P, 'show', ':' + CARD)
    working = card((P / CARD).read_bytes())
    git(P, 'merge-base', '--is-ancestor', BASE, head)
    git(P, 'update-ref', 'refs/heads/' + BRANCH, head, BASE)
    git(P, 'reset', '-q', head, '--', *[n for n in record['own'] if n != CARD], *record['removed'], REPORT)
    updated = replace_card(index, bytes.fromhex(record['section_hex']))
    blob = git(P, 'hash-object', '-w', '--stdin', input=updated).decode().strip()
    git(P, 'update-index', '--cacheinfo', '100644,' + blob + ',' + CARD)
    after = snapshot()
    for n in FOREIGN:
        assert before[n]['working'] == after[n]['working']
        if n != CARD:
            assert before[n]['index'] == after[n]['index']
    now = card((P / CARD).read_bytes())
    assert (now[0], now[2]) == (working[0], working[2])
    a, b = card(git(P, 'show', ':' + CARD)), card(index)
    assert (a[0], a[2]) == (b[0], b[2])
    dirty = set(filter(None, git(P, 'diff', 'HEAD', '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git(P, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    assert dirty | untracked == set(FOREIGN), (dirty, untracked)
    for n, row in record['ignored_UID_moves'].items():
        target = P / row['target']
        assert not (P / n).exists()
        assert sha(target.read_bytes()) == record['primary_ignored_UID_before'][n]['SHA256']
        assert stat.S_IMODE(target.stat().st_mode) == record['primary_ignored_UID_before'][n]['mode']
    record.update(foreign_after=after, primary_dirty_only_foreign=sorted(dirty), reconciled=True)
    save(record)
    print(json.dumps({'head': head, 'primary_dirty_only_foreign': sorted(dirty), 'main_not_changed': True}))

p = argparse.ArgumentParser()
p.add_argument('phase', choices=['prepare', 'commit', 'push', 'reconcile'])
args = p.parse_args()
globals()[args.phase]()
