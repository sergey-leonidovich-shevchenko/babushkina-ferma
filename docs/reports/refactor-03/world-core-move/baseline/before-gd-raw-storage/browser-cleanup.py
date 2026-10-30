"""Retain browser evidence and stop only this candidate's owned read-only server."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
from PIL import Image

root = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
report = root / 'docs/reports/refactor-03/world-core-move'
pid = 23968
command = subprocess.check_output(['ps', '-p', str(pid), '-o', 'command='], text=True).strip()
cwd = subprocess.check_output(['lsof', '-a', '-p', str(pid), '-d', 'cwd', '-Fn'], text=True)
assert command.endswith('node docs/reports/refactor-03/qa-server.mjs'), command
assert 'n' + str(root) in cwd.splitlines(), cwd
for label in ['article', 'mobile', 'task']:
    source = Path('/private/tmp/refactor03-browser377-' + label + '.json')
    target = report / ('browser-' + label + '.json')
    assert not target.exists()
    shutil.copyfile(source, target)
for label, size in [('desktop', (1280, 900)), ('mobile', (390, 844))]:
    source = Path('/private/tmp/refactor03-browser377-' + label + '.png')
    assert Image.open(source).size == size
    target = report / ('browser-' + label + '.png')
    assert not target.exists()
    shutil.copyfile(source, target)
shutil.copyfile('/private/tmp/refactor03-browser377-mobile-before-transition-settled.png', report / 'browser-mobile-before-transition-settled.png')
os.kill(pid, signal.SIGTERM)
Path('/private/tmp/refactor03-browser377-stop.json').write_text(json.dumps({
    'pid': pid, 'command': command, 'cwd': cwd, 'signal': 'SIGTERM',
    'own_tab_closed': '21', 'viewport_reset': True,
    'user_server4175_untouched': True}, indent=2) + '\n')
print(json.dumps({'own_server_SIGTERM': pid, 'browser_artifacts': 6,
                  'own_tab_closed': '21', 'viewport_reset': True}))
