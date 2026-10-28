#!/usr/bin/env python3
"""Портит копии фиксированных входов и настоящего минимального вывода Godot, не игровые PNG."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from PIL import Image
from tools.assets.contracts.source_paths import current_source

from tools.assets.contracts.preview_portability import ROOT, FIXTURE, read, sha, validate_inputs, validate_report, validate_ui


class PortabilityTests(unittest.TestCase):
    """Сохраняет byte-exact контроль исходников и проверяет независимый пересчёт диагностики."""

    @classmethod
    def setUpClass(cls):
        """Один раз выполняет настоящий fitter на тех же четырёх входах в отдельном минимальном проекте."""
        cls.base_temp = tempfile.TemporaryDirectory(prefix="farm-preview-unit-")
        cls.base = Path(cls.base_temp.name)
        shutil.copytree(ROOT / FIXTURE.parent, cls.base / FIXTURE.parent)
        (cls.base / "tools").mkdir()
        for name in ["item_ui_fitter.gd", "preview_portability_capture.gd"]:
            destination = current_source(cls.base, 'tools/' + name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(current_source(ROOT, 'tools/' + name), destination)
        (cls.base / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Codex Preview Unit"\n[debug]\nfile_logging/enable_file_logging=false\n'
        )
        godot = os.environ.get(
            "FARM_GODOT_BIN", str(ROOT / "tools/Godot.app/Contents/MacOS/Godot")
        )
        command = [
            godot,
            "--headless",
            "--path",
            str(cls.base),
            "--script",
            "res://tools/assets/contracts/preview_portability_capture.gd",
            "--",
            "--output=" + str(cls.base / "result"),
        ]
        run = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if run.returncode or "ERROR:" in run.stdout + run.stderr:
            cls.base_temp.cleanup()
            raise RuntimeError(run.stdout + run.stderr)

    @classmethod
    def tearDownClass(cls):
        """Удаляет только созданный этим классом временный проект."""
        cls.base_temp.cleanup()

    def setUp(self):
        """Копирует маленькие входы и реальный результат для независимой порчи каждого сценария."""
        self.temp = tempfile.TemporaryDirectory(prefix="farm-preview-negative-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        shutil.copytree(self.base, self.root)

    def change_manifest(self, change):
        """Меняет только JSON одной тестовой копии."""
        data = read(self.root / FIXTURE)
        change(data)
        (self.root / FIXTURE).write_text(json.dumps(data))

    def change_report(self, change):
        """Меняет только диагностический отчёт одной тестовой копии."""
        path = self.root / "result/report.json"
        data = read(path)
        change(data)
        path.write_text(json.dumps(data))

    def test_real_fixed_input_capture_is_valid(self):
        """Настоящие входы и вывод Godot проходят проверку независимо от наличия платформенных отличий."""
        self.assertEqual(validate_inputs(self.root), [])
        self.assertEqual(validate_report(self.root / "result", self.root), [])

    def test_raw_rgba_changed_is_rejected(self):
        """Один изменённый байт исходного RGBA не скрывается за прежней PNG-сериализацией."""
        path = self.root / read(self.root / FIXTURE)["cases"][0]["source_rgba_file"]
        data = bytearray(path.read_bytes())
        data[0] ^= 1
        path.write_bytes(data)
        self.assertTrue(
            any("raw RGBA" in error for error in validate_inputs(self.root))
        )

    def test_reference_pixel_changed_is_rejected_exactly(self):
        """Даже невидимый RGB-байт реального reference PNG получает отказ без допуска 1/255."""
        path = self.root / read(self.root / FIXTURE)["cases"][0]["reference_file"]
        with Image.open(path) as source:
            image = source.copy()
        image.putpixel((0, 0), (1, 0, 0, 0))
        image.save(path)
        self.assertTrue(
            any("reference file/RGBA" in error for error in validate_inputs(self.root))
        )

    def test_source_file_corruption_is_rejected(self):
        """Повреждение PNG-файла не подменяется проверкой одного декодированного хеша."""
        path = self.root / read(self.root / FIXTURE)["cases"][0]["source_file"]
        path.write_bytes(b"not PNG")
        self.assertTrue(validate_inputs(self.root))

    def test_bounds_and_case_coverage_are_fixed(self):
        """Неверные bounds и потеря одного из четырёх случаев обнаруживаются отдельно."""
        self.change_manifest(
            lambda data: data["cases"][0].update(bounds=[0, 0, 175, 206])
        )
        self.assertTrue(any("bounds" in error for error in validate_inputs(self.root)))
        self.change_manifest(lambda data: data["cases"].pop())
        self.assertTrue(
            any("fixed cases" in error for error in validate_inputs(self.root))
        )

    def test_engine_and_fitter_are_pinned(self):
        """Другой движок и изменение прежней функции масштабирования блокируют эксперимент."""
        self.change_manifest(lambda data: data.update(engine_hash="0" * 40))
        self.assertTrue(any("engine" in error for error in validate_inputs(self.root)))
        with (current_source(self.root, 'tools/item_ui_fitter.gd')).open("a") as file:
            file.write("\n# modified\n")
        self.assertTrue(any("fitter" in error for error in validate_inputs(self.root)))

    def test_paths_cannot_escape_fixture_root(self):
        """Относительный выход за корень не читается валидатором."""
        self.change_manifest(
            lambda data: data["cases"][0].update(source_file="../../unrelated.png")
        )
        self.assertTrue(
            any("outside root" in error for error in validate_inputs(self.root))
        )

    def test_diagnostic_cannot_claim_game_acceptance(self):
        """Зелёный сбор диагностики не превращается в принятие byte-exact игрового теста."""
        self.change_report(lambda data: data.update(purpose="accepted"))
        self.assertTrue(
            any(
                "cannot claim acceptance" in error
                for error in validate_report(self.root / "result", self.root)
            )
        )

    def test_recomputed_count_and_coordinates_are_checked(self):
        """Поддельные число, координата и канал отличия отвергаются по настоящим PNG."""
        self.change_report(
            lambda data: data["cases"][0].update(
                differing_bytes=999, samples=[{"x": 99, "channel": "a"}]
            )
        )
        errors = validate_report(self.root / "result", self.root)
        self.assertTrue(any("differing_bytes" in error for error in errors))
        self.assertTrue(any("samples" in error for error in errors))

    def test_derived_image_corruption_is_rejected(self):
        """Повреждённый результат не принимается при сохранённых метриках отчёта."""
        path = (
            self.root
            / "result"
            / read(self.root / "result/report.json")["cases"][0]["derived_file"]
        )
        with Image.open(path) as source:
            image = source.copy()
        image.putpixel((30, 30), (255, 0, 255, 255))
        image.save(path)
        self.assertTrue(
            any(
                "derived" in error or "recomputed" in error
                for error in validate_report(self.root / "result", self.root)
            )
        )

    def test_png_serialization_is_not_raw_rgba_identity(self):
        """Смешение хеша файла и RGBA не проходит даже при корректной форме SHA-256."""
        self.change_report(
            lambda data: data["cases"][0].update(
                source_rgba_sha256=data["cases"][0]["source_file_sha256"]
            )
        )
        self.assertTrue(
            any(
                "source_rgba_sha256" in error
                for error in validate_report(self.root / "result", self.root)
            )
        )

    def test_partial_or_unknown_current_source_map_is_rejected(self):
        """Metadata не выбирает внешний файл и не маскирует неполный новый layout."""
        for paths in [{'tools/item_ui_fitter.gd': 'outside'}, {'unknown': 'outside'}, None]:
            self.change_report(lambda data: data.update(source_paths=paths))
            self.assertTrue(any('source paths' in error
                                for error in validate_report(self.root / 'result', self.root)))

    def test_current_capture_cannot_drop_layout_and_use_legacy_reader(self):
        """Прежний Git pin не принимает SHA реально нового collector после удаления карты."""
        self.change_report(lambda data: data.pop('source_paths'))
        self.assertTrue(any('collector_sha256' in error
                            for error in validate_report(self.root / 'result', self.root)))

    def test_current_layout_cannot_claim_old_collector_sha(self):
        """Точная новая карта требует байты текущего collector, а не старую фиксированную подпись."""
        from tools.assets.contracts.preview_portability import LEGACY_COLLECTOR
        self.change_report(lambda data: data.update(collector_sha256=LEGACY_COLLECTOR[2]))
        self.assertTrue(any('collector_sha256' in error
                            for error in validate_report(self.root / 'result', self.root)))

    def test_current_collector_bytes_remain_checked(self):
        """Изменённый текущий инструмент не скрывается исторической веткой проверки."""
        with current_source(self.root, 'tools/preview_portability_capture.gd').open('a') as file:
            file.write('\n# changed current collector\n')
        self.assertTrue(any('collector_sha256' in error
                            for error in validate_report(self.root / 'result', self.root)))


class HudPortabilityTests(unittest.TestCase):
    """Портит только копии настоящих macOS-кадров и наблюдённых вызовов интерфейса."""

    def setUp(self):
        """Отделяет каждый сценарий от постоянного нативного архива."""
        self.temp = tempfile.TemporaryDirectory(prefix="farm-hud-negative-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name) / "ui"
        source = ROOT / "docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac/ui"
        shutil.copytree(source, self.folder)

    def change(self, update):
        """Меняет одну копию JSON, не источник архивной съёмки."""
        path = self.folder / "report.json"
        data = read(path)
        update(data)
        path.write_text(json.dumps(data))

    def test_real_six_locale_capture_is_valid(self):
        """Все пятнадцать реальных кадров и полный нулевой аудит проходят независимую сверку."""
        self.assertEqual(validate_ui(self.folder), [])

    def test_one_pixel_even_with_updated_file_hash_is_rejected(self):
        """Новый файловый SHA не скрывает изменение одного видимого RGBA-канала."""
        report = read(self.folder / "report.json")
        path = self.folder / report["cases"][3]["frame"]
        with Image.open(path) as original:
            image = original.copy()
        red, green, blue, alpha = image.getpixel((0, 0))
        image.putpixel((0, 0), (red ^ 1, green, blue, alpha))
        image.save(path)
        self.change(
            lambda data: data["cases"][3].update(file_sha256=sha(path.read_bytes()))
        )
        self.assertTrue(any("RGBA" in error for error in validate_ui(self.folder)))

    def test_missing_locale_cannot_claim_complete_coverage(self):
        """Потеря китайской контрольной подсказки нарушает точное покрытие."""
        self.change(lambda data: data["cases"].pop())
        self.assertTrue(any("coverage" in error for error in validate_ui(self.folder)))

    def test_smaller_font_is_not_a_fix(self):
        """Кегль семь не принимается даже при нулевом summary-аудите."""
        self.change(lambda data: data["cases"][3]["draws"][0].update(effective_size=7))
        self.assertTrue(
            any("unreadable" in error for error in validate_ui(self.folder))
        )

    def test_fourth_line_is_not_silently_clipped(self):
        """Четвёртая строка не проходит за счёт прежнего max_lines=3."""
        self.change(lambda data: data["cases"][3]["draws"][0].update(line_count=4))
        self.assertTrue(any("clipped" in error for error in validate_ui(self.folder)))

    def test_duplicate_frame_is_not_four_real_draws(self):
        """Четыре одинаковых записи одного process-frame получают отказ."""
        self.change(
            lambda data: data["cases"][3].update(
                draws=[data["cases"][3]["draws"][0]] * 4
            )
        )
        self.assertTrue(any("callbacks" in error for error in validate_ui(self.folder)))

    def test_missing_actual_font_and_wrong_geometry_are_rejected(self):
        """Имя запрошенного семейства не заменяет фактически наблюдённые font RID и геометрию."""
        self.change(
            lambda data: data["cases"][3]["draws"][0].update(families=[], width=300)
        )
        self.assertTrue(
            any("font identity" in error for error in validate_ui(self.folder))
        )

    def test_draw_cannot_mutate_saved_state(self):
        """Изменение монет между настоящими draw не считается чистой UI-проверкой."""
        self.change(lambda data: data["cases"][3]["after"].update(coins=999999))
        self.assertTrue(any("state" in error for error in validate_ui(self.folder)))

    def test_fallback_list_is_not_evidence_of_selected_glyph_font(self):
        """Полный список fallback не заменяет отсутствующую гарнитуру реально сформированных глифов."""
        self.change(lambda data: data["cases"][3]["draws"][0].update(used_faces=[]))
        self.assertTrue(
            any("font identity" in error for error in validate_ui(self.folder))
        )

    def test_capture_cannot_claim_hardware_or_wrong_scale(self):
        """Нативная картинка не разрешает объявить физическую или уменьшенную по масштабу приёмку."""
        self.change(
            lambda data: data.update(purpose="hardware_accepted", text_scale=1.0)
        )
        self.assertTrue(any("purpose" in error for error in validate_ui(self.folder)))


if __name__ == "__main__":
    unittest.main()
