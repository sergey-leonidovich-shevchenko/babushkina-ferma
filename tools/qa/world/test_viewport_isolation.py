#!/usr/bin/env python3
"""Reject damaged copies of VRENDER-009 evidence without rewriting the native run."""

import copy
import json
import subprocess
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any, ClassVar
from unittest.mock import patch

from tools.planning.bump_version import replace_or_insert_project_version
from tools.qa.world import viewport_isolation_verify as audit


class ViewportIsolationTests(unittest.TestCase):
    data: ClassVar[dict[str, Any]]

    @classmethod
    def setUpClass(cls) -> None:
        cls.data = json.loads((audit.NATIVE / "capture.json").read_text())

    def changed(
        self,
        edit: Callable[[dict[str, Any]], object],
        label: str = "",
        route: bool = False,
        manifest_edit: Callable[[dict[str, Any]], object] | None = None,
    ) -> None:
        data = copy.deepcopy(self.data)
        edit(data)
        with tempfile.TemporaryDirectory() as folder:
            report = Path(folder)
            native = report / "native"
            native.mkdir()
            for image in audit.NATIVE.glob("*.png"):
                (native / image.name).symlink_to(image)
            capture = native / "capture.json"
            capture.write_text(json.dumps(data))
            manifest = json.loads((audit.REPORT / audit.MANIFEST_NAME).read_text())
            (report / audit.MANIFEST_NAME).write_text(
                (audit.REPORT / audit.MANIFEST_NAME).read_text()
            )
            if route:
                manifest["capture_sha256"] = audit.digest(capture)
                if manifest_edit is not None:
                    manifest_edit(manifest)
                with (
                    patch.object(audit, "load_manifest", return_value=manifest),
                    self.assertRaisesRegex(
                        (
                            ValueError,
                            KeyError,
                            TypeError,
                            OSError,
                            subprocess.CalledProcessError,
                        ),
                        label,
                    ),
                ):
                    audit.verify(report)
            else:
                with self.assertRaisesRegex(
                    (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError), label
                ):
                    audit.verify(report)

    def test_actual_native_evidence(self) -> None:
        result = audit.verify()
        self.assertEqual(result["native_cases"], 5)
        self.assertEqual(result["production_draws"], 20)
        self.assertNotEqual(result["owners"]["game"]["game"], result["owners"]["preview"]["game"])

    def test_wrong_task(self) -> None:
        self.changed(lambda data: data.update(task="VRENDER-008"), "capture bytes changed")

    def test_headless_capture(self) -> None:
        def headless(data: dict[str, Any]) -> None:
            data["display"] = "headless"
            data["provenance"]["launch"]["display"] = "headless"

        self.changed(
            headless,
            "native display and clean capture",
            True,
            lambda manifest: manifest["configuration"].update(display="headless"),
        )

    def test_wrong_window(self) -> None:
        self.changed(lambda data: data.update(window=[2304, 1296]), "exact viewport sizes", True)

    def test_missing_case(self) -> None:
        self.changed(lambda data: data["rows"].pop(), "ordered route", True)

    def test_duplicate_case(self) -> None:
        self.changed(lambda data: data["rows"][1].update(id="same-camera"), "ordered route", True)

    def test_missing_world(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"].pop(), "image set|two states", True)

    def test_mutable_owner_payload(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][0]["owner"].update(node="Game"),
            "bounded owner token",
            True,
        )

    def test_shared_game_owner(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][1]["owner"].update(
                game=data["rows"][0]["states"][0]["owner"]["game"]
            ),
            "distinct game owners|frame belongs",
            True,
        )

    def test_foreign_frame(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][0].update(frame_owner=99),
            "frame belongs",
            True,
        )

    def test_draw_mutation(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][0]["draws"][0].update(equal=False),
            "production draw is pure",
            True,
        )

    def test_dirty_foreground_queue(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][0]["draws"][0].update(queue_after=1),
            "production draw is pure",
            True,
        )

    def test_preview_moves_with_game(self) -> None:
        self.changed(
            lambda data: data["rows"][1]["states"][1].update(player=[738.0, 696.0]),
            "game movement changes only",
            True,
        )

    def test_pause_clock_catchup(self) -> None:
        self.changed(
            lambda data: data["rows"][2]["states"][1].update(seconds=10.5),
            "manual pause freezes",
            True,
        )

    def test_cross_viewport_map_entry(self) -> None:
        self.changed(
            lambda data: data["rows"][3]["states"][1].update(location="village_market"),
            "isolated map entry",
            True,
        )

    def test_unexpected_preview_save(self) -> None:
        def edit(data: dict[str, Any]) -> None:
            state = data["rows"][2]["states"][1]
            state["save"]["coins"] = 999
            for draw in state["draws"]:
                draw["before"]["coins"] = 999
                draw["after"]["coins"] = 999

        self.changed(
            edit,
            "preview pause records only",
            True,
        )

    def test_nonexistent_base_commit(self) -> None:
        self.changed(
            lambda data: data.update(base_commit="0" * 40),
            "capture base commit",
            True,
            lambda manifest: manifest.update(base_commit="0" * 40),
        )

    def test_preview_camera_and_background_leak(self) -> None:
        def edit(data: dict[str, Any]) -> None:
            state = data["rows"][1]["states"][1]
            state["camera"] = [999.0, 777.0]
            state["background_position"] = [-999.0, -777.0]
            state["background_scale"] = [3.0, 3.0]

        self.changed(edit, "game movement changes only", True)

    def test_preview_clock_jump_on_map_entry(self) -> None:
        self.changed(
            lambda data: data["rows"][3]["states"][1].update(seconds=99.0),
            "isolated map entry",
            True,
        )

    def test_missing_post_motion_and_half_draws(self) -> None:
        def edit(data: dict[str, Any]) -> None:
            for row in data["rows"]:
                for state in row["states"]:
                    state["frame_owner"] = 0
                    state["frame_viewport_owner"] = 0
                    state["frame_background_owner"] = 0
                    state["draws"].pop()

        self.changed(edit, "frame belongs|two production draws", True)

    def test_runtime_source_byte_change(self) -> None:
        sources = copy.deepcopy(
            json.loads((audit.REPORT / audit.MANIFEST_NAME).read_text())["sources"]
        )
        sources["scripts/systems/render_system.gd"] = "f" * 64
        with (
            patch.object(audit, "current_sources", return_value=sources),
            self.assertRaisesRegex(ValueError, "runtime source bytes changed"),
        ):
            audit.verify(check_current_candidate=True)

    def test_missing_source_commit(self) -> None:
        self.changed(
            lambda _: None,
            "^source commit$",
            True,
            lambda manifest: manifest.update(source_commit="0" * 40),
        )

    def test_wrong_source_commit_bytes(self) -> None:
        self.changed(
            lambda _: None,
            "source commit bytes changed",
            True,
            lambda manifest: manifest.update(source_commit=manifest["base_commit"]),
        )

    def test_historical_evidence_survives_metadata_commit(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            audit.git(root, "init", "--template=")
            audit.git(root, "config", "user.name", "VRENDER QA")
            audit.git(root, "config", "user.email", "vrender-qa@example.invalid")
            audit.git(root, "config", "core.autocrlf", "false")
            audit.git(root, "config", "commit.gpgsign", "false")
            data = copy.deepcopy(self.data)
            for name in audit.SOURCES:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(audit.git_blob(audit.ROOT, data["base_commit"], name))
            audit.git(root, "add", "--all")
            audit.git(root, "commit", "-m", "capture base")
            data["base_commit"] = audit.git(root, "rev-parse", "HEAD").stdout.decode().strip()

            project = root / "project.godot"
            project.write_text(replace_or_insert_project_version(project.read_text(), "1.0.0"))
            audit.git(root, "add", "project.godot")
            audit.git(root, "commit", "-m", "captured sources")
            source_commit = audit.git(root, "rev-parse", "HEAD").stdout.decode().strip()
            data["provenance"]["sources"] = audit.current_sources(root)

            report = root / audit.REPORT.relative_to(audit.ROOT)
            native = report / "native"
            native.mkdir(parents=True)
            for image in audit.NATIVE.glob("*.png"):
                (native / image.name).symlink_to(image)
            (native / "capture.json").write_text(json.dumps(data))
            manifest = report / audit.MANIFEST_NAME
            relative = manifest.relative_to(root).as_posix()
            audit.seal(report, root)
            audit.git(root, "add", relative)
            self.assertEqual(audit.verify(report, root)["source_validation"], "current")
            audit.bind_source_commit(source_commit, report, root)
            audit.git(root, "add", relative)
            audit.git(root, "commit", "-m", "pin capture inputs")

            project.write_text(replace_or_insert_project_version(project.read_text(), "1.0.1"))
            audit.git(root, "add", "project.godot")
            audit.git(root, "commit", "-m", "bump project metadata")
            self.assertEqual(
                audit.git(root, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").stdout,
                b"project.godot\n",
            )
            with self.assertRaisesRegex(ValueError, "runtime source bytes changed"):
                audit.verify(report, root, check_current_candidate=True)
            result = audit.verify(report, root)
            self.assertEqual(result["source_commit"], source_commit)
            self.assertEqual(result["source_validation"], "git-commit")
            self.assertEqual(result["production_draws"], 20)


if __name__ == "__main__":
    unittest.main()
