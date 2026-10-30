"""Сравнивает реальные перемещённые аудио-инструменты с Git-базой в disposable проектах."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave
import numpy as np

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = '5ba619a3f2ce39845b4b71eee34d267ead05201e'
NAMES = ['audio_composer', 'audio_sound_effects', 'audit_audio_assets', 'generate_audio_assets']


class Addresses(ast.NodeTransformer):
    def visit_ImportFrom(self, node):
        if node.module == 'tools.common.paths':
            return None
        if node.module and node.module.startswith('tools.assets.audio.'):
            node.module = node.module.rsplit('.', 1)[-1]
        return node

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
        return self.generic_visit(node)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'profile.json')
    args = parser.parse_args()
    output_path = args.output.resolve()
    if output_path.exists() or output_path.suffix != '.json' or output_path.is_relative_to(ROOT / 'assets'):
        parser.error('нужен новый JSON вне assets; прежние данные не перезаписываются')
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.360'
    originals = {name: git('show', BASE + ':tools/' + name + '.py') for name in NAMES}
    prepared = {name: (ROOT / 'tools/assets/audio' / (name + '.py')).read_bytes() for name in NAMES}
    moves = json.loads((REPORT / 'migration.json').read_bytes())['moves']
    for row in moves:
        path = ROOT / row['target']
        assert not path.is_symlink() and not (ROOT / row['old_path']).exists()
        assert sha(path.read_bytes()) == row['new_sha256']
        assert path.stat().st_mode & 0o777 == row['mode']
    before_policy = json.loads((REPORT / 'inputs/asset-provenance.json').read_bytes())
    current_policy = json.loads((ROOT / 'tools/asset_provenance.json').read_bytes())
    for name in ['generate_audio_assets', 'audio_composer', 'audio_sound_effects']:
        assert current_policy['evidence_history'].pop('tools/' + name + '.py') == {
            'commit': 'd609ab4fa6d82d6d013265183f018b8836abf7cc', 'sha256': sha(originals[name])}
    assert before_policy == current_policy
    for name in NAMES:
        assert ast.dump(ast.parse(originals[name]), include_attributes=False) == ast.dump(Addresses().visit(ast.parse(prepared[name])), include_attributes=False)
        compile(prepared[name], name, 'exec')
    wavs = [*sorted((ROOT / 'assets/game/audio').rglob('*.wav')), ROOT / 'docs/reports/audio_preview.wav', ROOT / 'docs/reports/door_audio_preview.wav']
    protected = {str(path.relative_to(ROOT)): sha(path.read_bytes()) for path in wavs}
    for relative, expected in protected.items():
        assert sha(git('show', BASE + ':' + relative)) == expected
    calls = []
    results = {}
    with tempfile.TemporaryDirectory(prefix='audio move preview with spaces ') as temporary:
        parent = Path(temporary)
        foreign = parent / 'foreign cwd'
        (foreign / 'tools').mkdir(parents=True)
        (foreign / 'tools/__init__.py').write_text("raise RuntimeError('foreign tools imported')\n")
        environment = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'wrong.git'))
        for mode in ['old', 'new']:
            folder = parent / (mode + ' project')
            for relative in ['VERSION', 'project.godot', 'tools/__init__.py', 'tools/run.py',
                             'tools/assets/__init__.py', *[str(p.relative_to(ROOT)) for p in (ROOT / 'tools/common').glob('*.py')], *protected]:
                destination = folder / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)
            if mode == 'new':
                (folder / 'tools/assets/audio').mkdir()
                shutil.copyfile(ROOT / 'tools/assets/audio/__init__.py', folder / 'tools/assets/audio/__init__.py')
            for name in NAMES:
                target = folder / ('tools/' if mode == 'old' else 'tools/assets/audio/') / (name + '.py')
                target.write_bytes(originals[name] if mode == 'old' else prepared[name])
            audit = [sys.executable, str(folder / 'tools/audit_audio_assets.py')] if mode == 'old' else [sys.executable, str(folder / 'tools/run.py'), 'assets.audio.audit_audio_assets']
            def run_case(case):
                result = subprocess.run(audit, cwd=foreign, env=environment, capture_output=True, text=True, timeout=120)
                calls.append({'mode': mode, 'case': case, 'command': audit, 'cwd': str(foreign),
                              'override_keys': ['PYTHONPATH', 'GIT_DIR'], 'exit': result.returncode,
                              'stdout': result.stdout, 'stderr': result.stderr})
                return result
            result = run_case('actual audit CLI, hostile cwd/PYTHONPATH/GIT')
            assert result.returncode == 0, result.stderr
            data = (folder / 'docs/reports/audio_quality_audit.json').read_bytes()
            assert not json.loads(data)['failures']
            results[mode] = {'audit_sha256': sha(data), 'files': len(json.loads(data)['files']), 'checks': json.loads(data)['checks']}
            target = folder / 'assets/game/audio/sfx/ui_focus.wav'
            before = target.read_bytes()
            for damaged in ['invalid header', 'PCM8', 'clipping', 'wrong rate']:
                target.write_bytes(before)
                if damaged == 'invalid header':
                    target.write_bytes(b'not RIFF')
                else:
                    with wave.open(str(target), 'wb') as writer:
                        writer.setnchannels(1)
                        writer.setsampwidth(1 if damaged == 'PCM8' else 2)
                        writer.setframerate(12000 if damaged == 'wrong rate' else 24000)
                        writer.writeframes(bytes([128]) * 240 if damaged == 'PCM8' else (b'\xff\x7f' * 240 if damaged == 'clipping' else b'\0\0' * 240))
                assert run_case(damaged).returncode != 0
            target.write_bytes(before)
            imports = ('import audio_composer as c\nimport audio_sound_effects as s\nimport generate_audio_assets as g\n'
                       if mode == 'old' else
                       'from tools.assets.audio import audio_composer as c, audio_sound_effects as s, generate_audio_assets as g\n')
            probe = imports + '''import hashlib,json,numpy as np
from pathlib import Path
assert c.ROOT == Path(__file__).resolve().parent
assert s.voice is c.voice and g.compose_all is c.compose_all and g.generate_effects is s.generate_effects
samples={i:c.voice(69,.4,i,.15) for i in ['flute','pad','piano','guitar']}
samples['noise']=s.soft_noise(1024,57)
samples['door_open']=s.wooden_door(False)
samples['door_close']=s.wooden_door(True)
result={key:hashlib.sha256(value.tobytes()).hexdigest() for key,value in samples.items()}
c.write_wave(c.ROOT/'probe.wav',s.master_effect(samples['piano'],-24))
result['PCM16']=hashlib.sha256((c.ROOT/'probe.wav').read_bytes()).hexdigest()
try:c.write_wave(c.ROOT/'clipped.wav',np.ones(24))
except AssertionError:result['clipped_export_rejected']=True
else:raise AssertionError('clipped export accepted')
assert not (c.ROOT/'clipped.wav').exists()
print(json.dumps(result,sort_keys=True))
'''
            script = folder / 'sample_probe.py'
            # This fixture-only driver mirrors the accepted launcher's project precedence.
            script.write_text('import sys\nfrom pathlib import Path\nr=Path(__file__).resolve().parent\nsys.path[:0]=[str(r),str(r/"tools")]\n' + probe)
            result = subprocess.run([sys.executable, str(script)], cwd=foreign, env=environment, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stderr
            results[mode]['samples'] = json.loads(result.stdout)
        assert results['old'] == results['new'], results
    assert not parent.exists()
    assert all(sha((ROOT / name).read_bytes()) == value for name, value in protected.items())
    assert all((ROOT / 'tools/assets/audio' / (name + '.py')).read_bytes() == value for name, value in prepared.items())
    output = {'deployed_package_profile': True, 'head_before': BASE, 'version': '0.0.360',
              'python': sys.version, 'numpy': np.__version__, 'three_pins_only_policy_change': True,
              'AST_algorithms_preserved': True, 'sources': {name: {'old': sha(originals[name]), 'prepared': sha(prepared[name])} for name in NAMES},
              'old_new_equal': results, 'CLI_calls': calls, 'original_WAV_unchanged': protected,
              'temporary_removed': True, 'full_task03_accepted': False}
    with output_path.open('x') as stream:
        stream.write(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'old_new_equal': True, 'files': results['new']['files'], 'checks': results['new']['checks'], 'protected_WAV': len(protected), 'negative_CLI_each': 4, 'PCM_and_sample_hashes_equal': True}))


if __name__ == '__main__':
    main()
