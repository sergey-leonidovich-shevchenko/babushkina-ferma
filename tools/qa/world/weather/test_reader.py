"""Портит копии настоящего CI-архива; новые пиксели и синтетический native PASS не создаются."""

from __future__ import annotations

import json
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.weather import contract as c
from tools.qa.world.weather.archive import unpack
from tools.qa.world.weather.verify import verify

FIXTURE = c.ROOT / "docs/reports/visual-overhaul/vweather-001/failures/ci-01-artifact.zip"


class ReaderTests(unittest.TestCase):
    """Диагностический CI1 сохраняет статус failure; здесь проверяется исправленный reader."""

    def setUp(self) -> None:
        """Каждый сценарий получает отдельную извлечённую копию подлинного архива."""
        self.temporary = tempfile.TemporaryDirectory(prefix="weather-real-reader-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        with unpack(FIXTURE) as source:
            self.folder = self.root / "copy"
            shutil.copytree(source, self.folder)
        self.source: dict[str, Any] = json.loads((self.folder / "source.json").read_text())

    def write_document(self, name: str, value: Any) -> None:
        """Обновляет hash испорченного документа, чтобы semantic отказ не сводился к checksum."""
        raw = (json.dumps(value, ensure_ascii=False) + "\n").encode()
        (self.folder / name).write_bytes(raw)
        self.source["artifacts"][name] = c.digest(raw)
        (self.folder / "source.json").write_text(json.dumps(self.source) + "\n")

    def replace_image(self, target: str, source: str) -> None:
        """Переносит только уже снятые настоящие пиксели; исходный ZIP остаётся неизменным."""
        raw = (self.folder / source).read_bytes()
        (self.folder / target).write_bytes(raw)
        self.source["artifacts"][target] = c.digest(raw)
        (self.folder / "source.json").write_text(json.dumps(self.source) + "\n")

    def candidate(self) -> dict[str, Any]:
        """Читает одну действительную оконную серию для адресной порчи копии."""
        document: dict[str, Any] = json.loads(
            (self.folder / "candidate/1152/capture.json").read_text()
        )
        return document

    def test_real_archive_has_complete_corrected_semantics(self) -> None:
        """Положительный контроль использует все 160 фактических PNG и настоящие Git-входы."""
        result = verify(self.folder, self.source["head"])
        self.assertEqual(result["native_png"], 160)
        self.assertFalse(result["hardware_fps_acceptance"])

    def test_same_real_bundle_reproduces_old_camera_policy_refusal(self) -> None:
        """Запускает настоящий прежний CLI из captured Git; ошибка не моделируется mock."""
        old = self.root / "old-reader.py"
        old.write_bytes(c.git("show", self.source["head"] + ":" + c.PREFIX + "verify.py"))
        environment = git_environment()
        environment["PYTHONPATH"] = str(c.ROOT)
        result = subprocess.run(
            [
                sys.executable,
                str(old),
                "--output",
                str(self.folder),
                "--expected-head",
                self.source["head"],
            ],
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("actual accepted 120% camera differs", result.stderr)
        self.assertEqual(verify(self.folder)["native_png"], 160)

    def test_overworld_cannot_use_interior_zoom(self) -> None:
        """100% вне дома остаётся нарушением; исправление не отключает контроль камеры."""
        document = self.candidate()
        for phase in ("before", "after"):
            document["frames"]["rain-pause-a"][phase]["zoom"] = 1.0
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "actual location camera differs"):
            verify(self.folder)

    def test_interior_cannot_use_overworld_zoom(self) -> None:
        """120% внутри дома отвергается по сохранённой политике исходного renderer."""
        document = self.candidate()
        for phase in ("before", "after"):
            document["frames"]["rain-interior"][phase]["zoom"] = 1.2
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "actual location camera differs"):
            verify(self.folder)

    def test_paused_metadata_does_not_hide_moving_pixels(self) -> None:
        """Подставляет настоящий resumed PNG при прежней paused phase и корректном hash."""
        self.replace_image("candidate/1152/rain-pause-b.png", "candidate/1152/rain-resume.png")
        with self.assertRaisesRegex(ValueError, "weather pixels moved while paused"):
            verify(self.folder)

    def test_empty_weather_is_not_a_successful_freeze(self) -> None:
        """Пустые cold/return совпадают, но отсутствие самого дождя всё равно даёт отказ."""
        for target in ("rain-cold", "rain-return"):
            self.replace_image("candidate/1152/" + target + ".png", "candidate/1152/clear-cold.png")
        with self.assertRaisesRegex(ValueError, "precipitation draw is empty"):
            verify(self.folder)

    def test_resume_cannot_accumulate_wall_time(self) -> None:
        """Сохранённая PNG не позволяет объявить скачок фазы после меню корректным."""
        document = self.candidate()
        for phase in ("before", "after"):
            document["frames"]["rain-resume"][phase]["phase"] = 12.06
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "resume accumulated wall-time debt"):
            verify(self.folder)

    def test_viewport_cannot_receive_neighbours_clock(self) -> None:
        """Реальным раздельным PNG подставляет чужую фазу; reader проверяет оба контракта."""
        document = self.candidate()
        for phase in ("before", "after"):
            document["twins"]["0"][0][phase]["phase"] = 0.04
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "viewport clock leaked"):
            verify(self.folder)

    def test_native_viewport_owners_are_distinct(self) -> None:
        """Одинаковые владельцы не проходят даже при различных кадрах и верных фазах."""
        document = self.candidate()
        for phase in ("before", "after"):
            document["twins"]["0"][0][phase]["owner"] = document["twins"]["0"][1][phase]["owner"]
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "viewport owners are shared"):
            verify(self.folder)

    def test_draw_cannot_change_snapshot(self) -> None:
        """Добавляет поле только в after-save; checksum пересчитан, но draw остаётся грязным."""
        document = self.candidate()
        document["frames"]["rain-pause-a"]["after"]["save"]["unexpected_draw_field"] = 1
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "draw mutated"):
            verify(self.folder)

    def test_declared_window_matches_actual_contract(self) -> None:
        """Ложное физическое разрешение не заменяет размер снятого viewport."""
        document = self.candidate()
        document["window"] = [1920, 1080]
        self.write_document("candidate/1152/capture.json", document)
        with self.assertRaisesRegex(ValueError, "physical window differs"):
            verify(self.folder)

    def test_zip_parent_path_is_rejected(self) -> None:
        """Настоящая вредная запись не может выйти из собственной временной папки."""
        archive = self.root / "parent.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("../escape.json", "{}")
        with self.assertRaisesRegex(ValueError, "unsafe archive path"):
            with unpack(archive):
                self.fail("unsafe ZIP was accepted")

    def test_zip_symlink_is_rejected(self) -> None:
        """Symlink из ZIP не превращается в доступ к данным за пределами evidence."""
        archive = self.root / "symlink.zip"
        entry = zipfile.ZipInfo("linked")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr(entry, "/outside")
        with self.assertRaisesRegex(ValueError, "symlink or special"):
            with unpack(archive):
                self.fail("symlink ZIP was accepted")

    def test_zip_duplicate_is_rejected(self) -> None:
        """Дубликат manifest не позволяет выбрать другой source после проверки."""
        archive = self.root / "duplicate.zip"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr("source.json", "{}")
                bundle.writestr("source.json", "{}")
        with self.assertRaisesRegex(ValueError, "duplicate archive entry"):
            with unpack(archive):
                self.fail("duplicate ZIP was accepted")


if __name__ == "__main__":
    unittest.main()
