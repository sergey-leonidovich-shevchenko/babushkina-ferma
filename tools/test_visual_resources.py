#!/usr/bin/env python3
"""Проверяет паспорт на отдельных настоящих PNG, не повреждая игровые ресурсы."""
import copy
import hashlib
import json
import tempfile
import unittest
import shutil
from pathlib import Path
from PIL import Image
from visual_resources import ROOT, MANIFEST, REPORT, parse, validate, verify_capture


class ResourceTests(unittest.TestCase):
    """Изолирует негативные сценарии метаданных и импорта от дерева игры."""

    def setUp(self):
        """Создаёт три небольших RGBA, импортные профили и паспорт с честной прозрачной рамкой."""
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.data=parse((ROOT/MANIFEST).read_text())
        for index,texture in enumerate(self.data['textures'].values()):
            path=self.root/f'assets/game/image{index}.png'; path.parent.mkdir(parents=True,exist_ok=True)
            image=Image.new('RGBA',(16,16)); image.paste((180,120,60,255),(2,2,14,14)); image.save(path)
            texture['file']='res://'+path.relative_to(self.root).as_posix(); texture['pixels']=[16,16]
            texture['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            self.write_import(path,texture)
        for record in self.data['resources'].values():
            for view in record['views'].values():
                for variant in view['variants'].values():variant['source_rect']=[2,2,12,12]
            source=record.get('source',{})
            if source.get('kind')=='master':
                target=self.root/source['file'];target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(ROOT/source['file'],target);(target.parent/'.gdignore').touch()

    def write_import(self,path,texture):
        """Записывает минимальный профиль с настоящей связью источника и всеми проверяемыми опциями."""
        text='[deps]\nsource_file="'+texture['file']+'"\n[params]\n'
        text+='\n'.join(k+'='+json.dumps(v) for k,v in texture['import'].items())+'\n'
        Path(str(path)+'.import').write_text(text)

    def check(self):
        """Запускает общий валидатор на текущей тестовой копии."""
        return validate(self.root,self.data)

    def test_valid_real_png_and_manifest(self):
        """Корректные источники, прозрачная рамка, метаданные и импорты проходят вместе."""
        self.assertEqual(self.check(),[])

    def test_rename_preserves_ids_views_and_geometry(self):
        """Смена всех имён PNG требует обновить только таблицу текстур и импортную связь."""
        records=copy.deepcopy(self.data['resources'])
        for index,texture in enumerate(self.data['textures'].values()):
            old=self.root/texture['file'][6:]; target=old.with_name(f'neutral{index}.png')
            old.rename(target); Path(str(old)+'.import').unlink()
            texture['file']='res://'+target.relative_to(self.root).as_posix(); self.write_import(target,texture)
        self.assertEqual(self.check(),[])
        self.assertEqual(self.data['resources'],records)

    def test_corrupt_png_copy(self):
        """Повреждённая копия получает адресный отказ и по контрольной сумме, и по формату."""
        texture=next(iter(self.data['textures'].values()))
        (self.root/texture['file'][6:]).write_bytes(b'broken png')
        errors=self.check()
        self.assertTrue(any('SHA256 mismatch' in e for e in errors))
        self.assertTrue(any('invalid image/import' in e for e in errors))

    def test_crop_outside_or_clipping_alpha(self):
        """Неверная нарезка не проходит даже при неповреждённом PNG."""
        rect=self.data['resources']['prop.rustic_table']['views']['south']['variants']['standard']
        rect['source_rect']=[3,2,11,12]
        self.assertTrue(any('clips visible alpha' in e for e in self.check()))
        rect['source_rect']=[2,2,24,12]
        self.assertTrue(any('outside texture' in e for e in self.check()))

    def test_empty_alpha_frame(self):
        """Нулевая прозрачная рамка не считается рисунком предмета."""
        self.data['resources']['prop.rustic_table']['views']['south']['variants']['standard']['source_rect']=[0,0,1,1]
        self.assertTrue(any('empty alpha frame' in e for e in self.check()))

    def test_dimensions_and_import_profile(self):
        """Ошибочные размеры и непреднамеренные mipmaps обнаруживаются до запуска игры."""
        texture=next(iter(self.data['textures'].values())); texture['pixels']=[32,32]
        texture['import']['mipmaps/generate']=True
        errors=self.check()
        self.assertTrue(any('dimensions mismatch' in e for e in errors))
        self.assertTrue(any('import mismatch: mipmaps/generate' in e for e in errors))

    def test_invalid_geometry_and_prop_rear(self):
        """Бесконечные размеры, опора вне кадра и задний ракурс мебели явно отвергаются."""
        record=self.data['resources']['prop.rustic_table']; record['views']['north']=copy.deepcopy(record['views']['south'])
        record['views']['south']['logical_size']=[float('nan'),72]
        record['views']['south']['pivot']=[2,1]
        record['views']['south']['footprint_size']=[25,48]
        errors=self.check()
        self.assertTrue(any('south/west/east' in e for e in errors))
        self.assertTrue(any('invalid logical_size' in e for e in errors))
        self.assertTrue(any('pivot outside' in e for e in errors))
        self.assertTrue(any('footprint must match' in e for e in errors))

    def test_quality_uses_real_independent_density(self):
        """Второе качество имеет собственный настоящий PNG и общий физический профиль."""
        for key,texture in list(self.data['textures'].items()):
            dense=copy.deepcopy(texture); dense['file']=texture['file'].replace('.png','-dense.png'); dense['pixels']=[32,32]
            path=self.root/dense['file'][6:]
            image=Image.new('RGBA',(32,32)); image.paste((180,120,60,255),(4,4,28,28)); image.save(path)
            dense['sha256']=hashlib.sha256(path.read_bytes()).hexdigest(); self.write_import(path,dense)
            self.data['textures'][key+'_dense']=dense
        for record in self.data['resources'].values():
            for view in record['views'].values():
                key=view['variants']['standard']['texture']; view['variants']['dense']={'texture':key+'_dense','source_rect':[4,4,24,24]}
        self.assertEqual(self.check(),[])
        view=self.data['resources']['prop.rustic_table']['views']['south']
        view['variants']['dense']['source_rect']=[4,4,24,25]
        self.assertTrue(any('quality changes aspect' in e for e in self.check()))
        view['variants']['dense']['logical_size']=[192,144]
        self.assertTrue(any('unexpected variant fields' in e for e in self.check()))

    def test_missing_quality_texture_and_duplicate_id(self):
        """Потерянная ссылка и повтор ключа не могут незаметно подменить ресурс."""
        view=self.data['resources']['prop.rustic_table']['views']['south']; view['variants']['standard']['texture']='missing'
        self.assertTrue(any('missing texture ID' in e for e in self.check()))
        view['variants'].clear()
        self.assertTrue(any('missing default quality' in e for e in self.check()))
        with self.assertRaisesRegex(ValueError,'duplicate JSON key'): parse('{"resources":{"id":{},"id":{}}}')

    def test_master_stays_outside_runtime_and_has_hash(self):
        """Новый мастер хранится отдельно; повреждение исходника или снятие барьера вызывает отказ."""
        folder=self.root/'assets/source'; folder.mkdir(); (folder/'.gdignore').touch()
        image=folder/'master.png'; Image.new('RGBA',(24,24),(180,120,60,255)).save(image)
        source={'kind':'master','file':'assets/source/master.png','sha256':hashlib.sha256(image.read_bytes()).hexdigest()}
        self.data['resources']['prop.rustic_table']['source']=source
        self.assertEqual(self.check(),[])
        source['sha256']='0'*64
        self.assertTrue(any('master SHA256' in e for e in self.check()))
        (folder/'.gdignore').unlink()
        self.assertTrue(any('ignored source tree' in e for e in self.check()))

    def test_runtime_barrier_and_path_escape(self):
        """Путь в закрытое дерево и выход из проекта не принимаются как готовая текстура."""
        (self.root/'assets/game/.gdignore').touch()
        self.assertTrue(any('hidden by .gdignore' in e for e in self.check()))
        next(iter(self.data['textures'].values()))['file']='res://assets/game/../../outside.png'
        self.assertTrue(any('invalid runtime file' in e for e in self.check()))

    def test_filter_and_quality_completeness(self):
        """Неизвестный фильтр и недоступное в соседнем ракурсе качество не принимаются."""
        record=self.data['resources']['prop.rustic_table']; record['filter']='unknown'
        view=record['views']['south']; view['variants']['extra']=copy.deepcopy(view['variants']['standard'])
        errors=self.check()
        self.assertTrue(any('invalid filter' in e for e in errors))
        self.assertTrue(any('inconsistent qualities' in e for e in errors))

    def test_native_evidence_rejects_changed_pixels_and_camera(self):
        """Изменение кадра с обновлённым хешем и сдвиг камеры не проходят как равное сравнение."""
        folder=self.root/'evidence'; shutil.copytree(REPORT/'native',folder/'native')
        proof=parse((REPORT/'native-comparison.json').read_text())
        (folder/'native-comparison.json').write_text(json.dumps(proof))
        verify_capture(folder)
        path=folder/'native/after/gallery.png'
        with Image.open(path) as source: image=source.copy()
        image.putpixel((10,10),(255,0,0,255)); image.save(path)
        proof['frames']['gallery']['sha256']['after']=hashlib.sha256(path.read_bytes()).hexdigest()
        (folder/'native-comparison.json').write_text(json.dumps(proof))
        with self.assertRaisesRegex(ValueError,'pixels changed'): verify_capture(folder)
        state=folder/'native/after/capture.json'; data=parse(state.read_text()); data['camera']=[123,123]; state.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,'camera/configuration'): verify_capture(folder)


if __name__=='__main__': unittest.main()
