"""Заменяет только физические чтения старых tools-имён, не JSON keys/исторические descriptors."""
import ast
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    files = [p for p in mapping.values() if p.endswith('.py')]
    files += [p for p in baseline['consumers'] if p.endswith('.py')]
    changed = []
    for name in files:
        path = ROOT / name
        text = path.read_text()
        lines = text.splitlines(keepends=True)
        starts = [0]
        for line in lines:
            starts.append(starts[-1] + len(line))
        replacements = []
        for node in ast.walk(ast.parse(text)):
            if (isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div)
                    and isinstance(node.right, ast.Constant) and node.right.value in mapping):
                value = 'current_source(' + ast.unparse(node.left) + ', ' + repr(node.right.value) + ')'
                start = starts[node.lineno - 1] + len(lines[node.lineno - 1].encode()[:node.col_offset].decode())
                end = starts[node.end_lineno - 1] + len(lines[node.end_lineno - 1].encode()[:node.end_col_offset].decode())
                replacements.append((start, end, value))
        if not replacements:
            continue
        for start, end, value in sorted(replacements, reverse=True):
            text = text[:start] + value + text[end:]
        tree = ast.parse(text)
        last = max(n.end_lineno for n in tree.body if isinstance(n, (ast.Import, ast.ImportFrom)))
        lines = text.splitlines(keepends=True)
        lines.insert(last, 'from tools.assets.contracts.source_paths import current_source\n')
        text = ''.join(lines)
        compile(text, name, 'exec')
        path.write_text(text)
        changed.append({'path': name, 'literal_current_reads': len(replacements)})
    (REPORT / 'current-read-adaptations.json').write_text(json.dumps(changed, indent=2) + '\n')
    print('Adapted physical reads in', len(changed), 'modules; logical strings remain unchanged')


if __name__ == '__main__':
    main()
