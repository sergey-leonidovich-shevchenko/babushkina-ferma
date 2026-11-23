"""Проверяет реальные CLI-отказы, границы evidence и замкнутость входов VLIGHT-010."""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

from tools.common.git import git_environment
from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence


class ContractTests(unittest.TestCase):
    """Исторический настоящий PNG служит декодеру, не выдаётся за приёмку нового профиля."""

    def setUp(self) -> None:
        """Каждый сценарий использует новый собственный внешний каталог."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm low lighting ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()

    def test_full_matrix_and_gd_cases_agree(self) -> None:
        """Независимые Python/GDScript контракты имеют те же реальные случаи и полный набор."""
        import re

        raw = (c.ROOT / (c.PREFIX + "cases.gd")).read_text()
        self.assertEqual(
            set(re.findall(r'"id": "((?:street|home)-(?:day|dusk|night))"', raw)), set(c.CASES)
        )
        self.assertEqual(len(c.frame_ids(True)), 6)
        self.assertEqual(len(c.frame_ids(False)), 18)
        self.assertEqual(len(c.artifacts()), 304)
        self.assertEqual(sum(p.endswith(".png") for p in c.artifacts()), 270)
        self.assertEqual(len(c.INPUTS), len(set(c.INPUTS)))
        self.assertFalse([name for name in c.INPUTS if not (c.ROOT / name).is_file()])

    def test_actual_python_import_closure_is_captured(self) -> None:
        """Свежий Python импортирует настоящий producer/reader, а все tools bytes входят в pin."""
        code = """import json,sys
from pathlib import Path
import tools.qa.world.lighting.quality.collect
import tools.qa.world.lighting.quality.verify
root=Path.cwd()
print(json.dumps(sorted({str(Path(m.__file__).resolve().relative_to(root)) for n,m in sys.modules.items() if n.startswith('tools.') and getattr(m,'__file__',None) and Path(m.__file__).resolve().is_relative_to(root)})))
"""
        env = {**git_environment(), "PYTHONPATH": str(c.ROOT)}
        result = subprocess.run(
            [sys.executable, "-c", code],
            cwd=c.ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertFalse(set(json.loads(result.stdout)) - set(c.INPUTS))

    def test_actual_cli_refuses_missing_display_before_engine_or_output(self) -> None:
        """Публичный CLI из чужой cwd не запускает движок и сохраняет чужие Git/index/config."""
        foreign = self.root / "foreign repo"
        subprocess.run(
            ["/usr/bin/git", "init", "-q", str(foreign)], env=git_environment(), check=True
        )
        (foreign / "note.txt").write_text("foreign bytes\n")
        subprocess.run(
            ["/usr/bin/git", "-C", str(foreign), "add", "note.txt"],
            env=git_environment(),
            check=True,
        )
        before = {
            name: (foreign / ".git" / name).read_bytes() for name in ("config", "index", "HEAD")
        }
        poison = self.root / "hostile python" / "tools"
        poison.mkdir(parents=True)
        marker = self.root / "poison-loaded"
        (poison / "__init__.py").write_text(
            "from pathlib import Path\nPath(" + repr(str(marker)) + ").write_text('wrong import')\n"
        )
        env = dict(os.environ)
        env.pop("DISPLAY", None)
        env.update(
            PYTHONPATH=str(poison.parent),
            GIT_DIR=str(foreign / ".git"),
            GIT_INDEX_FILE=str(foreign / ".git/index"),
            GIT_WORK_TREE=str(foreign),
            FARM_GODOT_BIN=str(self.root / "missing engine"),
        )
        output = self.root / "must not be created"
        result = subprocess.run(
            [
                sys.executable,
                str(c.ROOT / "tools/run.py"),
                "qa.world.lighting.quality.collect",
                "--output",
                str(output),
            ],
            cwd=foreign,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("remote Linux X11", result.stderr)
        self.assertFalse(output.exists())
        self.assertFalse(marker.exists())
        self.assertEqual(before, {name: (foreign / ".git" / name).read_bytes() for name in before})

    def test_actual_retained_png_decode_never_resizes(self) -> None:
        """Читает настоящее принятое PNG из Git; чужой размер не исправляется ресемплингом."""
        import struct

        raw = c.shared.git(
            "show", c.BASE + ":docs/reports/visual-overhaul/vcompat-010/native-ci-02/home-off.png"
        )
        (self.root / "frame.png").write_bytes(raw)
        size = list(struct.unpack(">II", raw[16:24]))
        image = Evidence(self.root).image("frame.png", size)
        self.assertEqual(list(image.size), size)
        with self.assertRaisesRegex(ValueError, "PNG/size"):
            Evidence(self.root).image("frame.png", [size[0] + 1, size[1]])
        self.assertEqual((self.root / "frame.png").read_bytes(), raw)

    def test_evidence_rejects_paths_and_symlinks(self) -> None:
        """Traversal, absolute path и ссылка не получают доступ за границу своего пакета."""
        (self.root / "plain.json").write_text('{"real":true}')
        store = Evidence(self.root)
        self.assertEqual(store.document("plain.json"), {"real": True})
        for value in (
            "../plain.json",
            "/plain.json",
            "a/../plain.json",
            "./plain.json",
            "a\\b",
            "",
        ):
            with self.subTest(value=value), self.assertRaises(ValueError):
                store.read(value)
        (self.root / "link.json").symlink_to(self.root / "plain.json")
        with self.assertRaisesRegex(ValueError, "symlink"):
            store.read("link.json")

    def test_duplicate_zip_member_is_rejected(self) -> None:
        """Повторный member не позволяет выбрать удобную копию manifest."""
        archive = self.root / "duplicate.zip"
        with warnings.catch_warnings(), zipfile.ZipFile(archive, "w") as stream:
            warnings.simplefilter("ignore", UserWarning)
            stream.writestr("source.json", '{"version":1}')
            stream.writestr("source.json", '{"version":2}')
        with self.assertRaisesRegex(ValueError, "duplicate"):
            Evidence(archive).document("source.json")

    def _actual_actions_archive(self) -> tuple[Path, bytes, bytes]:
        """Копирует целый исторический Actions ZIP; его неудача не становится native-приёмкой."""
        name = "docs/reports/visual-overhaul/vlight-003/failures/ci-02-artifact.zip"
        original = c.ROOT / name
        raw = c.shared.git("show", c.BASE + ":" + name)
        self.assertEqual(original.read_bytes(), raw)
        archive = self.root / "actual-actions.zip"
        archive.write_bytes(raw)
        with zipfile.ZipFile(io.BytesIO(raw)) as stream:
            manifest = stream.read("evidence/source.json")
        return archive, raw, manifest

    def test_actual_actions_zip_namespace(self) -> None:
        """Читает настоящий evidence/source.json без extract/repack и не принимает сам пакет."""
        archive, raw, manifest = self._actual_actions_archive()
        document = Evidence(archive).document("source.json")
        self.assertEqual(document, json.loads(manifest))
        self.assertFalse(document["complete"])
        self.assertEqual(archive.read_bytes(), raw)

    def test_actual_actions_zip_ambiguous_roots(self) -> None:
        """В копии реального ZIP второй корень не позволяет выбрать удобный manifest."""
        archive, _, manifest = self._actual_actions_archive()
        with zipfile.ZipFile(archive, "a") as stream:
            stream.writestr("source.json", manifest)
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            Evidence(archive).document("source.json")

    def test_actual_actions_zip_duplicate_source(self) -> None:
        """Дубликат исходного prefixed member отклоняется до разбора его JSON."""
        archive, _, manifest = self._actual_actions_archive()
        with warnings.catch_warnings(), zipfile.ZipFile(archive, "a") as stream:
            warnings.simplefilter("ignore", UserWarning)
            stream.writestr("evidence/source.json", manifest)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            Evidence(archive).document("source.json")

    def test_workflow_pins_real_engine_and_head(self) -> None:
        """Реальная CI-конфигурация получает полный Git и официальный движок того же build."""
        raw = (c.ROOT / ".github/workflows/vlight-010.yml").read_text()
        for required in (
            "fetch-depth: 0",
            "ref: ${{ github.event.pull_request.head.sha || github.sha }}",
            "c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba",
            "Pillow==11.3.0",
            "--check-current-candidate",
            "if: always()",
        ):
            self.assertIn(required, raw)


if __name__ == "__main__":
    unittest.main()
