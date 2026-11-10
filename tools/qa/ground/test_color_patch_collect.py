#!/usr/bin/env python3
"""Process-lifecycle regressions for the VGROUND-002 native evidence collector."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from tools.qa.ground import color_patch_collect as collector


class ColorPatchCollectorLifecycle(unittest.TestCase):
    """A completed JSON document must not be confused with a finished engine."""

    def target_with_capture(self, parent: str) -> Path:
        target = Path(parent) / "capture"
        (target / "native").mkdir(parents=True)
        (target / "native/capture.json").write_text("{}")
        return target

    def helper(self, target: Path, exit_code: int, delay: float = 0.08) -> subprocess.Popen[bytes]:
        """Start a real child that publishes JSON before its requested exit code."""
        script = (
            "import pathlib,sys,time;"
            "p=pathlib.Path(sys.argv[1]);p.parent.mkdir(parents=True,exist_ok=True);"
            "p.write_text('{}');time.sleep(float(sys.argv[2]));"
            "raise SystemExit(int(sys.argv[3]))"
        )
        return subprocess.Popen(
            [
                sys.executable,
                "-c",
                script,
                str(target / "native/capture.json"),
                str(delay),
                str(exit_code),
            ]
        )

    def test_linux_waits_for_real_direct_child_after_capture_is_written(self) -> None:
        """CI reaps a real direct child instead of treating its early JSON as completion."""
        with tempfile.TemporaryDirectory() as parent:
            target = Path(parent) / "success"
            child = self.helper(target, 0)
            with patch.object(collector.sys, "platform", "linux"):
                code = collector.wait_for_capture(child, target, "ci")
            self.assertEqual(code, 0)
            self.assertEqual(child.returncode, 0)

    def test_linux_reaps_real_nonzero_child_with_ready_document(self) -> None:
        """A ready JSON cannot hide a real child's late exit 7 or leave it running."""
        with tempfile.TemporaryDirectory() as parent:
            target = Path(parent) / "failure"
            child = self.helper(target, 7)
            with patch.object(collector.sys, "platform", "linux"):
                code = collector.wait_for_capture(child, target, "ci")
            self.assertEqual(code, 7)
            self.assertEqual(child.returncode, 7)

    def test_two_real_direct_children_finish_sequentially(self) -> None:
        """The second CI-style window starts only after the first child is fully reaped."""
        with tempfile.TemporaryDirectory() as parent:
            codes = []
            children = []
            with patch.object(collector.sys, "platform", "linux"):
                for name in ["1152", "1280"]:
                    target = Path(parent) / name
                    child = self.helper(target, 0, 0.03)
                    children.append(child)
                    codes.append(collector.wait_for_capture(child, target, "ci-" + name))
            self.assertEqual(codes, [0, 0])
            self.assertEqual([child.returncode for child in children], [0, 0])

    def test_macos_wrapper_keeps_tagged_process_fallback(self) -> None:
        """The local ``open`` wrapper may stay alive after the tagged capture process exits."""
        with tempfile.TemporaryDirectory() as parent:
            child = Mock()
            child.poll.side_effect = [None, 0]
            with (
                patch.object(collector.sys, "platform", "darwin"),
                patch.object(collector, "capture_pid", side_effect=[123, None]),
                patch.object(collector.time, "sleep"),
            ):
                code = collector.wait_for_capture(child, self.target_with_capture(parent), "local")
            self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
