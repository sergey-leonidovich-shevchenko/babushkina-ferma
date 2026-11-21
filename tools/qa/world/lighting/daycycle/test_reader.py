"""Отрицательные контроли полного reader на копиях настоящих native ZIP VLIGHT-003."""

from __future__ import annotations

import copy
import json
import shutil
import subprocess
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any
from unittest.mock import patch

from PIL import Image

from tools.common.git import git_environment
from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle import gallery, metrics
from tools.qa.world.lighting.daycycle.evidence import Evidence
from tools.qa.world.lighting.daycycle.review_regressions import changed, pair
from tools.qa.world.lighting.daycycle.verify import REPORT, verify


class ReaderTests(unittest.TestCase):
    """SHA повреждённого member пересчитывается: отказ обязан проверять смысл, а не CRC."""

    capture: dict[str, Any]
    source: dict[str, Any]

    @classmethod
    def setUpClass(cls) -> None:
        store = Evidence(REPORT)
        cls.capture = store.document("candidate/1152/capture.json")
        cls.source = store.document("source.json")

    def reject(self, edits: dict[str, bytes], reason: str) -> None:
        """Не меняет исходный архив и запускает весь reader, включая Git, пиксели и состояния."""
        with changed(REPORT, edits) as damaged:
            with self.assertRaisesRegex(ValueError, reason):
                verify(damaged)

    def reject_capture(self, mutation: Callable[[dict[str, Any]], None], reason: str) -> None:
        """Редактирует копию фактического capture и подписывает её новые байты."""
        data = copy.deepcopy(self.capture)
        mutation(data)
        self.reject({"candidate/1152/capture.json": json.dumps(data).encode()}, reason)

    def test_complete_actual_packet(self) -> None:
        result = verify(REPORT)
        self.assertEqual(result["head"], self.source["head"])
        self.assertEqual(set(result["widths"]), {"1152", "1280"})
        self.assertFalse(result["hardware_fps_acceptance"])
        metrics.check(REPORT, REPORT.parent)

    def test_gallery_keeps_all_native_crop_pixels(self) -> None:
        gallery.check(REPORT, REPORT.parent)

    def test_gallery_pixel_tamper_is_rejected_even_resigned(self) -> None:
        with tempfile.TemporaryDirectory(prefix="daycycle native gallery ") as temporary:
            root = Path(temporary)
            for name in ("comparison.png", "cycle.png", "viewports.png", "gallery.json"):
                shutil.copyfile(REPORT.parent / name, root / name)
            manifest = json.loads((root / "gallery.json").read_bytes())
            placement = manifest["figures"]["comparison.png"]["placements"][0]
            x, y, _, _ = placement["at"]
            with Image.open(root / "comparison.png") as original:
                image = original.convert("RGBA")
            image.putpixel((x, y), (255, 0, 255, 255))
            image.save(root / "comparison.png")
            manifest["outputs"]["comparison.png"] = c.digest((root / "comparison.png").read_bytes())
            (root / "gallery.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "gallery changed native pixels"):
                gallery.check(REPORT, root)

    def test_full_old_and_new_reader_pair(self) -> None:
        """Исторический native остаётся валиден после будущих runtime-задач; current отдельно ниже."""
        with tempfile.TemporaryDirectory(prefix="daycycle full pair ") as temporary:
            report = pair(REPORT, Path(temporary).resolve() / "result", current=False)
            for name in ("all-reference-noon", "timed-legacy-off", "timed-other-scene"):
                self.assertEqual(report["cases"][name]["old_timing"]["exit_code"], 0)
                self.assertEqual(report["cases"][name]["current"]["exit_code"], 1)
            self.assertEqual(report["cases"]["unchanged-current"]["exit_code"], 0)

    def test_actual_bad_hud_root_even_resigned(self) -> None:
        store = Evidence(REPORT)
        self.reject(
            {
                "candidate/1152/street-dusk-palette.png": store.read(
                    "candidate/1152/street-dusk-palette-bad-hud.png"
                )
            },
            "normal root recolors opaque HUD",
        )

    def test_two_bad_hud_witnesses_cannot_approve_each_other(self) -> None:
        raw = Evidence(REPORT).read("candidate/1152/street-dusk-palette-bad-hud.png")
        self.reject(
            {
                "candidate/1152/street-dusk-palette.png": raw,
                "candidate/1152/street-dusk-palette-hud.png": raw,
            },
            "palette recolors accepted same-time HUD",
        )

    def test_actual_hidden_hero_and_threat_are_rejected_separately(self) -> None:
        store = Evidence(REPORT)
        for target in ("hero", "threat"):
            with self.subTest(target=target):
                self.reject(
                    {
                        "candidate/1152/street-dusk-palette.png": store.read(
                            "candidate/1152/street-dusk-palette-" + target + "-hidden.png"
                        )
                    },
                    "no readable native pixels",
                )

    def test_shifted_native_roi_is_rejected(self) -> None:
        def mutate(data: dict[str, Any]) -> None:
            data["frames"]["street-dusk-palette"]["hero"][0] += 20

        self.reject_capture(mutate, "target native rectangle differs")

    def test_wrong_actual_seed_even_with_consistent_before_after(self) -> None:
        def mutate(data: dict[str, Any]) -> None:
            row = data["frames"]["street-dusk-palette"]
            for side in ("before", "after"):
                row[side]["geometry"]["seed"] += 1
                row[side]["save"]["world_loot_seed"] += 1

        self.reject_capture(mutate, "actual fixed seed differs")

    def test_complete_save_mutation_is_rejected(self) -> None:
        def mutate(data: dict[str, Any]) -> None:
            data["frames"]["street-dusk-palette"]["after"]["save"]["world_loot_seed"] += 1

        self.reject_capture(mutate, "draw mutated full state")

    def test_raw_samples_require_length_finite_values_and_frame_progress(self) -> None:
        def truncated(data: dict[str, Any]) -> None:
            data["costs"][0]["draw_us"].pop()

        def nonfinite(data: dict[str, Any]) -> None:
            data["costs"][0]["draw_us"][0] = float("nan")

        def stalled(data: dict[str, Any]) -> None:
            rows = data["costs"][0]["observations"]
            rows[1]["process_frame"] = rows[0]["process_frame"]

        for mutation, reason in (
            (truncated, "invalid/truncated"),
            (nonfinite, "invalid/truncated"),
            (stalled, "frame counter/timestamp did not advance"),
        ):
            with self.subTest(mutation=mutation.__name__):
                self.reject_capture(mutation, reason)

    def test_shared_viewport_owner_is_rejected(self) -> None:
        def mutate(data: dict[str, Any]) -> None:
            rows = data["twins"]["both"]
            for side in ("before", "after"):
                rows[1][side]["owner"]["viewport"] = rows[0][side]["owner"]["viewport"]

        self.reject_capture(mutate, "shared viewport owner")

    def test_real_night_pixels_cannot_leak_into_unchanged_neighbour(self) -> None:
        self.reject(
            {
                "candidate/1152/twin-first-legacy-1.png": Evidence(REPORT).read(
                    "candidate/1152/twin-second-night-1.png"
                )
            },
            "legacy color leaked to neighbouring viewport",
        )

    def test_actual_native_launch_and_engine_log_are_required(self) -> None:
        store = Evidence(REPORT)
        launch = store.document("candidate/1152.launch.json")
        launch["command"].append("--headless")
        self.reject(
            {"candidate/1152.launch.json": json.dumps(launch).encode()},
            "actual native launch differs",
        )
        raw = store.read("candidate/1152.txt").replace(
            b"official.a13da4feb", b"unofficial.a13da4feb"
        )
        self.reject({"candidate/1152.txt": raw}, "native engine log differs")

    def test_qa_input_must_be_the_actual_captured_git_blob(self) -> None:
        name = "inputs/" + c.PREFIX + "capture.gd"
        self.reject(
            {name: Evidence(REPORT).read(name) + b"\n# controlled QA drift\n"},
            "QA input is not captured Git head",
        )

    def test_production_inventory_cannot_omit_a_real_asset(self) -> None:
        name = "candidate/production-blobs.json"
        inventory = Evidence(REPORT).document(name)
        inventory.pop(next(key for key in inventory if key.startswith("assets/game/")))
        self.reject(
            {name: json.dumps(inventory).encode()}, "production asset/runtime inventory differs"
        )

    def test_incomplete_source_cannot_approve_its_remaining_images(self) -> None:
        with changed(REPORT, {}, lambda value: value.update(complete=False)) as damaged:
            with self.assertRaisesRegex(ValueError, "source/task/completeness differs"):
                verify(damaged)

    def test_current_guard_on_actual_historical_git_checkout(self) -> None:
        """Current принимает настоящий Git съёмки, SemVer-only и отвергает изменение runtime."""
        environment = git_environment()
        parent_root = c.ROOT
        parent_paths = [
            Path(shared.git("rev-parse", "--git-path", name).decode().strip())
            for name in ("index", "config")
        ]
        parent_bytes = [path.read_bytes() for path in parent_paths]
        with tempfile.TemporaryDirectory(prefix="daycycle historical current ") as temporary:
            project = Path(temporary).resolve() / "project"
            subprocess.run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "clone",
                    "--shared",
                    "--no-checkout",
                    "--quiet",
                    str(parent_root),
                    str(project),
                ],
                env=environment,
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "-C",
                    str(project),
                    "checkout",
                    "--quiet",
                    "--detach",
                    self.source["head"],
                ],
                env=environment,
                check=True,
            )
            with patch.object(shared, "ROOT", project), patch.object(c, "ROOT", project):
                self.assertEqual(verify(REPORT, current=True)["head"], self.source["head"])
                config = project / "project.godot"
                before = config.read_text()
                version = (project / "VERSION").read_text().strip()
                config.write_text(
                    before.replace('config/version="' + version + '"', 'config/version="99.0.0"')
                )
                (project / "VERSION").write_text("99.0.0\n")
                self.assertEqual(verify(REPORT, current=True)["head"], self.source["head"])
                runtime = project / "scripts/systems/atmosphere_renderer.gd"
                runtime.write_bytes(runtime.read_bytes() + b"\n# controlled current drift\n")
                with self.assertRaisesRegex(ValueError, "current runtime differs"):
                    verify(REPORT, current=True)
        self.assertEqual([path.read_bytes() for path in parent_paths], parent_bytes)


if __name__ == "__main__":
    unittest.main()
