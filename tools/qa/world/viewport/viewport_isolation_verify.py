#!/usr/bin/env python3
"""Verify two native viewport worlds, sealed source bytes and draw-state isolation."""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, cast

from PIL import Image, ImageStat

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root(__file__)
REPORT = ROOT / "docs/reports/visual-overhaul/vrender-009"
NATIVE = REPORT / "native"
MANIFEST_NAME = "evidence-manifest.json"
CASES = ["same-camera", "game-moves", "editor-and-pause", "map-entry", "map-return"]

# Логические ключи съёмки сохраняются и после переноса физических файлов.
WORLD_PATH = "tools/qa/world"
VIEWPORT_PATH = f"{WORLD_PATH}/viewport"
CURRENT_PATHS = {
    f"{WORLD_PATH}/{name}": f"{VIEWPORT_PATH}/{name}"
    for name in (
        "test_viewport_isolation.py",
        "viewport_isolation_capture.gd",
        "viewport_isolation_review.gd",
        "viewport_isolation_verify.py",
    )
}
CAPTURE_SCRIPT = f"{WORLD_PATH}/viewport_isolation_capture.gd"
CAPTURE_IMPLEMENTATION = CURRENT_PATHS[CAPTURE_SCRIPT]
CAPTURE_ALIAS = f'extends "res://{CAPTURE_IMPLEMENTATION}"\n'.encode()
# Git may check out the one-line entry as CRLF on Windows.
CAPTURE_ALIAS_BYTES = (CAPTURE_ALIAS, CAPTURE_ALIAS.replace(b"\n", b"\r\n"))
SOURCES = [
    "project.godot",
    "main.tscn",
    "scripts/core/game_bootstrap.gd",
    "scripts/core/game_preview_bootstrap.gd",
    "scripts/core/game_unhandled_input_router.gd",
    "scripts/game_core.gd",
    "scripts/state/world_state.gd",
    "scripts/presentation/post_motion_frame.gd",
    "scripts/presentation/village_ground_clock.gd",
    "scripts/presentation/viewport_world_context.gd",
    "scripts/presentation/village_terrain_canvas.gd",
    "scripts/systems/camera_system.gd",
    "scripts/systems/estate_system.gd",
    "scripts/systems/fence_system.gd",
    "scripts/systems/render_system.gd",
    "scripts/systems/save_system.gd",
    "scripts/systems/world_projection_system.gd",
    "scripts/world_background.gd",
    "tests/suites/post_motion_frame_suite.gd",
    "tests/suites/viewport_world_context_suite.gd",
    "tools/qa/world/render_order_game.gd",
    *CURRENT_PATHS,
    "tools/quality/godot.py",
    "tools/quality/test_quality.py",
]


def require(value: object, label: str) -> None:
    """Reject incomplete native evidence instead of repairing it."""
    if not value:
        raise ValueError(label)


def digest(path: Path) -> str:
    """Return an exact byte identity for source and image evidence."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def byte_digest(value: bytes) -> str:
    """Return an exact identity for a Git blob."""
    return hashlib.sha256(value).hexdigest()


def git(root: Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    """Run Git without accepting inherited repository substitutions."""
    return subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), *arguments],
        env=git_environment(),
        check=check,
        capture_output=True,
    )


def git_blob(root: Path, commit: str, name: str) -> bytes:
    """Read one source exactly from the declared real commit."""
    return git(root, "cat-file", "blob", f"{commit}:{name}").stdout


def require_commit(root: Path, commit: str, label: str) -> None:
    """Reject abbreviated IDs, ref names, and non-commit objects."""
    require(isinstance(commit, str) and re.fullmatch(r"[0-9a-f]{40}", commit), label)
    result = git(root, "cat-file", "-t", commit, check=False)
    require(result.returncode == 0 and result.stdout == b"commit\n", label)


def validate_base(root: Path, commit: str) -> None:
    """Require an actual ancestor commit rather than a forty-character label."""
    require_commit(root, commit, "capture base commit")
    require(
        git(root, "merge-base", "--is-ancestor", commit, "HEAD", check=False).returncode == 0,
        "capture base is not an ancestor",
    )


def git_source_paths(root: Path, commit: str) -> dict[str, str]:
    """Select the implementation layout from the same immutable Git tree."""
    # A single commit supplies the whole family. A compatibility script at the
    # old location is never read as an implementation in the new layout.
    tree = git(root, "ls-tree", "-r", "-z", "--name-only", commit, "--", VIEWPORT_PATH + "/")
    entries = set(tree.stdout.split(b"\0"))
    has_viewport_sources = any(path.encode() in entries for path in CURRENT_PATHS.values())
    return CURRENT_PATHS if has_viewport_sources else {}


def git_sources(root: Path, commit: str) -> dict[str, str]:
    """Hash the complete capture contract from one immutable Git commit."""
    paths = git_source_paths(root, commit)
    return {name: byte_digest(git_blob(root, commit, paths.get(name, name))) for name in SOURCES}


def validate_launch_entry(root: Path, script: object, commit: str | None = None) -> None:
    """Check the entry that ran, using the same tree as the implementation hashes."""
    implementation = (
        CAPTURE_IMPLEMENTATION
        if commit is None
        else git_source_paths(root, commit).get(CAPTURE_SCRIPT, CAPTURE_SCRIPT)
    )
    is_alias = script == CAPTURE_SCRIPT and implementation == CAPTURE_IMPLEMENTATION
    if script != implementation and not is_alias:
        raise ValueError("capture script is unavailable in the source layout")
    entry_path = CAPTURE_SCRIPT if is_alias else implementation
    if commit is None:
        path = root / entry_path
        require(
            path.is_file()
            and not path.is_symlink()
            and path.resolve() == root.resolve() / entry_path,
            "capture launch entry is missing or is not a regular file",
        )
        if is_alias:
            require(
                path.read_bytes() in CAPTURE_ALIAS_BYTES, "capture launch entry does not delegate"
            )
    else:
        entry = git(root, "ls-tree", "-z", commit, "--", entry_path).stdout
        require(
            entry.startswith((b"100644 blob ", b"100755 blob ")),
            "capture launch entry is missing or is not a regular file",
        )
        if is_alias:
            require(
                git_blob(root, commit, entry_path) in CAPTURE_ALIAS_BYTES,
                "capture launch entry does not delegate",
            )


def source_overlay(root: Path, base: str, sources: dict[str, str]) -> dict[str, str]:
    """Compare logical keys with their implementation in the actual base commit."""
    baseline = git_sources(root, base)
    return {name: digest for name, digest in sources.items() if baseline[name] != digest}


def validate_source_commit(root: Path, base: str, commit: str) -> None:
    """Require a real accepted-source commit on the current ancestry."""
    require_commit(root, commit, "source commit")
    require(
        git(root, "merge-base", "--is-ancestor", base, commit, check=False).returncode == 0,
        "source commit does not descend from capture base",
    )
    require(
        git(root, "merge-base", "--is-ancestor", commit, "HEAD", check=False).returncode == 0,
        "source commit is not an ancestor",
    )


def stable_image(path: Path, size: list[int]) -> dict[str, Any]:
    """Require an actual non-flat PNG with the declared dimensions."""
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        require(list(rgba.size) == size, f"image size: {path.name}")
        require(
            sum(ImageStat.Stat(rgba.convert("RGB")).var) > 120.0,
            f"non-flat image: {path.name}",
        )
    return {"file": path.name, "sha256": digest(path), "bytes": path.stat().st_size}


def with_pause_tutorial(snapshot: dict[str, Any]) -> dict[str, Any]:
    """Return the one expected persisted effect of manually opening pause."""
    expected: dict[str, Any] = json.loads(json.dumps(snapshot))
    expected["estate"]["expansion"]["first_chapter"]["events"]["pause_menu"] = True
    expected["tutorial"]["events"]["pause_menu"] = True
    return expected


def expected_image_names(data: dict[str, Any]) -> set[str]:
    """Return the exact five composites and ten viewport readbacks."""
    names: set[str] = set()
    for row in data["rows"]:
        names.add(row["composite_file"])
        names.update(state["viewport_file"] for state in row["states"])
    return names


def load_manifest(report: Path, root: Path) -> dict[str, Any]:
    """Use the Git-indexed canonical seal even when testing a damaged report copy."""
    relative = REPORT.relative_to(ROOT) / MANIFEST_NAME
    canonical = root / relative
    candidate = report / MANIFEST_NAME
    require(canonical.is_file() and candidate.is_file(), "sealed evidence manifest")
    require(digest(candidate) == digest(canonical), "foreign evidence manifest")
    indexed = git(root, "show", ":" + relative.as_posix()).stdout
    require(byte_digest(indexed) == digest(canonical), "manifest differs from Git index")
    manifest = cast(dict[str, Any], json.loads(candidate.read_text()))
    require(
        manifest.get("schema") == 2
        and manifest.get("task") == "VRENDER-009"
        and "source_commit" in manifest,
        "manifest schema",
    )
    return manifest


def current_sources(root: Path) -> dict[str, str]:
    """Hash every runtime, test and QA input named by the capture contract."""
    return {name: digest(root / CURRENT_PATHS.get(name, name)) for name in SOURCES}


def seal(report: Path = REPORT, root: Path = ROOT) -> dict[str, Any]:
    """Seal capture-time bytes against one real base commit and an explicit overlay."""
    report = Path(report)
    native = report / "native"
    capture = native / "capture.json"
    data = json.loads(capture.read_text())
    base = data["base_commit"]
    validate_base(root, base)
    sources = current_sources(root)
    provenance = data.get("provenance", {})
    require(provenance.get("sources") == sources, "capture-time source bytes")
    configuration = provenance.get("launch", {})
    validate_launch_entry(root, configuration.get("script"))
    names = expected_image_names(data)
    images = {name: digest(native / name) for name in sorted(names)}
    require(provenance.get("images") == images, "capture-time image bytes")
    overlay = source_overlay(root, base, sources)
    manifest: dict[str, Any] = {
        "schema": 2,
        "task": "VRENDER-009",
        "base_commit": base,
        "source_commit": None,
        "capture_sha256": digest(capture),
        "sources": sources,
        "overlay": overlay,
        "images": images,
        "configuration": configuration,
    }
    (report / MANIFEST_NAME).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def bind_source_commit(commit: str, report: Path = REPORT, root: Path = ROOT) -> dict[str, Any]:
    """Bind an accepted current-mode package to exact sources in a real commit."""
    verify(report, root, check_current_candidate=True)
    path = Path(report) / MANIFEST_NAME
    manifest = cast(dict[str, Any], json.loads(path.read_text()))
    require(manifest.get("source_commit") is None, "source commit already bound")
    validate_source_commit(root, manifest["base_commit"], commit)
    require(git_sources(root, commit) == manifest["sources"], "source commit bytes changed")
    validate_launch_entry(root, manifest["configuration"].get("script"), commit)
    manifest["source_commit"] = commit
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def state_by_role(row: dict[str, Any], role: str) -> dict[str, Any]:
    """Return a role after exact role-order validation."""
    require([state["role"] for state in row["states"]] == ["game", "preview"], "state roles")
    return cast(dict[str, Any], row["states"][0 if role == "game" else 1])


def stable_fields(state: dict[str, Any]) -> dict[str, Any]:
    """Select every field that a neighbouring viewport must leave unchanged."""
    return {
        key: state[key]
        for key in [
            "owner",
            "location",
            "player",
            "camera",
            "seconds",
            "frame_owner",
            "frame_viewport_owner",
            "frame_background_owner",
            "background_position",
            "background_scale",
            "save",
        ]
    }


def verify(
    report: Path = REPORT, root: Path = ROOT, *, check_current_candidate: bool = False
) -> dict[str, Any]:
    """Validate provenance, owners, both mutation directions and exact render-only draws."""
    report = Path(report)
    native = report / "native"
    capture = native / "capture.json"
    manifest = load_manifest(report, root)
    require(digest(capture) == manifest["capture_sha256"], "capture bytes changed")
    data = json.loads(capture.read_text())
    require(data["task"] == "VRENDER-009", "capture task")
    require(data["base_commit"] == manifest["base_commit"], "capture base identity")
    validate_base(root, data["base_commit"])
    provenance = data.get("provenance", {})
    require(set(manifest["sources"]) == set(SOURCES), "sealed source set")
    require(provenance.get("sources") == manifest["sources"], "captured source manifest")
    source_commit = manifest["source_commit"]
    script = manifest["configuration"].get("script")
    if source_commit is None or check_current_candidate:
        require(current_sources(root) == manifest["sources"], "runtime source bytes changed")
        validate_launch_entry(root, script)
    source_validation = "current"
    if source_commit is not None:
        validate_source_commit(root, data["base_commit"], source_commit)
        require(
            git_sources(root, source_commit) == manifest["sources"],
            "source commit bytes changed",
        )
        validate_launch_entry(root, script, source_commit)
        source_validation = "current+git-commit" if check_current_candidate else "git-commit"
    expected_overlay = source_overlay(root, data["base_commit"], manifest["sources"])
    require(manifest["overlay"] == expected_overlay, "unsealed source overlay")
    require(provenance.get("images") == manifest["images"], "captured image manifest")
    require(provenance.get("launch") == manifest["configuration"], "capture configuration")
    require(
        manifest["configuration"]
        == {
            "script": script,
            "window": [1152, 648],
            "logical_viewport": [1152, 648],
            "cases": CASES,
            "profile": data["profile"],
            "engine": data["engine"],
            "display": data["display"],
        },
        "exact native launch configuration",
    )
    require(
        data["display"] != "headless" and not data["errors"],
        "native display and clean capture",
    )
    require(
        data["window"] == [1152, 648] and data["logical_viewport"] == [1152, 648],
        "exact viewport sizes",
    )
    require(
        data["coverage"]
        == [
            "hero",
            "bush",
            "rails",
            "foreground",
            "HUD",
            "manual-pause",
            "F12",
            "map-entry-return",
        ],
        "required visual route",
    )
    require([row["id"] for row in data["rows"]] == CASES, "ordered route")
    require(set(manifest["images"]) == expected_image_names(data), "exact image set")
    images = []
    tokens: dict[str, dict[str, int]] = {}
    for row in data["rows"]:
        require(row["composite_size"] == data["window"], "composite readback")
        composite = stable_image(native / row["composite_file"], data["window"])
        require(
            composite["sha256"] == manifest["images"][row["composite_file"]],
            "composite hash",
        )
        images.append(composite)
        require(len(row["states"]) == 2, "two states per case")
        state_by_role(row, "game")
        for state in row["states"]:
            role = state["role"]
            token = state["owner"]
            require(set(token) == {"game", "viewport", "background"}, "bounded owner token")
            require(
                all(isinstance(value, int) and value > 0 for value in token.values()),
                "numeric owner ids",
            )
            frame = (
                state["frame_owner"],
                state["frame_viewport_owner"],
                state["frame_background_owner"],
            )
            expected_frame = (token["game"], token["viewport"], token["background"])
            if row["id"] == "editor-and-pause" and role == "game":
                require(frame == (0, 0, 0), "editor invalidates its old post-motion frame")
            else:
                require(frame == expected_frame, "frame belongs to complete viewport world")
            require(state["viewport_size"] == [1152.0, 648.0], "full source viewport")
            viewport_image = stable_image(native / state["viewport_file"], [1152, 648])
            require(
                viewport_image["sha256"] == manifest["images"][state["viewport_file"]],
                "viewport image hash",
            )
            images.append(viewport_image)
            require(len(state["draws"]) == 2, "two production draws per role and case")
            require(
                all(
                    draw["equal"] and draw["geometry_equal"] and draw["queue_after"] == 0
                    for draw in state["draws"]
                ),
                "production draw is pure",
            )
            require(
                all(draw["before"] == draw["after"] == state["save"] for draw in state["draws"]),
                "full save snapshots around draw",
            )
            if role in tokens:
                require(tokens[role] == token, "stable owner across modes and maps")
            else:
                tokens[role] = token
        require(
            row["states"][0]["owner"]["game"] != row["states"][1]["owner"]["game"],
            "distinct game owners",
        )
        require(
            row["states"][0]["owner"]["viewport"] != row["states"][1]["owner"]["viewport"],
            "distinct viewport owners",
        )

    same, moved, modes, entered, returned = data["rows"]
    same_game, same_preview = state_by_role(same, "game"), state_by_role(same, "preview")
    moved_game, moved_preview = state_by_role(moved, "game"), state_by_role(moved, "preview")
    modes_game, modes_preview = state_by_role(modes, "game"), state_by_role(modes, "preview")
    entered_game, entered_preview = (
        state_by_role(entered, "game"),
        state_by_role(entered, "preview"),
    )
    returned_game, returned_preview = (
        state_by_role(returned, "game"),
        state_by_role(returned, "preview"),
    )
    require(
        same_game["player"] == same_preview["player"]
        and same_game["camera"] == same_preview["camera"]
        and same_game["background_position"] == same_preview["background_position"]
        and same_game["background_scale"] == same_preview["background_scale"],
        "same-camera comparison",
    )
    require(same_game["seconds"] != same_preview["seconds"], "independent initial time")
    require(
        moved_game["player"] != same_game["player"]
        and moved_game["camera"] != same_game["camera"]
        and moved_game["background_position"] != same_game["background_position"]
        and stable_fields(moved_preview) == stable_fields(same_preview),
        "game movement changes only the game viewport",
    )
    reverse = data["reverse_isolation"]
    require(reverse["game_before"] == reverse["game_after"], "preview cannot alter active game")
    require(
        reverse["preview_before"]["owner"] == reverse["preview_after"]["owner"]
        and reverse["preview_before"]["player"] != reverse["preview_after"]["player"]
        and reverse["preview_before"]["camera"] != reverse["preview_after"]["camera"]
        and reverse["preview_before"]["background_position"]
        != reverse["preview_after"]["background_position"]
        and reverse["preview_before"]["seconds"] < reverse["preview_after"]["seconds"],
        "preview moves through its own camera background clock and frame",
    )
    require(
        reverse["preview_before"]["save"] != reverse["preview_after"]["save"],
        "preview movement advances its own saved simulation",
    )
    require(
        modes_game["editor"]
        and modes_preview["pause"]
        and modes_game["player"] == moved_game["player"]
        and modes_game["seconds"] == moved_game["seconds"]
        and modes_game["save"] == moved_game["save"],
        "editor changes no game simulation or save",
    )
    require(
        modes_preview["player"] == reverse["preview_after"]["player"]
        and modes_preview["camera"] == reverse["preview_after"]["camera"]
        and modes_preview["background_position"] == reverse["preview_after"]["background_position"]
        and modes_preview["seconds"] == reverse["preview_after"]["seconds"],
        "manual pause freezes the moved preview world",
    )
    require(
        modes_preview["save"] == with_pause_tutorial(reverse["preview_after"]["save"]),
        "preview pause records only its own tutorial after movement",
    )
    require(
        entered_game["location"] == "village_market"
        and entered_preview["location"] == "overworld"
        and stable_fields(entered_preview) == stable_fields(modes_preview),
        "isolated map entry leaves the preview world unchanged",
    )
    require(
        returned_game["location"] == returned_preview["location"] == "overworld"
        and stable_fields(returned_preview) == stable_fields(entered_preview)
        and returned_game["seconds"] > entered_game["seconds"],
        "actual map return leaves the preview world unchanged",
    )
    require(
        len(images) == 15
        and sum(len(state["draws"]) for row in data["rows"] for state in row["states"]) == 20,
        "exact evidence cardinality",
    )
    tree_hash = hashlib.sha256(
        "\n".join(f"{name}:{manifest['sources'][name]}" for name in sorted(SOURCES)).encode()
    ).hexdigest()
    return {
        "task": "VRENDER-009",
        "base_commit": data["base_commit"],
        "source_commit": source_commit,
        "source_validation": source_validation,
        "configuration": manifest["configuration"],
        "capture_sha256": manifest["capture_sha256"],
        "source_tree_sha256": tree_hash,
        "sources": manifest["sources"],
        "overlay": manifest["overlay"],
        "owners": tokens,
        "native_cases": len(data["rows"]),
        "production_draws": 20,
        "full_save_pairs": 20,
        "performance_eligible": False,
        "full_map_accepted": False,
        "images": images,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--seal", action="store_true")
    action.add_argument("--bind-source-commit")
    action.add_argument("--check-current-candidate", action="store_true")
    parser.add_argument("--write", action="store_true")
    arguments = parser.parse_args()
    if arguments.seal:
        print(json.dumps(seal(), ensure_ascii=False, indent=2))
    elif arguments.bind_source_commit:
        print(
            json.dumps(
                bind_source_commit(arguments.bind_source_commit), ensure_ascii=False, indent=2
            )
        )
    else:
        result = verify(check_current_candidate=arguments.check_current_candidate)
        if arguments.write:
            REPORT.mkdir(parents=True, exist_ok=True)
            (REPORT / "summary.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2) + "\n"
            )
        print(json.dumps(result, ensure_ascii=False, indent=2))
