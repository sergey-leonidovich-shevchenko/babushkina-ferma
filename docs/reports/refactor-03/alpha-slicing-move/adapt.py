"""Разделяет текущую source-копию reader fixtures и неизменяемые логические ключи истории."""
from pathlib import Path
import json

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())


def change(name, old, new):
    path = ROOT / name
    text = path.read_text()
    assert old in text, (name, old)
    path.write_text(text.replace(old, new))


def main():
    prefix = 'tools/assets/'
    change(prefix+'alpha/test_alpha_audit.py', '(self.root/POLICY)', 'current_source(self.root, POLICY)')
    change(prefix+'alpha/test_alpha_audit.py', "file=self.root/'tools/alpha_metrics.py'", "file=current_source(self.root, 'tools/alpha_metrics.py')")
    for name in ['alpha/test_alpha_proof.py', 'slicing/test_slice_proof.py', 'slicing/test_slice_audit.py']:
        change(prefix+name, 'from pathlib import Path', 'from pathlib import Path\nfrom tools.assets.contracts.source_paths import current_source')
    change(prefix+'alpha/test_alpha_proof.py',
        "(self.root/'tools').mkdir();shutil.copyfile(ROOT/'tools/alpha_capture.gd',self.root/'tools/alpha_capture.gd')",
        "target=current_source(self.root, 'tools/alpha_capture.gd');target.parent.mkdir(parents=True)\n"
        "        shutil.copyfile(current_source(ROOT, 'tools/alpha_capture.gd'),target)")
    change(prefix+'alpha/test_alpha_proof.py', "(self.root/'tools/alpha_capture.gd')", "current_source(self.root, 'tools/alpha_capture.gd')")
    change(prefix+'slicing/test_slice_proof.py',
        "for name in ['slice_policy.json','slice_capture.gd','slice_legacy_capture.gd']:shutil.copyfile(ROOT/'tools'/name,self.root/'tools'/name)",
        "for name in ['slice_policy.json','slice_capture.gd','slice_legacy_capture.gd']:\n"
        "            target=current_source(self.root, 'tools/'+name);target.parent.mkdir(parents=True,exist_ok=True)\n"
        "            shutil.copyfile(current_source(ROOT, 'tools/'+name),target)")
    change(prefix+'slicing/test_slice_audit.py',
        "self.data['inputs_sha256']=inputs(self.root)",
        "policy=current_source(self.root, POLICY);policy.parent.mkdir(parents=True,exist_ok=True)\n"
        "        self.data['inputs_sha256']=inputs(self.root)")
    change(prefix+'slicing/test_slice_audit.py', '(self.root/POLICY).write_text', 'policy.write_text')
    name=prefix+'alpha/test_processing_history.py'
    change(name, 'from tools.common.paths import project_root',
        'from tools.common.paths import project_root\nfrom tools.assets.contracts.source_paths import current_source')
    change(name, 'shutil.copyfile(ROOT / name, self.root / name)',
        'target = current_source(self.root, name)\n            target.parent.mkdir(parents=True, exist_ok=True)\n'
        '            shutil.copyfile(current_source(ROOT, name), target)')
    for old, new in [('self.root / name', 'current_source(self.root, name)'), ('code / name', 'current_source(code, name)')]:
        path=ROOT/name;text=path.read_text();assert old in text;path.write_text(text.replace(old,new))
    change(name, "path.write_bytes(b'packaged current bytes: ' + old.encode())", 'path.write_bytes(current_source(ROOT, old).read_bytes())')
    change(name, "code = self.parent / 'no history'", """data = self.parent / 'data with history'
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(ROOT), str(data)],
                       env=git_environment(), check=True, capture_output=True)
        shutil.copytree(self.root, data, dirs_exist_ok=True)
        self.root = data
        for name in NAMES:
            self.assertEqual(digest(subprocess.check_output(
                ['git', '-C', str(data), 'show', COMMIT + ':' + name], env=git_environment())), self.expected[name])
        code = self.parent / 'no history'""")
    change(name, 'даже если данные находятся рядом с настоящей историей', 'даже если data Git действительно содержит D609')
    change(prefix+'slicing/slice_audit.py', 'before=inputs(root)', 'before=inputs(root, source_paths=PACKAGED_EXPORTERS)')
    change(prefix+'slicing/slice_audit.py', "'res://tools/slice_export.gd'", "'res://tools/assets/slicing/slice_export.gd'")
    change(prefix+'slicing/slice_audit.py', 'if before!=inputs(root):', 'if before!=inputs(root, source_paths=PACKAGED_EXPORTERS):')
    change(prefix+'slicing/slice_audit.py', "inventory=read(destination/'inventory.json');inventory['inputs_sha256']=before",
        "inventory=read(destination/'inventory.json')\n    if inventory.get('tool_source_paths')!=PACKAGED_EXPORTERS:raise ValueError('slice exporter paths differ')\n"
        "    inventory['inputs_sha256']=before")
    mapping={'tools/slice_export.gd':'tools/assets/slicing/slice_export.gd',
             'tools/slice_catalogs.gd':'tools/assets/slicing/slice_catalogs.gd'}
    change(prefix+'slicing/slice_export.gd', '"performance_eligible":false,"export_seconds"',
        '"performance_eligible":false,"tool_source_paths":'+json.dumps(mapping,separators=(',',':'))+',"export_seconds"')
    print('Adapted current-tree reader fixtures, real data Git negative and producer metadata; legacy keys/pins unchanged')


if __name__ == '__main__':
    main()
