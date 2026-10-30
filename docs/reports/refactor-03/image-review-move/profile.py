"""Проверяет реальные PIL/dev-переносы на временных входах и read-only каталоге."""
import argparse
import ast
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = 'd27f688fa3ec2670a757acd14019f8ae35e0f693'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class Addresses(ast.NodeTransformer):
    def visit_ImportFrom(self, node):
        if node.module == 'tools.common.paths':
            return None
        if node.module == 'tools.dev.art_review.check_art_review':
            node.module = 'check_art_review'
        return node

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
        return self.generic_visit(node)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'profile.json')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or output.suffix != '.json' or output.is_relative_to(ROOT / 'assets'):
        parser.error('нужен новый JSON вне assets; прежние данные не перезаписываются')
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.361'
    migration = json.loads((REPORT / 'migration.json').read_bytes())
    sources = {}
    for row in migration['moves']:
        old = subprocess.check_output(['git', '-C', str(ROOT), 'show', BASE + ':' + row['old_path']], env=git_environment())
        new = (ROOT / row['target']).read_bytes()
        assert old == gzip.decompress((REPORT / 'inputs' / (Path(row['old_path']).name + '.gz')).read_bytes())
        assert sha(old) == row['before_sha256'] and sha(new) == row['after_sha256']
        assert (ROOT / row['target']).stat().st_mode & 0o777 == row['mode']
        assert not (ROOT / row['old_path']).exists()
        if row['old_path'].endswith('.py'):
            assert ast.dump(ast.parse(old), include_attributes=False) == ast.dump(Addresses().visit(ast.parse(new)), include_attributes=False)
            compile(new, row['target'], 'exec')
        elif row['old_path'].endswith('.mjs'):
            assert new == old.replace(b'"../wiki/scripts/', b'"../../../wiki/scripts/')
        else:
            assert new == old
        sources[row['old_path']] = (old, new, row['target'])
    calls = []
    image_results = {}
    with tempfile.TemporaryDirectory(prefix='image review package with spaces ') as temporary:
        parent = Path(temporary)
        foreign = parent / 'foreign cwd'
        (foreign / 'tools').mkdir(parents=True)
        (foreign / 'tools/__init__.py').write_text("raise RuntimeError('foreign tools imported')\n")
        env = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'))
        for mode in ['old', 'new']:
            folder = parent / (mode + ' project')
            support = ['VERSION', 'project.godot', 'tools/run.py', 'tools/__init__.py',
                       'tools/assets/__init__.py', 'tools/assets/authoring/__init__.py',
                       'tools/dev/__init__.py', 'tools/dev/art_review/__init__.py',
                       *[str(p.relative_to(ROOT)) for p in (ROOT / 'tools/common').glob('*.py')]]
            for relative in support:
                target = folder / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            for old, (before, after, new) in sources.items():
                if not old.endswith('.py'):
                    continue
                target = folder / (old if mode == 'old' else new)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(before if mode == 'old' else after)
            data = folder / 'docs/concepts/visual-polish-2026-10-13'
            data.parent.mkdir(parents=True)
            data.symlink_to(ROOT / 'docs/concepts/visual-polish-2026-10-13', target_is_directory=True)
            for stem in ['check_art_review', 'test_art_review']:
                command = ([sys.executable, str(folder / 'tools' / (stem + '.py'))] if mode == 'old'
                           else [sys.executable, str(folder / 'tools/run.py'), 'dev.art_review.' + stem])
                result = subprocess.run(command, cwd=foreign, env=env, capture_output=True, text=True, timeout=90)
                assert result.returncode == 0, result.stdout + result.stderr
                calls.append({'mode': mode, 'command': command, 'exit': result.returncode,
                              'stdout': result.stdout, 'stderr': result.stderr})
            import_line = ('import import_pixabay_assets as m\n' if mode == 'old' else
                           'from tools.assets.authoring import import_pixabay_assets as m\n')
            driver = '''import sys,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
r=Path(__file__).resolve().parent
sys.path[:0]=[str(r),str(r/'tools')]
''' + import_line + '''assert m.OUTPUT == r/'assets/game/items'
m.OUTPUT.mkdir(parents=True)
result={}
for name,size,rect in [('tall',(24,80),(7,3,16,73)),('wide',(96,25),(3,7,90,18)),('small',(12,12),(4,4,7,7))]:
 source=r/(name+'.png');image=Image.new('RGBA',size);ImageDraw.Draw(image).rectangle(rect,fill=(205,91,33,255));image.save(source)
 m.alpha_sprite(source,name+'.png')
 result[name]=hashlib.sha256((m.OUTPUT/(name+'.png')).read_bytes()).hexdigest()
 assert Image.open(m.OUTPUT/(name+'.png')).size==(64,64)
source=r/'key.png';image=Image.new('RGBA',(120,100),(20,30,40,255));ImageDraw.Draw(image).rectangle((24,15,95,84),fill=(198,77,29,255));image.save(source)
m.keyed_crop(source,(0,0,120,100),'keyed.png');result['keyed']=hashlib.sha256((m.OUTPUT/'keyed.png').read_bytes()).hexdigest()
assert Image.open(m.OUTPUT/'keyed.png').size==(64,64)
bad=r/'invalid.png';bad.write_bytes(b'not PNG')
negative=0
for source in [r/'missing.png',bad]:
 try:m.alpha_sprite(source,'rejected.png')
 except (OSError,ValueError):negative+=1
assert negative==2 and not (m.OUTPUT/'rejected.png').exists()
result['rejected']=negative
print(json.dumps(result,sort_keys=True))
'''
            (folder / 'image_driver.py').write_text(driver)
            result = subprocess.run([sys.executable, str(folder / 'image_driver.py')], cwd=foreign, env=env,
                                    capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stderr
            image_results[mode] = json.loads(result.stdout)
        assert image_results['old'] == image_results['new']
    assert not parent.exists()
    node = shutil.which('node')
    assert node
    log = output.with_suffix('.node-server.txt')
    with tempfile.TemporaryDirectory(prefix='art server foreign cwd ') as temporary, log.open('x') as stream:
        command = [node, str(ROOT / 'tools/dev/art_review/art_review_serve.mjs')]
        process = subprocess.Popen(command, cwd=temporary, stdout=stream, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 15
            address = None
            while time.monotonic() < deadline:
                stream.flush()
                match = re.search(r'ART REVIEW: (http://127\.0\.0\.1:\d+)/', log.read_text())
                if match:
                    address = match[1]
                    break
                if process.poll() is not None:
                    raise AssertionError(log.read_text())
                time.sleep(.05)
            assert address
            status = json.load(urllib.request.urlopen(address + '/__wiki/status'))
            assert status['project'] == 'moon-valley-art-review' and status['pid'] == process.pid
            html = urllib.request.urlopen(address + '/').read()
            assert html == (ROOT / 'docs/concepts/visual-polish-2026-10-13/v1/index.html').read_bytes()
            server = {'command': command, 'cwd': temporary, 'pid': process.pid,
                      'project': status['project'], 'served_index_sha256': sha(html), 'actual_address': address}
        finally:
            process.terminate()
            process.wait(timeout=10)
    assert not Path(temporary).exists()
    godot = os.environ['FARM_GODOT_BIN']
    native = []
    for command in [[godot, '--headless', '--editor', '--path', str(ROOT), '--quit'],
                    [godot, '--headless', '--path', str(ROOT), '--check-only', '--script', 'res://tools/dev/art_review/art_review_export.gd']]:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
        assert result.returncode == 0 and 'ERROR:' not in result.stderr, result.stdout + result.stderr
        native.append({'command': command, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
    result = {'head_before': BASE, 'version': '0.0.361', 'source_moves': 5, 'tracked_UID_moves': 1,
              'AST_bytes_and_modes_preserved': True, 'image_results': image_results,
              'old_new_image_hashes_equal': True, 'real_negative_each': 2,
              'art_review_CLI': calls, 'Node_actual_server': server, 'native_parse_only': native,
              'temporary_removed': True, 'exporter_main_and_importer_main_not_called': True,
              'full_task03_accepted': False}
    with output.open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'moves': 5, 'image_cases': 4, 'negative_each': 2, 'review_CLI_calls': len(calls), 'Node_server': True, 'Godot_parse': True}))


if __name__ == '__main__':
    main()
