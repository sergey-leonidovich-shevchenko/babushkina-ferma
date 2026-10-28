"""Переводит живые ссылки365 на повторный профиль, сохраняя первый raw и Git-before SHA."""
import hashlib
import json
from pathlib import Path

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    path = REPORT / 'live-documents.json'
    rows = json.loads(path.read_text())
    old = 'assets-build-move/profile.json'
    updated = []
    for row in rows:
        document = ROOT / row['path']
        text = document.read_text()
        if old in text:
            document.write_text(text.replace(old, 'assets-build-move/profile-02.json'))
            updated.append(row['path'])
        row['after_sha256'] = hashlib.sha256(document.read_bytes()).hexdigest()
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'updated_live_links': updated, 'before_SHA_retained': True}))


if __name__ == '__main__':
    main()
