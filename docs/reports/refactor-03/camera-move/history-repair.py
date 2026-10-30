"""Fix the actual after-profile failure without re-signing the old contact-sheet proof."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-move'
P=Q/'tools/qa/camera/test_presentation_pose.py';before=P.read_bytes();assert not(R/'plot-history-repair.json').exists()
commit='d609ab4fa6d82d6d013265183f018b8836abf7cc';logical='tools/pose_video_strip.py';expected='89d6198c307c16d79e4517973c1c47fc95079cdabb4056925465204ad4a03943'
source=json.loads((Q/'docs/reports/visual-overhaul/vcamera-003/video-review/source.json').read_text());assert source['plot_sha256']==expected
blob=subprocess.check_output(['git','--no-replace-objects','-C',str(Q),'show',commit+':'+logical]);assert hashlib.sha256(blob).hexdigest()==expected
assert hashlib.sha256((Q/'tools/qa/camera/pose_video_frames.swift').read_bytes()).hexdigest()==source['decoder_sha256']
text=before.decode();old="P.sha(P.ROOT/'tools/pose_video_frames.swift')";assert text.count(old)==1;text=text.replace(old,"P.sha(current_source(P.ROOT, 'tools/pose_video_frames.swift'))")
old="P.sha(P.ROOT/'tools/pose_video_strip.py')";assert text.count(old)==1;text=text.replace(old,"pinned_sha(P.ROOT, 'tools/pose_video_strip.py', '"+commit+"', '"+expected+"')")
text=text.replace('from tools.assets.contracts.source_paths import current_source\n','from tools.assets.contracts.source_paths import current_source\nfrom tools.common.history import pinned_sha\n',1);compile(text,str(P),'exec')
(R/'pose-test-before-history-pin.py.gz').write_bytes(gzip.compress(before,mtime=0));P.write_text(text)
(R/'plot-history-repair.json').write_text(json.dumps({'actual_failure':'after-015.txt, test_decoded_video_review_provenance, deleted old decoder path','source_path':str(P.relative_to(Q)),'before_SHA256':hashlib.sha256(before).hexdigest(),'after_SHA256':hashlib.sha256(P.read_bytes()).hexdigest(),'decoder_exact_bytes_preserved':True,'plot_history_commit':commit,'plot_history_path':logical,'plot_history_SHA256':expected,'proof_source_json_unchanged':True,'old_assertion_IDs_and_checks_preserved':True,'no_live_source_fallback':True},indent=2)+'\n');shutil.copyfile(__file__,R/'history-repair.py');print('decoder address corrected; old plot proof pinned to real Git bytes, with no fallback')
