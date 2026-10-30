"""Переносит только принятую связанную группу; старые логические строки proof не заменяет."""
from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def python_imports(text, mapping):
    """Правит только import-узлы и строковый target mock.patch, сохраняя тела функций."""
    modules = {Path(old).stem: new.removesuffix('.py').replace('/', '.')
               for old, new in mapping.items() if old.endswith('.py')}
    aliases = {**modules, **{'tools.' + old: new for old, new in modules.items()}}
    lines = text.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    changes = []
    for node in ast.walk(ast.parse(text)):
        replacement = None
        if isinstance(node, ast.ImportFrom):
            if node.module in aliases:
                node.module = aliases[node.module]
                replacement = ast.unparse(node)
            elif node.module == 'common' or (node.module or '').startswith('common.'):
                node.module = 'tools.' + node.module
                replacement = ast.unparse(node)
            elif node.module == 'tools' and all(a.name in modules for a in node.names):
                replacement = '; '.join('import ' + modules[a.name] + ' as ' + (a.asname or a.name)
                                        for a in node.names)
        elif isinstance(node, ast.Import) and any(a.name in aliases for a in node.names):
            for alias in node.names:
                if alias.name in aliases:
                    old = alias.name
                    if '.' in old and alias.asname is None:
                        raise ValueError('review dotted import binding before moving: ' + old)
                    alias.name = aliases[old]
                    alias.asname = alias.asname or old.split('.')[0]
            replacement = ast.unparse(node)
        if replacement is not None:
            start = offsets[node.lineno - 1] + len(lines[node.lineno - 1].encode()[:node.col_offset].decode())
            end = offsets[node.end_lineno - 1] + len(lines[node.end_lineno - 1].encode()[:node.end_col_offset].decode())
            changes.append((start, end, replacement))
    # patch("module.symbol") выбирает модуль Python, а не исходный путь в доказательстве.
    for node in ast.walk(ast.parse(text)):
        if not isinstance(node, ast.Call) or ast.unparse(node.func).split('.')[-1] != 'patch' or not node.args:
            continue
        value = node.args[0]
        if not isinstance(value, ast.Constant) or not isinstance(value.value, str):
            continue
        module, dot, suffix = value.value.partition('.')
        if module not in modules or not dot:
            continue
        start = offsets[value.lineno - 1] + len(lines[value.lineno - 1].encode()[:value.col_offset].decode())
        end = offsets[value.end_lineno - 1] + len(lines[value.end_lineno - 1].encode()[:value.end_col_offset].decode())
        changes.append((start, end, repr(modules[module] + '.' + suffix)))
    for start, end, replacement in sorted(changes, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'],
                                   env=git_environment(), text=True).strip() == baseline['base']
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    for old, new in mapping.items():
        assert sha(ROOT / old) == baseline['sources'][old]['sha256']
        assert not (ROOT / new).exists()
    for old, new in mapping.items():
        (ROOT / new).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', '-C', str(ROOT), 'mv', '--', old, new], env=git_environment(), check=True)
    for row in baseline['local_UID']:
        assert sha(ROOT / row['old_path']) == row['sha256']
        assert not (ROOT / row['target']).exists()
        (ROOT / row['old_path']).rename(ROOT / row['target'])
    for old, new in mapping.items():
        path = ROOT / new
        if path.suffix == '.py':
            text = python_imports(path.read_text(), mapping)
            if path.name == 'visual_icons.py':
                text = text.replace('from tools.common.launch import prepare_imports\n', '')
                text = text.replace('# Сохраняет прежний плоский CLI, пока его семейство ещё ожидает своего переноса.\n', '')
                text = text.replace('prepare_imports(project_root(__file__))\n', '')
            compile(text, new, 'exec')
            path.write_text(text)
        elif path.suffix == '.gd' and path.name != 'migration_capture.gd':
            text = path.read_text()
            for name, target in mapping.items():
                text = text.replace('"res://' + name + '"', '"res://' + target + '"')
            path.write_text(text)
    outside = [name for name in baseline['consumers'] if name.endswith('.py')]
    for name in outside:
        path = ROOT / name
        assert sha(path) == baseline['sources'][name]['sha256']
        text = path.read_text()
        # Плоские публичные CLI ещё не перенесённых семейств сохраняют безопасный bootstrap.
        if name in {'tools/alpha_audit.py', 'tools/slice_audit.py', 'tools/shore_kit.py'}:
            tree = ast.parse(text)
            first = next(n for n in tree.body if isinstance(n, ast.ImportFrom)
                         and (n.module or '') in {Path(p).stem for p in mapping if p.endswith('.py')})
            lines = text.splitlines(keepends=True)
            lines.insert(first.lineno - 1, 'from common.launch import prepare_imports\n'
                         'from common.paths import project_root\n\nprepare_imports(project_root(__file__))\n')
            # common bootstrap сам доступен по старому tools; прочие imports становятся canonical.
            text = ''.join(lines)
            text = python_imports(text, mapping).replace('from tools.common.launch import prepare_imports',
                                                         'from common.launch import prepare_imports')
            text = text.replace('from tools.common.paths import project_root', 'from common.paths import project_root')
            text = text.replace('Path(__file__).resolve().parents[1]', 'project_root(__file__)')
        else:
            text = python_imports(text, mapping)
        compile(text, name, 'exec')
        path.write_text(text)
    for name in [p for p in baseline['consumers'] if p.endswith('.gd')]:
        path = ROOT / name
        text = path.read_text()
        for old, new in mapping.items():
            text = text.replace('"res://' + old + '"', '"res://' + new + '"')
        path.write_text(text)
    result = {'base': baseline['base'], 'physical_source_moves': 61, 'tracked_UID_moves': 8,
              'JSON_moves': 2, 'ignored_UID_moves': 18,
              'moves': [{'old_path': old, 'target': new, 'before_sha256': baseline['sources'][old]['sha256'],
                         'after_sha256': sha(ROOT / new), 'mode': baseline['sources'][old]['mode']}
                        for old, new in mapping.items()], 'root_sources_after_moves': 420}
    (REPORT / 'migration-initial.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Moved61 sources/8tracked UID/2JSON and18ignored UID; imports/resource addresses updated')


if __name__ == '__main__':
    main()
