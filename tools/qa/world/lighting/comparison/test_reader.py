"""Портит только временные копии реальных native ZIP; пересъёмка для тестов не вызывается."""

from __future__ import annotations

import copy
import io
import json
import shutil
import tempfile
import unittest
import zipfile
from collections.abc import Callable
from pathlib import Path
from typing import Any

from PIL import Image

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import gallery, pixels, timing
from tools.qa.world.lighting.comparison.verify import REPORT, verify


class ReaderTests(unittest.TestCase):
    """Контроли используют фактические scene snapshots, samples и PNG принятого прибора."""

    capture: dict[str, Any]

    @classmethod
    def setUpClass(cls) -> None:
        with zipfile.ZipFile(REPORT / "1152.zip") as archive:
            cls.capture = json.loads(archive.read("frames/capture.json"))

    def test_complete_real_archive(self) -> None:
        result = verify(REPORT, current=True)
        self.assertTrue(result["native_complete"])
        self.assertFalse(result["hardware_fps_accepted"])
        self.assertEqual(set(result["results"]), {"1152", "1280"})

    def test_actual_cpu_controls(self) -> None:
        cases: list[Callable[[dict[str, Any]], None]] = [
            lambda x: x["costs"][0]["draw_us"].pop(),
            lambda x: x["costs"][0]["samples"][0].update(focused=False),
            lambda x: x["costs"][0]["samples"][0].update(window=[3584, 2240]),
            lambda x: x["costs"][0]["samples"][2].update(tick_us=0),
            lambda x: x["costs"][0]["after"]["world_context"].update(minutes=1321),
            lambda x: x["costs"][1]["before"]["world_context"].update(player=[0, 0]),
        ]
        for index, mutation in enumerate(cases):
            with self.subTest(index=index):
                damaged = copy.deepcopy(self.capture)
                mutation(damaged)
                with self.assertRaises(ValueError):
                    timing.costs(damaged)

    def test_real_rejected_ground_from_series_b(self) -> None:
        record = json.loads((REPORT.parent / "failures/native-b-ground.json").read_bytes())[
            "native_record"
        ]
        with self.assertRaisesRegex(ValueError, "production lamp ground"):
            pixels.light_geometry(record["light"], record["before"]["world_context"])

    def test_self_consistent_shift_does_not_hide_wrong_emitter(self) -> None:
        record = copy.deepcopy(self.capture["frames"]["west-lamp-1320-mask"])
        record["light"]["center"][1] += 24
        with self.assertRaisesRegex(ValueError, "emitter projection"):
            pixels.light_geometry(record["light"], record["before"]["world_context"])

    def test_gallery_native_pixels(self) -> None:
        gallery.check(REPORT, REPORT.parent)

    def test_gallery_pixel_tamper_even_resigned(self) -> None:
        with tempfile.TemporaryDirectory(prefix="lantern gallery ") as folder:
            out = Path(folder)
            for name in ["comparison.png", "overview.png", "viewports.png", "gallery.json"]:
                shutil.copyfile(REPORT.parent / name, out / name)
            document = json.loads((out / "gallery.json").read_bytes())
            row = document["placements"][0]
            x, y, _, _ = row["destination"]
            with Image.open(out / "comparison.png") as source:
                image = source.convert("RGB")
                image.putpixel((x, y), (255, 0, 255))
                image.save(out / "comparison.png")
            document["outputs"]["comparison.png"] = shared.digest(
                (out / "comparison.png").read_bytes()
            )
            (out / "gallery.json").write_text(json.dumps(document))
            with self.assertRaisesRegex(ValueError, "changed native pixels"):
                gallery.check(REPORT, out)

    def changed_archive(self, name: str, change: Callable[[bytes], bytes], expected: str) -> None:
        """Обновляет SHA повреждённого payload: отказ должен быть содержательным, а не CRC/hash-only."""
        with tempfile.TemporaryDirectory(prefix="lantern archive ") as folder:
            root = Path(folder)
            shutil.copytree(REPORT, root / "native")
            root = root / "native"
            source = json.loads((root / "source.json").read_bytes())
            path = root / "1152.zip"
            with zipfile.ZipFile(path) as archive:
                items = {n: archive.read(n) for n in archive.namelist()}
            items[name] = change(items[name])
            source["runs"]["1152"]["artifacts"][name] = shared.digest(items[name])
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for item, raw in items.items():
                    archive.writestr(item, raw)
            (root / "source.json").write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError, expected):
                verify(root, current=True)

    def changed_capture(self, change: Callable[[dict[str, Any]], None], expected: str) -> None:
        """Пересчитывает SHA настоящего capture; отказ не может свестись к целостности ZIP."""

        def mutate(raw: bytes) -> bytes:
            capture = json.loads(raw)
            change(capture)
            return json.dumps(capture).encode()

        self.changed_archive("frames/capture.json", mutate, expected)

    def test_review_timed_native_light_disabled(self) -> None:
        def change(capture: dict[str, Any]) -> None:
            rows = [r for r in capture["costs"] if r["mode"] in ["local", "shadow"]]
            self.assertEqual(len(rows), 12)
            for row in rows:
                row["light"].update(enabled=False, energy=0, shadow_enabled=False)

        self.changed_capture(change, "actual light energy|actual light enabled|actual shadow")

    def test_review_visual_point_texture_scale(self) -> None:
        def change(capture: dict[str, Any]) -> None:
            rows = [
                row
                for row in capture["frames"].values()
                if row["light"]["mode"] in ["local", "shadow"]
            ]
            self.assertEqual(len(rows), 12)
            for row in rows:
                row["light"]["texture_scale"] *= 4

        self.changed_capture(change, "actual PointLight texture_scale/radius")

    def test_each_timed_light_parameter_is_required(self) -> None:
        for field, value in [("enabled", False), ("energy", 0), ("shadow_enabled", False)]:
            with self.subTest(field=field):

                def change(
                    capture: dict[str, Any], field: str = field, value: bool | int = value
                ) -> None:
                    row = next(r for r in capture["costs"] if r["mode"] == "shadow")
                    row["light"][field] = value

                self.changed_capture(
                    change, "actual light energy|actual light enabled|actual shadow"
                )

    def test_geometry_is_checked_in_costs_and_viewports(self) -> None:
        for target in ["costs", "viewport", "viewport-with-matching-claimed-radius"]:
            with self.subTest(target=target):

                def change(capture: dict[str, Any], target: str = target) -> None:
                    if target == "costs":
                        rows = [r for r in capture["costs"] if r["mode"] in ["local", "shadow"]]
                    else:
                        rows = [capture["viewports"]["both-local"]["items"][0]]
                    for row in rows:
                        row["light"]["texture_scale"] *= 4
                        if target == "viewport-with-matching-claimed-radius":
                            row["light"]["radius"] *= 4

                self.changed_capture(change, "actual PointLight texture_scale/radius")

    def test_timed_context_matches_validated_visual_case(self) -> None:
        for name in ["world_context", "hud_context"]:
            with self.subTest(context=name):

                def change(capture: dict[str, Any], name: str = name) -> None:
                    for row in capture["costs"]:
                        for side in ["before", "after"]:
                            row[side][name]["seed"] += 1

                self.changed_capture(
                    change, "timed scene differs from validated 1320 visual context"
                )

    def test_unofficial_log_even_resigned(self) -> None:
        self.changed_archive(
            "engine.txt",
            lambda raw: raw.replace(b"official.a13da4feb", b"unofficial.a13da4feb"),
            "official engine build",
        )

    def test_engine_argv_even_resigned(self) -> None:
        def change(raw: bytes) -> bytes:
            row = json.loads(raw)
            row["command"].append("--headless")
            return json.dumps(row).encode()

        self.changed_archive("engine.launch.json", change, "actual engine argv")

    @staticmethod
    def changed_pixel(raw: bytes) -> bytes:
        with Image.open(io.BytesIO(raw)) as source:
            image = source.convert("RGBA")
            r, g, b, a = image.getpixel((30, 30))
            image.putpixel((30, 30), ((r + 7) % 256, g, b, a))
            out = io.BytesIO()
            image.save(out, format="PNG")
            return out.getvalue()

    def test_hud_payload_even_resigned(self) -> None:
        self.changed_archive(
            "frames/west-lamp-720-mask-hud.png", self.changed_pixel, "HUD-only RGBA"
        )

    def test_full_frame_hud_even_resigned(self) -> None:
        self.changed_archive(
            "frames/west-lamp-720-mask.png", self.changed_pixel, "opaque HUD|daytime light"
        )

    def test_neighbor_viewport_even_resigned(self) -> None:
        self.changed_archive(
            "frames/viewport-left-off-1.png", self.changed_pixel, "leaked between viewports"
        )

    def test_scene_time_even_resigned(self) -> None:
        def change(raw: bytes) -> bytes:
            row = json.loads(raw)
            row["frames"]["west-lamp-720-off"]["before"]["world_context"]["minutes"] = 721
            return json.dumps(row).encode()

        self.changed_archive("frames/capture.json", change, "actual scene time|save/context")


if __name__ == "__main__":
    unittest.main()
