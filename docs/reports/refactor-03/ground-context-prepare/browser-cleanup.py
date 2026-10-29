"""Copy actual browser observations and stop only this packet's own read-only Wiki server."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--pid', required=True, type=int)
p.add_argument('--tab', required=True)
args = p.parse_args()
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
command = subprocess.check_output(['ps', '-p', str(args.pid), '-o', 'command='], text=True).strip()
cwd = subprocess.check_output(['lsof', '-a', '-p', str(args.pid), '-d', 'cwd', '-Fn'], text=True)
assert command.endswith('node docs/reports/refactor-03/qa-server.mjs'), command
assert 'n' + str(Q) in cwd.splitlines(), cwd
for label in ['article', 'mobile', 'task']:
    source = Path('/private/tmp/refactor03-browser378-' + label + '.json')
    assert source.is_file() and not (R / ('browser-' + label + '.json')).exists()
    shutil.copy2(source, R / ('browser-' + label + '.json'))
for label, size in [('desktop', (1280, 900)), ('mobile', (390, 844))]:
    source = Path('/private/tmp/refactor03-browser378-' + label + '.png')
    assert Image.open(source).size == size
    assert not (R / ('browser-' + label + '.png')).exists()
    shutil.copy2(source, R / ('browser-' + label + '.png'))
os.kill(args.pid, signal.SIGTERM)
record = {'pid': args.pid, 'command': command, 'cwd': cwd, 'signal': 'SIGTERM',
    'own_tab_closed': args.tab, 'viewport_reset': True, 'user_server4175_untouched': True,
    'own_server_exit': 'awaiting actual process completion'}
Path('/private/tmp/refactor03-browser378-stop.json').write_text(json.dumps(record, indent=2) + '\n')
shutil.copy2(__file__, R / 'browser-cleanup.py')
print(json.dumps({'own_server_SIGTERM': args.pid, 'copied_artifacts': 5, 'exit': 'not yet confirmed'}))
