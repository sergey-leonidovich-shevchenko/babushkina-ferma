"""Record actual UI evidence and compare the DOM-observed JSON link without a claimed download."""
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
from PIL import Image

R=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm/docs/reports/refactor-03/closeout')
data=json.loads(Path('/private/tmp/refactor03-browser382.json').read_text())
href=data['desktop']['link'][0]['href']
with urllib.request.urlopen(href,timeout=15) as response:
    raw=response.read();status=response.status
assert status==200 and raw==(R/'completion.json').read_bytes()
for name,size in [('desktop',(1280,900)),('mobile',(390,844)),('task03',(1280,900)),
                  ('epic-before',(1280,900)),('epic',(1280,900)),('task06',(1280,900))]:
    source=Path('/private/tmp/refactor03-browser382-'+name+'.jpg')
    image=Image.open(source);assert image.format=='JPEG' and image.size==size,(name,image.size)
    shutil.copy2(source,R/('browser-'+name+'.jpg'))
shutil.copy2('/private/tmp/refactor03-browser382.json',R/'browser.json')
shutil.copy2('/private/tmp/refactor03-browser382-task06-AX.txt',R/'browser-task06-AX.txt')
(R/'browser-link-http.json').write_text(json.dumps({'href_observed_from_DOM':href,'status':status,
    'SHA256':hashlib.sha256(raw).hexdigest(),'exact_completion_bytes':True,'browser_download_claimed':False},indent=2)+'\n')
assert data['task03']['done'] and data['task03']['date'] and data['task03']['acceptedMerge']
assert data['epicBefore']['stale'] and not data['epic']['stale'] and data['epic']['acceptedGoal']
assert data['task06']['blocked'] and data['task06']['dependencyDoneViaAX'] and data['task06']['next07']
assert data['task06']['ownerConfirmationNotRequired'] and data['task06']['oldStopRemoved']
for label,width in [('desktop',1280),('mobile',390)]:assert data[label]['width']==data[label]['scrollWidth']==width
shutil.copy2(__file__,R/'record-browser.py')
print(json.dumps({'browser':'done/date/PR21, new epic summary and blocked06 after07','screenshots':6,'JSON_HTTP':status,'exact_bytes':True,'horizontal_overflow':False}))
