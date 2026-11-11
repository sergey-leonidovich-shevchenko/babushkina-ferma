#!/usr/bin/env python3
"""Reject damaged copies of VRENDER-009 evidence without rewriting the native run."""

import copy
import json
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any, ClassVar

from tools.qa.world import viewport_isolation_verify as audit


class ViewportIsolationTests(unittest.TestCase):
    data: ClassVar[dict[str, Any]]

    @classmethod
    def setUpClass(cls) -> None:
        cls.data = json.loads((audit.NATIVE / "capture.json").read_text())

    def changed(self, edit: Callable[[dict[str, Any]], object]) -> None:
        data = copy.deepcopy(self.data)
        edit(data)
        with tempfile.TemporaryDirectory() as folder:
            native = Path(folder) / "native"
            native.mkdir()
            for image in audit.NATIVE.glob("*.png"):
                (native / image.name).symlink_to(image)
            (native / "capture.json").write_text(json.dumps(data))
            with self.assertRaises((ValueError, KeyError, TypeError)):
                audit.verify(Path(folder))

    def test_actual_native_evidence(self) -> None:
        result = audit.verify()
        self.assertEqual(result["native_cases"], 5)
        self.assertEqual(result["production_draws"], 20)
        self.assertNotEqual(result["owners"]["game"]["game"], result["owners"]["preview"]["game"])

    def test_wrong_task(self) -> None:
        self.changed(lambda data: data.update(task="VRENDER-008"))

    def test_headless_capture(self) -> None:
        self.changed(lambda data: data.update(display="headless"))

    def test_wrong_window(self) -> None:
        self.changed(lambda data: data.update(window=[2304, 1296]))

    def test_missing_case(self) -> None:
        self.changed(lambda data: data["rows"].pop())

    def test_duplicate_case(self) -> None:
        self.changed(lambda data: data["rows"][1].update(id="same-camera"))

    def test_missing_world(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"].pop())

    def test_mutable_owner_payload(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"][0]["owner"].update(node="Game"))

    def test_shared_game_owner(self) -> None:
        self.changed(
            lambda data: data["rows"][0]["states"][1]["owner"].update(
                game=data["rows"][0]["states"][0]["owner"]["game"]
            )
        )

    def test_foreign_frame(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"][0].update(frame_owner=99))

    def test_draw_mutation(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"][0]["draws"][0].update(equal=False))

    def test_dirty_foreground_queue(self) -> None:
        self.changed(lambda data: data["rows"][0]["states"][0]["draws"][0].update(queue_after=1))

    def test_preview_moves_with_game(self) -> None:
        self.changed(lambda data: data["rows"][1]["states"][1].update(player=[738.0, 696.0]))

    def test_pause_clock_catchup(self) -> None:
        self.changed(lambda data: data["rows"][2]["states"][1].update(seconds=10.5))

    def test_cross_viewport_map_entry(self) -> None:
        self.changed(lambda data: data["rows"][3]["states"][1].update(location="village_market"))

    def test_unexpected_preview_save(self) -> None:
        self.changed(lambda data: data["rows"][2]["states"][1]["save"].update(coins=999))


if __name__ == "__main__":
    unittest.main()
