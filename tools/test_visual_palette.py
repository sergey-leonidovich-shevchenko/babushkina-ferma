#!/usr/bin/env python3
"""Проверяет ошибки контракта палитры, не заменяя художественный выбор автотестом."""
import copy
import unittest
from PIL import Image
import visual_palette as palette


class PaletteTests(unittest.TestCase):
    """Изолированно портит копии сохранённого паспорта шести материалов."""

    def changed(self, mutate):
        """Проверяет, что независимое повреждение паспорта обнаружено."""
        data=copy.deepcopy(palette.read(palette.REPORT/'palette.json'));mutate(data)
        self.assertTrue(palette.contract_errors(data,Image.open(palette.REPORT/'material-master.png')))

    # Сценарий: проверяется полный неизменный материал и его цветовые шкалы.
    # Исходное состояние: сохранённый мастер и автономная страница просмотра.
    # Ожидаемый результат: источники, области и все варианты согласованы.
    def test_saved_report(self):
        self.assertEqual(palette.verify(),[])

    # Сценарий: потерян материал либо вечерняя версия одной шкалы.
    # Исходное состояние: шесть материалов, два варианта и два времени.
    # Ожидаемый результат: частичная партия не проходит как полная.
    def test_missing_material_or_time(self):
        self.changed(lambda d:d['materials'].pop())
        self.changed(lambda d:d['variants']['b']['ramps']['water'].pop('evening'))

    # Сценарий: новый цвет ошибочно записан или шкала стала немонотонной.
    # Исходное состояние: пять последовательных яркостей от тени к свету.
    # Ожидаемый результат: невалидная запись и обращённый свет отклоняются.
    def test_invalid_or_reversed_color(self):
        self.changed(lambda d:d['variants']['a']['ramps']['grass']['day'].__setitem__(1,'green'))
        self.changed(lambda d:d['variants']['a']['ramps']['wood']['day'].reverse())

    # Сценарий: просмотр меняет принятую проекцию либо ставит образец вне поля.
    # Исходное состояние: масштаб сто двадцать процентов и поле девятьсот шестьдесят на пятьсот сорок.
    # Ожидаемый результат: несопоставимые варианты не принимаются.
    def test_scale_or_layout(self):
        self.changed(lambda d:d.update(world_zoom=1.0))
        self.changed(lambda d:d['materials'][0].update(center=[4,4]))
        self.changed(lambda d:d['materials'][0].update(world_frame=[100,100]))

    # Сценарий: граница области режет видимый рисунок или выходит за мастер.
    # Исходное состояние: измеренные области с безопасными полями.
    # Ожидаемый результат: подрезанный силуэт выявляется до просмотра.
    def test_clipped_or_invalid_region(self):
        self.changed(lambda d:d['materials'][0].update(source_rect=[100,100,150,150]))
        self.changed(lambda d:d['materials'][1].update(source_rect=[1530,100,400,300]))

    # Сценарий: выбранный в просмотре вариант выдаётся за подтверждённый пользователем.
    # Исходное состояние: принятие и режим просмотра разделены в паспорте.
    # Ожидаемый результат: фиктивное принятие или перенос в игру отклоняются.
    def test_false_approval_or_runtime_claim(self):
        self.changed(lambda d:d.update(status='approved',selection=None))
        self.changed(lambda d:d.update(status='awaiting_user_choice',selection='a'))
        self.changed(lambda d:d.update(runtime_integration=True))
        self.changed(lambda d:d.update(status='approved',selection='a',decision_source=''))

    # Сценарий: браузер показывает другой масштаб, область либо таблицу цвета.
    # Исходное состояние: четыре настоящих просмотра и их параметры DOM.
    # Ожидаемый результат: несопоставимый кадр, подмена цвета и изменение альфы обнаруживаются.
    def test_browser_proof_drift(self):
        original=palette.read(palette.REPORT/'browser-check.json');data=palette.read(palette.REPORT/'palette.json')
        self.assertEqual(palette.browser_errors(original,data),[])
        for mutate in [lambda d:d['cases'].pop(),lambda d:d['cases'][0]['motifs'][0].update(x='111'),lambda d:d['filters'][0].update(alpha='linear'),lambda d:d['filters'][0]['tables'][0].__setitem__(0,1.0)]:
            changed=copy.deepcopy(original);mutate(changed)
            self.assertTrue(palette.browser_errors(changed,data))


if __name__=='__main__': unittest.main()
