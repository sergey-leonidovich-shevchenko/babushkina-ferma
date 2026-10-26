"""Разделяет точные ссылки, Python imports, UID и потенциальные динамические пути."""
from __future__ import annotations

import ast
from pathlib import PurePosixPath
import re
import posixpath
from urllib.parse import unquote, urlparse


CODE_SUFFIXES = {".py", ".gd", ".gdshader", ".sh", ".mjs", ".js", ".ts", ".vue", ".swift"}
TEXT_SUFFIXES = CODE_SUFFIXES | {
    "", ".json", ".jsonl", ".md", ".yaml", ".yml", ".toml", ".cfg",
    ".godot", ".tscn", ".tres", ".uid", ".import", ".plist", ".txt", ".log", ".csv", ".html",
}
PATH_TOKEN = re.compile(
    r"(?:(?:res://)?(?:tools|scripts|tests|wiki/scripts|docs/reports)/)[A-Za-z0-9_./{}*?\-]+"
)
UID_TOKEN = re.compile(r"uid://[A-Za-z0-9_]+")


def scope(path: str) -> str:
    """Код внутри frozen reports не превращается в редактируемую текущую документацию."""
    suffix = PurePosixPath(path).suffix
    executable = suffix in CODE_SUFFIXES or path.startswith(".githooks/")
    if path.startswith("docs/reports/"):
        return "frozen_code" if executable else "historical_evidence"
    if path.startswith((".github/", ".githooks/")) or path in {
        "run_tests.sh", "tools/check_architecture.sh", "tools/smoke_test.sh", "tools/performance_gate.sh",
    }:
        return "automation"
    return "live_code" if executable else "live_documentation_or_data"


def python_imports(path: str, text: str, paths: set[str]) -> tuple[list[dict], list[dict]]:
    """Разрешает только существующие модули: соседний каталог, явный пакет, затем tools."""
    edges, problems = [], []
    try:
        tree = ast.parse(text, filename=path)
    except SyntaxError as error:
        return [], [{"consumer": path, "line": error.lineno, "kind": "python_parse", "text": str(error)}]
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules = [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            modules = [node.module or ""]
        else:
            continue
        for module in modules:
            relative = module.replace(".", "/")
            parent = PurePosixPath(path).parent
            if isinstance(node, ast.ImportFrom) and node.level:
                for _ in range(node.level - 1):
                    parent = parent.parent
            candidates = [str(parent / (relative + ".py")), relative + ".py"]
            target = next((name for name in candidates if name in paths), None)
            binding = "resolved_local_module"
            if not target and "tools/" + relative + ".py" in paths:
                target = "tools/" + relative + ".py"
                binding = "candidate_requires_search_path"
                problems.append({"consumer": path, "line": node.lineno,
                                 "kind": "module_search_path_requires_review", "text": module})
            if target:
                edges.append({
                    "consumer": path, "line": node.lineno, "kind": "python_import",
                    "target": target, "binding": binding, "scope": scope(path),
                    "text": ast.get_source_segment(text, node) or module,
                })
    return edges, problems


def pattern_matches(pattern: str, paths: set[str]) -> list[str]:
    """Одиночная звёздочка не пересекает каталог; f-string остаётся потенциальной связью."""
    pattern = re.sub(r"\{[^}]*\}", "*", pattern)
    expression = re.escape(pattern).replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", "[^/]")
    compiled = re.compile("^" + expression + "$")
    return sorted(name for name in paths if compiled.fullmatch(name))


class References:
    """Собирает воспроизводимый статический ledger без исполнения исследуемых программ."""

    def __init__(self, paths: set[str]):
        self.paths = paths
        self.rows = []
        self.hazards = []
        self.uids = {}

    def add(self, path: str, text: str) -> None:
        """Сохраняет место ссылки; отсутствие target не выдаётся за доказательство неиспользования."""
        suffix = PurePosixPath(path).suffix
        if suffix == ".uid":
            uid = text.strip()
            if UID_TOKEN.fullmatch(uid):
                targets = self.uids.setdefault(uid, [])
                if path[:-4] not in targets:
                    targets.append(path[:-4])
            return
        if suffix == ".py":
            edges, problems = python_imports(path, text, self.paths)
            self.rows.extend(edges)
            self.hazards.extend(problems)
        if suffix == ".md":
            self._markdown_links(path, text)
        for number, line in enumerate(text.splitlines(), 1):
            for match in PATH_TOKEN.finditer(line):
                token = match.group().removeprefix("res://").rstrip(".")
                if token == path:
                    continue
                snippet = line[max(0, match.start() - 70):match.end() + 70].strip()
                row = {"consumer": path, "line": number, "text": snippet[:320], "scope": scope(path)}
                if token in self.paths:
                    kind = "path"
                    if suffix == ".gd" and re.search(r"\b(?:preload|load)\s*\(|^extends\s", line.strip()):
                        kind = "godot_resource"
                    self.rows.append({**row, "kind": kind, "target": token, "binding": "literal"})
                elif any(character in token for character in "{*?"):
                    candidates = pattern_matches(token, self.paths)
                    self.rows.append({**row, "kind": "dynamic_path", "target": None, "pattern": token,
                                      "candidates": candidates, "binding": "potential_only"})
                elif token.startswith(("tools/Godot.app", "tools/Godot.exe")):
                    self.rows.append({**row, "kind": "installed_runtime", "target": token,
                                      "binding": "outside_tracked_sources"})
                elif token.startswith("tools/") and ("startswith" in line or token.endswith("/")):
                    candidates = sorted(name for name in self.paths if name.startswith(token))
                    self.rows.append({**row, "kind": "prefix_filter", "target": None, "pattern": token,
                                      "candidates": candidates, "binding": "potential_only"})
                elif token.startswith("tools/"):
                    self.rows.append({**row, "kind": "unresolved_path", "target": token,
                                      "binding": "missing_generated_fixture_or_historical"})
            for match in UID_TOKEN.finditer(line):
                targets = self.uids.get(match.group(), [])
                for target in targets:
                    if target != path:
                        self.rows.append({"consumer": path, "line": number, "kind": "uid",
                                          "uid": match.group(), "text": line[:240], "scope": scope(path),
                                          "target": target, "binding": "uid_sidecar",
                                          "uid_collision": len(targets) > 1})
            self._hazards(path, number, line)

    def _markdown_links(self, path: str, text: str) -> None:
        """Физические Markdown-ссылки отделяет от команд в backticks и будущих имён в плане."""
        for match in re.finditer(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            raw = match.group(1).strip()
            if raw.startswith("<") and ">" in raw:
                raw = raw[1:raw.index(">")]
            else:
                raw = raw.split(maxsplit=1)[0]
            parsed = urlparse(raw)
            if parsed.scheme or parsed.netloc or raw.startswith("#"):
                continue
            target = posixpath.normpath(str(PurePosixPath(path).parent / unquote(parsed.path)))
            if target.startswith("tools/"):
                self.rows.append({"consumer": path, "line": text.count("\n", 0, match.start()) + 1,
                                  "kind": "markdown_link", "target": target, "scope": scope(path),
                                  "binding": "filesystem_markdown", "text": match.group()})

    def _hazards(self, path: str, number: int, line: str) -> None:
        """Это адреса для человеческой проверки, а не автоматический диагноз любого совпадения."""
        if scope(path) not in {"live_code", "automation", "frozen_code"}:
            return
        kinds = []
        if re.search(r"parents\[\d+\]|\.parent\.parent", line):
            kinds.append("fixed_parent_depth")
        if "sys.path" in line or "PYTHONPATH" in line:
            kinds.append("import_search_path")
        if ("glob(" in line and "rglob(" not in line) or re.search(r"(?:tools|presentation|suites)/\*", line):
            kinds.append("nonrecursive_pattern_candidate")
        if re.search(r"from .+ import .*\b(?:SOURCES|OVERLAY|SOURCE_FILES)\b", line):
            kinds.append("shared_live_historical_descriptor")
        if "startswith" in line and "tools/" in line:
            kinds.append("historical_overlay_prefix_review")
        if "git" in line and ("init" in line or "add" in line) and "subprocess" in line:
            kinds.append("nested_git_environment_review")
        if "__file__" in line or "with_name(" in line:
            kinds.append("file_relative_binding")
        for kind in kinds:
            self.hazards.append({"consumer": path, "line": number, "kind": kind, "text": line.strip()[:300]})

    def finish(self) -> None:
        """Упорядочивает ledger; UID-sidecars основных исходников загружены до анализа текста."""
        self.rows.sort(key=lambda row: (row["consumer"], row["line"], row["kind"], row.get("target") or row.get("pattern", "")))
        self.hazards.sort(key=lambda row: (row["consumer"], row["line"], row["kind"]))


def source_description(path: str, text: str) -> dict:
    """Отделяет извлечённое авторское описание от предлагаемого назначения семейства."""
    suffix = PurePosixPath(path).suffix
    result = {"author_description": "", "entry_kind": "support_or_data", "cli_options": []}
    result["observed_option_literals"] = [
        {"line": number, "tokens": sorted(set(re.findall(r'[\"\'](--[A-Za-z][A-Za-z0-9_=-]*)[\"\']', line)))}
        for number, line in enumerate(text.splitlines(), 1)
        if re.search(r'[\"\']--[A-Za-z]', line)
    ]
    result["environment_tokens"] = sorted(set(re.findall(r'\bFARM_[A-Z0-9_]+\b', text)))
    result["argument_inventory_limit"] = "static declarations/literals; not a claim that arbitrary --help invocation is safe"
    if suffix == ".py":
        try:
            tree = ast.parse(text, filename=path)
        except SyntaxError:
            result["entry_kind"] = "parse_requires_review"
            return result
        result["author_description"] = (ast.get_docstring(tree) or "").split("\n")[0]
        guards = [node for node in ast.walk(tree) if isinstance(node, ast.If) and "__name__" in ast.unparse(node.test)]
        result["entry_kind"] = "python_main" if guards else "python_module_or_unguarded_script"
        result["main_guard_lines"] = [node.lineno for node in guards]
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "add_argument":
                result["cli_options"].append({"line": node.lineno, "flags": [value.value for value in node.args
                                              if isinstance(value, ast.Constant) and isinstance(value.value, str)]})
    elif suffix in {".gd", ".gdshader"}:
        match = re.search(r"^extends\s+(.+)", text, re.MULTILINE)
        extends = match.group(1).strip() if match else ""
        result["entry_kind"] = "godot_cli" if extends == "SceneTree" else "godot_support_or_overlay"
        result["extends"] = extends
    elif suffix in {".sh", ".swift", ".mjs"}:
        result["entry_kind"] = "command_or_manual_tool"
    return result
