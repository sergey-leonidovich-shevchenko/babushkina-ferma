"""Replay the reviewer's full twelve-row matrix through both actual readers."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import urllib.request

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.qa.foliage import grass_methods as current
spec=importlib.util.spec_from_file_location('parent_matrix381',R/'baseline/grass_methods.py')
parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent)
matrix_path=Path('/private/tmp/pr21-2c85-review/launch-boundary-matrix.json')
shutil.copy2(matrix_path,R/'baseline/reviewer-launch-boundary-matrix.json')
rows=[]
for row in json.loads(matrix_path.read_text()):
    result={**row,'parent_accept':None,'current_accept':None}
    with tempfile.TemporaryDirectory(prefix='review matrix381 ') as directory:
        folder=Path(directory);profile='Codex-VRENDER-002-boundary-matrix'
        (folder/'environment.json').write_text(json.dumps({'exit_code':0,'jobs_after':[],
            'profile':profile,'command':row['command']}))
        (folder/'engine.txt').write_text('metadata fixture; engine not launched\n')
        source={'source_paths':{current.CAPTURE_SOURCE[0]:'tools/qa/foliage/grass_compare/capture.gd'}} if row['layout']=='current' else {}
        for label,module in [('parent_accept',parent),('current_accept',current)]:
            try:module.launch(folder,profile,source)
            except ValueError:result[label]=False
            else:result[label]=True
    assert result['parent_accept']==row['actual_accept'] is True
    assert result['current_accept']==row['expected_accept']
    rows.append(result)
assert len(rows)==12 and sum(r['current_accept'] for r in rows)==4
(R/'reviewer-matrix-replay.json').write_text(json.dumps({'rows':rows,'valid_accepted':4,
    'invalid_rejected':8,'parent_false_accepts':8,'engine_launched':False,
    'current_source_SHA256':hashlib.sha256((Q/'tools/qa/foliage/grass_methods.py').read_bytes()).hexdigest()},indent=2)+'\n')
browser=json.loads(Path('/private/tmp/refactor03-browser381.json').read_text())
href=browser['desktop']['link'][0]['href']
with urllib.request.urlopen(href,timeout=15) as response:
    raw=response.read();status=response.status
assert status==200 and raw==(R/'result.json').read_bytes()
(R/'browser-link-http.json').write_text(json.dumps({'href_observed_from_DOM':href,
    'status':status,'SHA256':hashlib.sha256(raw).hexdigest(),
    'exact_report_bytes':True,'browser_download_claimed':False},indent=2)+'\n')
for name in ['desktop.png','mobile.png','task.png','json']:
    source=Path('/private/tmp/refactor03-browser381'+('.json' if name=='json' else '-'+name))
    shutil.copy2(source,R/('browser.json' if name=='json' else 'browser-'+name))
shutil.copy2(__file__,R/'replay-reviewer-matrix.py')
print(json.dumps({'reviewer_matrix':12,'valid_accepted':4,'invalid_rejected':8,'parent_false_accepts':8,'HTTP':status}))
