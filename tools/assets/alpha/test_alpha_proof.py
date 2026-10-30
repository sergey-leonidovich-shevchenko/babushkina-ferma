#!/usr/bin/env python3
"""Проверяет сохранённую GPU-матрицу и адресные отказы при порче её копий."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
from PIL import Image
from tools.assets.alpha.alpha_audit import ROOT, REPORT
from tools.assets.alpha.alpha_proof import validate, read


class AlphaProofTests(unittest.TestCase):
    """Изолирует подмену фона, белого цвета и отрицательного контроля от реальных кадров."""

    def setUp(self):
        """Копирует только диагностические файлы и оставляет оригиналы нетронутыми."""
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        shutil.copytree(ROOT/REPORT,self.root/REPORT)
        target=current_source(self.root, 'tools/alpha_capture.gd');target.parent.mkdir(parents=True)
        shutil.copyfile(current_source(ROOT, 'tools/alpha_capture.gd'),target)

    def test_complete_native_matrix(self):
        """Все восемь кадров и числовые контроли проходят вместе."""
        self.assertEqual(validate(self.root),[])

    def test_removed_white_detail_is_not_accepted(self):
        """Белый участок не может исчезнуть под видом очистки matte."""
        path=self.root/REPORT/'native/controls-dark.png'
        with Image.open(path) as source:image=source.copy()
        image.putpixel((163,184),(25,35,43,255));image.save(path)
        self.assertTrue(any('removed or modified' in e for e in validate(self.root)))

    def test_wrong_background_and_missing_case(self):
        """Матрица требует все фоны, правильные пиксели и отдельные файлы каждого случая."""
        path=self.root/REPORT/'native/controls-green.png'
        with Image.open(path) as source:image=source.copy()
        image.putpixel((0,0),(0,0,0,255));image.save(path)
        self.assertTrue(any('background differs' in e for e in validate(self.root)))
        (self.root/REPORT/'native/sources-purple.png').unlink()
        self.assertTrue(validate(self.root))

    def test_fixture_replacement_and_corrupt_provenance(self):
        """Чистая картинка не подменяет отрицательный matte-контроль, происхождение фиксировано."""
        folder=self.root/REPORT/'fixtures';shutil.copyfile(folder/'clean-white-details.png',folder/'white-soft-matte.png')
        self.assertTrue(any('not detected' in e for e in validate(self.root)))
        path=self.root/REPORT/'proof.json';data=read(path);data['runtime_after_sha256']='0'*64;path.write_text(json.dumps(data))
        self.assertTrue(any('source preservation' in e for e in validate(self.root)))

    def test_missing_inventory_and_changed_capture_are_rejected(self):
        """Пустой список хешей и другая реализация съёмки не подменяют комплект доказательств."""
        path=self.root/REPORT/'proof.json';data=read(path);data['files']={};path.write_text(json.dumps(data))
        self.assertTrue(any('file inventory' in e for e in validate(self.root)))
        current_source(self.root, 'tools/alpha_capture.gd').write_text('changed')
        self.assertTrue(any('implementation differs' in e for e in validate(self.root)))


if __name__=='__main__':unittest.main()
