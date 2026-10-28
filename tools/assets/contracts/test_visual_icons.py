#!/usr/bin/env python3
"""Отрицательные сценарии VART-010 без изменения игровых PNG."""
import unittest
from tools.assets.contracts.visual_icons import REPORT, read, contract_errors, verify


class IconTests(unittest.TestCase):
    def setUp(self):
        """Для каждого сценария читает отдельные копии протокола."""
        self.data=read(REPORT/'icons.json');self.review=read(REPORT/'review.json');self.capture=read(REPORT/'native/capture.json')

    def errors(self):
        """Проверяет изменённое описание без записи на диск."""
        return contract_errors(self.data,self.review,self.capture)

    def test_real_files(self):
        """Мастера, размеры, области, код и доказательства проходят полную сверку."""
        self.assertEqual(verify(),[])

    def test_missing_category(self):
        """Шестая копия еды не заменяет пример одежды."""
        self.data['items'][-1]=self.data['items'][0].copy();self.assertIn('item coverage',self.errors())

    def test_variant_coverage(self):
        """Повтор варианта не скрывает потерянный предмет."""
        self.data['entries'][-1]=self.data['entries'][0].copy();self.assertIn('variant coverage',self.errors())

    def test_two_sizes(self):
        """Один размер и мировое увеличение UI отклоняются."""
        self.data['sizes']=[160];self.data['ui_scale']=1.2;self.capture['exports'].pop();self.assertIn('screen sizes',self.errors());self.assertIn('export coverage',self.errors())

    def test_choice(self):
        """Одобрение без прямого ответа пользователя не считается выбором."""
        self.review.update(status='approved',selection='a',source=None,quote=None);self.assertIn('unconfirmed choice',self.errors())

    def test_native(self):
        """Headless, неверный физический размер и пропущенный фон отклоняются."""
        self.capture['display_server']='headless';self.capture['frames'].pop();self.capture['frames'][0]['size']=[960,540];self.assertIn('native profile',self.errors());self.assertIn('frame coverage',self.errors());self.assertIn('readback',self.errors())

    def test_scope_and_loading(self):
        """Макеты не доказывают FPS и не разрешают загрузку мастеров для ячейки."""
        self.data['claims']['performance_eligible']=True;self.capture['masters_used_for_ui']=True;self.assertIn('unsupported claims',self.errors());self.assertIn('texture preparation',self.errors())


if __name__=='__main__':unittest.main()
