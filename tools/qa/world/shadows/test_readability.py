"""Повреждает временные копии настоящего архива; synthetic кадры приёмкой не считаются."""

from __future__ import annotations

import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
import zlib
from collections.abc import Callable
from pathlib import Path
from typing import Any
from unittest.mock import patch

from PIL import Image, ImageChops

from tools.qa.world.shadows.contract import ROOT, digest
from tools.qa.world.shadows.pixels import changed, mask, opaque_core
from tools.qa.world.shadows.storage import artifact_bytes, validate_storage
from tools.qa.world.shadows.test_support import frozen_checkout
from tools.qa.world.shadows.verify import DEFAULT, read, verify


class NativeArchiveTests(unittest.TestCase):
    """Каждый отказ сохраняет исходный архив и не нуждается в запуске Godot."""

    def setUp(self) -> None:
        """Копия отделяет повреждение от принятого доказательства и остальных тестов."""
        self.temporary = tempfile.TemporaryDirectory(prefix="shadow real archive ")
        self.folder = Path(self.temporary.name) / "archive"
        shutil.copytree(DEFAULT, self.folder)
        validate_storage(self.folder, read(self.folder / "source.json"))
        for package in self.folder.glob("*.zip"):
            with zipfile.ZipFile(package) as archive:
                archive.extractall(self.folder)
            package.unlink()

    def tearDown(self) -> None:
        """Удаляет только созданную данным тестом временную копию."""
        self.temporary.cleanup()

    def source(self, change: Callable[[dict[str, Any]], None]) -> None:
        """Редактирует manifest для проверки семантики, сохраняя остальные записи."""
        path = self.folder / "source.json"
        data = read(path)
        change(data)
        path.write_text(json.dumps(data))

    def captured(self, change: Callable[[dict[str, Any]], None], key: str = "1152-on") -> None:
        """Обновлённый SHA позволяет дойти до содержательной проверки JSON."""
        relative = "frames/capture.json"
        path = self.folder / key / relative
        data = read(path)
        change(data)
        path.write_text(json.dumps(data))
        self.rehash(key, relative)

    def rehash(self, key: str, relative: str) -> None:
        """Повреждённый артефакт получает свой настоящий новый хеш, не обходя semantic gates."""
        path = self.folder / key / relative
        self.source(
            lambda data: data["runs"][key]["artifacts"].update(
                {relative: digest(path.read_bytes())}
            )
        )

    def test_real_archive_and_both_sizes(self) -> None:
        """Полный reader принимает исходные64 настоящих PNG, без исполнения producer."""
        result = verify(DEFAULT)
        self.assertTrue(result["acceptance_eligible"])
        self.assertFalse(result["performance_eligible"])
        self.assertEqual(len(result["results"]), 16)

    def test_previous_candidate_keeps_its_historical_result(self) -> None:
        """Предыдущие байты остаются читаемыми после смены рабочего callback и guard путей."""
        result = verify(DEFAULT.parent / "native")
        self.assertTrue(result["acceptance_eligible"])
        self.assertFalse(result["checked_current_candidate"])

    def test_old_production_reproduces_the_actual_loot_defect(self) -> None:
        """Тот же reader отклоняет настоящую исходную серию, а не нарисованную fixture."""
        with self.assertRaisesRegex(ValueError, "shadow covers opaque loot: stone"):
            verify(DEFAULT.parent / "native-before")

    def test_before_after_keep_save_and_pixels_outside_contacts(self) -> None:
        """В16 парах исправление меняет контакт, сохраняя прежний мир и остальные пиксели."""
        before = DEFAULT.parent / "native-before"
        for width in (1152, 1280):
            old = read(before / f"{width}-production/frames/capture.json")["frames"]
            new = read(self.folder / f"{width}-production/frames/capture.json")["frames"]
            contacts = read(self.folder / f"{width}-on/frames/capture.json")["frames"]
            for frame_id, frame in new.items():
                with self.subTest(width=width, frame=frame_id):
                    self.assertEqual(old[frame_id]["before"], frame["before"])
                    with Image.open(
                        io.BytesIO(
                            artifact_bytes(before / f"{width}-production/frames/{frame_id}.png")
                        )
                    ) as raw:
                        left = raw.convert("RGBA")
                    with Image.open(
                        self.folder / f"{width}-production/frames/{frame_id}.png"
                    ) as raw:
                        right = raw.convert("RGBA")
                    difference = changed(left, right)
                    self.assertIsNotNone(difference.getbbox())
                    self.assertIsNone(
                        ImageChops.subtract(
                            difference, mask(left.size, contacts[frame_id]["contacts"], 2)
                        ).getbbox()
                    )

    def test_strict_current_candidate_rejects_changed_runtime(self) -> None:
        """Исторический хеш не выдаёт изменённый render-код за текущий PR-кандидат."""
        name = "scripts/systems/hero_visual_system.gd"
        with frozen_checkout(self.folder) as repo:
            with (
                patch("tools.qa.world.shadows.contract.ROOT", repo),
                patch("tools.qa.world.shadows.verify.ROOT", repo),
            ):
                self.assertTrue(
                    verify(self.folder, check_current=True)["checked_current_candidate"]
                )
                path = repo / name
                path.write_bytes(path.read_bytes() + b"\n# changed after capture\n")
                with self.assertRaisesRegex(ValueError, "current runtime candidate mismatch"):
                    verify(self.folder, check_current=True)

    def test_partial_series_is_not_accepted(self) -> None:
        """Прерванный вывод нельзя превратить в приёмку наличием нескольких PNG."""
        self.source(lambda source: source.update(complete=False))
        with self.assertRaisesRegex(ValueError, "incomplete capture"):
            verify(self.folder)

    def test_one_width_is_diagnostic_only(self) -> None:
        """Явная диагностика проходит, обычная приёмка той же серии запрещена."""
        self.source(
            lambda source: source.update(
                runs={k: v for k, v in source["runs"].items() if k.startswith("1152-")}
            )
        )
        with self.assertRaisesRegex(ValueError, "both widths required"):
            verify(self.folder)
        self.assertFalse(verify(self.folder, diagnostic=True)["acceptance_eligible"])

    def packed_copy(self) -> Path:
        """Копирует контейнеры для повреждения, сохраняя нормативный архив."""
        target = Path(self.temporary.name) / "packed"
        shutil.copytree(DEFAULT, target)
        return target

    def test_zip_corruption_is_not_accepted_as_original_bytes(self) -> None:
        """Портит compressed data настоящего capture.json; CRC/decoder должны отказать."""
        target = self.packed_copy()
        package = target / "1152.zip"
        with zipfile.ZipFile(package) as archive:
            entry = archive.getinfo("1152-on/frames/capture.json")
        with package.open("r+b") as stream:
            stream.seek(entry.header_offset)
            header = stream.read(30)
            name_size, extra_size = struct.unpack_from("<HH", header, 26)
            offset = entry.header_offset + 30 + name_size + extra_size + entry.compress_size // 2
            stream.seek(offset)
            byte = stream.read(1)
            stream.seek(offset)
            stream.write(bytes([byte[0] ^ 255]))
        with self.assertRaises((zipfile.BadZipFile, zlib.error, EOFError)):
            verify(target)

    def test_zip_cannot_hide_an_extra_path(self) -> None:
        """Лишний traversal-member отклоняется до чтения кадров и не извлекается."""
        target = self.packed_copy()
        with zipfile.ZipFile(target / "1152.zip", "a") as archive:
            archive.writestr("../must-not-exist", b"forbidden")
        with self.assertRaisesRegex(ValueError, "ZIP artifact inventory"):
            verify(target)
        self.assertFalse((target.parent / "must-not-exist").exists())

    def test_raw_and_zip_copies_are_not_silently_mixed(self) -> None:
        """Отдельный файл поверх ZIP не может незаметно заменить нормативный JSON."""
        target = self.packed_copy()
        path = target / "1152-on/frames/capture.json"
        path.parent.mkdir(parents=True)
        path.write_bytes(artifact_bytes(DEFAULT / "1152-on/frames/capture.json"))
        with self.assertRaisesRegex(ValueError, "ambiguous raw/ZIP"):
            verify(target)

    def test_qa_input_cannot_be_omitted(self) -> None:
        """Нельзя убрать скрипт из manifest и перестать проверять его происхождение."""
        self.source(lambda source: source["qa_inputs"].pop(next(iter(source["qa_inputs"]))))
        with self.assertRaisesRegex(ValueError, "QA input inventory"):
            verify(self.folder)

    def test_changed_overlay_even_with_updated_hash_is_rejected(self) -> None:
        """Настоящий код фонаря вне ограниченной вставки не становится допустимым overlay."""
        name = "scripts/presentation/village_lamp_visual.gd"
        path = self.folder / "overlays" / name
        path.write_bytes(path.read_bytes() + b"\n# unauthorized glow/body change\n")
        self.source(
            lambda source: source["overlays"][name].update(instrumented=digest(path.read_bytes()))
        )
        with self.assertRaisesRegex(ValueError, "unexpected instrumentation"):
            verify(self.folder)

    def test_png_bytes_and_inventory_are_required(self) -> None:
        """И удалённый кадр, и удалённая вместе с ним запись SHA дают отказ."""
        key, relative = "1152-on", "frames/farm-720.png"
        (self.folder / key / relative).unlink()
        self.source(lambda source: source["runs"][key]["artifacts"].pop(relative))
        with self.assertRaisesRegex(ValueError, "artifact inventory"):
            verify(self.folder)

    def test_native_settings_and_actual_arguments(self) -> None:
        """Чужой профиль/окно/renderer не принимаются после пересчёта SHA JSON."""
        self.captured(lambda data: data.update(display="headless"))
        with self.assertRaisesRegex(ValueError, "native renderer"):
            verify(self.folder)

    def test_fake_actual_argv_is_rejected(self) -> None:
        """Декларация команды не заменяет фактические user argv, записанные самим движком."""
        self.captured(lambda data: data["user_arguments"].append("--without-contacts"))
        with self.assertRaisesRegex(ValueError, "actual user arguments"):
            verify(self.folder)

    def test_state_mutation_and_missing_callback_are_rejected(self) -> None:
        """Отрисовка не вправе тратить HP, и одного наблюдаемого draw недостаточно."""
        self.captured(lambda data: data["frames"]["farm-720"]["after"].update(hp=-1))
        with self.assertRaisesRegex(ValueError, "drawing mutated save"):
            verify(self.folder)

    def test_callback_count_is_not_inferred_from_png(self) -> None:
        """Настоящий кадр с удалённой записью callback не проходит по одному PNG."""
        self.captured(lambda data: data["frames"]["farm-720"]["draws"].pop())
        with self.assertRaisesRegex(ValueError, "two draw callbacks"):
            verify(self.folder)

    def test_duplicate_actual_contact_is_rejected(self) -> None:
        """Второй вызов при той же геометрии не маскируется общей областью тени."""
        self.captured(
            lambda data: data["frames"]["farm-720"]["contacts"].append(
                data["frames"]["farm-720"]["contacts"][0]
            )
        )
        with self.assertRaisesRegex(ValueError, "duplicate contact draw"):
            verify(self.folder)

    def test_exit_zero_does_not_hide_a_colored_engine_error(self) -> None:
        """Обновление хеша журнала и code0 не превращают ERROR в успешную серию."""
        key = "1152-on"
        path = self.folder / key / "engine.txt"
        path.write_text(path.read_text() + "\n  \x1b[31mERROR:\x1b[0m injected engine failure\n")
        self.rehash(key, "engine.txt")
        with self.assertRaisesRegex(ValueError, "engine error"):
            verify(self.folder)

    def test_paired_world_seed_is_required(self) -> None:
        """Ранее найденный сброс seed не скрывается одинаковыми камерой и часами."""
        self.captured(lambda data: data["frames"]["farm-720"]["snapshot"].update(seed=1))
        with self.assertRaisesRegex(ValueError, "deterministic seed"):
            verify(self.folder)

    def test_changed_body_cannot_be_hidden_by_rehashing_png(self) -> None:
        """Порча настоящего тела вне контакта отклоняется, даже если production и on совпали."""
        for key in ("1152-on", "1152-production"):
            relative = "frames/farm-720.png"
            path = self.folder / key / relative
            with Image.open(path) as source:
                image = source.convert("RGBA")
            image.putpixel((576, 275), (255, 0, 255, 255))
            image.save(path)
            self.rehash(key, relative)
        with self.assertRaisesRegex(ValueError, "outside contact bounds"):
            verify(self.folder)

    def test_opaque_loot_cannot_be_painted_inside_allowed_shadow_bounds(self) -> None:
        """Реальный внутренний пиксель камня повреждается внутри допустимой области контакта."""
        folder = self.folder / "1152-on/frames"
        frame = read(folder / "capture.json")["frames"]["farm-720"]
        item = next(value for value in frame["loot"] if value["kind"] == "stone")
        with Image.open(folder / "farm-720.png") as raw:
            on = raw.convert("RGBA")
        with Image.open(self.folder / "1152-no-loot/frames/farm-720.png") as raw:
            no_loot = raw.convert("RGBA")
        with Image.open(folder / "loot-source-stone.png") as raw:
            core = opaque_core(on.size, raw.convert("RGBA"), item)
        core = ImageChops.multiply(core, mask(on.size, frame["contacts"], 2))
        core = ImageChops.multiply(core, changed(on, no_loot))
        point = next(
            (x, y) for y in range(core.height) for x in range(core.width) if core.getpixel((x, y))
        )
        for key in ("1152-on", "1152-production"):
            relative = "frames/farm-720.png"
            path = self.folder / key / relative
            with Image.open(path) as raw:
                image = raw.convert("RGBA")
            image.putpixel(point, (255, 0, 255, 255))
            image.save(path)
            self.rehash(key, relative)
        with self.assertRaisesRegex(ValueError, "shadow covers opaque loot: stone"):
            verify(self.folder)

    def test_cli_from_foreign_cwd_and_hostile_environment(self) -> None:
        """Настоящий CLI игнорирует подложные tools/Git и сохраняет чужие index/config."""
        foreign = Path(self.temporary.name) / "foreign"
        foreign.mkdir()
        (foreign / "tools").mkdir()
        (foreign / "tools/__init__.py").write_text('raise RuntimeError("foreign import")\n')
        index = foreign / "index"
        index.write_bytes(b"foreign-index")
        env = {
            **os.environ,
            "PYTHONPATH": str(foreign),
            "GIT_DIR": str(foreign),
            "GIT_INDEX_FILE": str(index),
        }
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools/run.py"),
                "qa.world.shadows.verify",
                "--input",
                str(self.folder),
            ],
            cwd=foreign,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["acceptance_eligible"])
        self.assertEqual(index.read_bytes(), b"foreign-index")


if __name__ == "__main__":
    unittest.main()
