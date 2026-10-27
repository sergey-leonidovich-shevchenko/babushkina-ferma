#!/usr/bin/env python3
"""Отказы при подмене сравнения масштаба и его нативных доказательств."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from PIL import Image
from tools.qa.art import visual_scale as scale


class ScaleTests(unittest.TestCase):
    """Проверяет сохранённый нативный набор и независимые повреждения одной копии."""

    def changed(self, mutate):
        """Отклоняет независимое изменение настоящего паспорта."""
        data = copy.deepcopy(scale.read(scale.REPORT/'native/capture.json'))
        mutate(data)
        self.assertTrue(scale.capture_errors(data))

    # Сценарий: читаются все шесть нативных изображений и прозрачные образцы.
    # Исходное состояние: сохранённый паспорт, матрицы и хеши.
    # Ожидаемый результат: полный набор проверок принимает данные без ошибок.
    def test_saved_comparison(self):
        self.assertEqual(scale.verify(scale.REPORT/'native'), [])

    # Сценарий: решение пользователя переносится из макета в художественный паспорт.
    # Исходное состояние: принятый вариант и измеренные нативные силуэты.
    # Ожидаемый результат: паспорт согласован с проекцией всего мира и прежней физикой.
    def test_approved_profile(self):
        self.assertEqual(scale.decision_errors(scale.read(scale.REPORT/'review.json'),scale.read(scale.REPORT/'scale-profile.json')),[])

    # Сценарий: в паспорте остался другой вариант либо вместо мира изменены герой/HUD.
    # Исходное состояние: независимая копия принятого решения.
    # Ожидаемый результат: несогласованный выбор и неподтверждённый перенос отклоняются.
    def test_profile_drift(self):
        review = scale.read(scale.REPORT/'review.json'); profile = scale.read(scale.REPORT/'scale-profile.json')
        for key, value in [('selection','wide'),('world_zoom',0.8),('hero_physical_radius',21.6),('hud_zoom',1.2),('reference_silhouette_down_px',115),('runtime_integration',True)]:
            changed = copy.deepcopy(profile); changed[key]=value
            self.assertTrue(scale.decision_errors(review,changed),key)
        review['selection']=None
        self.assertTrue(scale.decision_errors(review,profile))

    # Сценарий: одна проекция теряется либо заменяет другую с тем же именем.
    # Исходное состояние: по три варианта двух камер.
    # Ожидаемый результат: нарушение покрытия выявляется.
    def test_missing_or_repeated_variant(self):
        self.changed(lambda d:d['points'].pop())
        self.changed(lambda d:d['points'][1].update(id='plaza-current'))

    # Сценарий: сравнение незаметно меняет центр или область отсечения.
    # Исходное состояние: одинаковый мировой центр у трёх вариантов.
    # Ожидаемый результат: сдвиг или прежний прямоугольник отсечения отклоняются.
    def test_camera_and_culling(self):
        self.changed(lambda d:d['points'][1].update(camera_center=[1250,744]))
        self.changed(lambda d:d['points'][1].update(visible_world=[528,339,1152,648]))
        self.changed(lambda d:d['points'][1].update(projection=[[1,0],[0,1],[0,0]]))

    # Сценарий: ради картинки уменьшается коллизия или меняется состояние сохранения.
    # Исходное состояние: физический радиус восемнадцать и одинаковые снимки.
    # Ожидаемый результат: любое расхождение обнаруживается.
    def test_physics_is_not_visual_scale(self):
        self.changed(lambda d:d['points'][1]['physical_after'].update(radius=14.4))
        self.changed(lambda d:d['points'][1]['physical_before'].update(save_sha256='0'*64))

    # Сценарий: кадр снят без фокуса, в другом размере или модельным рендерером.
    # Исходное состояние: действительное окно с фиксированным target.
    # Ожидаемый результат: плохие условия и ложное заявление о FPS отклоняются.
    def test_native_conditions(self):
        self.changed(lambda d:d.update(display_server='headless'))
        self.changed(lambda d:d.update(performance_eligible=True))
        self.changed(lambda d:d['points'][1]['conditions'].update(focused=False))
        self.changed(lambda d:d['points'][1].update(world_readback=[1440,810]))

    # Сценарий: портреты имеют разные размеры, но целые силуэты.
    # Исходное состояние: настоящие прозрачные позы для трёх полей обзора.
    # Ожидаемый результат: измеренная высота соответствует восемьдесят одному, шестидесяти пяти и девяноста семи пикселям.
    def test_measured_silhouettes(self):
        self.assertEqual([scale.silhouette(scale.REPORT/f'native/hero-{v}.png')[0]['height'] for v in scale.FIELDS],[81,65,97])

    # Сценарий: изменяется один пиксель настоящего непрозрачного HUD.
    # Исходное состояние: отдельный слой HUD и финальный кадр исходного масштаба.
    # Ожидаемый результат: проверка пикселей и хеша обнаруживает подмену.
    def test_native_hud_and_file_tampering(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)/'native'; shutil.copytree(scale.REPORT/'native',folder)
            file = folder/'plaza-current.png'; image = Image.open(file).convert('RGB'); image.putpixel((30,30),(255,0,255)); image.save(file)
            errors = scale.verify(folder)
            self.assertTrue(any('HUD changed' in e for e in errors))
            self.assertTrue(any('artifact hash' in e for e in errors))

    # Сценарий: удаляются подтверждения файлов из манифеста.
    # Исходное состояние: полный сохранённый набор, который иначе остаётся правильным.
    # Ожидаемый результат: незаполненное происхождение не считается успешной проверкой.
    def test_incomplete_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)/'native'; shutil.copytree(scale.REPORT/'native',folder)
            source = scale.read(folder/'source.json'); source['artifacts']={}
            (folder/'source.json').write_text(json.dumps(source))
            self.assertIn('incomplete provenance',scale.verify(folder))


if __name__=='__main__': unittest.main()
