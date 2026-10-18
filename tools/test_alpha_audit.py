#!/usr/bin/env python3
"""Проверяет цветовые контроли, защиту белых деталей и запрет автоматического принятия нового matte."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from alpha_metrics import analyse
from alpha_fixtures import controls,create
from alpha_audit import ROOT,POLICY,BASELINE,inspect,scan,check,sha,write_report


class AlphaTests(unittest.TestCase):
    """Изолирует все повреждения и записи от игровых ресурсов и настоящего снимка долга."""

    def setUp(self):
        """Готовит минимальный проект с одним неизменным чистым спрайтом и настоящим алгоритмом."""
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        (self.root/'assets/game').mkdir(parents=True);(self.root/'tools').mkdir()
        for name in ['alpha_metrics.py','visual_asset_policy.json']:shutil.copyfile(ROOT/'tools'/name,self.root/'tools'/name)
        self.data=controls();self.path=self.root/'assets/game/clean.png';self.data['clean-white-details'].save(self.path)
        self.policy={'schema_version':1,'baseline_commit':'a'*40,'reviews':{},'data_masks':{}}
        self.write_policy();base=scan(self.root);(self.root/BASELINE).parent.mkdir(parents=True);(self.root/BASELINE).write_text(json.dumps(base))

    def write_policy(self):
        """Сохраняет только изолированную политику тестового проекта."""
        (self.root/POLICY).write_text(json.dumps(self.policy))

    def test_soft_and_opaque_matte_controls(self):
        """Белый и пурпурный matte обнаруживаются как в мягкой альфе, так и в непрозрачной кайме."""
        for colour in ['white','magenta']:
            for suffix,kind in [('soft-matte','soft_matte'),('opaque-rim','opaque_colour_rim')]:
                result=analyse(self.data[colour+'-'+suffix]);found=result['findings']
                self.assertTrue(found,(colour,suffix));self.assertEqual({r['colour'] for r in found},{colour})
                self.assertIn(kind,{k for r in found for region in r['regions'] for k in region['kinds']})

    def test_legitimate_colours_and_white_details_are_preserved(self):
        """Белые детали, белый материал и пурпурный материал не удаляются и не считаются этими контрольными ошибками."""
        for name in ['clean-white-details','white-material','magenta-material']:
            image=self.data[name];before=image.tobytes();result=analyse(image)
            self.assertEqual(result['findings'],[],name);self.assertEqual(image.tobytes(),before,name)
        self.assertEqual(self.data['clean-white-details'].getpixel((48,42)),(250,245,230,255))

    def test_invisible_rgb_is_reported_separately(self):
        """Цвет нулевой альфы не выдаётся за видимый matte; риск линейной выборки остаётся отдельным показателем."""
        result=analyse(self.data['invisible-rgb']);self.assertEqual(result['findings'],[])
        self.assertGreater(result['invisible_rgb']['white'],0);self.assertGreater(result['invisible_rgb']['magenta'],0)

    def test_data_masks_are_not_processed_as_colours(self):
        """Числовой RGBA сохраняется при явном назначении data, неизвестное назначение отклоняется."""
        image=self.data['magenta-soft-matte'];before=image.tobytes()
        self.assertEqual(analyse(image,'data_rgba8'),{'classification':'data_mask','findings':[]});self.assertEqual(before,image.tobytes())
        with self.assertRaises(ValueError):analyse(image,'guess')

    def test_read_only_scan_and_unchanged_baseline(self):
        """Обычная проверка сохраняет каждый байт PNG и принимает точный исходный снимок."""
        before=self.path.read_bytes();self.assertEqual(check(self.root),[]);self.assertEqual(inspect(self.path)['sha256'],sha(before));self.assertEqual(self.path.read_bytes(),before)

    def test_new_matte_cannot_hide_in_existing_filename(self):
        """Подмена существующего источника новым matte требует отдельной оценки, старый cache не скрывает изменение."""
        self.data['white-soft-matte'].save(self.path)
        self.assertTrue(any('require review' in e for e in check(self.root)))

    def test_new_file_and_clean_replacement(self):
        """Новый пурпурный файл блокируется; честная белая замена может пройти без удаления белого цвета."""
        extra=self.path.with_name('new.png');self.data['magenta-opaque-rim'].save(extra)
        self.assertTrue(any('require review' in e for e in check(self.root)))
        extra.unlink();self.data['white-material'].save(self.path);self.assertEqual(check(self.root),[])

    def test_legacy_candidate_is_debt_not_auto_cleaned(self):
        """Зафиксированный исходный matte остаётся явным долгом и не переписывается инструментом."""
        self.data['white-opaque-rim'].save(self.path);base=scan(self.root);(self.root/BASELINE).write_text(json.dumps(base));before=self.path.read_bytes()
        self.assertEqual(base['summary']['files_with_candidates'],1);self.assertEqual(check(self.root),[]);self.assertEqual(self.path.read_bytes(),before)

    def test_review_requires_exact_source_and_existing_evidence(self):
        """Исключение привязано к конкретным байтам источника и настоящему доказательству; устаревший review отклоняется."""
        self.data['white-soft-matte'].save(self.path);key='assets/game/clean.png';evidence=self.root/'review.txt';evidence.write_text('Four-background visual review of intentional trim')
        self.policy['reviews'][key]={'sha256':sha(self.path.read_bytes()),'reason':'Intentional white border verified on backgrounds','evidence':[{'file':'review.txt','sha256':sha(evidence.read_bytes())}]};self.write_policy()
        self.assertEqual(check(self.root),[])
        evidence.write_text('changed');self.assertTrue(any('evidence' in e for e in check(self.root)))
        self.data['magenta-soft-matte'].save(self.path);self.assertTrue(any('stale alpha review' in e for e in check(self.root)))

    def test_data_import_must_match_numeric_contract(self):
        """Объявление data не позволяет молча выключить проверку картинки с цветовым импортом."""
        self.policy['data_masks']['assets/game/clean.png']='data_rgba8';self.write_policy()
        from texture_intents import DATA_IMPORT
        imports=dict(DATA_IMPORT);imports['process/fix_alpha_border']=True
        Path(str(self.path)+'.import').write_text('\n'.join(k+'='+json.dumps(v) for k,v in imports.items()))
        self.assertTrue(any('import mismatch' in e for e in check(self.root)))

    def test_report_and_fixture_cannot_overwrite_assets_or_results(self):
        """Диагностика пишет только новый внешний JSON, а контролям нужна новая папка вне assets."""
        for target in [self.path,self.root/'assets/game/report.json']:
            with self.assertRaises(ValueError):write_report(self.root,target,{})
        output=self.root/'out.json';write_report(self.root,output,{})
        with self.assertRaises(ValueError):write_report(self.root,output,{})
        with self.assertRaises(ValueError):create(self.root/'assets/fixtures')

    def test_changed_algorithm_and_invalid_image_fail_explicitly(self):
        """Другой алгоритм не использует старые метрики, повреждённый PNG не превращается в пустой успех."""
        file=self.root/'tools/alpha_metrics.py';file.write_text(file.read_text()+'\n# changed\n')
        self.assertTrue(any('algorithm changed' in e for e in check(self.root)))
        self.path.write_bytes(b'broken')
        with self.assertRaises(OSError):inspect(self.path)


if __name__=='__main__':unittest.main()
