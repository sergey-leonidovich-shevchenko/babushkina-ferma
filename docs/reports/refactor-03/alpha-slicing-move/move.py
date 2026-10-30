"""Перемещает принятую alpha/slicing-группу, не меняя логические Git/policy ключи."""
import ast
import hashlib
import json
from pathlib import Path
import pprint
import runpy
import subprocess

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == baseline['base']
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    for old, new in mapping.items():
        assert hashlib.sha256((ROOT / old).read_bytes()).hexdigest() == baseline['sources'][old]['sha256']
        assert not (ROOT / new).exists()
    path = ROOT / '.gitignore'
    text = path.read_text().replace('# REFACTOR-03: alpha/slicing history preparation, without moving the producer files yet.',
        '# REFACTOR-03: alpha/slicing source and policies; caches/local UID remain ignored.')
    text = text.replace('!tools/assets/alpha/__init__.py\n!tools/assets/alpha/test_processing_history.py',
        '!tools/assets/alpha/*.py\n!tools/assets/alpha/*.gd\n!tools/assets/alpha/*.json\n'
        '!tools/assets/slicing/\ntools/assets/slicing/*\n!tools/assets/slicing/*.py\n'
        '!tools/assets/slicing/*.gd\n!tools/assets/slicing/*.json')
    path.write_text(text)
    attributes = ROOT / '.gitattributes'
    attributes.write_text(attributes.read_text() + '# Preserve the rejected fresh-QA import log, including its final blank line.\n'
        'docs/reports/refactor-03/alpha-slicing-prepare/gates-01/architecture.txt -whitespace\n'
        '# Cancelled CI raw keeps timestamp-only lines and package-manager output verbatim.\n'
        'docs/reports/refactor-03/alpha-slicing-move/baseline/cancelled-linux123020343023.txt -whitespace\n')
    for old, new in mapping.items():
        (ROOT / new).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'mv', '--', old, new], cwd=ROOT, check=True)
    for row in baseline['local_UID']:
        source, target = ROOT / row['old_path'], ROOT / row['target']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == row['sha256'] and not target.exists()
        source.rename(target)
    (ROOT / 'tools/assets/slicing/__init__.py').write_text('"""Диагностика целостности нарезки и её исторические доказательства."""\n')
    imports = runpy.run_path(str(REPORT.parent / 'assets-build-move/move.py'),
                            run_name='accepted_move_helpers')['python_imports']
    for name in [*mapping.values(), 'tools/assets/alpha/test_processing_history.py', 'tools/village_street_verify.py']:
        path = ROOT / name
        if path.suffix == '.py':
            text = imports(path.read_text(), mapping)
            if path.name in {'alpha_audit.py', 'slice_audit.py'}:
                text = text.replace('from tools.common.launch import prepare_imports\n', '')
                text = text.replace('prepare_imports(project_root(__file__))\n', '')
            elif path.name == 'village_street_verify.py':
                text = text.replace('from tools.assets.alpha.alpha_audit import inspect as inspect_alpha',
                    'from common.launch import prepare_imports\nprepare_imports(ROOT)\n'
                    'from tools.assets.alpha.alpha_audit import inspect as inspect_alpha')
            compile(text, name, 'exec')
            path.write_text(text)
        elif path.suffix == '.gd':
            text = path.read_text()
            for old, new in mapping.items():
                text = text.replace('"res://' + old + '"', '"res://' + new + '"')
            path.write_text(text)
    path = ROOT / 'tools/assets/contracts/source_paths.py'
    text = path.read_text()
    node = next(n for n in ast.parse(text).body if isinstance(n, ast.Assign)
        and any(isinstance(t, ast.Name) and t.id == 'MOVED_PATHS' for t in n.targets))
    known = ast.literal_eval(node.value.args[0])
    assert len(known) == 71 and not set(known).intersection(mapping)
    known.update(mapping)
    start = text.index('MOVED_PATHS = MappingProxyType(')
    end = text.index('\n\n', start)
    text = text[:start] + 'MOVED_PATHS = MappingProxyType(' + pprint.pformat(dict(sorted(known.items())), sort_dicts=False) + ')' + text[end:]
    text = text.replace('# Только принятый связанный пакет71; таблица не загружается из проверяемой metadata.',
        '# Принятый пакет71 и связанный перенос alpha/slicing19; metadata не выбирает таблицу.')
    path.write_text(text)
    path = ROOT / 'tools/assets/contracts/test_source_paths.py'
    text = path.read_text().replace('test_table_matches_accepted71_and_actual_files', 'test_table_matches_accepted_plan_and_actual_files')
    text = text.replace("{'assets-contracts', 'assets-migration', 'build'}", "{'assets-contracts', 'assets-migration', 'build', 'assets-alpha', 'assets-slicing'}")
    text = text.replace('self.assertEqual(len(expected), 71)', 'self.assertEqual(len(expected), 90)')
    path.write_text(text)
    path = ROOT / 'tools/quality/check_architecture.sh'
    text = path.read_text()
    for old, new in mapping.items():
        if old.endswith('.py'):
            text = text.replace('python3 ' + old, 'python3 tools/run.py ' + new.removeprefix('tools/').removesuffix('.py').replace('/', '.'))
    path.write_text(text)
    print('Moved17 source/2 JSON/6 ignored UID; known table90; root403; fixture/export adaptation remains')


if __name__ == '__main__':
    main()
