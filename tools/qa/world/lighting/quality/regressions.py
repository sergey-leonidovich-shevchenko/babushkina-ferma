"""Run only against an original real VLIGHT-010 Actions artifact; copies are disposable."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import tempfile
import types
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality import pixels, provenance
from tools.qa.world.lighting.quality.evidence import Evidence
from tools.qa.world.lighting.quality.verify import verify

OLD_HEAD = "62f9f697d143b7383432459ec8a6d26992a3235f"


def historical_verifier() -> tuple[Any, dict[str, str]]:
    """Historical verify/checks functions share the same current source/pixel/timing guards.

    This is deliberately a paired function experiment, not execution of the entire old head
    (that head had a different, unaccepted capture observer and no actual native packet).
    """
    raw_checks = c.shared.git("show", OLD_HEAD + ":" + c.PREFIX + "checks.py")
    raw_verify = c.shared.git("show", OLD_HEAD + ":" + c.PREFIX + "verify.py")
    checks = types.ModuleType("vlight010_historical_checks")
    exec(compile(raw_checks, "historical-checks.py", "exec"), checks.__dict__)
    function = next(
        node
        for node in ast.parse(raw_verify).body
        if isinstance(node, ast.FunctionDef) and node.name == "verify"
    )
    tree = ast.Module(
        body=[
            ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0),
            function,
        ],
        type_ignores=[],
    )
    namespace = {
        "Evidence": Evidence,
        "c": c,
        "provenance": provenance,
        "pixels": pixels,
        "checks": checks,
        "Path": Path,
        "Any": Any,
    }
    exec(
        compile(ast.fix_missing_locations(tree), "historical-verify-function.py", "exec"), namespace
    )
    return namespace["verify"], {
        "head": OLD_HEAD,
        "checks_sha256": c.digest(raw_checks),
        "verify_sha256": c.digest(raw_verify),
        "scope": "historical verify/checks functions; same current source/pixel/timing guards",
    }


def run(archive: Path, head: str, output: Path, strict: bool) -> None:
    """No synthetic positive package, archive rewrite, missing-case fill-in, or PNG resampling."""
    assert not output.exists()
    archive_bytes = archive.read_bytes()
    positive = verify(archive, head, strict)
    assert positive["native_png"] == 270 and positive["runs"] == 4
    store = Evidence(archive)
    source = store.document("source.json")
    names = ["source.json", *sorted(c.artifacts()), *("inputs/" + n for n in c.INPUTS)]
    original = {name: store.read(name) for name in names}
    old_verify, old_identity = historical_verifier()
    results: list[dict[str, Any]] = []
    capture = "candidate/1152/capture.json"
    off = "street-night-off"
    with tempfile.TemporaryDirectory(prefix="farm real vlight010 controls ") as temporary:
        root = Path(temporary).resolve()
        for name, raw in original.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        assert old_verify(root, head)["native_png"] == 270
        results.append(
            {"case": "original real packet", "new_accepted": True, "old_functions_accepted": True}
        )

        def trial(label: str, modify: Any, expected: str, old_should_accept: bool = False) -> None:
            """Update hashes deliberately: semantic guards must reject a coherent signed copy."""
            modified: set[str] = set()

            def write(name: str, raw: bytes) -> None:
                modified.add(name)
                (root / name).write_bytes(raw)

            def document(name: str, change: Any) -> None:
                value = json.loads((root / name).read_bytes())
                change(value)
                write(name, (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())
                if name in source["artifacts"]:
                    digest = c.digest((root / name).read_bytes())
                    document("source.json", lambda row: row["artifacts"].__setitem__(name, digest))

            def substitute(target: str, actual: str) -> None:
                write(target, original[actual])
                document(
                    "source.json",
                    lambda row: row["artifacts"].__setitem__(target, c.digest(original[actual])),
                )

            row: dict[str, Any] = {"case": label}
            try:
                modify(write, document, substitute)
                if old_should_accept:
                    old_verify(root, head)
                    row["old_functions_accepted"] = True
                try:
                    verify(root, head)
                except (ValueError, KeyError, IndexError, TypeError, OSError) as error:
                    message = str(error)
                    assert expected in message, (label, message, expected)
                    row.update(new_rejected=True, reason=message)
                else:
                    row["new_rejected"] = False
                results.append(row)
                print(json.dumps(row, ensure_ascii=False), flush=True)
            finally:
                for name in modified:
                    (root / name).write_bytes(original[name])
                assert all((root / name).read_bytes() == original[name] for name in modified)

        def coherent_coins(data: dict[str, Any]) -> None:
            row = data["frames"][off]
            row["before"]["save"]["coins"] += 1
            row["after"]["save"]["coins"] += 1
            for draw in row["draws"]:
                draw["before"]["coins"] += 1
                draw["after"]["coins"] += 1

        trial(
            "truncated matrix",
            lambda w, d, s: d(
                "source.json", lambda x: x["artifacts"].pop("candidate/1152/street-night-off.png")
            ),
            "artifact matrix",
        )
        trial(
            "wrong exact head",
            lambda w, d, s: d("source.json", lambda x: x.__setitem__("head", "0" * 40)),
            "exact head",
        )
        trial(
            "input changed",
            lambda w, d, s: w("inputs/" + c.INPUTS[0], original["inputs/" + c.INPUTS[0]] + b"\n"),
            "input differs",
        )
        trial(
            "effective profile",
            lambda w, d, s: d(
                capture, lambda x: x["frames"][off]["before"].__setitem__("profile", "standard")
            ),
            "profile or seed",
        )
        trial(
            "wrong seed",
            lambda w, d, s: d(
                capture, lambda x: x["frames"][off]["before"].__setitem__("seed", 123)
            ),
            "profile or seed",
        )
        trial(
            "coherent full save change",
            lambda w, d, s: d(capture, coherent_coins),
            "full cross-profile gameplay differs: save",
        )
        trial(
            "target entity changed",
            lambda w, d, s: d(
                capture,
                lambda x: x["frames"][off]["before"]["entities"]["enemies"][0].__setitem__(
                    "alive", False
                ),
            ),
            "draw changed full",
        )
        trial(
            "inactive window",
            lambda w, d, s: d(
                capture, lambda x: x["frames"][off]["observation"].__setitem__("focused", False)
            ),
            "inactive/resized",
        )
        trial(
            "reused frame",
            lambda w, d, s: d(
                capture, lambda x: x["frames"][off]["observation"].__setitem__("process_frame", 0)
            ),
            "nonadvancing",
        )
        trial(
            "wrong actual render pass",
            lambda w, d, s: d(
                capture,
                lambda x: x["frames"][off]["hidden_passes"].__setitem__("door", ["background"]),
            ),
            "actual hidden render pass",
        )
        trial(
            "native target ROI changed",
            lambda w, d, s: d(
                capture, lambda x: x["frames"][off]["targets"]["enemy"]["native"].__setitem__(0, 0)
            ),
            "actual camera/stretch",
        )
        trial(
            "actual bad HUD",
            lambda w, d, s: s(
                "candidate/1152/street-dusk-standard.png",
                "candidate/1152/street-dusk-standard-bad-hud.png",
            ),
            "recolors opaque HUD",
        )
        trial(
            "hidden target replaced by actual full image",
            lambda w, d, s: s(
                "candidate/1152/street-night-off-enemy-hidden.png",
                "candidate/1152/street-night-off.png",
            ),
            "no readable native pixel",
        )
        trial(
            "off is actual standard",
            lambda w, d, s: s(
                "candidate/1152/street-night-off.png", "candidate/1152/street-night-standard.png"
            ),
            "lighting order",
            True,
        )
        trial(
            "truncated timing",
            lambda w, d, s: d(capture, lambda x: x["costs"][0]["observations"].pop()),
            "sample/warmup",
        )
        trial(
            "forged timing interval",
            lambda w, d, s: d(
                capture,
                lambda x: x["costs"][0]["observations"][0].__setitem__(
                    "frame_us", x["costs"][0]["observations"][0]["frame_us"] + 1
                ),
            ),
            "forged interval",
        )
        trial(
            "normal setup userdata",
            lambda w, d, s: d(
                "candidate/import-profile.launch.json",
                lambda x: x["command"].__setitem__(-1, "Normal-user"),
            ),
            "actual OS profile",
        )
        trial(
            "aliased twins",
            lambda w, d, s: d(
                capture,
                lambda x: x["twins"]["standard"][1]["before"]["owner"].__setitem__(
                    "viewport", x["twins"]["standard"][0]["before"]["owner"]["viewport"]
                ),
            ),
            "alias",
        )
        trial(
            "broken standard restore",
            lambda w, d, s: s(
                "candidate/1152/street-night-restored.png", "candidate/1152/street-night-off.png"
            ),
            "exact RGBA",
        )
        verify(root, head)
    assert archive.read_bytes() == archive_bytes
    report = {
        "schema": 1,
        "task": "VLIGHT-010",
        "head": head,
        "archive_sha256": hashlib.sha256(archive_bytes).hexdigest(),
        "historical_functions": old_identity,
        "results": results,
        "all_negative_rejected": all(row.get("new_rejected", True) for row in results),
        "original_unchanged": True,
        "synthetic_positive": False,
    }
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    assert report["all_negative_rejected"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--strict-current", action="store_true")
    args = parser.parse_args()
    run(args.archive, args.head, args.output, args.strict_current)


if __name__ == "__main__":
    main()
