"""Записывает явную таблицу текущего пакета из сохранённой принятой карты71."""
import json
from pathlib import Path
import pprint

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
data = json.loads((REPORT / 'baseline/inventory.json').read_text())
mapping = {old: row['target'] for old, row in data['assignments'].items()}
assert len(mapping) == 71
path = ROOT / 'tools/assets/contracts/source_paths.py'
text = path.read_text()
assert text.count('MappingProxyType({})') == 1
path.write_text(text.replace('MappingProxyType({})', 'MappingProxyType(' + pprint.pformat(mapping, width=100, sort_dicts=True) + ')'))
print('Recorded fixed71 aliases; no runtime planning-file dependency')
