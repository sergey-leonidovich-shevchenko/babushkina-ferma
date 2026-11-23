"""Проверяет полный Git/QA/PNG manifest VLIGHT-010 и действительные engine argv/logs."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence


def versionless(raw: bytes) -> tuple[bytes, str]:
    """Разрешает только согласованный SemVer, сохраняя прочие настройки byte-exact."""
    pattern = rb'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
    matches = list(re.finditer(pattern, raw))
    c.need(len(matches) == 1, "one exact project version required")
    return re.sub(pattern, b'config/version="<metadata>"', raw), matches[0].group(1).decode()


def current_candidate(source: dict[str, Any]) -> None:
    """Грязный checkout и смена runtime/QA не допускаются как якобы только новый отчёт."""
    c.need(
        not c.shared.git("status", "--porcelain", "--untracked-files=all"),
        "strict current-candidate requires clean source",
    )
    old, now = c.blobs(source["head"]), c.blobs("HEAD")
    c.need(set(old) == set(now), "current runtime/asset file set differs")
    for name, oid in old.items():
        captured = c.shared.git("show", source["head"] + ":" + name)
        working = (c.ROOT / name).read_bytes()
        if name == "VERSION":
            c.need(
                bool(re.fullmatch(rb"[0-9]+\.[0-9]+\.[0-9]+\n?", working)), "invalid current SemVer"
            )
        elif name == "project.godot":
            left, _ = versionless(captured)
            right, version = versionless(working)
            c.need(
                left == right and (c.ROOT / "VERSION").read_text().strip() == version,
                "current project differs beyond SemVer",
            )
        else:
            c.need(captured == working, "current runtime bytes differ: " + name)
            c.need(now[name] == oid, "current committed runtime differs: " + name)


def launch(store: Evidence, source: dict[str, Any], label: str, width: int) -> None:
    """Оконный аргумент и output проверяются независимо от самоподписанного имени режима."""
    row = source["variants"][label]
    run = row["runs"][str(width)]
    receipt = store.document(f"{label}/{width}.launch.json")
    command = receipt["command"]
    c.need(receipt["complete"] and receipt["exit_code"] == 0, "native launch failed/incomplete")
    c.need(
        len(command) > 4 and command[1] == "--path" and Path(command[0]).is_absolute(),
        "native command prefix differs",
    )
    project = Path(command[2])
    c.need(project.name == "project" and project.parent.name == label, "wrong native project owner")
    profile = run["profile"]
    c.need(
        bool(re.fullmatch(r"Codex-VLIGHT-010-[0-9a-f]{32}", profile)),
        "native profile is not UUID isolated",
    )
    expected = [
        "--windowed",
        "--resolution",
        f"{width}x{width * 9 // 16}",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--script",
        "res://" + c.PREFIX + "capture.gd",
        "--",
        "--output=" + str(project.parent / str(width)),
        "--profile=" + profile,
    ]
    if width == 1280:
        expected.append("--wide")
    if label == "baseline":
        expected.append("--baseline")
    c.need(command[3:] == expected == run["arguments"], "actual native argv differs")
    raw = store.read(f"{label}/{width}.txt").decode()
    c.need(
        raw.count(c.BANNER) == 1
        and "LIGHT QUALITY NATIVE:" in raw
        and not any(x in raw for x in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
        "native actual engine log differs",
    )


def check(store: Evidence, source: dict[str, Any], expected_head: str, current: bool) -> None:
    """Все входы и artifacts сверяются с настоящими Git bytes, а не только со своим SHA."""
    c.need(
        source["schema"] == 1 and source["task"] == "VLIGHT-010" and source["complete"] is True,
        "wrong task/schema or incomplete source",
    )
    c.need(
        source["base"] == c.BASE
        and source["head"] == expected_head
        and re.fullmatch("[0-9a-f]{40}", expected_head),
        "wrong base or exact head",
    )
    c.need(set(source["inputs"]) == set(c.INPUTS), "producer/reader input closure differs")
    c.need(set(source["artifacts"]) == c.artifacts(), "full native artifact matrix differs")
    c.need(set(source["variants"]) == {"baseline", "candidate"}, "Git variant set differs")
    c.need(
        source["hardware_fps_acceptance"] is False, "software capture cannot accept hardware FPS"
    )
    for name, digest in source["inputs"].items():
        raw = store.read("inputs/" + name)
        c.need(
            c.digest(raw) == digest and raw == c.shared.git("show", expected_head + ":" + name),
            "input differs from captured Git: " + name,
        )
        if current:
            c.need((c.ROOT / name).read_bytes() == raw, "current QA input differs: " + name)
    for name, digest in source["artifacts"].items():
        c.need(c.digest(store.read(name)) == digest, "artifact SHA differs: " + name)
    for label, commit in (("baseline", c.BASE), ("candidate", expected_head)):
        row = source["variants"][label]
        c.need(
            row["commit"] == commit
            and row["tree"] == c.shared.git("rev-parse", commit + "^{tree}").decode().strip(),
            "variant Git identity differs",
        )
        c.need(
            store.document(label + "/production-blobs.json") == c.blobs(commit),
            "full production inventory differs",
        )
        c.need(set(row["runs"]) == {str(w) for w in c.WIDTHS}, "native widths differ")
        native = store.document(f"{label}/1152.launch.json")["command"]
        prefix = native[:3]
        c.need(len(prefix) == 3 and prefix[1] == "--path", "setup project prefix missing")
        profiles = [row["import_profile"], *(run["profile"] for run in row["runs"].values())]
        c.need(
            len(set(profiles)) == 3
            and all(re.fullmatch(r"Codex-VLIGHT-010-[0-9a-f]{32}", p) for p in profiles),
            "setup/native UUID profiles must be distinct",
        )
        for setup in ("import-profile", "import", "compile", "1152-profile", "1280-profile"):
            receipt = store.document(f"{label}/{setup}.launch.json")
            log = store.read(f"{label}/{setup}.txt").decode()
            c.need(
                receipt["complete"]
                and receipt["exit_code"] == 0
                and "--headless" in receipt["command"],
                "setup launch differs",
            )
            c.need(
                log.count(c.BANNER) == 1
                and not any(x in log for x in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
                "setup actual engine log differs",
            )
            if setup.endswith("profile"):
                selected = (
                    row["import_profile"]
                    if setup == "import-profile"
                    else row["runs"][setup.split("-")[0]]["profile"]
                )
                c.need(
                    receipt["command"][-1] == selected and log.rstrip().endswith("/" + selected),
                    "actual OS profile differs",
                )
                expected = [
                    "--headless",
                    "--script",
                    "res://" + c.PREFIX + "profile.gd",
                    "--",
                    selected,
                ]
                c.need(log.count("LIGHT QUALITY PROFILE: ") == 1, "actual userdata probe missing")
            elif setup == "import":
                expected = ["--headless", "--editor", "--quit"]
            else:
                expected = [
                    "--headless",
                    "--check-only",
                    "--script",
                    "res://" + c.PREFIX + "capture.gd",
                ]
            c.need(receipt["command"] == prefix + expected, "setup actual argv/project differs")
        for width in c.WIDTHS:
            launch(store, source, label, width)
            c.need(
                store.document(f"{label}/{width}.launch.json")["command"][:3] == prefix,
                "native runs do not share their exported project and engine",
            )
    if current:
        current_candidate(source)
    profiles = [
        selected
        for row in source["variants"].values()
        for selected in [row["import_profile"], *(run["profile"] for run in row["runs"].values())]
    ]
    c.need(len(set(profiles)) == 6, "Git variants share an import/native userdata profile")
