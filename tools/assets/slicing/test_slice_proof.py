#!/usr/bin/env python3
"""Проверяет нативные доказательства на отдельных испорченных копиях."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
from PIL import Image
from tools.assets.slicing.slice_audit import ROOT, REPORT, POLICY, read
from tools.assets.slicing.slice_proof import validate


class SliceProofTests(unittest.TestCase):
    """Отличает настоящий целый кадр от подменённых метрик или выключенного отрицательного контроля."""

    def setUp(self):
        """Копирует только пакет доказательств и не меняет настоящие PNG либо политику."""
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        shutil.copytree(ROOT/REPORT,self.root/REPORT);(self.root/'tools').mkdir()
        for name in ['slice_policy.json','slice_capture.gd','slice_legacy_capture.gd']:
            target=current_source(self.root, 'tools/'+name);target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(current_source(ROOT, 'tools/'+name),target)

    def test_complete_proof(self):
        """Обе нативные серии, контролируемые обрезы и двадцать исправлений проходят вместе."""
        self.assertEqual(validate(self.root),[])

    def test_changed_visible_pixel_fails_even_if_geometry_is_valid(self):
        """Повреждённый пиксель целого подсолнуха не скрывается за прежними source rect и pivot."""
        path=self.root/REPORT/'after-native/game-dark.png'
        with Image.open(path) as source:image=source.copy()
        image.putpixel((192,190),(255,0,0,255));image.save(path)
        self.assertTrue(any('control failed' in e or 'pixels changed' in e for e in validate(self.root)))

    def test_negative_crop_cannot_be_replaced_with_good_image(self):
        """Зелёная целая картинка не заменяет намеренно урезанный контроль."""
        folder=self.root/REPORT/'after-native';shutil.copyfile(folder/'game-dark.png',folder/'clipped-dark.png')
        self.assertTrue(any('control failed' in e for e in validate(self.root)))

    def test_missing_frame_and_wrong_viewport_fail(self):
        """Матрица требует каждый кадр и подлинный размер GPU-readback."""
        folder=self.root/REPORT/'before-native';path=folder/'capture.json';data=read(path);data['framebuffer']=[1920,1080];path.write_text(json.dumps(data))
        self.assertTrue(any('configuration' in e for e in validate(self.root)))
        (folder/'game-light.png').unlink();self.assertTrue(validate(self.root))

    def test_fractional_after_source_is_rejected(self):
        """Старая дробная граница остаётся ошибкой после исправления и не становится разрешённым долгом."""
        path=self.root/REPORT/'after/inventory.json';data=read(path)
        id=next(k for k in data['frames'] if k.startswith('legacy/pirate_enemy/'))
        data['frames'][id]['rect'][0]=0.5;path.write_text(json.dumps(data))
        self.assertTrue(any('integer source rect' in e for e in validate(self.root)))


if __name__=='__main__':unittest.main()
