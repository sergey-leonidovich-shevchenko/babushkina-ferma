"""Проверяет аппаратный допуск VBASE-002 на временных трассах, без запуска игры и смены питания."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from tools.qa.camera.analyze_visual_baseline import analyze_session
from tools.qa.camera.test_visual_baseline import fixture
from tools.qa.camera.visual_hardware import POLICY, TOOLS, active_power, digest, display_inventory, validate_policy, verify


class VisualHardwareTest(unittest.TestCase):
    """Честная плохая производительность сохраняется; другое оборудование и условия получают отказ."""

    def setUp(self):
        """Создаёт отдельный полный набор с известной машиной и тремя независимыми процессами."""
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)
        self.policy = json.loads(POLICY.read_text())
        device = self.policy['devices'][0]
        gpu = dict(model=device['gpu_model'], dedicated_vram='4 GB', shared_vram=None)
        inv = {key: device[key] for key in ('system', 'os_version', 'architecture')}
        inv['gpus'] = [gpu]
        stamp = dict(inv, machine=device['machine'], background_available=True,
                     background=[{'executable': 'fixture'}], power="Now drawing from 'Battery Power'\n -InternalBattery-0 75%; discharging;",
                     power_settings='Battery Power:\n lowpowermode 0\n gpuswitch 2\nAC Power:\n lowpowermode 1\n gpuswitch 0',
                     thermal='CPU_Scheduler_Limit = 100\nCPU_Speed_Limit = 100')
        self.session = dict(requested_repeats=3, fault='',
                            source=dict(commit='a' * 40, sha256={name: 'b' * 64 for name in TOOLS}), runs=[])
        signatures = {}
        for name in TOOLS:
            target = self.folder / 'instrumentation' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('test instrumentation')
            signatures[name] = digest(target)
        self.session['source']['sha256'] = signatures
        self.native = self.folder / 'native'
        self.native.mkdir()
        for i in range(3):
            data = fixture()
            data.update({key: device[key] for key in ('adapter', 'engine', 'driver', 'display_server', 'screen', 'screen_scale')})
            data.update(repeat=i, pid=100 + i, profile=f'Codex-VBASE-001-fixture-{i}', start_camera=[0, 348])
            target = self.native / f'run-{i+1}'
            target.mkdir()
            (target / 'native.json').write_text(json.dumps(data))
            (target / 'stdout.txt').write_text('ok')
            for name in ('start.png', 'end.png'):
                Image.new('RGB', (1152, 648), (25, 50, 75)).save(target / name)
            self.session['runs'].append(dict(repeat=i, exit_code=0, folder=target.name, profile=data['profile'],
                                             before=deepcopy(stamp), after=deepcopy(stamp)))
        self.write_session()
        self.capture = dict(schema=1, policy=self.policy, before=deepcopy(inv), after=deepcopy(inv), exit_code=0,
                            source=self.session['source'], tool_sha256=signatures)
        self.sign()

    def write_session(self):
        """Сохраняет изменённый паспорт; сводка отдельно воспроизводится существующим анализатором."""
        (self.native / 'session.json').write_text(json.dumps(self.session))
        (self.native / 'summary.json').write_text(json.dumps(analyze_session(self.native)))

    def sign(self):
        """Пересчитывает подписи тестовых файлов: семантический отказ нельзя обойти новым SHA."""
        self.capture['files'] = {str(p.relative_to(self.folder)): digest(p) for p in self.native.rglob('*') if p.is_file()}
        (self.folder / 'capture.json').write_text(json.dumps(self.capture))

    def edit_run(self, index, edit):
        """Меняет один raw-повтор; канонический отчёт и сохранения пользователя не затрагиваются."""
        path = self.native / f'run-{index}/native.json'
        data = json.loads(path.read_text())
        edit(data)
        path.write_text(json.dumps(data))
        self.sign()

    def assert_rejected(self):
        """Ожидает отказ без изменения исходных тестовых данных самим верификатором."""
        with self.assertRaises((ValueError, KeyError, OSError)):
            verify(self.folder, self.policy)

    def test_complete_reference_is_admitted_without_release_claim(self):
        """Полные данные известного устройства дают допуск; релиз и масштаб 120% остаются открытыми."""
        result = verify(self.folder, self.policy)
        self.assertEqual(result['admission'], 'VALID_REFERENCE_DEVICE')
        self.assertFalse(result['release_minimum_approved'])
        self.assertFalse(result['target_scale_accepted'])

    def test_inventory_drops_serials_and_shared_vram_is_distinct(self):
        """Инвентарь с EDID и серийным номером сохраняет только модель и разные виды памяти."""
        raw = {'SPDisplaysDataType': [{'sppci_model': 'Intel', 'spdisplays_vram_shared': '1536 MB',
                                     '_serial': 'private', 'spdisplays_ndrvs': [{'_spdisplays_edid': 'private'}]}]}
        self.assertEqual(display_inventory(raw), [{'model': 'Intel', 'dedicated_vram': None, 'shared_vram': '1536 MB'}])

    def test_other_platforms_cannot_be_accepted_by_documentation(self):
        """Неизмеренные ОС нельзя сделать reference или объявить релизный минимум."""
        for edit in (lambda p: p.update(release_minimum_approved=True),
                     lambda p: p['devices'][2].update(status='reference'),
                     lambda p: p['devices'].pop(),
                     lambda p: p['measurement'].update(runtime_quality_preset='low')):
            policy = deepcopy(self.policy)
            edit(policy)
            with self.subTest(edit=edit), self.assertRaises(ValueError): validate_policy(policy)

    def test_active_power_section_is_used(self):
        """В неактивной схеме противоположные настройки: чтение Battery не подменяется AC."""
        text = self.session['runs'][0]['before']['power_settings']
        self.assertEqual(active_power(text, 'Battery Power'), {'lowpowermode': '0', 'gpuswitch': '2'})
        self.assertEqual(active_power(text, 'AC Power'), {'lowpowermode': '1', 'gpuswitch': '0'})

    def test_changed_gpu_or_inventory_is_rejected(self):
        """Замена GPU, памяти или ОС после снимка не проходит даже с правильной игровой трассой."""
        for key, value in [('system', 'Linux'), ('os_version', 'other'), ('gpus', []), ('architecture', 'arm64')]:
            original = deepcopy(self.capture['after'])
            self.capture['after'][key] = value
            self.sign()
            self.assert_rejected()
            self.capture['after'] = original

    def test_same_wrong_camera_in_all_repeats_is_rejected(self):
        """Три одинаковые неверные камеры обходят равенство повторов, но не эталон профиля."""
        for i in range(1, 4): self.edit_run(i, lambda d: d.update(start_camera=[10, 348]))
        self.write_session(); self.sign()
        self.assert_rejected()

    def test_same_wrong_adapter_or_engine_in_all_repeats_is_rejected(self):
        """Равные повторы на другом адаптере не подтверждают выбранную физическую конфигурацию."""
        for i in range(1, 4): self.edit_run(i, lambda d: d.update(adapter='Intel UHD Graphics 630'))
        self.write_session(); self.sign()
        self.assert_rejected()

    def test_ac_and_battery_series_cannot_be_mixed(self):
        """Даже все повторы от сети не принимаются как батарейная серия."""
        for run in self.session['runs']:
            for stamp in (run['before'], run['after']): stamp['power'] = "Now drawing from 'AC Power'\n75%; charged;"
        self.write_session(); self.sign()
        self.assert_rejected()

    def test_charge_low_power_and_thermal_limits_are_rejected(self):
        """Низкий заряд, энергосбережение и явный лимит CPU не проходят профиль батареи."""
        original = deepcopy(self.session)
        cases = [('power', "Now drawing from 'Battery Power'\n49%; discharging;"),
                 ('power_settings', 'Battery Power:\n lowpowermode 1\n gpuswitch 2'),
                 ('power_settings', 'AC Power:\n lowpowermode 0\n gpuswitch 2'),
                 ('thermal', 'CPU_Speed_Limit = 75'), ('thermal', 'UNAVAILABLE')]
        for key, value in cases:
            self.session = deepcopy(original)
            for run in self.session['runs']:
                for stamp in (run['before'], run['after']): stamp[key] = value
            self.write_session(); self.sign()
            with self.subTest(key=key, value=value): self.assert_rejected()

    def test_resize_pause_and_focus_still_block_admission(self):
        """Отказ исходного baseline сохраняется в аппаратном gate, даже если valid подделан."""
        path = self.native / 'run-2/native.json'
        original = path.read_bytes()
        for edit in (lambda d: d['condition_groups'][0]['conditions'].update(framebuffer=[1000, 600], valid=True),
                     lambda d: d['condition_groups'][0]['conditions'].update(focused=False, valid=True),
                     lambda d: d['frames'][50].__setitem__(8, False)):
            path.write_bytes(original)
            self.edit_run(2, edit)
            self.assert_rejected()

    def test_stall_remains_valid_but_budget_fails(self):
        """Рывок в секунду остаётся в raw и выводе, аппаратный допуск не прячет FAIL бюджета."""
        def stall(data):
            """Сохраняет длинный интервал и согласованную накопленную шкалу времени."""
            extra = 1000000 - data['frames'][50][0]
            data['frames'][50][0] = 1000000
            for row in data['frames'][50:]: row[1] += extra
            data['interval_span_usec'] += extra
        self.edit_run(2, stall)
        self.write_session(); self.sign()
        result = verify(self.folder, self.policy)['repeats'][1]
        self.assertEqual(result['budget_60fps_candidate'], 'FAIL')
        self.assertEqual(result['draw']['max_ms'], 1000)

    def test_missing_or_modified_evidence_is_rejected(self):
        """Потеря подписи или изменённый PNG блокируют сохранённый пакет."""
        del self.capture['files']['native/run-1/start.png']
        (self.folder / 'capture.json').write_text(json.dumps(self.capture))
        self.assert_rejected()
        self.sign()
        (self.native / 'run-1/start.png').write_bytes(b'changed')
        self.assert_rejected()

    def test_signed_wrong_png_size_is_rejected(self):
        """Обновлённый SHA уменьшенного кадра не подтверждает настоящий framebuffer."""
        Image.new('RGB', (320, 180)).save(self.native / 'run-1/start.png')
        self.sign()
        self.assert_rejected()

    def test_stale_summary_source_and_path_escape_are_rejected(self):
        """Подписанная сводка, чужая ревизия и выход пути проверяются независимо от SHA."""
        self.capture['source'] = {'commit': 'f' * 40}
        self.sign()
        self.assert_rejected()
        self.capture['source'] = self.session['source']
        self.capture['files']['../outside'] = 'a' * 64
        (self.folder / 'capture.json').write_text(json.dumps(self.capture))
        self.assert_rejected()
        (self.native / 'summary.json').write_text('{}')
        self.sign()
        self.assert_rejected()

    def test_archived_ac_attempt_is_preserved_as_a_rejection(self):
        """Реальный старый отказ хранит три сырых повтора батареи и не становится принятым AC-замером."""
        folder = POLICY.parent / 'controls/ac-profile-rejected'
        record = json.loads((folder / 'capture.json').read_text())
        for name, signature in record['files'].items():
            path = (folder / name).resolve()
            self.assertTrue(path.is_relative_to(folder.resolve()))
            self.assertEqual(digest(path), signature)
        session = json.loads((folder / 'native/session.json').read_text())
        self.assertEqual(analyze_session(folder / 'native')['admission'], 'VALID_BASELINE')
        self.assertTrue(record['policy']['measurement']['power'].startswith('AC,'))
        for run in session['runs']:
            for stamp in (run['before'], run['after']):
                self.assertEqual(stamp['power'].splitlines()[0], "Now drawing from 'Battery Power'")
        self.assertEqual(json.loads((folder / 'rejection.json').read_text())['admission'], 'REJECTED')
        with self.assertRaisesRegex(ValueError, 'capture policy mismatch'):
            verify(folder, self.policy)

    def test_float_rounding_is_portable_but_material_difference_is_rejected(self):
        """Другая версия суммирования Python даёт допустимый ULP; заметная подмена среднего отклоняется."""
        path = self.native / 'summary.json'
        stored = json.loads(path.read_text())
        stored['repeats'][0]['draw']['mean_ms'] += 1e-12
        path.write_text(json.dumps(stored)); self.sign()
        self.assertEqual(verify(self.folder, self.policy)['admission'], 'VALID_REFERENCE_DEVICE')
        stored['repeats'][0]['draw']['mean_ms'] += 0.01
        path.write_text(json.dumps(stored)); self.sign()
        self.assert_rejected()

    def test_archived_instrumentation_is_required(self):
        """Историческая подпись инструмента должна иметь точный исходник, даже когда текущий код изменился."""
        (self.folder / 'instrumentation' / TOOLS[0]).write_text('different instrumentation')
        self.assert_rejected()


if __name__ == '__main__':
    unittest.main()
