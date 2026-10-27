"""Меняет только source-root перед переносом связанного asset/build семейства."""
import gzip
import hashlib
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    changes = []
    for relative, record in baseline['sources'].items():
        if relative == 'tools/migration_inventory.py':
            continue
        path = ROOT / relative
        original = gzip.decompress((REPORT / 'inputs' / (path.name + '.gz')).read_bytes())
        assert path.read_bytes() == original
        assert hashlib.sha256(original).hexdigest() == record['sha256']
        text = original.decode()
        if 'from common.paths import project_root' not in text:
            assert text.count('from pathlib import Path\n') == 1
            text = text.replace('from pathlib import Path\n',
                                'from pathlib import Path\nfrom common.paths import project_root\n', 1)
        changed = text.replace('Path(__file__).resolve().parents[1]', 'project_root(__file__)')
        changed = changed.replace('Path(__file__).resolve().parent.parent', 'project_root(__file__)')
        assert changed != text
        compile(changed, relative, 'exec')
        path.write_text(changed)
        changes.append({'path': relative, 'before_sha256': record['sha256'],
                        'after_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'mode': record['mode'], 'physically_moved': False})
    assert len(changes) == 15
    (REPORT / 'roots.json').write_text(json.dumps(changes, indent=2) + '\n')
    print('Prepared15 Python roots; no physical moves/GDScript/policy edits')


if __name__ == '__main__':
    main()
