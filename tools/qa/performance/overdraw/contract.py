"""Закрепляет полную парную серию VPERF-004 и отдельные неподвижные ракурсы."""

from tools.qa.performance.pass_cost import contract as base

TASK = "VPERF-004"
CAPTURE = "tools/qa/performance/overdraw/capture.gd"
DIAGNOSTIC = "tools/qa/performance/overdraw/diagnostic.gd"
VARIANTS = ("baseline", "trimmed")
VIEWS = {
    "west-bridge": ((864, 456), 1, 780.0, "normal", 1.2, 12.5),
    "east-bridge": ((1608, 912), 1, 1200.0, "low", 1.2, 29.25),
    "dense-grass": ((1944, 768), 1, 845.0, "normal", 1.2, 46.75),
    "still-bridge": ((864, 456), 31, 780.0, "static", 1.0, 0.0),
}
CASES = tuple(VIEWS)


def schedule() -> tuple[tuple[str, str, int], ...]:
    return tuple(
        (name, variant, seconds)
        for index, (name, seconds) in enumerate(base.RUNS)
        for variant in (VARIANTS if index % 2 == 0 else tuple(reversed(VARIANTS)))
    )


def expected_files() -> set[str]:
    timed = {f"{run}/{variant}/{name}" for run, variant, _ in schedule() for name in base.RUN_FILES}
    fixed = {
        f"views/{case}-{variant}-{layer}.png"
        for case in CASES
        for variant in VARIANTS
        for layer in (("frame", "world") if case == "still-bridge" else ("frame", "world", "wind"))
    }
    return (
        timed
        | fixed
        | {
            "import.txt",
            "engine-version.txt",
            "views/views.json",
            "views/calibration.png",
            "views-launch.json",
            "views-engine.log",
            "views-stdout.txt",
        }
    )
