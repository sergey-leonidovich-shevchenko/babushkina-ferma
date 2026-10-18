#!/usr/bin/env python3
"""Проверяет отказ на повреждённом изображении и нарушенных границах без порчи ресурсов игры."""
import tempfile
import unittest
import json
import hashlib
from pathlib import Path
from PIL import Image
from visual_pipeline import validate, quarantine, editor_textures, verify_evidence


class BoundaryTests(unittest.TestCase):
    """Изолирует каждый положительный и отрицательный сценарий в собственной папке."""

    def setUp(self):
        """Создаёт минимальное дерево мастеров, игрового PNG и сценария загрузки."""
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.policy = {"non_runtime_roots":["docs", "assets/source"], "runtime_roots":["assets/game"], "development_io":[]}
        for folder in ["docs", "assets/source", "assets/game", "scripts"]: (self.root / folder).mkdir(parents=True)
        for folder in self.policy["non_runtime_roots"]: (self.root / folder / ".gdignore").touch()
        Image.new("RGBA",(16,16),(200,150,70,255)).save(self.root / "assets/game/bench.png")
        self.code = self.root / "scripts/example.gd"
        self.code.write_text('const BENCH = preload("res://assets/game/bench.png")\n')
        self.files = ["assets/game/bench.png", "scripts/example.gd"]

    def check(self):
        """Запускает настоящую проверку на минимальном дереве."""
        return validate(self.root,self.policy,self.files)

    def test_valid_runtime_and_raw_sources(self):
        """Корректный PNG импортируется независимо от сохранённого рядом авторами исходника."""
        (self.root / "assets/source/master.png").write_bytes(b"not published yet")
        self.assertEqual(self.check(),[])

    def test_missing_barrier(self):
        """Отсутствующий импортный барьер явно блокирует проверку."""
        (self.root / "docs/.gdignore").unlink()
        self.assertIn("missing .gdignore: docs",self.check())

    def test_corrupt_runtime_copy(self):
        """Повреждение только тестовой копии изображения даёт адресную ошибку."""
        (self.root / "assets/game/bench.png").write_bytes(b"broken image")
        self.assertTrue(any("invalid image: assets/game/bench.png" in e for e in self.check()))

    def test_runtime_hidden_by_accidental_barrier(self):
        """Барьер внутри игрового дерева не может незаметно скрыть живой ресурс."""
        (self.root / "assets/game/.gdignore").touch()
        self.assertTrue(any("runtime hidden" in e for e in self.check()))

    def test_dependency_into_source_and_path_escape(self):
        """Игровая ссылка в исходники или выход за корень не принимаются."""
        for path in ["assets/source/master.png", "../outside.png", "docs/mockup.png"]:
            self.code.write_text(f'var texture = load("res://{path}")')
            self.assertTrue(self.check(),path)

    def test_missing_runtime_dependency(self):
        """Потерянный runtime-файл обнаруживается до импорта движком."""
        (self.root / "assets/game/bench.png").unlink()
        self.assertTrue(any("missing runtime resource" in e for e in self.check()))

    def test_raw_exception_is_not_resource_load_permission(self):
        """Разрешение диагностического ввода-вывода не позволяет загружать источник как ресурс."""
        self.policy["development_io"]=[{"owner":"scripts/example.gd","path":"res://docs/ref.png"}]
        self.code.write_text('var path="res://docs/ref.png"')
        self.assertEqual(self.check(),[])
        self.code.write_text('var image=load("res://docs/ref.png")')
        self.assertTrue(any("non-runtime reference" in e for e in self.check()))
        self.code.write_text("")
        self.assertTrue(any("stale development" in e for e in self.check()))

    def test_local_preview_migration_preserves_bytes_and_refuses_overwrite(self):
        """Локальное превью переносится без потери байтов и не перезаписывает сохранённую копию."""
        source=self.root / "level_preview.png"; source.write_bytes(b"local prototype")
        rows=quarantine(self.root,self.policy,self.files)
        self.assertEqual(len(rows),1); self.assertFalse(source.exists())
        self.assertEqual((self.root / rows[0]["to"]).read_bytes(),b"local prototype")
        source.write_bytes(b"another prototype")
        with self.assertRaisesRegex(ValueError,"refusing overwrite"): quarantine(self.root,self.policy,self.files)
        self.assertTrue(source.exists())
        folder = self.root / "assets/game/tiles"; folder.mkdir()
        tile = folder / "grass_preview.png"; tile.write_bytes(b"local grass preview")
        self.assertEqual(len(quarantine(self.root,self.policy,self.files,True)),1)
        self.assertFalse(tile.exists())

    def test_referenced_or_tracked_preview_is_not_moved(self):
        """Имя превью не даёт права трогать отслеживаемый либо используемый файл."""
        source=self.root / "level_preview.png"; source.write_bytes(b"keep")
        self.assertEqual(quarantine(self.root,self.policy,self.files+[source.name]),[])
        self.code.write_text('const SOURCE="res://level_preview.png"')
        with self.assertRaisesRegex(ValueError,"still referenced"): quarantine(self.root,self.policy,self.files)

    def test_cache_reader_is_explicit_and_rejects_empty_snapshot(self):
        """Диагностический разбор известного формата не выдаёт пустой индекс за успех."""
        path=self.root / "cache"
        path.write_text("header\n::res://assets/game/::123\nbench.png::CompressedTexture2D::123\n")
        self.assertEqual(editor_textures(path),["assets/game/bench.png"])
        path.write_text("new unknown format")
        with self.assertRaises(ValueError): editor_textures(path)

    def test_native_proof_rejects_different_pixels_and_camera(self):
        """Равные размеры и обновлённые хеши не скрывают испорченную картинку или сдвиг камеры."""
        proof={"sha256":{},"decoded_pixel_equal":True,"performance_eligible":False}
        for phase in ["before", "after"]:
            folder=self.root / "native" / phase; folder.mkdir(parents=True)
            Image.new("RGBA",(1152,648),(200,150,70,255)).save(folder / "village.png")
            proof["sha256"][phase]=hashlib.sha256((folder / "village.png").read_bytes()).hexdigest()
            (folder / "capture.json").write_text(json.dumps({"errors":[],"performance_eligible":False,"framebuffer":[1152,648],"camera":[0,348]}))
        meta=self.root / "native-comparison.json"; meta.write_text(json.dumps(proof))
        verify_evidence(self.root)
        path=self.root / "native/after/village.png"
        with Image.open(path) as source: changed=source.copy()
        changed.putpixel((10,10),(100,100,100,255)); changed.save(path)
        proof["sha256"]["after"]=hashlib.sha256(path.read_bytes()).hexdigest(); meta.write_text(json.dumps(proof))
        with self.assertRaisesRegex(ValueError,"pixels changed"): verify_evidence(self.root)
        state=self.root / "native/after/capture.json"; data=json.loads(state.read_text()); data["camera"]=[1,348]; state.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,"camera/configuration mismatch"): verify_evidence(self.root)


if __name__ == "__main__": unittest.main()
