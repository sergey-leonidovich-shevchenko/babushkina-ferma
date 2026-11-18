"""Проверяет отказы доказательства синхронизации без запуска игрового движка."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from tools.qa.ground import color_patch_sync as sync


class ColorPatchSyncTests(unittest.TestCase):
    """Не позволяет принять произвольный сбой или подменённый readback за регрессию."""

    def evidence(self, historical: bool) -> dict[str, Any]:
        """Создаёт минимальный паспорт для проверки границы доверия валидатора."""
        pixel = "00ff00ff" if historical else "ff0000ff"
        return {
            "schema": 1,
            "task": "QA-06",
            "display": "X11",
            "engine": "4.7.1-stable (official)",
            "window": [1152, 648],
            "initial": "00ff00ff",
            "requested": "ff0000ff",
            "readback": pixel,
            "exit_code": 1 if historical else 0,
            "performance_eligible": False,
            "trace": [
                "request:1",
                *([] if historical else ["draw:1", "complete"]),
                "read:" + pixel,
            ],
        }

    def test_distinguishes_expected_old_failure_from_infrastructure(self) -> None:
        """Сценарий: старый процесс завершился с разными кодами.
        Исходное состояние: паспорт подтверждает зелёный кеш после запроса красного.
        Ожидаемый результат: только намеренный код 1 принимается как доказанный дефект.
        """
        proof = self.evidence(True)
        sync.validate_probe(proof, 1, True, 1152, "00ff00ff")
        for code in (0, 2, -9):
            with self.subTest(code=code), self.assertRaises(ValueError):
                sync.validate_probe(proof, code, True, 1152, "00ff00ff")

    def test_candidate_requires_actual_draw_before_completion_and_read(self) -> None:
        """Сценарий: паспорт утверждает успех без свежих команд либо с неправильным порядком.
        Исходное состояние: красный пиксель сам по себе выглядит правильным.
        Ожидаемый результат: принимается только запрос → draw → завершение → чтение.
        """
        proof = self.evidence(False)
        sync.validate_probe(proof, 0, False, 1152, "ff0000ff")
        for trace in (
            ["request:1", "complete", "read:ff0000ff"],
            ["request:1", "complete", "draw:1", "read:ff0000ff"],
            ["draw:1", "request:1", "complete", "read:ff0000ff"],
            ["request:1", "draw:1", "draw:1", "complete", "read:ff0000ff"],
        ):
            with self.subTest(trace=trace), self.assertRaises(ValueError):
                sync.validate_probe({**proof, "trace": trace}, 0, False, 1152, "ff0000ff")

    def test_png_and_case_identity_cannot_be_replaced_by_json_claim(self) -> None:
        """Сценарий: файл PNG, окно, исходный цвет или запрошенное состояние не совпадают.
        Исходное состояние: остальной паспорт сообщает успешный новый кадр.
        Ожидаемый результат: независимый пиксель и обязательные поля не обходятся паспортом.
        """
        proof = self.evidence(False)
        with self.assertRaises(ValueError):
            sync.validate_probe(proof, 0, False, 1152, "00ff00ff")
        for field, value in (
            ("display", "headless"),
            ("window", [1280, 720]),
            ("engine", "4.6.stable"),
            ("initial", "ff0000ff"),
            ("requested", "00ff00ff"),
            ("performance_eligible", True),
        ):
            with self.subTest(field=field), self.assertRaises(ValueError):
                sync.validate_probe({**proof, field: value}, 0, False, 1152, "ff0000ff")

    def test_old_failure_must_precede_fresh_commands(self) -> None:
        """Сценарий: красные команды уже собраны, но старый паспорт сообщает зелёный кеш.
        Исходное состояние: код 1 похож на ожидаемый отказ.
        Ожидаемый результат: другая причина не выдаётся за исследуемое опережение draw.
        """
        proof = self.evidence(True)
        proof["trace"].insert(1, "draw:1")
        with self.assertRaises(ValueError):
            sync.validate_probe(proof, 1, True, 1152, "00ff00ff")

    def test_requires_native_engine_string_not_cli_version(self) -> None:
        """Сценарий: JSON использует get_version_info().string, а не строку CLI.
        Исходное состояние: формат подтверждён первым нативным артефактом QA-06.
        Ожидаемый результат: точная официальная версия проходит, другие отвергаются.
        """
        proof = self.evidence(False)
        sync.validate_probe(proof, 0, False, 1152, "ff0000ff")
        for version in (
            "4.7.1.stable.official",
            "4.7.1-stable (custom)",
            "4.7.2-stable (official)",
        ):
            with self.subTest(version=version), self.assertRaises(ValueError):
                sync.validate_probe({**proof, "engine": version}, 0, False, 1152, "ff0000ff")

    def test_engine_errors_never_count_as_expected_historical_failure(self) -> None:
        """Сценарий: старый процесс завершился кодом 1 с ошибкой движка в журнале.
        Исходное состояние: имитируются реальные ALSA/GLES и ошибки скрипта из CI.
        Ожидаемый результат: отказ до чтения паспорта, журнал сохраняется для разбора.
        """
        for error in (
            b'ERROR: Condition "status < 0" is true.\n',
            b'ERROR: Condition "f.is_null()" is true.\n',
            b"SCRIPT ERROR: Parse Error\n",
        ):
            with self.subTest(error=error), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)

                def engine(*args: Any, error: bytes = error, **kwargs: Any) -> Any:
                    kwargs["stdout"].write(error)
                    return sync.subprocess.CompletedProcess(args[0], 1)

                with patch.object(sync.subprocess, "run", side_effect=engine):
                    with self.assertRaisesRegex(ValueError, "engine error"):
                        sync.run_case(Path("unused"), output, "unused", 1152, True)
                self.assertEqual((output / "historical-1152.log").read_bytes(), error)

    def test_extracts_only_exact_historical_method_and_rejects_ambiguity(self) -> None:
        """Сценарий: извлечение старого метода окружено соседними функциями.
        Исходное состояние: реальные закреплённые байты доступны из Git.
        Ожидаемый результат: сохраняется тело метода; отсутствие и дубликат отклоняются.
        """
        source = sync.read_git_blob(sync.ROOT, sync.CAPTURE, sync.BASELINE, sync.BASELINE_SHA)
        method = sync.redraw_method(source)
        self.assertIn("RenderingServer.force_draw(false)", method)
        self.assertNotIn("func _settle", method)
        self.assertIn(method.encode(), source)
        for invalid in (b"", source + method.encode()):
            with self.assertRaises(ValueError):
                sync.redraw_method(invalid)

    def test_output_never_overwrites_or_follows_symlink(self) -> None:
        """Сценарий: вывод уже существует, находится в проекте либо проходит через ссылку.
        Исходное состояние: отдельные временные каталоги и файл-маркер.
        Ожидаемый результат: все опасные назначения отклонены, маркер сохранён.
        """
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory).resolve()
            root = parent / "project"
            root.mkdir()
            (root / "marker").write_text("preserve")
            link = parent / "link"
            link.symlink_to(root, target_is_directory=True)
            for target in (root, root / "new", link / "new"):
                with self.subTest(target=target), self.assertRaises(ValueError):
                    sync.fresh_output(target, root)
            fresh = sync.fresh_output(parent / "evidence", root)
            self.assertTrue(fresh.is_dir())
            with self.assertRaises(ValueError):
                sync.fresh_output(fresh, root)
            self.assertEqual((root / "marker").read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
