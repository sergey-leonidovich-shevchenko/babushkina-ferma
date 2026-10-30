"""Сравнивает полные GD-тела после точного обратного преобразования только адресов/metadata."""
import gzip
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def normalize(text, name, mapping):
    if name == 'tools/preview_portability_capture.gd':
        text = re.sub(r'^const SOURCE_PATHS := \{\n.*?^\}\n', '', text, count=1, flags=re.M | re.S)
        text = text.replace('\tif not _check(manifest.fitter_file == "tools/item_ui_fitter.gd", "unknown fitter source"):\n\t\treturn\n', '')
        text = text.replace('String(SOURCE_PATHS[manifest.fitter_file])', 'manifest.fitter_file')
        text = text.replace('\t\t"source_paths": SOURCE_PATHS,\n', '')
    if name in {'tools/item_sizes_capture.gd', 'tools/padded_atlas_capture.gd', 'tools/visual_sampling_capture.gd'}:
        current = 'FileAccess.get_sha256("res://"+(' + json.dumps(mapping[name]) + ' if path==' + json.dumps(name) + ' else path))'
        text = text.replace(current, 'FileAccess.get_sha256("res://"+path)')
    for old, new in mapping.items():
        text = text.replace('"res://' + new + '"', '"res://' + old + '"')
    return text


def check():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    names = [p for p in mapping if p.endswith('.gd')] + [p for p in baseline['consumers'] if p.endswith('.gd')]
    rows = []
    for name in names:
        target = mapping.get(name, name)
        original = gzip.decompress((REPORT / 'inputs' / (name.replace('/', '--') + '.gz')).read_bytes()).decode()
        current = (ROOT / target).read_text()
        equal = normalize(current, name, mapping) == original
        rows.append({'old_path': name, 'current': target, 'equal_except_declared_paths_and_metadata': equal})
    return rows


if __name__ == '__main__':
    rows = check()
    (REPORT / 'gd-01.json').write_text(json.dumps(rows, indent=2) + '\n')
    assert all(r['equal_except_declared_paths_and_metadata'] for r in rows), rows
    print('GD bodies equal:', len(rows), '(26 moved and2 live consumers)')
