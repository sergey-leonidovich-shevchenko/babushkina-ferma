"""Проверяет реальный source-overlay и Git/path-границы нового светового аудита."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.common.git import git_environment
from tools.qa.world.lighting import contract

CAPTURED_COMMIT = "dc4429f89be9ddc29cf5a052ae4dd665fbfd71df"


def captured_source(name: str) -> bytes:
    """VLIGHT-001 проверяет свой принятый source, а новая палитра имеет отдельный прибор VLIGHT-003."""
    return contract.git("show", CAPTURED_COMMIT + ":" + name)


class LightingContractTests(unittest.TestCase):
    """Исторический прибор проверяет свои принятые исходники; новый runtime имеет отдельный QA."""

    def test_historical_probe_refuses_new_live_palette(self) -> None:
        """Смена владельца не выдаётся за успешную съёмку старым прибором VLIGHT-001."""
        name = contract.SOURCES[0]
        raw = (contract.ROOT / name).read_bytes()
        self.assertNotEqual(raw, captured_source(name))
        with self.assertRaisesRegex(ValueError, "expected one lighting call"):
            contract.instrument(name, raw)

    def test_overlay_is_exactly_reversible_for_every_real_owner(self) -> None:
        """Никакой соседний примитив не меняется вместе с пятью объявленными вызовами."""
        for name, calls in contract.CALLS.items():
            raw = captured_source(name)
            modified = contract.instrument(name, raw).decode()
            for _owner, original, replacement in calls:
                modified = modified.replace(f'preload("{contract.PROBE}").' + replacement, original)
            self.assertEqual(modified.encode(), raw, name)

    def test_weather_eclipse_decoration_and_contact_mesh_remain_byte_equal(self) -> None:
        """Выключение света не становится общим выключателем атмосферы или теней."""
        cases = {
            contract.SOURCES[0]: ("draw_rain", "draw_snow", "draw_eclipse"),
            contract.SOURCES[1]: ("draw", "draw_shadow", "shadow", "glow_mesh"),
        }
        for name, functions in cases.items():
            raw = captured_source(name).decode()
            changed = contract.instrument(name, raw.encode()).decode()
            for function in functions:
                self.assertEqual(
                    contract.function_body(raw, function), contract.function_body(changed, function)
                )

    def test_missing_and_duplicate_calls_fail_closed(self) -> None:
        """Неизвестная версия source не получает оптимистичный пустой прибор."""
        name = contract.SOURCES[0]
        raw = captured_source(name).decode()
        marker = contract.CALLS[name][0][1]
        for changed in (
            raw.replace(marker, "pass"),
            raw.replace(marker, marker + "\n\t\t" + marker),
        ):
            with self.assertRaises(ValueError):
                contract.instrument(name, changed.encode())

    def test_new_unlisted_native_call_is_rejected(self) -> None:
        """Новый световой примитив требует обновления ведомости и повторной приёмки."""
        name = contract.SOURCES[0]
        raw = captured_source(name).decode()
        changed = raw.replace(
            "\tvar darkness:", "\tgame.draw_circle(Vector2.ZERO, 1.0, Color.WHITE)\n\tvar darkness:"
        )
        self.assertNotEqual(changed, raw)
        with self.assertRaisesRegex(ValueError, "call inventory changed"):
            contract.instrument(name, changed.encode())

    def test_unrelated_source_is_not_an_instrumentation_target(self) -> None:
        """Collector не может незаметно патчить оркестратор или игровой HUD."""
        with self.assertRaisesRegex(ValueError, "unexpected lighting"):
            contract.instrument("scripts/systems/render_system.gd", b"extends RefCounted\n")

    def test_existing_output_and_symlink_are_preserved(self) -> None:
        """Проверяется фактическая файловая граница, а не только нормализованная строка."""
        with tempfile.TemporaryDirectory(prefix="light-output-") as value:
            root = Path(value).resolve()
            existing = root / "existing"
            existing.mkdir()
            sentinel = existing / "keep"
            sentinel.write_bytes(b"owned by another operation")
            link = root / "linked"
            link.symlink_to(existing, target_is_directory=True)
            for output in (existing, link / "child"):
                with self.assertRaises(ValueError):
                    contract.fresh_output(output)
            self.assertEqual(sentinel.read_bytes(), b"owned by another operation")
            self.assertFalse((existing / "child").exists())
            self.assertTrue(contract.fresh_output(root / "fresh").is_dir())

    def test_project_output_is_rejected_before_creation(self) -> None:
        """Новый внешний отчёт не оказывается среди игровых ресурсов."""
        target = contract.ROOT / "tmp-lighting-invalid-output"
        self.assertFalse(target.exists())
        with self.assertRaises(ValueError):
            contract.fresh_output(target)
        self.assertFalse(target.exists())

    def test_real_git_read_ignores_foreign_hook_overrides(self) -> None:
        """Настоящий Git не читает и не меняет чужую fixture даже под унаследованным GIT_DIR."""
        expected = contract.git("rev-parse", "HEAD")
        with tempfile.TemporaryDirectory(prefix="light-foreign-git-") as value:
            folder = Path(value)
            subprocess.run(["git", "init", "-q", str(folder)], check=True, env=git_environment())
            config = folder / ".git/config"
            before = config.read_bytes()
            environment = dict(os.environ)
            with patch.dict(
                os.environ,
                {
                    "GIT_DIR": str(folder / ".git"),
                    "GIT_INDEX_FILE": str(folder / "foreign-index"),
                    "GIT_WORK_TREE": str(folder),
                },
            ):
                self.assertEqual(contract.git("rev-parse", "HEAD"), expected)
            self.assertEqual(dict(os.environ), environment)
            self.assertEqual(config.read_bytes(), before)
            self.assertFalse((folder / "foreign-index").exists())


if __name__ == "__main__":
    unittest.main()
