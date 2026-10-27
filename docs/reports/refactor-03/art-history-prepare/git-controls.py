"""Исполняет изменённые Git-вызовы scale/reuse; capture явно отвергает /usr/bin/false."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import types
from unittest.mock import patch

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment
REPORT = Path(__file__).resolve().parent


def load(name, path, raw):
    """Исполняет реальные сохранённые байты без замены subprocess или самой функции."""
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(raw, str(path), 'exec'), module.__dict__)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'git-controls.json')
    output = parser.parse_args().output.resolve()
    if output.exists() or output.suffix != '.json' or output.is_relative_to(ROOT / 'assets'):
        parser.error('нужен новый JSON вне assets; существующие данные не перезаписываются')
    result = {'native_capture_accepted': False, 'engine_control': '/usr/bin/false; intentional rejection'}
    with tempfile.TemporaryDirectory(prefix='art producer Git controls ') as temporary:
        parent = Path(temporary).resolve()
        root = parent / 'own clone with spaces'
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(ROOT), str(root)],
                       env=git_environment(), check=True)
        own_head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'],
                                           env=git_environment(), text=True).strip()
        result['expected_own_clone_HEAD'] = own_head
        for relative in ['VERSION', 'project.godot', 'tools/__init__.py',
                         *[str(p.relative_to(ROOT)) for p in (ROOT / 'tools/common').glob('*.py')]]:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, path)
        sys.path.insert(0, str(root / 'tools'))
        modules = {}
        for name in ['scale', 'reuse']:
            relative = 'tools/visual_' + name + '.py'
            target = root / relative
            before = gzip.decompress((REPORT / 'inputs' / (Path(relative).name + '.gz')).read_bytes())
            after = (ROOT / relative).read_bytes()
            target.write_bytes(after)
            modules[name] = {mode: load(mode + '_' + name, target, raw) for mode, raw in [('old', before), ('new', after)]}
        for relative in modules['scale']['new'].SOURCES:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        foreign = parent / 'foreign cwd'
        foreign.mkdir()
        hostile = {'GIT_DIR': str(foreign / 'missing.git'), 'GIT_WORK_TREE': str(foreign),
                   'GIT_INDEX_FILE': str(foreign / 'never-created-index'),
                   'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'core.bare', 'GIT_CONFIG_VALUE_0': 'true',
                   'FARM_GODOT_BIN': '/usr/bin/false'}
        records = []
        with patch.dict(os.environ, hostile):
            environment = dict(os.environ)
            for mode in ['old', 'new']:
                folder = parent / (mode + ' rejected capture')
                try:
                    modules['scale'][mode].capture(folder)
                except (ValueError, subprocess.CalledProcessError) as error:
                    if mode == 'old':
                        assert isinstance(error, subprocess.CalledProcessError)
                        assert not (folder / 'source.json').exists()
                    else:
                        assert isinstance(error, ValueError) and 'Нативная съёмка отклонена' in str(error)
                        source = json.loads((folder / 'source.json').read_text())
                        assert source['base_commit'] == own_head
                        expected = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in modules['scale'][mode].SOURCES}
                        assert source['sources'] == expected and source['silhouettes'] == {}
                        result['own_Git_source_metadata_before_engine_refusal'] = source
                    records.append({'mode': mode, 'error_type': type(error).__name__, 'error': str(error)})
                else:
                    raise AssertionError('a rejected capture was accepted')
            relative = 'tools/visual_scale.py'
            original = gzip.decompress((REPORT / 'inputs/visual_scale.py.gz').read_bytes())
            expected = hashlib.sha256(original).hexdigest()
            for mode in ['old', 'new']:
                try:
                    raw = modules['reuse'][mode].baseline_bytes(root / relative, expected,
                                '832964d4de4a0a0207500dd185039642738874e7')
                except subprocess.CalledProcessError as error:
                    assert mode == 'old'
                    result['legacy_reuse_hostile_Git_rejected'] = str(error)
                else:
                    assert mode == 'new' and raw == original
                    result['prepared_reuse_reads_own_historical_bytes'] = True
            assert dict(os.environ) == environment
        assert not (foreign / 'never-created-index').exists()
        result.update(scale_capture_refusals=records, parent_environment_unchanged=True,
                      foreign_index_not_created=True, actual_Git_call_sites_executed=3)
    assert not parent.exists()
    result['temporary_clone_removed'] = True
    with output.open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('Three actual Git call sites isolated; both capture outcomes are refusals, no native pass')


if __name__ == '__main__':
    main()
