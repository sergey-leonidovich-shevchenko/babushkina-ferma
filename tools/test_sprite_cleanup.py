"""Проверяет защиту динамических ресурсов на изолированной партии, без игровых слотов."""
import hashlib
import tempfile
import unittest
from pathlib import Path
from check_sprite_cleanup import validate


class SpriteCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.asset = self.root/"assets/unused.png"; self.asset.parent.mkdir(); self.asset.write_bytes(b"fixture sprite")
        self.name = "assets/unused.png"
        self.manifest = {"removed":[{"path":self.name,"bytes":self.asset.stat().st_size,"sha256":hashlib.sha256(self.asset.read_bytes()).hexdigest()}]}

    def tearDown(self):
        self.temp.cleanup()

    def test_unreferenced_exact_file_can_be_reviewed(self):
        self.assertEqual(validate(self.root,self.manifest,{}, {},"before"),[])

    def test_dynamic_loading_and_editor_entries_are_protected(self):
        for key in ["loaded","editor","dynamic"]:
            with self.subTest(key=key):
                errors = validate(self.root,self.manifest,{key:[self.name]}, {},"before")
                self.assertIn("live_dynamic:"+self.name,errors)

    def test_legacy_pose_and_parent_atlas_are_protected(self):
        for key in ["texture","atlas"]:
            usage={"poses":{"legacy direction 2":{key:"res://"+self.name}}}
            self.assertIn("live_dynamic:"+self.name,validate(self.root,self.manifest,usage,{},"before"))

    def test_literal_path_and_relative_basename_are_protected(self):
        for text in ['load("res://assets/unused.png")','path="unused.png"']:
            errors=validate(self.root,self.manifest,{}, {"scripts/consumer.gd":text},"before")
            self.assertTrue(any(x.startswith("reference:") for x in errors))

    def test_formatted_runtime_test_and_wiki_paths_are_protected(self):
        cases = [
            ("tests/suites/buildings_suite.gd", 'Image.load_from_file("res://assets/%s.png" % kind)'),
            ("scripts/consumer.gd", 'var path="res://assets/{kind}.png".format(data)'),
            ("wiki/export.py", 'path=f"assets/{kind}.png"'),
            ("wiki/src/consumer.ts", 'const path=`assets/${kind}.png`'),
        ]
        for source,text in cases:
            with self.subTest(source=source):
                self.assertIn("formatted_reference:"+source+":"+self.name,validate(self.root,self.manifest,{}, {source:text},"before"))

    def test_format_patterns_keep_fixed_prefix_suffix_and_directory(self):
        self.manifest["removed"][0]["path"]="assets/frames/pose_07_idle.png"
        source="scripts/consumer.gd"
        for pattern,expected in [("frames/pose_%02d_idle.png",True),("other/pose_%02d_idle.png",False),("frames/pose_%02d_attack.png",False)]:
            errors=validate(self.root,self.manifest,{}, {source:'load("res://assets/'+pattern+'")'},"after")
            self.assertEqual(any(x.startswith("formatted_reference:") for x in errors),expected)

    def test_replacement_after_review_is_rejected(self):
        self.asset.write_bytes(b"new sprite")
        self.assertIn("changed_file:"+self.name,validate(self.root,self.manifest,{}, {},"before"))

    def test_reserved_preview_and_legacy_asset_must_remain_available(self):
        for key in ["reserved_test_previews","reserved_legacy_png"]:
            with self.subTest(key=key):
                manifest={"removed":[],key:[{"path":self.name}]}
                self.assertEqual(validate(self.root,manifest,{}, {},"after"),[])
                self.asset.unlink()
                self.assertIn("required_missing:"+self.name,validate(self.root,manifest,{}, {},"after"))
                self.asset.write_bytes(b"fixture sprite")
                manifest["removed"]=self.manifest["removed"]
                self.assertIn("live_dynamic:"+self.name,validate(self.root,manifest,{}, {},"before"))

    def test_traversal_and_symlinks_cannot_escape_assets(self):
        self.manifest["removed"][0]["path"]="assets/../../outside.png"
        self.assertTrue(any(x.startswith("unsafe_path:") for x in validate(self.root,self.manifest,{}, {},"before")))
        self.manifest["removed"][0]["path"]=self.name
        self.asset.unlink(); self.asset.symlink_to(self.root/"outside.png")
        self.assertTrue(any(x.startswith("unsafe_path:") for x in validate(self.root,self.manifest,{}, {},"before")))

    def test_removal_is_complete_only_without_import_sidecar(self):
        self.asset.unlink(); sidecar=Path(str(self.asset)+".import"); sidecar.write_text("source_file self-reference")
        self.assertIn("retired_file_returned:"+self.name,validate(self.root,self.manifest,{}, {},"after"))
        sidecar.unlink(); self.assertEqual(validate(self.root,self.manifest,{}, {},"after"),[])

    def test_regenerated_retired_file_and_duplicate_entries_fail(self):
        self.assertIn("retired_file_returned:"+self.name,validate(self.root,self.manifest,{}, {},"after"))
        self.manifest["removed"].append(self.manifest["removed"][0].copy())
        self.assertIn("duplicate:"+self.name,validate(self.root,self.manifest,{}, {},"before"))


if __name__ == "__main__":
    unittest.main()
