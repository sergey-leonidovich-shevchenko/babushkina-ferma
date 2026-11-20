"""Проверяет Git/QA/asset происхождение и эффективные профили нативной серии."""

from __future__ import annotations

import re
from typing import Any

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle.evidence import Evidence


def config_without_version(raw: bytes) -> tuple[bytes, str]:
    """Исключает ровно SemVer метаданных; остальные настройки framebuffer остаются точными."""
    pattern = rb'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
    matches = list(re.finditer(pattern, raw))
    c.need(len(matches) == 1, "one project SemVer required")
    return re.sub(pattern, b'config/version="<metadata>"', raw), matches[0].group(1).decode()


def check(store: Evidence, source: dict[str, Any], current: bool) -> None:
    """Все runtime blobs читаются из настоящей истории; QA bytes сверяются с записанным head."""
    c.need(
        source["task"] == "VLIGHT-003" and source["base"] == c.BASE and source["complete"],
        "source/task/completeness differs",
    )
    c.need(set(source["inputs"]) == set(c.INPUTS), "producer input closure differs")
    c.need(set(source["artifacts"]) == c.artifacts(), "complete native artifact inventory differs")
    c.need(set(source["variants"]) == {"baseline", "candidate"}, "Git variant matrix differs")
    for name, digest in source["inputs"].items():
        raw = store.read("inputs/" + name)
        c.need(c.digest(raw) == digest, "QA input hash differs: " + name)
        c.need(
            raw == shared.git("show", source["head"] + ":" + name),
            "QA input is not captured Git head",
        )
        if current:
            c.need((c.ROOT / name).read_bytes() == raw, "current QA producer differs")
    for name, digest in source["artifacts"].items():
        c.need(c.digest(store.read(name)) == digest, "native artifact hash differs: " + name)
    for label, commit in (("baseline", c.BASE), ("candidate", source["head"])):
        row = source["variants"][label]
        c.need(
            set(row["runs"]) == {str(width) for width in c.WIDTHS}, "native width matrix differs"
        )
        c.need(row["commit"] == commit, "variant Git commit differs")
        c.need(
            row["tree"] == shared.git("rev-parse", commit + "^{tree}").decode().strip(),
            "variant Git tree differs",
        )
        c.need(
            store.document(label + "/production-blobs.json") == c.blobs(commit),
            "production asset/runtime inventory differs",
        )
        for setup in ("import", "compile", "import-profile", "1152-profile", "1280-profile"):
            launch = store.document(f"{label}/{setup}.launch.json")
            log = store.read(f"{label}/{setup}.txt").decode()
            c.need(
                launch["complete"]
                and launch["exit_code"] == 0
                and "--headless" in launch["command"],
                "headless setup launch differs",
            )
            c.need(
                "Godot Engine v4.7.1.stable.official.a13da4feb" in log
                and not any(mark in log for mark in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
                "setup engine log differs",
            )
            if setup.endswith("profile"):
                profile = (
                    row["import_profile"]
                    if setup == "import-profile"
                    else row["runs"][setup.split("-")[0]]["profile"]
                )
                c.need(
                    launch["command"][-1] == profile and log.rstrip().endswith("/" + profile),
                    "actual setup profile differs",
                )
    if current:
        old = c.blobs(source["head"])
        now = c.blobs("HEAD")
        c.need(set(old) == set(now), "current production file set differs")
        for name, oid in old.items():
            raw = (c.ROOT / name).read_bytes()
            if name == "VERSION":
                continue
            if name == "project.godot":
                captured = shared.git("show", source["head"] + ":" + name)
                left, _ = config_without_version(captured)
                right, version = config_without_version(raw)
                c.need(
                    left == right and (c.ROOT / "VERSION").read_text().strip() == version,
                    "current config differs beyond SemVer",
                )
            else:
                c.need(c.blob_id(raw) == oid, "current runtime differs: " + name)
