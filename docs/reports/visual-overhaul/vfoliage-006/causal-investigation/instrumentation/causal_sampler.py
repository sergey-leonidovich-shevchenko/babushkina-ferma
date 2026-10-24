"""Generate QA-only subclasses: actual super calls, buffered method spans, no gameplay replacement."""

from pathlib import Path
import re

EXTRA = """
const DIAG_CAP := @CAP@
const DIAG_PLAN := "@PLAN@"
const DIAG_LIMIT := 500000
var diag_names: Array[String] = []
var diag_spans: Array[PackedInt64Array] = []
var diag_states: Array = []
var diag_overflow := false

func diag_record(label: String, start: int, stop: int) -> void:
\tif perf_finished or perf_window_start_us == 0: return
\tvar index := diag_names.find(label)
\tif index < 0:
\t\tindex = diag_names.size()
\t\tdiag_names.append(label)
\tif diag_spans.size() >= DIAG_LIMIT:
\t\tdiag_overflow = true
\t\treturn
\tdiag_spans.append(PackedInt64Array([index, start, stop, Engine.get_process_frames(), Engine.get_physics_frames()]))

func diag_settings() -> Dictionary:
\treturn {"plan_sha256":DIAG_PLAN,"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),
\t\t"driver":RenderingServer.get_current_rendering_driver_name(),"method":RenderingServer.get_current_rendering_method(),
\t\t"render_loop":RenderingServer.render_loop_enabled,"max_fps":Engine.max_fps,
\t\t"low_processor_usage_mode":OS.low_processor_usage_mode,"idle_sleep_usec":OS.low_processor_usage_mode_sleep_usec,
\t\t"delta_smoothing":OS.delta_smoothing,"time_scale":Engine.time_scale,
\t\t"physics_ticks_per_second":Engine.physics_ticks_per_second,"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,
\t\t"tree_paused":get_tree().paused,"process_enabled":is_processing(),"physics_enabled":is_physics_processing(),
\t\t"window_available":false,"focus":null,"vsync":null,"window_size":null,
\t\t"window_reason":"headless backend; no physical window/focus/vsync", "location":current_location,
\t\t"player":[player.x,player.y],"camera":[camera_offset.x,camera_offset.y]}

func diag_frame() -> void:
\tif perf_window_start_us == 0: return
\tif diag_states.size() >= DIAG_LIMIT:
\t\tdiag_overflow = true
\t\treturn
\tdiag_states.append([Time.get_ticks_usec(),Engine.get_process_frames(),Engine.get_physics_frames(),
\t\tPerformance.get_monitor(Performance.TIME_PROCESS),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
\t\tEngine.max_fps,OS.low_processor_usage_mode,OS.low_processor_usage_mode_sleep_usec,Engine.time_scale,
\t\tget_tree().paused,is_processing(),is_physics_processing(),current_location,player.x,player.y,camera_offset.x,camera_offset.y])

func diag_flush() -> void:
\t# End marker is already flushed: keep the owned process alive for the host CPU boundary read.
\tOS.delay_msec(500)
\tprint("DIAG_FINAL ",JSON.stringify({"names":diag_names,"overflow":diag_overflow,"settings":diag_settings()}))
\tfor row in diag_spans: print("DIAG_SPAN ",JSON.stringify(Array(row)))
\tfor row in diag_states: print("DIAG_STATE ",JSON.stringify(row))
"""


def wrap(name, argument=""):
    declaration = "delta: float" if argument else ""
    return (
        f"\nfunc {name}({declaration}) -> void:\n"
        "\tvar diag_start := Time.get_ticks_usec()\n"
        f"\tsuper.{name}({argument})\n"
        f'\tdiag_record("{name}",diag_start,Time.get_ticks_usec())\n'
    )


def generate(project: Path, canonical: bytes, cap: int, plan_sha: str):
    if cap not in (0, 60) or not re.fullmatch(r"[a-f0-9]{64}", plan_sha):
        raise ValueError("unplanned cap/plan")
    text = canonical.decode()
    changes = [
        ("Engine.max_fps = 60", "Engine.max_fps = DIAG_CAP"),
        ("if Engine.max_fps != 60:", "if Engine.max_fps != DIAG_CAP:"),
        (
            "\tsuper._process(delta)\n",
            '\tvar diag_start := Time.get_ticks_usec()\n\tsuper._process(delta)\n\tdiag_record("_process",diag_start,Time.get_ticks_usec())\n\tdiag_frame()\n',
        ),
        (
            "\tperf_finished = true\n\tget_tree().quit(0)",
            "\tperf_finished = true\n\tdiag_flush()\n\tget_tree().quit(0)",
        ),
        (
            "func perf_emit(value: Dictionary) -> void:\n\tprint(PREFIX, JSON.stringify(value))",
            'func perf_emit(value: Dictionary) -> void:\n\tprint(PREFIX, JSON.stringify(value))\n\tif value.kind in ["ready","begin","end"]:\n\t\tprint("DIAG_SETTINGS ",JSON.stringify({"marker":value.kind,"settings":diag_settings()}))',
        ),
    ]
    if cap == 0:
        changes.append(('"fixed_window_headless_gate"', '"causal_uncapped_diagnostic"'))
    for old, new in changes:
        if text.count(old) != 1:
            raise ValueError("canonical sampler changed: " + old[:45])
        text = text.replace(old, new)
    text += EXTRA.replace("@CAP@", str(cap)).replace("@PLAN@", plan_sha)
    renderer = (project / "scripts/game_renderer.gd").read_text()
    methods = re.findall(r"^func (draw_\w+|_draw)\(\) -> void:", renderer, re.M)
    core = (project / "scripts/game_core.gd").read_text()
    updates = re.findall(r"^func (update_\w+)\(delta: float\) -> void:", core, re.M)
    for name in methods:
        text += wrap(name)
    for name in ["_physics_process", *updates]:
        text += wrap(name, "delta")
    background = """extends "res://scripts/world_background.gd"
func _draw() -> void:
\tvar diag_start := Time.get_ticks_usec()
\tsuper._draw()
\tget_parent().diag_record("background._draw",diag_start,Time.get_ticks_usec())
"""
    return (
        text.encode(),
        background.encode(),
        {"draw_methods": methods, "update_methods": updates},
    )
