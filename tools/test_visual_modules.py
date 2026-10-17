#!/usr/bin/env python3
"""Сценарии потери художественного контракта VART-008."""
import unittest
from visual_modules import REPORT,read,contract_errors,verify


class ModuleTests(unittest.TestCase):
    def setUp(self):
        """Загружает свежие копии подтверждённых условий."""
        self.data=read(REPORT/'modules.json');self.measure=read(REPORT/'measurements.json');self.capture=read(REPORT/'native/capture.json')

    def test_files(self):
        """Точная нарезка мастеров и все кадры проходят полную сверку."""
        self.assertEqual(verify(),[])

    def test_missing_clump(self):
        """Потерянный пучок не скрывается остальными красивыми картинками."""
        self.data['parts'].pop(0)
        self.assertIn('module coverage',contract_errors(self.data,self.measure,self.capture))

    def test_clip(self):
        """Кончики на самой границе региона считаются обрезкой."""
        self.measure['parts']['grass-low']['visible_bbox'][0]=0
        self.assertIn('clipped silhouette',contract_errors(self.data,self.measure,self.capture))

    def test_direction(self):
        """Диагональное вращение моста отклоняется."""
        next(p for p in self.data['parts'] if p['id']=='bridge-deck')['rotation']=45
        self.assertIn('prop direction',contract_errors(self.data,self.measure,self.capture))

    def test_scale(self):
        """Один куст нельзя независимо подогнать под квадратную иконку."""
        next(p for p in self.data['parts'] if p['id']=='bush-berry')['scale']=.2
        self.assertIn('family density',contract_errors(self.data,self.measure,self.capture))

    def test_incomplete_native(self):
        """Потеря ракурса перекрытия и уменьшенный кадр отклоняются."""
        self.capture['frames'].pop();self.capture['frames'][0]['size']=[960,540]
        errors=contract_errors(self.data,self.measure,self.capture)
        self.assertIn('frame coverage',errors);self.assertIn('readback',errors)

    def test_no_performance_claim(self):
        """Витрина с остановленной симуляцией не становится замером FPS."""
        self.capture['performance_eligible']=True;self.data['constraints']['seamless_autotile_approved']=True
        errors=contract_errors(self.data,self.measure,self.capture)
        self.assertIn('native: performance_eligible',errors);self.assertIn('unsupported claim',errors)


if __name__=='__main__':unittest.main()
