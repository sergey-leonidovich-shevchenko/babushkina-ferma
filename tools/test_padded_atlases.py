#!/usr/bin/env python3
"""Проверяет поля и независимые уровни на отдельных настоящих PNG и намеренно испорченных копиях."""
import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from padded_atlases import ROOT,FOLDER,SOURCE,CATALOG,REPORT,pack,extrude,validate,source_frames,verify_capture
from visual_resources import parse


class PaddedTests(unittest.TestCase):
    """Создаёт маленький настоящий исходный атлас, сохраняя игровые файлы неизменными."""

    def setUp(self):
        """Копирует готовый пакет и его два источника для отрицательных сценариев."""
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup); self.root=Path(self.temp.name)
        for name in [SOURCE,CATALOG]:
            path=self.root/name; path.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/name,path)
        shutil.copytree(ROOT/FOLDER,self.root/FOLDER)
        self.path=self.root/FOLDER/'catalog.json'; self.data=parse(self.path.read_text())

    def save(self):
        """Записывает только собственную изменённую копию паспорта."""
        self.path.write_text(json.dumps(self.data))

    def test_valid_real_package(self):
        """Каждый регион и вся экструзия четырёх страниц совпадают с независимым исходником."""
        self.assertEqual(validate(self.root),[])

    def test_extrusion_preserves_rgba_edges_and_corners(self):
        """Непрозрачный и полупрозрачный углы продолжаются полностью, включая цвет прозрачного пикселя."""
        source=Image.new('RGBA',(2,2)); source.putdata([(255,0,0,255),(0,200,0,128),(0,0,250,0),(230,200,10,255)])
        result=extrude(source,2)
        for y in range(6):
            for x in range(6): self.assertEqual(result.getpixel((x,y)),source.getpixel((max(0,min(1,x-2)),max(0,min(1,y-2)))))

    def test_neighbor_color_never_enters_an_independent_level(self):
        """Зелёный кадр остаётся зелёным на всех уровнях, даже рядом с красным и синим."""
        colors={'a':(255,0,0,255),'b':(0,255,0,255),'c':(0,0,255,255)}
        frames={key:Image.new('RGBA',(64,64),value) for key,value in colors.items()}
        for size in [64,32,16,8]:
            page,entries=pack(frames,size,3,2)
            for key,(x,y,w,h) in entries.items():
                self.assertEqual(set(page.crop((x-2,y-2,x+w+2,y+h+2)).getdata()),{colors[key]})

    def test_deterministic_packing_ignores_dictionary_order(self):
        """Переупорядочивание реестра не меняет пиксели, ID или прямоугольники."""
        frames=source_frames(self.root); a,ar=pack(frames,16,16,2); b,br=pack(dict(reversed(list(frames.items()))),16,16,2)
        self.assertEqual(a.tobytes(),b.tobytes()); self.assertEqual(ar,br)

    def test_corrupt_png_and_hash_are_rejected(self):
        """Повреждённый PNG вызывает явную ошибку, исходная игра остаётся целой."""
        file=self.root/self.data['levels'][0]['file'][6:]; file.write_bytes(b'broken png')
        self.assertTrue(any('invalid padded atlas' in e for e in validate(self.root)))

    def test_wrong_gutter_pixel_is_rejected_even_with_new_hash(self):
        """Обновление SHA256 не скрывает единственный неверный пиксель запаса."""
        row=self.data['levels'][0]; file=self.root/row['file'][6:]
        with Image.open(file) as image:
            image=image.convert('RGBA'); image.putpixel((0,0),(255,0,255,255)); image.save(file)
        row['sha256']=hashlib.sha256(file.read_bytes()).hexdigest(); self.save()
        self.assertTrue(any('pixel mismatch' in e for e in validate(self.root)))

    def test_wrong_frame_rectangle_and_missing_level_are_rejected(self):
        """Неверная область и отсутствие отдельного mip-уровня не считаются готовой упаковкой."""
        key=next(iter(self.data['levels'][0]['entries'])); self.data['levels'][0]['entries'][key][0]+=1; self.data['levels'].pop(); self.save()
        errors=validate(self.root)
        self.assertTrue(any('rectangles differ' in e for e in errors)); self.assertTrue(any('incomplete' in e for e in errors))

    def test_hardware_mips_and_alpha_reprocessing_are_rejected(self):
        """Импорт не может заново смешать кадры либо изменить заранее вычисленный RGBA-край."""
        file=self.root/self.data['levels'][0]['file'][6:]; path=Path(str(file)+'.import')
        path.write_text(path.read_text().replace('mipmaps/generate=false','mipmaps/generate=true').replace('process/fix_alpha_border=false','process/fix_alpha_border=true'))
        errors=validate(self.root)
        self.assertTrue(any('mipmaps/generate' in e for e in errors)); self.assertTrue(any('fix_alpha_border' in e for e in errors))

    def test_stale_source_and_escaped_page_are_rejected(self):
        """Устаревший исходный пакет и путь за каталогом не допускаются автоматически."""
        self.data['source']['sha256']='0'*64; self.data['levels'][0]['file']='res://assets/game/items/ui/padded/../../outside.png'; self.save()
        errors=validate(self.root)
        self.assertTrue(any('stale source' in e for e in errors)); self.assertTrue(any('unsafe page' in e for e in errors))

    def test_duplicate_id_and_outside_source_crop_are_rejected(self):
        """Дублирование JSON-ID и выход исходного кадра за PNG получают отказ до экспорта."""
        with self.assertRaisesRegex(ValueError,'duplicate JSON'): parse('{"bread":{},"bread":{}}')
        source=self.root/CATALOG; data=json.loads(source.read_text()); data['entries']['bread']['cell']=[-1,0]; source.write_text(json.dumps(data))
        self.assertTrue(any('outside source' in e for e in validate(self.root)))

    def test_native_negative_control_and_isolated_reference(self):
        """Настоящие кадры подтверждают отличие небезопасной выборки и точность нового изолированного пути."""
        verify_capture(REPORT)

    def test_tampered_native_pixel_fails_even_with_updated_sha(self):
        """Подмена пикселя готовой страницы в снимке не скрывается новым хешем."""
        folder=self.root/'evidence'; shutil.copytree(REPORT,folder)
        file=folder/'native/light-padded.png'
        with Image.open(file) as image:
            image=image.convert('RGBA'); image.putpixel((750,157),(255,0,0,255)); image.save(file)
        path=folder/'native-comparison.json'; data=parse(path.read_text()); data['frames']['light-padded']=hashlib.sha256(file.read_bytes()).hexdigest(); path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,'differs from isolated'): verify_capture(folder)


if __name__=='__main__': unittest.main()
