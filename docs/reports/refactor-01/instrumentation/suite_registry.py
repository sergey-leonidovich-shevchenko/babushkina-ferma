"""Фиксирует подключения GDScript suites, включая вложенные run, отдельно от счётчика файлов."""
from __future__ import annotations

from collections import Counter, defaultdict
import re


CONST = re.compile(r'const\s+(\w+)\s*(?::\s*[A-Za-z_0-9]*\s*)?=\s*preload\("res://(tests/suites/[^"\n]+)"\)')
INLINE = re.compile(r'preload\("res://(tests/suites/[^"\n]+)"\)[^;\n]*?\.run\(')


def registry(texts: dict[str, str]) -> dict:
    """Распознаёт прямые run и текущий массив runner; неизвестные случаи не объявляет выполненными."""
    if "tests/test_game.gd" not in texts:
        raise ValueError("runner source missing")
    edges, preload_links = [], []
    for path, text in sorted(texts.items()):
        if path != "tests/test_game.gd" and not path.startswith("tests/suites/"):
            continue
        if not path.endswith(".gd"):
            continue
        constants = {match.group(1): match.group(2) for match in CONST.finditer(text)}
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for match in re.finditer(r'preload\("res://(tests/suites/[^"\n]+)"\)', line):
                preload_links.append({"consumer": path, "line": number, "target": match.group(1)})
            for match in INLINE.finditer(line):
                edges.append({"consumer": path, "line": number, "target": match.group(1), "kind": "inline_run"})
            for name, target in constants.items():
                if re.search(r'\b' + re.escape(name) + r'(?:\.new\([^\n)]*\))?\.run\(', line):
                    edges.append({"consumer": path, "line": number, "target": target, "kind": "constant_run"})
        if path == "tests/test_game.gd":
            array = re.search(r'var\s+suites[^=\n]*=\s*\[(.*?)\]', text, re.DOTALL)
            loop = re.search(r'for suite in suites:\s*suite\.new\(self\)\.run\(\)', text)
            if not array or not loop:
                raise ValueError("runner suite-array invocation requires explicit review")
            for name in re.findall(r'\b[A-Za-z_]\w*\b', array.group(1)):
                if name not in constants:
                    raise ValueError("runner suite alias not resolved: " + name)
                edges.append({"consumer": path, "line": text.count("\n", 0, loop.start()) + 1,
                              "target": constants[name], "kind": "runner_array", "alias": name})
    graph = defaultdict(list)
    for edge in edges:
        graph[edge["consumer"]].append(edge["target"])
    counts, cycles = Counter(), []
    def visit(path: str, stack: list[str]) -> None:
        """Считает статические пути вызовов; условные branches остаются ограничением ведомости."""
        if path in stack:
            cycles.append([*stack, path])
            return
        for target in graph[path]:
            counts[target] += 1
            visit(target, [*stack, path])
    visit("tests/test_game.gd", [])
    suites = sorted(path for path in texts if path.startswith("tests/suites/") and path.endswith("_suite.gd"))
    return {"runner": "tests/test_game.gd", "suite_files": len(suites),
            "base_or_other_gd": sorted(path for path in texts if path.startswith("tests/suites/")
                                       and path.endswith(".gd") and not path.endswith("_suite.gd")),
            "top_level_run_edges": len(graph["tests/test_game.gd"]),
            "run_edges": edges, "preload_links": preload_links,
            "static_run_path_counts": dict(sorted(counts.items())), "cycles": cycles,
            "unreached_suite_files": sorted(set(suites) - set(counts)),
            "multiple_static_run_paths": {path: count for path, count in sorted(counts.items()) if count > 1},
            "limit": "static activation graph, not an execution trace; actual full Game result recorded separately"}
