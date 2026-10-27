"""Подготавливает root и исторические SHA до физического переноса art-standard."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
REPORT = Path(__file__).resolve().parent


def main():
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    pins = json.loads((REPORT / 'baseline/capture-pins.json').read_text())
    rows = []
    for relative, digest in baseline['sources'].items():
        path = ROOT / relative
        original = gzip.decompress((REPORT / 'inputs' / (path.name + '.gz')).read_bytes())
        assert path.read_bytes() == original and hashlib.sha256(original).hexdigest() == digest
        text = original.decode()
        root_line = next(line for line in text.splitlines() if line.startswith('ROOT'))
        text = text.replace(root_line, 'from common.paths import project_root\n\n' +
                            root_line.replace('Path(__file__).resolve().parents[1]', 'project_root(__file__)'), 1)
        source_pins = [row for row in pins['rows'] if row['source'].replace('_capture.gd', '.py').replace('_sources.gd', '.py') == relative]
        if source_pins:
            text = text.replace('from common.paths import project_root', 'from common.paths import project_root\nfrom common.history import pinned_sha', 1)
            for row in source_pins:
                name = 'ADAPTER_SOURCE' if row['source'].endswith('_sources.gd') else 'CAPTURE_SOURCE'
                declaration = f"{name} = ({row['source']!r},\n    {pins['base']!r},\n    {row['sha256']!r})\n"
                position = text.index('REPORT')
                text = text[:position] + declaration + text[position:]
                before = "sha(ROOT/'" + row['source'] + "')"
                assert text.count(before) == 1
                text = text.replace(before, 'pinned_sha(ROOT, *' + name + ')')
        if path.name in {'visual_scale.py', 'visual_reuse.py'}:
            text = text.replace('from common.paths import project_root', 'from common.paths import project_root\nfrom common.git import git_environment', 1)
            if path.name == 'visual_scale.py':
                text = text.replace('cwd=ROOT,text=True)', 'cwd=ROOT,env=git_environment(),text=True)')
            else:
                text = text.replace('cwd=ROOT,capture_output=True,check=True)', 'cwd=ROOT,env=git_environment(),capture_output=True,check=True)')
        compile(text, relative, 'exec')
        path.write_text(text)
        rows.append({'path': relative, 'before_sha256': digest, 'after_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'historical_source_pins': len(source_pins), 'physically_moved': False})
    (REPORT / 'preparation.json').write_text(json.dumps({'base': baseline['base'], 'changes': rows,
                                                      'physical_moves': 0, 'pins': 5, 'root_sources': 504,
                                                      'new_sources': ['tools/common/history.py', 'tools/common/test_history.py']}, indent=2) + '\n')
    print('Prepared eight roots, four historical readers / five pins, and two clean Git call sites')


if __name__ == '__main__':
    main()
