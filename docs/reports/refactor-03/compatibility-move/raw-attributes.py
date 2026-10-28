"""Preserve only the91 exact native check-only raw logs with Godot's final blank line."""
import gzip,hashlib,json,subprocess
from pathlib import Path
REPORT=Path(__file__).resolve().parent
ROOT=next(p for p in REPORT.parents if(p/'project.godot').is_file())
def main():
 baseline=json.loads((REPORT/'baseline/inventory.json').read_text());base=baseline['base']
 path=ROOT/'.gitattributes';original=subprocess.check_output(['git','-C',str(ROOT),'show',base+':.gitattributes'])
 assert path.read_bytes()==original
 paths=[str(REPORT.relative_to(ROOT))+'/after-%03d.txt'%i for i in range(2,93)]
 path.write_bytes(original+b'# Preserve only these exact native parse raw logs, including Godot\'s final blank line.\n'+''.join(n+' -whitespace\n'for n in paths).encode())
 (REPORT/'raw-whitespace-paths.json').write_text(json.dumps(paths,indent=2)+'\n')
 print(json.dumps({'exact_raw_log_paths':len(paths),'code_exemptions_added':0}))
if __name__=='__main__':main()
