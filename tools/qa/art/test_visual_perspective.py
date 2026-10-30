#!/usr/bin/env python3
"""Проверяет геометрию стандарта, не выдавая старую графику за принятую новую партию."""
import copy
import unittest
from pathlib import Path
import shutil
import tempfile
from unittest.mock import patch
from tools.qa.art import visual_perspective as perspective


class PerspectiveTests(unittest.TestCase):
    """Независимо повреждает паспорта трёх ракурсов и реального браузерного просмотра."""

    def changed(self, mutate):
        """Ожидает явный отказ после независимого изменения правильного контракта."""
        data=copy.deepcopy(perspective.read(perspective.REPORT/'standard.json'));mutate(data)
        self.assertTrue(perspective.contract_errors(data,perspective.read(perspective.REPORT/'runtime-export.json')))

    # Сценарий: проверяется полный сохранённый стандарт и его подтверждения.
    # Исходное состояние: девять настоящих ресурсов и восемнадцать просмотров.
    # Ожидаемый результат: геометрия, исходники и все кадры согласованы.
    def test_saved_standard(self):
        self.assertEqual(perspective.verify(),[])

    # Сценарий: в доступные стороны возвращается задний либо диагональный вид.
    # Исходное состояние: три целых направления и совместимый алиас старого второго слота.
    # Ожидаемый результат: лишний ракурс и изменение алиаса отклоняются.
    def test_forbidden_facing(self):
        self.changed(lambda d:d['directions'].append(2))
        self.changed(lambda d:d['families'][0]['views'][0].update(direction=2))
        self.changed(lambda d:d.update(legacy_up_alias=2))

    # Сценарий: одна сторона растягивается по оси или получает другую плотность рисунка.
    # Исходное состояние: у семейства один коэффициент исходных пикселей к миру.
    # Ожидаемый результат: несогласованный боковой рисунок обнаруживается.
    def test_uniform_scale(self):
        self.changed(lambda d:d['families'][0]['views'][0]['visual_size'].__setitem__(0,96))
        self.changed(lambda d:d['families'][1].update(source_scale=0.3))

    # Сценарий: основание сходит с сетки или его нижний центр округляется ещё раз.
    # Исходное состояние: границы на сетке двадцать четыре, центр может находиться на полуклетке.
    # Ожидаемый результат: сдвиг основания и визуальной опоры выявляются.
    def test_grid_and_half_cell_anchor(self):
        self.changed(lambda d:d['families'][0]['views'][0]['origin'].__setitem__(0,121))
        self.changed(lambda d:d['families'][0]['views'][0]['anchor'].__setitem__(0,168))

    # Сценарий: рабочая сторона направлена в противоположную сторону или меняется камера.
    # Исходное состояние: стрелки согласованы с тремя разрешёнными гранями.
    # Ожидаемый результат: развёрнутый подход и несопоставимая проекция отклоняются.
    def test_working_side_and_projection(self):
        self.changed(lambda d:d['families'][0]['views'][0]['work_tip'].__setitem__(0,300))
        self.changed(lambda d:d.update(world_zoom=1.0))
        self.changed(lambda d:d.update(runtime_integration=True))

    # Сценарий: браузер теряет вариант, вращает PNG, смещает опору либо использует другой crop.
    # Исходное состояние: сохранены реальные параметры всех комбинаций просмотра.
    # Ожидаемый результат: неподтверждённый кадр не проходит за эталон.
    def test_browser_drift(self):
        original=perspective.read(perspective.REPORT/'browser-check.json');data=perspective.read(perspective.REPORT/'standard.json')
        for mutate in [lambda d:d['cases'].pop(),lambda d:d['cases'][0]['views'][0].update(css_transform='matrix(0,1,-1,0,0,0)'),lambda d:d['cases'][0]['views'][0].update(clip='0 0 100 100'),lambda d:d['cases'][0]['pivots'].__setitem__(0,'M 0 0'),lambda d:d['cases'][0]['bases'][0].__setitem__(0,121)]:
            changed=copy.deepcopy(original);mutate(changed)
            self.assertTrue(perspective.browser_errors(changed,data))

    # Сценарий: оригинальная копия изображения незаметно меняется после съёмки.
    # Исходное состояние: независимая временная копия отчёта с корректным манифестом.
    # Ожидаемый результат: изменение байтов фиксируется по хешу без редактирования отчёта проекта.
    def test_asset_tampering(self):
        with tempfile.TemporaryDirectory() as folder:
            report=Path(folder)/'report';shutil.copytree(perspective.REPORT,report)
            file=report/'masters/rustic_table_south.png';file.write_bytes(file.read_bytes()+b'\0')
            with patch.object(perspective,'REPORT',report):
                self.assertIn('master provenance: masters/rustic_table_south.png',perspective.verify())


if __name__=='__main__': unittest.main()
