"""Повреждает копии настоящего native-архива; не создаёт синтетическую приёмку."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
import zipfile
from collections.abc import Callable
from pathlib import Path
from typing import Any
from unittest.mock import patch

from PIL import Image

from tools.qa.world.lighting import contract
from tools.qa.world.lighting.storage import Artifacts
from tools.qa.world.lighting.test_support import document, frozen_checkout, raw_copy
from tools.qa.world.lighting.verify import DEFAULT, config_without_version, verify


class LightingArchiveTests(unittest.TestCase):
    """Каждый опыт сохраняет нормативные PNG/JSON и работает без запуска движка."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="light real archive ")
        self.folder = Path(self.temporary.name) / "archive"
        raw_copy(DEFAULT, self.folder)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def source(self, change: Callable[[dict[str, Any]], None]) -> None:
        path = self.folder / "source.json"
        data = document(path)
        change(data)
        path.write_text(json.dumps(data))

    def rehash(self, key: str, name: str) -> None:
        sha = contract.digest((self.folder / key / name).read_bytes())
        self.source(lambda source: source["runs"][key]["artifacts"].update({name: sha}))

    def captured(self, change: Callable[[dict[str, Any]], None], key: str = "1152-on") -> None:
        path = self.folder / key / "frames/capture.json"
        data = document(path)
        change(data)
        path.write_text(json.dumps(data))
        self.rehash(key, "frames/capture.json")

    def test_complete_real_archive(self) -> None:
        result = verify(DEFAULT)
        self.assertTrue(result["acceptance_eligible"])
        self.assertEqual(result["native_world_frames"], 54)
        self.assertEqual(result["native_HUD_frames"], 54)
        self.assertFalse(result["hardware_FPS_accepted"])
        self.assertFalse(result["whole_map_accepted"])

    def test_partial_and_diagnostic_do_not_become_acceptance(self) -> None:
        self.source(lambda source: source.update(complete=False))
        with self.assertRaisesRegex(ValueError, "incomplete"):
            verify(self.folder)
        self.source(
            lambda source: source.update(
                complete=True,
                diagnostic=True,
                runs={key: row for key, row in source["runs"].items() if key == "1152-production"},
            )
        )
        with self.assertRaisesRegex(ValueError, "diagnostic series"):
            verify(self.folder)
        self.assertFalse(verify(self.folder, diagnostic=True)["acceptance_eligible"])

    def test_missing_extra_and_corrupted_artifacts(self) -> None:
        key, name = "1152-production", "frames/west-lamp-720.png"
        path = self.folder / key / name
        raw = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(ValueError, "raw artifact inventory"):
            verify(self.folder)
        path.write_bytes(raw + b"changed")
        with self.assertRaisesRegex(ValueError, "artifact SHA"):
            verify(self.folder)
        path.write_bytes(raw)
        (self.folder / key / "extra.png").write_bytes(b"extra")
        self.source(
            lambda source: source["runs"][key]["artifacts"].update(
                {"extra.png": contract.digest(b"extra")}
            )
        )
        with self.assertRaisesRegex(ValueError, "artifact/exit inventory"):
            verify(self.folder)

    def test_compiler_and_runtime_errors_override_zero_exit(self) -> None:
        setup = self.folder / "compile-control.txt"
        original = setup.read_bytes()
        setup.write_bytes(original + b"\nSCRIPT ERROR: actual negative control\n")
        self.source(
            lambda source: source["setup_artifacts"].update(
                {setup.name: contract.digest(setup.read_bytes())}
            )
        )
        with self.assertRaisesRegex(ValueError, "compiler failure"):
            verify(self.folder)
        setup.write_bytes(original)
        self.source(
            lambda source: source["setup_artifacts"].update({setup.name: contract.digest(original)})
        )
        log = self.folder / "1152-production/engine.txt"
        log.write_bytes(log.read_bytes() + b"\nSCRIPT ERROR: Array assignment\n")
        self.rehash("1152-production", "engine.txt")
        with self.assertRaisesRegex(ValueError, "engine error"):
            verify(self.folder)

    def test_wrong_actual_native_script_is_rejected_after_rehash(self) -> None:
        path = self.folder / "1152-production/engine.launch.json"
        launch = document(path)
        index = launch["command"].index("--script")
        launch["command"][index + 1] = "res://other-controller.gd"
        path.write_text(json.dumps(launch))
        self.rehash("1152-production", "engine.launch.json")
        with self.assertRaisesRegex(ValueError, "actual native argv"):
            verify(self.folder)

    def test_saved_state_and_geometry_flags_do_not_hide_mutation(self) -> None:
        self.captured(
            lambda capture: capture["frames"]["home-720"]["after"].update(negative_control=True)
        )
        with self.assertRaisesRegex(ValueError, "saved state changed"):
            verify(self.folder)
        self.captured(
            lambda capture: capture["frames"]["home-720"]["after"].pop("negative_control")
        )
        self.captured(
            lambda capture: capture["frames"]["home-720"]["draws"][0]["geometry_after"].update(
                negative_control=True
            )
        )
        with self.assertRaisesRegex(ValueError, "inconsistent draw snapshots"):
            verify(self.folder)

    def test_same_alpha_rgb_mutation_cannot_hide_in_production(self) -> None:
        name = "frames/west-lamp-720.png"
        path = self.folder / "1152-on" / name
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        r, g, b, a = image.getpixel((500, 350))
        image.putpixel((500, 350), (r ^ 1, g, b, a))
        image.save(path)
        self.rehash("1152-on", name)
        with self.assertRaisesRegex(ValueError, "instrumentation changed production RGBA"):
            verify(self.folder)

    def test_hud_contamination_cannot_hide_behind_unchanged_save(self) -> None:
        name = "frames/west-lamp-720-hud.png"
        path = self.folder / "1152-off" / name
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        image.putpixel((500, 350), (255, 0, 255, 255))
        image.save(path)
        self.rehash("1152-off", name)
        with self.assertRaisesRegex(ValueError, "lighting contaminated HUD"):
            verify(self.folder)

    def test_cpu_requires_actual_repeat_samples(self) -> None:
        original = document(self.folder / "1152-on/frames/capture.json")["costs"][0]["samples_us"]
        self.captured(lambda capture: capture["costs"][0].update(samples_us=[]))
        with self.assertRaisesRegex(ValueError, "actual CPU sample"):
            verify(self.folder)
        self.captured(lambda capture: capture["costs"][0].update(samples_us=original))

        def unequal_pair(capture: dict[str, Any]) -> None:
            for side in ("before", "after"):
                capture["costs"][0][side]["coins"] += 1

        self.captured(unequal_pair)
        with self.assertRaisesRegex(ValueError, "CPU on/off/repeat saved state differs"):
            verify(self.folder)

    def test_full_frame_hud_is_checked_beyond_transparent_target(self) -> None:
        name = "frames/west-lamp-1320.png"
        path = self.folder / "1152-off" / name
        with Image.open(self.folder / "1152-off/frames/west-lamp-1320-hud.png") as hud:
            alpha = hud.convert("RGBA").getchannel("A")
            index = next(index for index, value in enumerate(alpha.getdata()) if value == 255)
            point = (index % hud.width, index // hud.width)
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        image.putpixel(point, (255, 0, 255, 255))
        image.save(path)
        self.rehash("1152-off", name)
        with self.assertRaisesRegex(ValueError, "opaque HUD in full production"):
            verify(self.folder)

    def test_two_viewports_cannot_share_owner_or_off_switch(self) -> None:
        self.captured(
            lambda capture: capture["viewports"]["records"]["home-off"]["states"][0].update(
                off=True
            )
        )
        with self.assertRaisesRegex(ValueError, "switch leaked"):
            verify(self.folder)

    def test_second_framebuffer_contamination_is_rejected(self) -> None:
        name = "frames/viewport-west-off-1.png"
        path = self.folder / "1152-on" / name
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        image.putpixel((400, 300), (255, 0, 255, 255))
        image.save(path)
        self.rehash("1152-on", name)
        with self.assertRaisesRegex(ValueError, "viewport isolation failure"):
            verify(self.folder)

    def test_off_cannot_change_pixels_outside_light_calls(self) -> None:
        name = "frames/west-lamp-720.png"
        path = self.folder / "1152-off" / name
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        image.putpixel((500, 350), (255, 0, 255, 255))
        image.save(path)
        self.rehash("1152-off", name)
        with self.assertRaisesRegex(ValueError, "outside lighting bounds"):
            verify(self.folder)

    def test_zip_extra_and_raw_ambiguity_are_rejected(self) -> None:
        packed = Path(self.temporary.name) / "packed"
        shutil.copytree(DEFAULT, packed)
        with zipfile.ZipFile(packed / "1152.zip", "a") as archive:
            archive.writestr("../outside", b"forbidden")
        with self.assertRaisesRegex(ValueError, "ZIP artifact inventory"):
            verify(packed)
        self.assertFalse((packed.parent / "outside").exists())
        shutil.rmtree(packed)
        shutil.copytree(DEFAULT, packed)
        path = packed / "1152-on/frames/capture.json"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"ambiguity")
        with self.assertRaisesRegex(ValueError, "ambiguous raw/ZIP"):
            verify(packed)

    def test_raw_symlink_cannot_substitute_an_artifact(self) -> None:
        path = self.folder / "1152-production/engine.txt"
        raw = path.read_bytes()
        other = Path(self.temporary.name) / "outside-log"
        other.write_bytes(raw)
        path.unlink()
        path.symlink_to(other)
        source = document(self.folder / "source.json")
        with self.assertRaisesRegex(ValueError, "symlinks"):
            Artifacts(self.folder, source).read("1152-production/engine.txt")
        self.assertEqual(other.read_bytes(), raw)

    def test_current_render_config_and_version_metadata_have_separate_rules(self) -> None:
        with (
            frozen_checkout(DEFAULT) as repo,
            patch("tools.qa.world.lighting.contract.ROOT", repo),
            patch("tools.qa.world.lighting.inventory.ROOT", repo),
        ):
            self.assertTrue(verify(DEFAULT, current=True)["provenance"]["current_checked"])
            path = repo / "project.godot"
            raw = path.read_bytes()
            _, version = config_without_version(raw)
            path.write_bytes(
                raw.replace(
                    ('config/version="' + version + '"').encode(), b'config/version="9.9.9"'
                )
            )
            (repo / "VERSION").write_text("9.9.9\n")
            delta = verify(DEFAULT, current=True)["provenance"]["project_versions"]
            self.assertTrue(delta["metadata_only_delta"])
            path.write_bytes(path.read_bytes() + b"\n[rendering]\nnegative_control=true\n")
            with self.assertRaisesRegex(ValueError, "render configuration changed"):
                verify(DEFAULT, current=True)
            path.write_bytes(raw)
            (repo / "VERSION").write_text(version + "\n")
            helper = repo / "tools/qa/camera/visual_camera_points.gd"
            original = helper.read_bytes()
            helper.write_bytes(original + b"\n# changed shared dependency\n")
            with self.assertRaisesRegex(ValueError, "current shared QA dependency changed"):
                verify(DEFAULT, current=True)
            helper.write_bytes(original)
            runtime = repo / "scripts/systems/atmosphere_renderer.gd"
            runtime.write_bytes(runtime.read_bytes() + b"\n# changed after capture\n")
            with self.assertRaisesRegex(ValueError, "uncommitted production changes"):
                verify(DEFAULT, current=True)


if __name__ == "__main__":
    unittest.main()
