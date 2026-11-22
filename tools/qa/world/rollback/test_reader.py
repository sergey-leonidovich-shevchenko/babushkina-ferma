"""Синтетические отрицательные фикстуры reader; они не являются нативным доказательством игры."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.qa.world.rollback import contract as c
from tools.qa.world.rollback.verify import check_run
from tools.qa.world.weather.verify import Evidence


def fixture(root: Path) -> dict:
    """Даёт маленькие явные тестовые данные полного reader-контракта без запуска Godot."""
    rows = []
    for name in sorted(c.FRAME_IDS):
        master = not name.endswith("-off")
        if name.startswith("twin-"):
            _, step, index = name.split("-")
            master = step == index
        interior = name.startswith("old-interior-")
        owner_id = 2 if name.endswith("-1") and name.startswith("twin-") else 1
        state = {
            "save": {
                "location": "cottage_interior" if interior else "overworld",
                "coins": 41,
                "counts": {"wood": 14, "apple": 2},
            },
            "player": [432, 672],
            "camera": [0, 0],
            "location": "cottage_interior" if interior else "overworld",
            "master": master,
            "terrain": dict.fromkeys(c.TERRAIN_FLAGS, master or interior),
            "water_layer": master,
            "terrain_ready": True,
            "processing": False,
            "reference_mode": False,
            "owner": {"game": owner_id, "viewport": owner_id + 10, "background": owner_id + 20},
            "game_id": owner_id,
            "viewport_id": owner_id + 10,
            "background_id": owner_id + 20,
            "wind": {"active": 1 if master else 0},
            "master_metadata": not name.startswith("startup-"),
            "project_flag": master if name.startswith("startup-") else True,
        }
        size = [640, 360] if name.startswith(("twin-", "startup-")) else [1152, 648]
        Image.new(
            "RGBA", size, (40, 90, 150, 255) if master or interior else (10, 40, 70, 255)
        ).save(root / (name + ".png"))
        rows.append(
            {
                "id": name,
                "file": name + ".png",
                "before": state,
                "after": copy.deepcopy(state),
                "draws": 2,
                "size": size,
                "window": [1152, 648],
                "visible": True,
                "png_error": 0,
            }
        )
    return {
        "task": "VCOMPAT-010",
        "errors": [],
        "display": "X11",
        "renderer": "gl_compatibility",
        "engine": "4.7.1-stable (official)",
        "profile": "Codex-VCOMPAT-010-" + "a" * 32,
        "user_dir": "/test/Codex-VCOMPAT-010-" + "a" * 32,
        "window": [1152, 648],
        "performance_eligible": False,
        "frames": rows,
    }


class ReaderTests(unittest.TestCase):
    """Проверяет реальные bytes/размеры/пути и семантику вместо доверия зелёным счётчикам JSON."""

    def setUp(self) -> None:
        """Каждый отказ изменяет только новый временный каталог своей явной unit-фикстуры."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.capture_doc = fixture(self.root)

    def check(self) -> dict[str, str]:
        """Подаёт сериализованный документ в тот же reader, который проверяет CI evidence."""
        (self.root / "capture.json").write_text(json.dumps(self.capture_doc))
        return check_run(Evidence(self.root), "", True, 1152)

    def test_valid_unit_contract(self) -> None:
        """Противоположные профили и точный возврат совместимы с заявленным форматом reader."""
        self.assertEqual(set(self.check()), c.FRAME_IDS)

    def test_missing_actual_png(self) -> None:
        """Зелёная строка capture не заменяет отсутствующий framebuffer."""
        (self.root / "home-on.png").unlink()
        with self.assertRaises(FileNotFoundError):
            self.check()

    def test_fake_dimensions(self) -> None:
        """Настоящий декодированный размер проверяется независимо от JSON."""
        Image.new("RGBA", (16, 16)).save(self.root / "home-on.png")
        with self.assertRaisesRegex(ValueError, "PNG/framebuffer"):
            self.check()

    def test_master_without_terrain(self) -> None:
        """Изменение только master metadata не считается возвратом прежнего грунта."""
        row = next(row for row in self.capture_doc["frames"] if row["id"] == "home-off")
        row["before"]["terrain"]["painted_grass"] = True
        row["after"] = copy.deepcopy(row["before"])
        with self.assertRaisesRegex(ValueError, "whole terrain"):
            self.check()

    def test_missing_effective_flag(self) -> None:
        """Пустой или урезанный словарь не проходит vacuous all(false)."""
        row = self.capture_doc["frames"][0]
        row["before"]["terrain"].clear()
        row["after"] = copy.deepcopy(row["before"])
        with self.assertRaisesRegex(ValueError, "effective terrain"):
            self.check()

    def test_narrow_reference_substitute(self) -> None:
        """Режим скрытия всех эффектов нельзя выдать за полную production-отрисовку."""
        row = self.capture_doc["frames"][0]
        row["before"]["reference_mode"] = True
        row["after"] = copy.deepcopy(row["before"])
        with self.assertRaisesRegex(ValueError, "reference substitute"):
            self.check()

    def test_other_owner(self) -> None:
        """Одинаковый номер окна не заменяет правильную связь game/viewport/background."""
        row = self.capture_doc["frames"][0]
        row["before"]["owner"]["game"] = 999
        row["after"] = copy.deepcopy(row["before"])
        with self.assertRaisesRegex(ValueError, "viewport owner"):
            self.check()

    def test_progress_changed(self) -> None:
        """Один draw не имеет права менять даже поле сохранения, не показанное в HUD."""
        self.capture_doc["frames"][0]["after"]["save"]["coins"] = 0
        with self.assertRaisesRegex(ValueError, "mutated"):
            self.check()

    def test_no_visual_return(self) -> None:
        """Вернувшийся флаг без вернувшихся пикселей проваливает сравнение."""
        Image.new("RGBA", (1152, 648), (1, 2, 3, 255)).save(self.root / "home-restore.png")
        with self.assertRaisesRegex(ValueError, "restore exactly"):
            self.check()

    def test_symlink_evidence(self) -> None:
        """Другой файл нельзя скрытно подставить ссылкой в evidence-каталог."""
        path = self.root / "home-on.png"
        path.unlink()
        path.symlink_to(self.root / "home-restore.png")
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.check()


if __name__ == "__main__":
    unittest.main()
