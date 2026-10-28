#!/usr/bin/env python3
"""Портит только отдельные копии кадров и метаданных, не затрагивая игру."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
from PIL import Image,ImageDraw
from tools.assets.slicing.slice_metrics import geometry, chain_errors, measure
from tools.assets.slicing.slice_audit import POLICY, REPORT, read, digest, evaluate, check, inputs


class SliceAuditTests(unittest.TestCase):
    """Проверяет границы, поля, опоры, уровни, происхождение и честность старого долга."""

    def setUp(self):
        """Создаёт один чистый числовой предмет и минимальный изолированный проект."""
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.folder=self.root/'export';self.folder.mkdir();(self.root/'tools').mkdir();(self.root/'scripts').mkdir()
        p=self.root/'assets/game/items/ui/padded';p.mkdir(parents=True);(p/'catalog.json').write_text(json.dumps({'levels':[{'entries':{}}]}))
        self.image=Image.new('RGBA',(32,32));draw=ImageDraw.Draw(self.image);draw.rectangle((4,4,27,27),fill=(100,65,40,255));draw.line((7,8,24,8),fill='white',width=2)
        self.image.save(self.folder/'sprite.png')
        self.frame={'image':'source','rect':[0,0,32,32],'pivot':[16,28],'scale':1.0,'flip':False}
        self.data={'textures':{'source':{'file':'sprite.png','pixels':[32,32],'rgba_sha256':digest(self.image.tobytes()),'png_sha256':digest((self.folder/'sprite.png').read_bytes()),'chain':[{'class':'ImageTexture','path':'','pixels':[32,32]}]}},'frames':{'characters/actor/walk/0':self.frame},'atlas_resources':[],'expected_characters':['actor']}
        self.policy={'schema_version':1,'baseline_commit':'a'*40,'reviews':{},'call_sites':{}}
        self.baseline={'baseline_commit':'a'*40,'warnings':{}}
        (self.root/REPORT).mkdir(parents=True);self.save()

    def save(self):
        """Записывает только временную конфигурацию тестового проекта."""
        policy=current_source(self.root, POLICY);policy.parent.mkdir(parents=True,exist_ok=True)
        self.data['inputs_sha256']=inputs(self.root)
        (self.folder/'inventory.json').write_text(json.dumps(self.data));policy.write_text(json.dumps(self.policy));(self.root/REPORT/'legacy-slices.json').write_text(json.dumps(self.baseline))

    def errors(self):
        """Проверяет актуальную копию теми же функциями, что используются в gate."""
        self.save();return check(self.root,self.folder,evaluate(self.folder))

    def test_complete_integer_frame_and_read_only_pixels(self):
        """Целый предмет сохраняет поля, белую деталь и все исходные байты."""
        before=(self.folder/'sprite.png').read_bytes();self.assertEqual(self.errors(),[])
        result=evaluate(self.folder)['frames']['characters/actor/walk/0']
        self.assertEqual(result['metrics']['alpha1']['margins'],[4,4,4,4]);self.assertEqual(before,(self.folder/'sprite.png').read_bytes())

    def test_outside_negative_empty_fractional_and_nan_regions(self):
        """Неверный source rect не становится допустимым из-за совпадения старого ID."""
        for rect in [[-1,0,32,32],[0,0,33,32],[0,0,0,32],[0.5,0,31,32],[0,float('nan'),32,32]]:
            self.assertTrue(geometry({**self.frame,'rect':rect},[32,32]),rect)

    def test_missing_and_outside_pivots_are_explicit_errors(self):
        """Потерянная опора, бесконечный масштаб и опора вне кадра получают отказ."""
        for pivot in [None,[float('inf'),2],[-1,16],[16,33]]:self.assertTrue(geometry({**self.frame,'pivot':pivot},[32,32]))
        for scale in [0,-1,float('inf'),True]:self.assertTrue(geometry({**self.frame,'scale':scale},[32,32]))

    def test_cut_inside_valid_image_is_a_new_risk(self):
        """Геометрически допустимый обрез головы всё равно обнаруживается по продолжению альфы через край."""
        self.frame['rect']=[0,9,32,23];self.frame['pivot']=[16,19]
        errors=self.errors();self.assertTrue(any('requires review' in e for e in errors))
        row=evaluate(self.folder)['frames']['characters/actor/walk/0'];self.assertGreater(row['metrics']['boundary_connections'],0)

    def test_legacy_risk_is_not_a_blanket_permission(self):
        """Старый плотный crop фиксируется по точным пикселям и геометрии; другой crop требует оценки."""
        self.frame['rect']=[4,4,24,24];self.frame['pivot']=[12,24];self.save()
        self.baseline['warnings']=evaluate(self.folder)['frames'];self.assertEqual(self.errors(),[])
        self.frame['rect']=[4,5,24,23];self.frame['pivot']=[12,23];self.assertTrue(any('requires review' in e for e in self.errors()))

    def test_nested_atlas_and_virtual_padding(self):
        """Каждый уровень вложенного атласа имеет собственные границы и виртуальное поле."""
        chain=[{'class':'AtlasTexture','pixels':[28,28],'region':[4,4,24,24],'margin':[2,2,4,4]},{'class':'ImageTexture','pixels':[32,32]}]
        self.assertEqual(chain_errors(chain),[])
        chain[0]['region']=[12,4,24,24];self.assertTrue(any('outside' in e for e in chain_errors(chain)))
        chain[0]['region']=[0,0,0,0];self.assertEqual(chain_errors(chain),[])
        chain[0]['margin']=[5,0,4,4];self.assertTrue(chain_errors(chain))
        self.assertTrue(chain_errors([]));self.assertTrue(chain_errors([{}]))

    def test_resource_index_cannot_hide_missing_actor_pivot(self):
        """Отсутствие физической опоры допустимо для самого .tres, но не для произвольной игровой позы."""
        self.frame['resource_only']=True;self.frame['pivot']=None
        self.assertTrue(any('resource-only' in e for e in self.errors()))

    def test_png_bytes_and_dimensions_are_checked(self):
        """Испорченные пиксели не скрываются за прежней метрикой или названием файла."""
        self.image.putpixel((0,0),(255,0,0,255));self.image.save(self.folder/'sprite.png')
        self.assertTrue(any('bytes/dimensions' in e for e in self.errors()))

    def test_diagnostic_file_cannot_escape_folder(self):
        """Внешний путь не читается как часть принятого комплекта изображений."""
        self.data['textures']['source']['file']='../other.png';self.save()
        with self.assertRaisesRegex(ValueError,'escaped'):evaluate(self.folder)

    def test_call_sites_and_resource_coverage_cannot_disappear(self):
        """Новый источник нарезки и потерянный .tres требуют обновления реального охвата."""
        (self.root/'scripts/renderer.gd').write_text('draw_texture_rect_region(texture, destination, source)')
        self.assertTrue(any('call-site' in e for e in self.errors()))
        self.policy['call_sites']={'scripts/renderer.gd':{'calls':1}};self.assertEqual(self.errors(),[])
        (self.root/'assets/game/new.tres').write_text('[gd_resource type="AtlasTexture" format=3]')
        self.assertTrue(any('resource coverage' in e for e in self.errors()))

    def test_fake_unprotected_mip_is_rejected(self):
        """Обычный PNG не может выдать себя за защищённый уровень и выключить проверку поля."""
        self.data['frames']={'ui/example/32':self.frame}
        self.assertTrue(any('unprotected UI' in e for e in self.errors()))

    def test_preview_requires_eight_pixel_margin(self):
        """Крупное превью сохраняет реальное поле, а не только допустимый размер source rect."""
        self.data['frames']={'ui/example/160':self.frame}
        self.assertTrue(any('8px margin' in e for e in self.errors()))

    def test_exact_review_requires_real_evidence_and_expires(self):
        """Исключение привязано к кадру и хешу настоящего доказательства, не к общему имени семейства."""
        self.frame['rect']=[4,4,24,24];self.frame['pivot']=[12,24];self.save();row=evaluate(self.folder)['frames']['characters/actor/walk/0']
        evidence=self.root/'review.txt';evidence.write_text('Intentional nearest-only tight trim verified on native sheet')
        self.policy['reviews']['characters/actor/walk/0']={'signature':row['signature'],'reason':'Intentional trim','evidence':[{'file':'review.txt','sha256':digest(evidence.read_bytes())}]}
        self.assertEqual(self.errors(),[])
        evidence.write_text('different');self.assertTrue(any('evidence' in e for e in self.errors()))
        self.frame['pivot']=[11,24];self.assertTrue(any('stale' in e for e in self.errors()))

    def test_stale_export_is_not_a_current_validation(self):
        """Изменившийся поставщик поз не может пройти по прежней выгрузке, даже при тех же PNG."""
        self.save();(self.root/'scripts/provider.gd').write_text('new pose geometry')
        self.assertTrue(any('stale slice export' in e for e in check(self.root,self.folder,evaluate(self.folder))))


if __name__=='__main__':unittest.main()
