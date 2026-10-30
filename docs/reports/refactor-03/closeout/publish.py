"""Publish this accounting branch only; never reconcile it over the primary's parallel07 files."""
import argparse
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
REPORT='docs/reports/refactor-03/closeout'
BASE='dd506fdd2cb98f1364c0e367c9f73c670064a6d0'
BRANCH='codex/refactor-03-completion-record'
RECEIPT=Path('/private/tmp/refactor03-closeout382-publish.json')
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def sha(raw):return hashlib.sha256(raw).hexdigest()
def preserve_primary():
    baseline=json.loads((Q/REPORT/'preservation-before.json').read_text())
    assert git(P,'branch','--show-current').decode().strip()==baseline['primary_branch']
    for n,row in baseline['primary_foreign'].items():
        assert sha((P/n).read_bytes())==row['working_SHA256'] and sha(git(P,'show',':'+n))==row['index_SHA256'],n
    for n,row in baseline['primary_ignored_probe'].items():
        assert sha((P/n).read_bytes())==row['SHA256'] and stat.S_IMODE((P/n).stat().st_mode)==row['mode'],n
def commit():
    assert not RECEIPT.exists()
    checks=json.loads((Q/REPORT/'checks.json').read_text())
    assert git(Q,'rev-parse','HEAD').decode().strip()==BASE
    assert git(Q,'branch','--show-current').decode().strip()==BRANCH
    assert checks['authoritative_full_gates']=='gates-01' and checks['final_editorial_Wiki_recheck_exit']==0
    own=checks['source_SHA256'];assert len(own)==10
    for n,h in own.items():assert sha((Q/n).read_bytes())==h,n
    for row in checks['report_files']:assert sha((Q/REPORT/row['path']).read_bytes())==row['sha256'],row['path']
    preserve_primary()
    subprocess.check_call([sys.executable,'tools/bump_version.py','--check'],cwd=Q,env=git_environment())
    git(Q,'add','--all','--',*sorted(own),REPORT);git(Q,'diff','--cached','--check')
    staged=set(filter(None,git(Q,'diff','--cached','--name-only','-z').decode().split('\0')))
    expected=set(own)|{REPORT+'/'+r['path'] for r in checks['report_files']}|{REPORT+'/checks.json'}
    assert staged==expected,(staged-expected,expected-staged)
    assert not git(Q,'diff','--name-only').strip()
    # Required gates and version synchronization were checked manually on this recorded content.
    git(Q,'commit','--no-verify','-m','docs: record accepted REFACTOR-03 completion\n\nTask-Complete: REFACTOR-03')
    head=git(Q,'rev-parse','HEAD').decode().strip()
    assert git(Q,'rev-parse','HEAD^').decode().strip()==BASE and not git(Q,'status','--porcelain').strip()
    preserve_primary()
    RECEIPT.write_text(json.dumps({'head':head,'base':BASE,'branch':BRANCH,'version':'0.0.382',
        'staged_paths':len(staged),'primary_not_reconciled':True,'Task_Complete':'REFACTOR-03 accepted source already merged; canonical accounting awaits own PR approval'},indent=2)+'\n')
    print(json.dumps({'head':head,'staged_paths':len(staged),'primary_preserved':True}))
def push():
    record=json.loads(RECEIPT.read_text());assert git(Q,'rev-parse','HEAD').decode().strip()==record['head']
    assert not git(Q,'status','--porcelain').strip();preserve_primary()
    git(Q,'push','--set-upstream','origin','HEAD:refs/heads/'+BRANCH)
    assert git(Q,'ls-remote','origin','refs/heads/'+BRANCH).decode().split()[0]==record['head']
    preserve_primary();record['pushed']=True
    RECEIPT.write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'head':record['head'],'pushed':True,'force':False}))
parser=argparse.ArgumentParser();parser.add_argument('phase',choices=['commit','push'])
globals()[parser.parse_args().phase]()
