#!/usr/bin/env python3
"""Отрицательные сценарии стоимости, неизвестного происхождения и реально экспортированного payload."""
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
import wave
import zipfile
from PIL import Image
from tools.assets.contracts.asset_costs import measure, names, origin, rgba_bytes, sha, summarize
from tools.build.asset_pack import inspect_pack, preset_errors, create, proof_errors
from tools.assets.contracts.asset_report import ROOT, REPORT, csv_bytes, current_errors
from tools.assets.contracts.source_paths import current_source


def png(size=(7,3)):
    """Создаёт маленький независимый источник без чтения или изменения production."""
    out=io.BytesIO();Image.new('RGBA',size,(20,90,160,0)).save(out,format='PNG');return out.getvalue()


class CostTests(unittest.TestCase):
    """Проверяет физические размеры, mip-цепочки, отсутствие ложного разрешения и экспортные отказы."""
    def test_rectangular_mips_and_limit(self):
        """Полоса 8×1 доходит до 1×1, ограничение уровней не округляет оценку коэффициентом 4/3."""
        self.assertEqual(rgba_bytes(8,1,True),60);self.assertEqual(rgba_bytes(8,1,True,1),48)
        self.assertEqual(rgba_bytes(3,5,True),72)

    def test_png_size_is_not_decoded_memory(self):
        """Сжатые байты и номинальная память RGBA8 остаются разными величинами."""
        row=measure('a.png',png((100,100)),b'mipmaps/generate=false\n')
        self.assertEqual(row['texture_rgba8_bytes'],40000);self.assertLess(row['disk_bytes'],40000)
        self.assertIsNone(row['alpha_bounds'])

    def test_corrupt_image_fails(self):
        """Испорченный заголовок PNG не превращается в нулевой успешный отчёт."""
        with self.assertRaises(Exception):measure('broken.png',b'not a png')

    def test_import_duplicate_and_size_limit(self):
        """Неоднозначный импорт отклоняется; при resize оценка не угадывается по исходному размеру."""
        with self.assertRaises(ValueError):measure('a.png',png(),b'mipmaps/generate=true\nmipmaps/generate=false\n')
        self.assertIsNone(measure('a.png',png(),b'process/size_limit=2\n')['texture_rgba8_bytes'])

    def test_scope_includes_root_images_and_excludes_nested_archives(self):
        """Название master не прячет живой лист; корневые title/icon учитываются; барьер закрывает поддерево."""
        files=['assets/game/hero_master.png','assets/title_art_rpg.png','assets/game/source/.gdignore','assets/game/source/a.png','assets/source/a.png']
        self.assertEqual(names(files,{'non_runtime_roots':['assets/source']}),['assets/game/hero_master.png','assets/title_art_rpg.png'])

    def test_unknown_is_never_approved(self):
        """Само присутствие в Git не доказывает автора и право распространения."""
        row=origin('assets/game/unknown.png',png(),{'rules':[]},lambda _:b'')
        self.assertEqual(row['kind'],'unresolved');self.assertFalse(row['release_clearance'])

    def test_legacy_debt_does_not_authorize_new_unknown_art(self):
        """Прежний адресный долг проходит; изменённый и новый неизвестный рисунок требуют своего источника."""
        old={'files':{'a.png':{'sha256':'old','origin':{'kind':'unresolved'}}}}
        self.assertEqual(current_errors(old,old),[])
        changed=copy.deepcopy(old);changed['files']['a.png']['sha256']='new';self.assertTrue(current_errors(old,changed))
        changed['files']['a.png']['origin']['kind']='project-generation-documented';self.assertEqual(current_errors(old,changed),[])
        changed['files']['b.png']={'sha256':'new','origin':{'kind':'unresolved'}};self.assertTrue(current_errors(old,changed))

    def test_local_receipt_is_bound_to_exact_bytes(self):
        """Совпадение локального набора не переживает подмену PNG и не означает лицензионное разрешение."""
        rules={'rules':[],'local_matches':{'a.png':{'sha256':sha(b'a'),'candidates':[]}}}
        self.assertFalse(origin('a.png',b'a',rules,lambda _:b'')['release_clearance'])
        with self.assertRaisesRegex(ValueError,'receipt differs'):origin('a.png',b'b',rules,lambda _:b'')

    def test_reference_notice_does_not_become_full_license(self):
        """Даже адресное правило с ссылкой сохраняет reference-only и хеш местного документа."""
        rule={'id':'external','paths':['assets/game/a.png'],'asset_sha256':{'assets/game/a.png':sha(png())},'kind':'external-documented','claim':'documented pack','license_status':'reference-only-review','evidence':['notice.txt']}
        row=origin('assets/game/a.png',png(),{'rules':[rule]},lambda _:b'https://example.test/terms')
        self.assertEqual(row['license_status'],'reference-only-review');self.assertFalse(row['release_clearance']);self.assertEqual(row['evidence'][0]['sha256'],sha(b'https://example.test/terms'))
        with self.assertRaisesRegex(ValueError,'reviewed bytes'):origin('assets/game/a.png',png((9,9)),{'rules':[rule]},lambda _:b'notice')

    def test_conflicting_rules_fail(self):
        """Два владельца происхождения не перетирают друг друга по порядку массива."""
        r={'id':'a','paths':['assets/game/*.png']}
        with self.assertRaisesRegex(ValueError,'overlapping'):origin('assets/game/a.png',b'',{'rules':[r,r]},lambda _:b'')

    def test_alias_is_not_another_texture(self):
        """Двадцать кадров AtlasTexture имеют общий backing, а не двадцать новых RGBA-буферов."""
        raw=b'[gd_resource type="AtlasTexture" format=3]\n[ext_resource type="Texture2D" path="res://assets/game/sheet.png" id="1"]'
        row=measure('frame.tres',raw);self.assertEqual(row['texture_rgba8_bytes'],0);self.assertEqual(row['references'],['res://assets/game/sheet.png'])

    def test_pcm_and_font_do_not_fake_vram(self):
        """PCM измеряется отдельно, память динамического шрифтового атласа явно не известна."""
        out=io.BytesIO()
        with wave.open(out,'wb') as sound:sound.setnchannels(2);sound.setsampwidth(2);sound.setframerate(24000);sound.writeframes(b'\0'*400)
        row=measure('a.wav',out.getvalue());self.assertEqual(row['pcm_bytes'],400);self.assertEqual(row['texture_rgba8_bytes'],0)
        self.assertIn('cannot be inferred',measure('a.ttf',b'font')['memory_note'])

    def test_actual_policy_is_strict(self):
        """Рабочий preset сохраняет raw JSON/notice, но не широкое включение архивов."""
        text=(ROOT/'export_presets.cfg').read_text();policy=json.loads((current_source(ROOT, 'tools/visual_asset_policy.json')).read_text())
        self.assertEqual(preset_errors(text,policy),[])
        self.assertTrue(preset_errors(text.replace('docs/*,',''),policy))
        self.assertTrue(preset_errors(text.replace('assets/game/*.json','*.json'),policy))

    def test_exported_remap_requires_payload(self):
        """Существующий .import без импортированной ctex не считается успешно экспортированным PNG."""
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'test.zip';expected={'assets/game/a.png':{'sha256':sha(png())}}
            with zipfile.ZipFile(p,'w') as z:z.writestr('assets/game/a.png.import','[remap]\npath="res://.godot/imported/a.ctex"\n')
            self.assertTrue(any('missing exported payload' in e for e in inspect_pack(p,expected,{'non_runtime_roots':['docs']})['errors']))
            with zipfile.ZipFile(p,'a') as z:z.writestr('.godot/imported/a.ctex',b'imported bytes')
            self.assertEqual(inspect_pack(p,expected,{'non_runtime_roots':['docs']})['errors'],[])

    def test_raw_json_corruption_and_archive_leak(self):
        """JSON не теряется и не меняется; архив из docs отклоняется по фактическому составу пакета."""
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'test.zip'
            with zipfile.ZipFile(p,'w') as z:z.writestr('assets/game/a.json','{}');z.writestr('docs/mockup.zip','archive')
            errors=inspect_pack(p,{'assets/game/a.json':{'sha256':sha(b'original')}},{'non_runtime_roots':['docs']})['errors']
            self.assertTrue(any('raw exported bytes differ' in e for e in errors));self.assertTrue(any('non-runtime' in e for e in errors))

    def test_missing_resource_and_unsafe_archive_path(self):
        """Подмена адреса traversal не заполняет отсутствующий ресурс и не принимается."""
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'test.zip'
            with zipfile.ZipFile(p,'w') as z:z.writestr('../bad',b'x');z.writestr('assets/game/unlisted.png',png())
            errors=inspect_pack(p,{'assets/game/missing.res':{'sha256':''}},{'non_runtime_roots':[]})['errors']
            self.assertTrue(any('unsafe' in e for e in errors));self.assertTrue(any('missing exported resource' in e for e in errors))
            self.assertTrue(any('unreported asset' in e for e in errors))

    def test_fixture_cannot_target_repository_or_existing_directory(self):
        """Диагностическая копия не перезаписывает игру или прежние доказательства."""
        with self.assertRaises(ValueError):create(ROOT,ROOT/'assets/new-fixture',{})
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):create(ROOT,Path(directory),{})


if __name__=='__main__':unittest.main()
