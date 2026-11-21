"""Пограничные тесты настоящего CLI/путей и пиксельного reader VLIGHT-003."""

from __future__ import annotations

import copy
import tempfile
import unittest
import zipfile
from pathlib import Path
from typing import Any
from unittest.mock import patch

from PIL import Image

from tools.qa.world.lighting.daycycle import collect, pixels
from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle.evidence import Evidence


class ContractTests(unittest.TestCase):
    """Отказы не запускают движок и не трогают существующие проекты/каталоги."""

    def test_native_collection_refuses_local_platform_before_engine(self) -> None:
        """macOS запрещён даже при подставленном engine — нативный игровой запуск остаётся в CI."""
        with (
            patch.object(collect.sys, "platform", "darwin"),
            patch.object(collect, "execute") as run,
        ):
            with self.assertRaisesRegex(ValueError, "remote Linux"):
                collect.collect(Path("/tmp/not-created-vlight003"))
            run.assert_not_called()

    def test_hud_reader_rejects_tint_over_actual_opaque_pixels(self) -> None:
        """Тот же анализатор отклоняет recolor, а прозрачная часть не даёт ложного совпадения."""
        hud = Image.new("RGBA", (64, 64), (220, 200, 150, 255))
        self.assertEqual(pixels.hud(hud, hud), 4096)
        bad = Image.new("RGBA", hud.size, (150, 140, 120, 255))
        with self.assertRaisesRegex(ValueError, "recolors opaque HUD"):
            pixels.hud(bad, hud)
        with self.assertRaisesRegex(ValueError, "opaque witness"):
            pixels.hud(hud, Image.new("RGBA", hud.size))

    def test_target_reader_refuses_missing_or_outside_witness(self) -> None:
        """Пустая пара и координаты за framebuffer не доказывают читаемость угрозы."""
        image = Image.new("RGBA", (64, 64), (20, 20, 20, 255))
        with self.assertRaisesRegex(ValueError, "no readable"):
            pixels.target(image, image, [0, 0, 64, 64])
        with self.assertRaisesRegex(ValueError, "outside frame"):
            pixels.target(image, image, [1, 1, 64, 64])

    def test_two_tinted_witnesses_cannot_approve_each_other(self) -> None:
        """Совпадение двух новых кадров недостаточно, если оба потеряли прежний цвет HUD."""
        accepted = Image.new("RGBA", (64, 64), (220, 200, 150, 255))
        tinted = Image.new("RGBA", (64, 64), (150, 140, 120, 255))
        self.assertEqual(pixels.hud(tinted, tinted), 4096)
        with self.assertRaisesRegex(ValueError, "palette recolors accepted"):
            pixels.stable_hud(accepted, accepted, tinted)
        pixels.stable_hud(accepted, accepted, accepted)

    def test_native_target_coordinates_reject_logical_or_shifted_boxes(self) -> None:
        """Широкий framebuffer требует своего stretch; сдвиг ROI не подтверждается общим сигналом."""
        row: dict[str, Any] = {
            "before": {"geometry": {"player": [500, 300], "camera": [0, 0], "zoom": 1.0}},
            "ground": [500, 300],
            "stretch": [2, 0, 0, 2, 0, 0],
            "hero": [910, 390, 180, 260],
            "threat": [1210, 430, 250, 290],
        }
        pixels.geometry(row)
        for name in ("hero", "threat"):
            bad = copy.deepcopy(row)
            rect = bad[name]
            self.assertIsInstance(rect, list)
            rect[0] -= 20
            with self.assertRaisesRegex(ValueError, "native rectangle differs"):
                pixels.geometry(bad)
        row["stretch"] = [1, 0, 0, 1, 0, 0]
        with self.assertRaisesRegex(ValueError, "native rectangle differs"):
            pixels.geometry(row)

    def test_evidence_paths_and_duplicate_zip_members_are_rejected(self) -> None:
        """Относительный reader не извлекает ZIP и не переходит к чужим файлам."""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            store = Evidence(root)
            for name in ("../outside", "/absolute", "candidate/../../outside", "candidate\\file"):
                with self.assertRaisesRegex(ValueError, "unsafe evidence"):
                    store.read(name)
            outside = root / "outside"
            outside.write_text("unchanged")
            (root / "link").symlink_to(outside)
            with self.assertRaisesRegex(ValueError, "symlink evidence"):
                store.read("link")
            with zipfile.ZipFile(root / "candidate.zip", "w") as stream:
                stream.writestr("frame", b"native")
            self.assertEqual(store.read("candidate/frame"), b"native")
            with self.assertRaisesRegex(ValueError, "duplicate/missing ZIP member"):
                store.read("candidate/missing")
            self.assertEqual(outside.read_text(), "unchanged")

    def test_git_export_inventory_is_complete_and_matches_real_blobs(self) -> None:
        """Принятая main содержит реальные runtime/asset blobs, без выдуманного малого списка."""
        inventory = c.blobs(c.BASE)
        self.assertGreater(len(inventory), 3000)
        name = "scripts/systems/world_event_system.gd"
        self.assertEqual(c.blob_id(c.shared.git("show", c.BASE + ":" + name)), inventory[name])
        self.assertNotIn("scripts/presentation/daylight_palette.gd", inventory)

    def test_declared_inputs_exist_in_git_without_local_import_cache(self) -> None:
        """Тот же список обязан существовать в чистом checkout; локальный generated UID не доказательство."""
        head = c.shared.git("rev-parse", "HEAD").decode().strip()
        for name in c.INPUTS:
            with self.subTest(name=name):
                self.assertTrue(c.shared.git("show", head + ":" + name))
        self.assertNotIn("tools/qa/camera/visual_camera_points.gd.uid", c.INPUTS)


if __name__ == "__main__":
    unittest.main()
