"""Отрицательные проверки маршрута VBASE-005 на копиях настоящих нативных данных."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from PIL import Image

from visual_motion import REPORT, read, sha, validate_run, verify, verify_controls


class MotionRouteTest(unittest.TestCase):
    """Подмена ввода, телепорт и хорошие кадры замершего мира не подтверждают маршрут."""

    def setUp(self):
        """Берёт неизменяемый сохранённый пример; повреждения остаются только в памяти или tmp."""
        self.plan = read(REPORT / 'native/routes.json')
        self.data = read(REPORT / 'native/run-1/capture.json')

    def reject(self, edit):
        """Меняет независимую копию и ожидает содержательный отказ валидатора."""
        data = deepcopy(self.data)
        edit(data)
        with self.assertRaises(ValueError): validate_run(data, self.plan)

    def test_complete_native_pair_is_functional_not_performance(self):
        """Настоящие два процесса покрывают четыре вида прохода, сохраняя запрет допуска в FPS."""
        result = verify(REPORT / 'native')
        self.assertEqual(result['admission'], 'VALID_MOTION_PAIR')
        self.assertFalse(result['performance_eligible'])
        self.assertEqual(len(result['repeats']), 2)

    def test_headless_frozen_or_performance_claim_is_rejected(self):
        """Быстрый headless, остановленный мир и ложный FPS-допуск не заменяют нативную прогулку."""
        for key, value in [('kind','headless-route-probe'), ('display_server','headless'), ('performance_eligible',True),
                           ('simulation_live',False), ('physics_hz',30), ('finished',False)]:
            with self.subTest(key=key): self.reject(lambda d: d.update({key:value}))

    def test_actual_conditions_override_self_reported_valid(self):
        """Поддельный valid не скрывает один неверный размер, fullscreen, VSync или потерю фокуса."""
        for key, value in [('window',[1920,1080]), ('root',[1000,600]), ('texture',[1000,600]),
                           ('focus',False), ('mode',3), ('vsync',0)]:
            self.reject(lambda d: d['conditions'][-1].update({key:value,'valid':True}))

    def test_stopped_clock_and_native_physics_are_rejected(self):
        """Остановка симуляции в середине не проходит под общим simulation_live=true."""
        self.reject(lambda d: d['rows'][50].update(minutes=d['rows'][49]['minutes']))
        self.reject(lambda d: d['rows'][50].update(auto_physics=False))
        self.reject(lambda d: d['rows'][50].update(live=False))
        self.reject(lambda d: d['rows'][50].update(physics_delta=0))

    def test_tick_gap_wrong_feet_and_camera_are_rejected(self):
        """Потерянный шаг и другой вид мира отклоняются без сравнения только первого кадра."""
        self.reject(lambda d: d['rows'].pop(50))
        self.reject(lambda d: d['rows'][50].update(foot=[0,0]))
        self.reject(lambda d: d['rows'][50].update(camera=[0,0]))

    def test_nan_and_nonphysical_jump_are_rejected(self):
        """Необычные числа и скачок без законного перехода не становятся движением по клавишам."""
        for value in ([float('nan'),744],[float('inf'),744],[2000,744]):
            self.reject(lambda d: d['rows'][50].update(player=value,foot=value))

    def test_missing_and_duplicate_input_are_rejected(self):
        """Тот же путь без удерживаемой клавиши или с повторным press не подтверждает ввод."""
        self.reject(lambda d: d.update(inputs=[]))
        self.reject(lambda d: d['inputs'].insert(1,deepcopy(d['inputs'][0])))
        self.reject(lambda d: d['inputs'][0].update(key='E'))

    def test_door_jump_requires_input_and_physical_approach(self):
        """Разрешённый ID помещения не даёт прыгнуть к нему из любой точки карты."""
        tick = self.data['transitions'][0]['tick']
        self.reject(lambda d: d['rows'][tick-1].update(player=[1100,740],foot=[1100,740]))
        self.reject(lambda d: d['rows'][tick].update(location='cave'))
        self.reject(lambda d: d['transitions'].pop())

    def test_partial_route_and_false_checkpoints_are_rejected(self):
        """Готовый флаг не скрывает пропущенную траву, дверь или изменённую точку."""
        self.reject(lambda d: d['checkpoints'].pop())
        self.reject(lambda d: d['checkpoints'][3].update(position=[0,0]))
        self.reject(lambda d: d['checkpoints'][3].update(tick=1))

    def test_grass_and_resident_coverage_are_required(self):
        """Короткая дорожка и пустая площадь не закрывают четыре вида проверки."""
        def remove_grass(data):
            """Убирает все наблюдения поверхности, сохраняя остальные исходные данные."""
            for row in data['rows']: row['road_distance']=0
        self.reject(remove_grass)
        self.reject(lambda d: d['rows'][0].update(actors=[]))

    def package(self):
        """Копирует исторический пакет в собственный временный каталог без записи в оригинал."""
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        folder = Path(temporary.name) / 'native'
        shutil.copytree(REPORT/'native', folder)
        return folder

    def resign(self, folder):
        """Разрешает семантическую порчу с новым SHA, чтобы проверять поведение, а не лишь хеш."""
        source = read(folder/'source.json')
        for name in source['artifacts']: source['artifacts'][name]=sha(folder/name)
        (folder/'source.json').write_text(json.dumps(source))

    def test_package_requires_all_media_and_exact_sources(self):
        """Потерянная подпись или исходник блокируют архив независимо от наличия видео рядом."""
        folder = self.package(); source = read(folder/'source.json')
        del source['artifacts']['run-1/bridge.png']; (folder/'source.json').write_text(json.dumps(source))
        with self.assertRaises(ValueError): verify(folder)
        source['artifacts']['run-1/bridge.png']=sha(folder/'run-1/bridge.png')
        (folder/'source.json').write_text(json.dumps(source))
        (folder/'instrumentation/tools/visual_motion_route.gd').write_text('changed')
        with self.assertRaises(ValueError): verify(folder)

    def test_signed_wrong_image_and_video_size_are_rejected(self):
        """Новый SHA уменьшенного PNG или ложные размеры видеопотока не обходят проверку медиа."""
        folder = self.package()
        Image.new('RGB',(320,180)).save(folder/'run-1/grass.png'); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)
        shutil.copy2(REPORT/'native/run-1/grass.png',folder/'run-1/grass.png')
        video=read(folder/'run-1/walk.json'); video['width']=320
        (folder/'run-1/walk.json').write_text(json.dumps(video)); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)

    def test_reused_process_and_mutated_frame_are_rejected(self):
        """Копия того же процесса и кадр от другой точки не считаются вторым повтором."""
        folder=self.package(); data=read(folder/'run-2/capture.json'); original=deepcopy(data)
        data['pid']=self.data['pid']; (folder/'run-2/capture.json').write_text(json.dumps(data)); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)
        original['frames'][3]['camera']=[0,0]
        (folder/'run-2/capture.json').write_text(json.dumps(original)); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)

    def test_unknown_paths_and_incomplete_collection_are_rejected(self):
        """Неполный запуск и выход имени файла за папку отчёта всегда получают отказ."""
        folder=self.package(); source=read(folder/'source.json'); source['collection_complete']=False
        (folder/'source.json').write_text(json.dumps(source))
        with self.assertRaises(ValueError): verify(folder)
        source['collection_complete']=True; source['runs'][0]='../outside'
        (folder/'source.json').write_text(json.dumps(source))
        with self.assertRaises(ValueError): verify(folder)

    def test_recorded_launch_clock_and_sampling_timeline_are_required(self):
        """Сохраняемые argv и равномерность кадров проверяются отдельно от объявленного режима."""
        folder=self.package(); path=folder/'run-1/environment.json'; env=read(path); original=deepcopy(env)
        env['command'].remove('--fixed-fps'); path.write_text(json.dumps(env)); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)
        path.write_text(json.dumps(original))
        data=read(folder/'run-1/capture.json'); data['frames'][1]=deepcopy(data['frames'][2])
        (folder/'run-1/capture.json').write_text(json.dumps(data)); self.resign(folder)
        with self.assertRaises(ValueError): verify(folder)

    def test_four_native_rejections_have_observed_causes(self):
        """Настоящие отдельные resize/pause/focus/teleport подтверждены наблюдением, не статусом теста."""
        result=verify_controls(REPORT/'controls')
        self.assertEqual(set(result['observed']),{'resize','pause','focus','teleport'})
        self.assertFalse(result['performance_eligible'])

    def test_fault_flag_cannot_replace_native_focus_loss(self):
        """Подписанный отчёт с флагом focus, но без потери фокуса, получает независимый отказ."""
        temporary=tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        root=Path(temporary.name)
        shutil.copytree(REPORT/'controls',root/'controls'); shutil.copytree(REPORT/'native',root/'native')
        path=root/'controls/focus/capture.json'; data=read(path)
        for state in data['conditions']: state['focus']=True
        path.write_text(json.dumps(data))
        source=read(root/'controls/source.json'); source['artifacts']['focus/capture.json']=sha(path)
        (root/'controls/source.json').write_text(json.dumps(source))
        with self.assertRaisesRegex(ValueError,'not observed'): verify_controls(root/'controls')


if __name__ == '__main__':
    unittest.main()
