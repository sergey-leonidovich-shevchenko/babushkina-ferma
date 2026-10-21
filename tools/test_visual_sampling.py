#!/usr/bin/env python3
"""Проверяет ошибки фильтрации и доказательств только на собственных копиях файлов."""
import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from visual_resources import ROOT, MANIFEST, parse
from visual_sampling import POLICY, REPORT, validate, verify_capture


class SamplingTests(unittest.TestCase):
    """Изолирует настоящие PNG и профили импорта от повреждений в негативных сценариях."""

    def setUp(self):
        """Копирует runtime-текстуры, импорты и закрытые исходники в независимый проект."""
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup); self.root=Path(self.temp.name)
        self.policy=parse((ROOT/POLICY).read_text()); self.resources=parse((ROOT/MANIFEST).read_text())
        for row in self.resources['textures'].values():
            name=row['file'][6:]; path=self.root/name; path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(ROOT/name,path); shutil.copy2(str(ROOT/name)+'.import',str(path)+'.import')
        for record in self.resources['resources'].values():
            source=record.get('source',{})
            if source.get('kind')=='master':
                target=self.root/source['file']; target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/source['file'],target); (target.parent/'.gdignore').touch()

    def check(self):
        """Сверяет изменённую копию политики с настоящими изображениями и паспортом."""
        return validate(self.root,self.policy,self.resources)

    def test_valid_real_images_and_independent_policy_copy(self):
        """Текущая политика согласована с PNG и явно выбирает linear только для стола и рисованного семейства."""
        self.assertEqual(self.check(),[])
        self.assertEqual(self.resources['resources']['prop.rustic_table']['sampling_family'],'painted_world')
        cloned=copy.deepcopy(self.policy); cloned['families'].clear()
        self.assertEqual(len(self.policy['families']),5)

    def test_duplicate_family_is_rejected(self):
        """Повторный ID нельзя незаметно перезаписать последним профилем JSON."""
        with self.assertRaisesRegex(ValueError,'duplicate JSON key'): parse('{"legacy_ui":{},"legacy_ui":{}}')

    def test_inherited_or_mip_filter_is_not_an_explicit_profile(self):
        """Наследование и неподготовленные mip-режимы не проходят как адресная фильтрация."""
        for value in ['inherit','linear_mipmap',None,3]:
            self.policy['families']['painted_world']['filter']=value
            self.assertTrue(any('filter must be explicit' in e for e in self.check()))

    def test_legacy_protection_cannot_be_switched_globally(self):
        """Смена режима защищённого семейства требует явной ошибки вместо размытия атласов."""
        self.policy['families']['legacy_ui']['filter']='linear'
        self.assertTrue(any('unsafe family mode' in e for e in self.check()))

    def test_invalid_repeat_and_layout_are_rejected(self):
        """Неизвестные повтор, состав полей и вложенные вместо строк значения получают адресный отказ."""
        self.policy['families']['painted_world']['repeat']='enabled'
        self.assertTrue(any('repeat must be disabled' in e for e in self.check()))
        self.policy['families']['painted_world']['layouts']=[{}]
        self.assertTrue(any('invalid layouts' in e for e in self.check()))
        self.policy['families']['painted_world']['unexpected']=True
        self.assertTrue(any('invalid profile' in e for e in self.check()))

    def test_passport_family_and_filter_must_agree(self):
        """Пропущенный профиль и конфликт с прежним полем filter не получают скрытый режим по умолчанию."""
        row=self.resources['resources']['prop.rustic_table']; row['sampling_family']='missing'
        self.assertTrue(any('unknown sampling family' in e for e in self.check()))
        row['sampling_family']='legacy_world'
        self.assertTrue(any('conflicts with family' in e for e in self.check()))

    def test_linear_atlas_is_blocked_until_padding(self):
        """И профиль, и паспорт защищены от линейного чтения соседнего кадра без запаса."""
        self.policy['families']['painted_world']['layouts'].append('atlas')
        self.assertTrue(any('VPIPELINE-004' in e for e in self.check()))
        self.policy['families']['painted_world']['layouts']=['standalone']
        next(iter(self.resources['textures'].values()))['layout']='atlas'
        self.assertTrue(any('rejects texture layout' in e for e in self.check()))

    def test_corrupt_real_png_and_import_are_explicit_errors(self):
        """Новая проверка сохраняет прежний контроль настоящих PNG и параметров импорта."""
        row=next(iter(self.resources['textures'].values())); file=self.root/row['file'][6:]
        file.write_bytes(b'broken png')
        errors=self.check()
        self.assertTrue(any('SHA256 mismatch' in e for e in errors)); self.assertTrue(any('invalid image/import' in e for e in errors))
        shutil.copy2(ROOT/row['file'][6:],file)
        imp=Path(str(file)+'.import'); imp.write_text(imp.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
        self.assertTrue(any('import mismatch' in e for e in self.check()))

    def evidence(self):
        """Копирует исторические нативные данные для проверки намеренной порчи."""
        target=self.root/'evidence'; shutil.copytree(REPORT,target); return target

    def test_saved_native_matrix_is_complete(self):
        """Реальные 14 кадров, камера, защищённые пиксели и адресное отличие проходят вместе."""
        verify_capture(REPORT)

    def test_missing_native_case_and_wrong_camera_are_rejected(self):
        """Удалённый вариант масштаба и несовпадающая камера не считаются корректным сравнением."""
        folder=self.evidence(); path=folder/'native/after/capture.json'; data=parse(path.read_text())
        original=copy.deepcopy(data); data['camera'][0]+=1; path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,'configuration mismatch'): verify_capture(folder)
        original['frames'].pop(); path.write_text(json.dumps(original))
        with self.assertRaisesRegex(ValueError,'incomplete comparison matrix'): verify_capture(folder)

    def test_changed_protected_pixel_is_rejected_even_with_updated_hash(self):
        """Подмена хеша не скрывает размытие или изменение контрольного интерфейса."""
        folder=self.evidence(); name='native/after/samples-0-1_0-painted_world.png'; path=folder/name
        with Image.open(path) as image:
            image=image.convert('RGBA'); image.putpixel((176,520),(255,0,255,255)); image.save(path)
        proof=folder/'native-comparison.json'; data=parse(proof.read_text()); data['images'][name]=hashlib.sha256(path.read_bytes()).hexdigest(); proof.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,'protected font/atlas/clock changed'): verify_capture(folder)


if __name__=='__main__': unittest.main()
