#!/usr/bin/env python3
"""Негативные проверки берегового комплекта не меняют игровые ресурсы и исходные доказательства."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.qa.world import shore_kit as kit
from tools.common.git import git_environment


class ShoreKitTests(unittest.TestCase):
    """Проверяет реальные пиксели и паспорт в отдельном маленьком проекте."""

    def setUp(self):
        """Создаёт копию только нужных файлов и доступ к прежней Git-истории."""
        self.temp = tempfile.TemporaryDirectory(prefix='farm-shore-kit-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(kit.ROOT/kit.REPORT,self.root/kit.REPORT)
        self.folder = self.root/kit.REPORT
        proof = kit.read(self.folder/'native/capture.json')
        for name in proof['sources']:
            if not name.startswith('res://') or name.startswith('res://scripts/'): continue
            source = (kit.ROOT/name[6:]).resolve()
            target = self.root/source.relative_to(kit.ROOT)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,target)
        source = kit.read(self.folder/'source.json')
        for name in source['files']:
            original = (kit.ROOT/kit.REPORT/name).resolve()
            target = self.root/original.relative_to(kit.ROOT)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(original,target)
        target = self.root/'tools/shore_kit_review.gd'
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(kit.ROOT/'tools/shore_kit_review.gd',target)
        (self.root/'.git').symlink_to(kit.ROOT/'.git',target_is_directory=True)

    def change(self, filename, edit):
        """Изменяет один документ копии, сохраняя оригинал нетронутым."""
        path = self.folder/filename
        data = kit.read(path); edit(data)
        path.write_text(json.dumps(data,ensure_ascii=False))

    def check(self, needle):
        """Требует адресную ошибку вместо общего зелёного результата."""
        errors = kit.verify(self.root)
        self.assertTrue(any(needle in e for e in errors),errors)

    def test_complete(self):
        """Сценарий: полная копия. Исходное состояние: все настоящие артефакты. Результат: комплект принят как художественная витрина."""
        self.assertEqual(kit.verify(self.root),[])

    def test_required_log_must_be_indexed(self):
        """Сценарий: журнал существует, но игнорируется Git. Исходное состояние: отдельный репозиторий. Результат: только добавленный в индекс файл проходит."""
        with tempfile.TemporaryDirectory(prefix='shore-log-index-') as value:
            root = Path(value)
            subprocess.run(['git','init','-q',str(root)],check=True,capture_output=True,env=git_environment())
            (root/'.gitignore').write_text('*.log\n')
            (root/'review.log').write_text('passed')
            self.assertFalse(kit.tracked(root,['review.log']))
            subprocess.run(['git','-C',str(root),'add','-f','review.log'],check=True,capture_output=True,env=git_environment())
            self.assertTrue(kit.tracked(root,['review.log']))

    def test_missing_part(self):
        """Сценарий: потерян торец. Исходное состояние: неполный паспорт. Результат: неполный комплект отклонён."""
        self.change('profile.json',lambda d:d['parts'].pop(12))
        self.check('incomplete')

    def test_fractional_or_outside_crop(self):
        """Сценарий: неправильная нарезка. Исходное состояние: дробная координата. Результат: выборка не принимается."""
        self.change('profile.json',lambda d:d['parts'][0]['rect'].__setitem__(0,.5))
        self.check('noninteger source rect')

    def test_rotated_lit_stone(self):
        """Сценарий: повёрнут свет. Исходное состояние: мастер развёрнут кодом. Результат: требуется самостоятельный ракурс."""
        self.change('profile.json',lambda d:d['parts'][0].__setitem__('rotation',90))
        self.check('rotated/mirrored')

    def test_replaced_export(self):
        """Сценарий: подменён PNG. Исходное состояние: пиксели другого кадра. Результат: происхождение и точная нарезка не совпадают."""
        shutil.copyfile(self.folder/'native/sprites/stone-e.png',self.folder/'native/sprites/stone-n.png')
        self.check('crop pixels differ')

    def test_widening_and_uniform_scale(self):
        """Сценарий: мост снова узкий или растянут. Исходное состояние: неверные размеры. Результат: три клетки и общая плотность обязательны."""
        self.change('profile.json',lambda d:d['scene']['bridge'].__setitem__(3,48))
        self.check('wider bridge')
        self.change('profile.json',lambda d:d['parts'][-1].__setitem__('scale',.5))
        self.check('stretched/mismatched')

    def test_headless_or_fps_claim(self):
        """Сценарий: подмена типа доказательства. Исходное состояние: headless и заявление FPS. Результат: нативная приёмка отклоняется."""
        self.change('native/capture.json',lambda d:d.update(display_server='headless',performance_eligible=True))
        self.check('native display')
        self.check('classified as gameplay/FPS')

    def test_frozen_camera_video(self):
        """Сценарий: вместо движения повторены кадры. Исходное состояние: все подписи одинаковые. Результат: неподвижный ролик не проходит."""
        self.change('native/capture.json',lambda d:[r.update(sha256=d['motion'][0]['sha256']) for r in d['motion']])
        self.check('repeated motion')

    def test_corrupt_witness(self):
        """Сценарий: испорчен свидетель движения. Исходное состояние: байты кадра заменены. Результат: подпись не совпадает."""
        shutil.copyfile(self.folder/'native/motion-000.png',self.folder/'native/motion-060.png')
        self.check('motion witness SHA')


if __name__ == '__main__':
    unittest.main()
