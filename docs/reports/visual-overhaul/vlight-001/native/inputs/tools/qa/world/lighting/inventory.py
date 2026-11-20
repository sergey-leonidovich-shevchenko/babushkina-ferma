"""Строит ведомость настоящих световых владельцев по закреплённым исходникам."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.lighting.contract import ROOT, digest, git, head

ATMOSPHERE = "scripts/systems/atmosphere_renderer.gd"
CAVE = "scripts/systems/cave_renderer.gd"
THEME = "scripts/systems/cave_theme_renderer.gd"
ARENA = "scripts/systems/cave_boss_arena_renderer.gd"


@dataclass(frozen=True)
class Entry:
    """Отделяет художественный эффект от физического освещения и его игровой причины."""

    id: str
    source: str
    function: str
    coordinates: str
    representation: str
    clock: str
    retain: str
    followup: str
    scope: str = "first-location"


ENTRIES = (
    Entry(
        "world-darkness",
        ATMOSPHERE,
        "draw",
        "screen-after-world-before-HUD",
        "alpha rectangle",
        "game_minutes",
        "Календарь и событие затмения",
        "VLIGHT-003",
    ),
    Entry(
        "village-lamp",
        "scripts/presentation/village_lamp_visual.gd",
        "draw_glow",
        "screen-after-darkness",
        "shared colored ArrayMesh",
        "WorldEventSystem.darkness",
        "Корпус, emitter-anchor и три ракурса",
        "VLIGHT-004",
    ),
    Entry(
        "window-ray",
        "scripts/systems/interior_renderer.gd",
        "draw_textured_shell",
        "world-before-actors",
        "constant alpha polygon",
        "none",
        "Окно, привязка к комнате и коллизии",
        "VLIGHT-005",
    ),
    Entry(
        "eclipse-portal",
        ATMOSPHERE,
        "draw_lights",
        "screen-after-darkness",
        "alpha circle",
        "day/game_minutes",
        "Условия перехода и положение портала",
        "VLIGHT-002",
    ),
    Entry(
        "eclipse-sky",
        ATMOSPHERE,
        "draw_eclipse",
        "screen-before-HUD",
        "decorative circles; not illumination",
        "day/game_minutes",
        "Небесное событие; не выключать вместе со светом",
        "VLIGHT-009",
    ),
    Entry(
        "storm-flash",
        ATMOSPHERE,
        "draw_rain",
        "screen-before-HUD",
        "weather-owned white alpha rectangle; not a local light",
        "wall-clock Time.get_ticks_msec",
        "Погоду и вспышку не выключать прибором освещения; комфорт и тон проверять отдельно",
        "VLIGHT-009",
    ),
    Entry(
        "moon-return-portal",
        ATMOSPHERE,
        "draw_lights",
        "screen-after-darkness",
        "alpha circle; moon_glade only",
        "game_minutes; reduced scene darkness",
        "Условия возврата и маркер перехода; только аудит существующего владельца",
        "VLIGHT-002",
        "compatibility-source-only",
    ),
    Entry(
        "cave-vein",
        CAVE,
        "draw_lights",
        "world-before-actors",
        "shared radial GradientTexture2D",
        "wall-clock Time.get_ticks_msec",
        "Истощённая жила не светится",
        "VLIGHT-007",
        "compatibility-source-only",
    ),
    Entry(
        "cave-entrance-torch",
        CAVE,
        "draw_lights",
        "world-before-actors",
        "shared radial GradientTexture2D",
        "wall-clock Time.get_ticks_msec",
        "Привязки к существующему выходу",
        "VLIGHT-006",
        "compatibility-source-only",
    ),
    Entry(
        "cave-static-beds",
        THEME,
        "draw_background",
        "cached-world-background",
        "tinted radial texture and painted vegetation",
        "none",
        "Статичный декор и открытые проходы",
        "VLIGHT-007",
        "compatibility-source-only",
    ),
    Entry(
        "cave-dynamic-beds",
        THEME,
        "draw_lights",
        "world-before-actors",
        "radial textures and decorative lake arcs",
        "wall-clock Time.get_ticks_msec",
        "Кластеры, водоёмы и декор",
        "VLIGHT-007",
        "compatibility-source-only",
    ),
    Entry(
        "boss-crystals-and-seals",
        ARENA,
        "draw_lights",
        "world-before-actors",
        "radial textures, polygons and seal line",
        "saved cave_boss.clock",
        "Победа, печати и возможность выхода",
        "VLIGHT-007",
        "compatibility-source-only",
    ),
    Entry(
        "cave-passages",
        CAVE,
        "_draw_passage",
        "world-gate-pass",
        "radial texture and decorative arc",
        "none",
        "Межкомнатные переходы и подписи",
        "VLIGHT-002",
        "compatibility-source-only",
    ),
    Entry(
        "kitchen-fire-and-steam",
        "scripts/presentation/kitchen_fx_renderer.gd",
        "draw",
        "world-station-pass",
        "fire sprite frames and steam circles; no light cast",
        "paid job progress",
        "Топливо, рецепт, пауза и производство",
        "VLIGHT-006",
        "compatibility-source-only",
    ),
    Entry(
        "basement-painted-lantern",
        "scripts/presentation/basement_room_renderer.gd",
        "draw",
        "cached-interior-background",
        "painted lantern texture; no separate glow",
        "none",
        "Самостоятельный спрайт и его пропорции",
        "VLIGHT-006",
        "compatibility-source-only",
    ),
)
INPUTS = tuple(
    sorted(
        {entry.source for entry in ENTRIES}
        | {
            "scripts/systems/render_system.gd",
            "scripts/systems/world_event_system.gd",
            "scripts/systems/cave_lighting_system.gd",
            "scripts/presentation/visual_reference_mode.gd",
            "scripts/presentation/viewport_world_context.gd",
            "assets/game/locations/overworld/lamps/profile.json",
            "main.tscn",
            "project.godot",
        }
    )
)


def inventory(commit: str | None = None) -> dict[str, Any]:
    """Ссылки, SHA и отсутствие специальных light nodes проверяются по реальному Git tree."""
    commit = commit or head()
    inputs = {name: git("show", commit + ":" + name) for name in INPUTS}
    rows = []
    for entry in ENTRIES:
        text = inputs[entry.source].decode()
        matches = list(
            re.finditer(r"^static func " + re.escape(entry.function) + r"\(", text, re.MULTILINE)
        )
        if len(matches) != 1:
            raise ValueError("missing or ambiguous lighting owner: " + entry.id)
        rows.append({**asdict(entry), "line": text.count("\n", 0, matches[0].start()) + 1})
    names = (
        git("ls-tree", "-r", "--name-only", commit, "--", "main.tscn", "scripts", "assets/game")
        .decode()
        .splitlines()
    )
    scanned = {name for name in names if name.endswith((".gd", ".tscn"))}
    # Один Git grep читает закреплённый tree без сотен отдельных дочерних git show.
    search = subprocess.run(
        [
            "git",
            "--no-replace-objects",
            "-C",
            str(ROOT),
            "grep",
            "-n",
            "-I",
            "-E",
            r"\b(PointLight2D|DirectionalLight2D|CanvasModulate|LightOccluder2D|WorldEnvironment)\b",
            commit,
            "--",
            "main.tscn",
            "scripts",
            "assets/game",
        ],
        env=git_environment(),
        capture_output=True,
        text=True,
        check=False,
    )
    if search.returncode not in (0, 1):
        raise ValueError("lighting source search failed: " + search.stderr)
    dedicated_nodes = []
    for line in search.stdout.splitlines():
        source, number, text = line.removeprefix(commit + ":").split(":", 2)
        if source in scanned:
            dedicated_nodes.append({"source": source, "line": int(number), "text": text.strip()})
    return {
        "schema": 1,
        "task": "VLIGHT-001",
        "commit": commit,
        "sources": {
            name: {"sha256": digest(raw), "bytes": len(raw)} for name, raw in inputs.items()
        },
        "owners": rows,
        "dedicated_light_nodes": dedicated_nodes,
        "scanned_runtime_sources": len(scanned),
        "lamp_profile": json.loads(inputs["assets/game/locations/overworld/lamps/profile.json"]),
        "native_acceptance": False,
        "performance_eligible": False,
        "note": "Source inventory only. Cave/interior production systems are preserved; native matrix is separate.",
    }


def main() -> None:
    """Отчёт идёт в stdout либо новый явно указанный файл; существующий не заменяется."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = json.dumps(inventory(), ensure_ascii=False, indent=2) + "\n"
    if args.output is None:
        print(result, end="")
    else:
        if any(
            path.is_symlink() for path in (args.output.absolute(), *args.output.absolute().parents)
        ):
            raise ValueError("output must not traverse symlinks")
        with args.output.open("x") as stream:
            stream.write(result)


if __name__ == "__main__":
    main()
