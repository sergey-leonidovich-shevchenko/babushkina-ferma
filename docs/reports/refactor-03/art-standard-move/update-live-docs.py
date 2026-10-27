"""Обновляет только живые команды/пути; raw и историческую ведомость оставляет прежними."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
REPORT = Path(__file__).resolve().parent


def main():
    rows = json.loads((REPORT / 'baseline/inventory.json').read_text())['moves']
    paths = ['QA_CHECKLIST.md', 'TESTING.md', 'docs/DEVELOPMENT.md',
             'docs/epics/visual-overhaul-2026-10/backlog.json', 'docs/epics/visual-overhaul-2026-10/epics/vart.md']
    changes = []
    for name in paths:
        path = ROOT / name
        before = path.read_bytes()
        text = before.decode()
        for row in rows:
            if row['old_path'].endswith('.py'):
                text = text.replace('python3 ' + row['old_path'], 'python3 tools/run.py qa.art.' + Path(row['old_path']).stem)
            text = text.replace(row['old_path'], row['target'])
        if text == before.decode():
            continue
        snapshot = name.replace('/', '--') + '.gz'
        assert not (REPORT / 'inputs' / snapshot).exists()
        (REPORT / 'inputs' / snapshot).write_bytes(gzip.compress(before, mtime=0))
        path.write_text(text)
        changes.append({'path': name, 'before_sha256': hashlib.sha256(before).hexdigest(),
                        'after_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (REPORT / 'live-documents.json').write_text(json.dumps(changes, indent=2) + '\n')
    print(json.dumps({'live_documents': len(changes), 'historical_reports_and_original_map_not_rewritten': True}))


if __name__ == '__main__':
    main()
