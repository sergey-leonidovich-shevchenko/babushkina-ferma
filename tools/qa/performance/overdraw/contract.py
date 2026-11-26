"""Закрепляет полную парную серию VPERF-004 и отдельные неподвижные ракурсы."""

from tools.qa.performance.pass_cost import contract as base

TASK = "VPERF-004"
CAPTURE = "tools/qa/performance/overdraw/capture.gd"
DIAGNOSTIC = "tools/qa/performance/overdraw/diagnostic.gd"
VARIANTS = ("baseline", "trimmed")
CONTACT = "grass-contact"
CONTACT_DEFAULT = "grass-contact-120"
CONTACTS = (CONTACT, CONTACT_DEFAULT)
CONTACT_INDEX = 6
CONTACT_WORLD_RECT = (1896, 588, 1992, 684)
VIEWS = {
    "west-bridge": ((864, 456), 1, 780.0, "normal", 1.2, 12.5),
    "east-bridge": ((1608, 912), 1, 1200.0, "low", 1.2, 29.25),
    "dense-grass": ((1944, 768), 1, 845.0, "normal", 1.2, 46.75),
    "still-bridge": ((864, 456), 31, 780.0, "static", 1.0, 0.0),
    CONTACT: ((1955, 655), 1, 845.0, "normal", 1.0, 51.25),
    CONTACT_DEFAULT: ((1955, 655), 1, 845.0, "normal", 1.2, 51.25),
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
    fixed.update(
        f"views/{case}-{variant}-{layer}.png"
        for case in CONTACTS
        for variant in VARIANTS
        for layer in ("composite", "wind-color")
    )
    fixed.update(f"views/{CONTACT_DEFAULT}-{variant}-plant.png" for variant in VARIANTS)
    fixed.add(f"views/{CONTACT_DEFAULT}-baseline-composite-only.png")
    fixed.add(f"views/{CONTACT_DEFAULT}-trimmed-mesh-only.png")
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
