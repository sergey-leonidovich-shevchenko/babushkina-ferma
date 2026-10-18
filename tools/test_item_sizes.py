#!/usr/bin/env python3
"""Повреждает отдельные копии двух размеров и нативного доказательства шкафа."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from item_sizes import ROOT,FOLDER,CATALOG,REPORT,read,validate,proof_errors,native_errors,digest


class SizeTests(unittest.TestCase):
    """Проверяет отказы без изменения игровых изображений или пользовательского инвентаря."""

    def setUp(self):
        """Копирует только подготовленные размеры и маленький архив настоящих кадров."""
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        shutil.copytree(ROOT/FOLDER,self.root/FOLDER)
        shutil.copytree(ROOT/REPORT,self.root/REPORT)

    def write_catalog(self,data):
        """Обновляет обе проекции тестовой копии, чтобы ошибка не скрывалась за рассинхронизацией зеркала."""
        value=json.dumps(data,ensure_ascii=False,indent=2)
        (self.root/CATALOG).write_text(value+'\n');(self.root/FOLDER/'catalog.gd').write_text('extends RefCounted\nconst DATA := '+value+'\n')

    def test_valid_current_and_native_packets(self):
        """Живой каталог и историческая нативная пара проходят полную независимую проверку."""
        self.assertEqual(validate(self.root),[]);self.assertEqual(proof_errors(self.root),[])

    def test_sizes_and_projection_mismatch(self):
        """Неверные роли размеров и отставшая Godot-проекция обнаруживаются явно."""
        data=read(self.root/CATALOG);data['large']=64;self.write_catalog(data)
        self.assertTrue(any('64/160' in e for e in validate(self.root)))
        (self.root/FOLDER/'catalog.gd').write_text('const DATA := {}')
        self.assertTrue(any('catalogues differ' in e for e in validate(self.root)))

    def test_wrong_or_overlapping_source_rect(self):
        """Копия не может переадресовать две миниатюры в одну ячейку."""
        data=read(self.root/CATALOG);data['entries']['bread']['cell']=[0,0];self.write_catalog(data)
        self.assertTrue(any('source rect: bread' in e for e in validate(self.root)))

    def test_corrupt_and_resized_preview(self):
        """Повреждённый PNG и растянутая миниатюра другого размера получают отказ."""
        path=self.root/FOLDER/'preview/bread.png';original=path.read_bytes();path.write_bytes(b'broken PNG')
        self.assertTrue(validate(self.root));path.write_bytes(original)
        with Image.open(path) as source:image=source.resize((64,64))
        image.save(path);self.assertTrue(any('independent 160px' in e for e in validate(self.root)))

    def test_cut_alpha_and_empty_preview(self):
        """Срезанный край или пустая картинка не считается целым превью."""
        path=self.root/FOLDER/'preview/bread.png';image=Image.new('RGBA',(160,160));image.putpixel((80,0),(255,255,0,255));image.save(path)
        self.assertTrue(any('preview alpha' in e for e in validate(self.root)))
        image=Image.new('RGBA',(160,160));image.save(path)
        self.assertTrue(any('preview alpha' in e for e in validate(self.root)))

    def test_import_and_missing_fingerprint(self):
        """Непреднамеренный mip и потерянное происхождение источника блокируют пакет."""
        path=self.root/FOLDER/'preview/bread.png.import';path.write_text(path.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
        data=read(self.root/CATALOG);data['entries']['bread']['sourceHash']='';self.write_catalog(data)
        errors=validate(self.root);self.assertTrue(any('wrong import' in e for e in errors));self.assertTrue(any('fingerprint' in e for e in errors))

    def test_master_loading_or_preview_prewarm_is_detected(self):
        """Вызванная открытием загрузка мастера и скрытый прогрев всех превью не принимаются."""
        path=self.root/REPORT/'after/capture.json';data=read(path);data['room']['preview_ids_cached']=['bread'];path.write_text(json.dumps(data))
        self.assertTrue(any('prewarmed' in e for e in native_errors(path.parent,True)))
        data['room']['preview_ids_cached']=[];data['first_frame']['sources']['loaded_paths']=1;path.write_text(json.dumps(data))
        self.assertTrue(any('original source loads' in e for e in native_errors(path.parent,True)))

    def test_warm_reopen_load_and_state_mutation_are_detected(self):
        """Повторная загрузка выбранного превью и изменение игрового сохранения получают отдельные отказы."""
        path=self.root/REPORT/'after/capture.json';data=read(path);data['reopened']['prepared']['preview_load_requests']=2
        data['serialized_after']['coins']=999999;path.write_text(json.dumps(data))
        errors=native_errors(path.parent,True)
        self.assertTrue(any('additional preview load' in e for e in errors));self.assertTrue(any('serialized state' in e for e in errors))

    def test_opaque_rgb_outside_preview_even_with_new_hash(self):
        """Подмена контрольной суммы не скрывает изменение интерфейса за пределами выбранного рисунка."""
        path=self.root/REPORT/'after/cabinet-stable.png'
        with Image.open(path) as source:image=source.copy()
        image.putpixel((200,100),(255,0,0,255));image.save(path)
        p=self.root/REPORT/'proof.json';proof=read(p);proof['files']['after/cabinet-stable.png']=digest(path);p.write_text(json.dumps(proof))
        capture_path=path.parent/'capture.json';capture=read(capture_path);capture['frames']['cabinet-stable']=digest(path);capture_path.write_text(json.dumps(capture))
        self.assertTrue(any('outside selected preview' in e for e in proof_errors(self.root)))


if __name__=='__main__':unittest.main()
