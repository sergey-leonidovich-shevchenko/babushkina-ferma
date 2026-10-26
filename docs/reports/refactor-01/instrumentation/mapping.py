"""Проверяет полную явную карту и связывает её с обнаруженными потребителями."""
from __future__ import annotations

from collections import Counter, defaultdict, deque
from pathlib import PurePosixPath
from fnmatch import fnmatchcase

from references import source_description


def role(name: str) -> str:
    """Описывает назначение по явной роли имени; авторский docstring хранится отдельно."""
    stem = PurePosixPath(name).stem
    if stem.startswith("test_"):
        return "профильные и отрицательные Python-контроли"
    for suffix, description in [
        ("_collect", "драйвер сбора серии"), ("_capture", "сценарий захвата артефактов"),
        ("_verify", "проверка сохранённых доказательств"), ("_review", "профильные Godot-проверки"),
        ("_gallery", "галерея вариантов"), ("_board", "контрольный визуальный стенд"),
        ("_game", "QA-надстройка над настоящей игрой"), ("_probe", "диагностический наблюдатель"),
    ]:
        if stem.endswith(suffix):
            return description
    if stem.startswith(("build_", "prepare_", "extract_", "generate_")):
        return "подготовка ресурсов или эталонов"
    if name.endswith(".json"):
        return "политика или паспорт данных"
    return "вход или вспомогательный модуль семейства"


def validate_plan(plan: dict, paths: set[str]) -> int:
    """Отказывает при пропуске, коллизии, выходе из tools или разрыве UID-пары."""
    tools = {name for name in paths if name.startswith("tools/")}
    assignments = plan["assignments"]
    if tools != set(assignments):
        raise ValueError("map coverage: missing/extra " + str(sorted(tools ^ set(assignments))))
    targets = {}
    declared_facades = {}
    code_extensions = set(plan["source_extensions"]) | set(plan.get("shader_extensions", []))
    anchors = set(plan.get("protected_anchors", [plan["protected_anchor"]]))
    retained = set()
    for name, decision in assignments.items():
        target = PurePosixPath(decision["target"])
        if target.is_absolute() or ".." in target.parts or target.parts[0] != "tools":
            raise ValueError("unsafe target: " + str(target))
        if str(target) in targets:
            raise ValueError("target collision: " + str(target))
        targets[str(target)] = name
        if decision["family"] not in plan["families"]:
            raise ValueError("unknown family: " + name)
        if name.endswith(".uid"):
            source = name[:-4]
            if source not in assignments or decision["target"] != assignments[source]["target"] + ".uid":
                raise ValueError("UID pair split: " + name)
        if decision.get("public_entry") and not decision.get("exception_reason"):
            raise ValueError("public exception without reason: " + name)
        if decision.get("public_entry"):
            if decision["public_entry"] != name or decision["action"] != "move_implementation_keep_public_facade":
                raise ValueError("public facade does not preserve its entry: " + name)
            declared_facades[name] = decision["exception_reason"]
        if target.parent == PurePosixPath("tools") and target.suffix in code_extensions:
            if name not in anchors or decision["action"] != "retain_protected_anchor" or not decision.get("exception_reason"):
                raise ValueError("undocumented root implementation: " + name)
            retained.add(name)
    if retained != anchors:
        raise ValueError("protected root anchor registry differs from map")
    if declared_facades != plan["public_facades"]:
        raise ValueError("public facade registry differs from map")
    for entry in plan["new_entries_proposed_not_implemented"]:
        if entry["path"] in paths or entry["path"] in targets or entry["path"] in declared_facades or not entry.get("reason"):
            raise ValueError("new entry collision or missing reason")
    extensions = code_extensions
    future_root = {str(target) for target in map(PurePosixPath, targets)
                   if target.parent == PurePosixPath("tools") and target.suffix in extensions}
    future_root.update(plan["public_facades"])
    future_root.update(row["path"] for row in plan["new_entries_proposed_not_implemented"])
    if len(future_root) > plan["root_source_budget"] or len(future_root) != plan["future_root_source_count"]:
        raise ValueError("future root source budget/count mismatch")
    return len(future_root)


def dependency_chains(rows: list[dict]) -> dict[str, list[str]]:
    """Показывает достижимость файлов-зависимостей gate, не объявляя каждый literal исполнением."""
    graph = defaultdict(set)
    for row in rows:
        if row["scope"] in {"automation", "live_code", "frozen_code"} and row["binding"] in {
            "literal", "resolved_local_module", "uid_sidecar",
        }:
            graph[row["consumer"]].add(row["target"])
    roots = sorted(name for name in graph if name.startswith((".github/workflows/", ".githooks/"))
                   or name in {"run_tests.sh", "tools/check_architecture.sh"})
    result = {name: [name] for name in roots}
    pending = deque(roots)
    while pending:
        consumer = pending.popleft()
        for target in sorted(graph[consumer]):
            if target not in result:
                result[target] = [*result[consumer], target]
                pending.append(target)
    return result


def tool_inventory(plan: dict, blobs: dict, hashes: dict, texts: dict, rows: list[dict]) -> list[dict]:
    """У каждой строки есть назначение, путь, UID, место в ledger и честная граница покрытия."""
    incoming, potential = defaultdict(list), defaultdict(list)
    for number, reference in enumerate(rows):
        if reference.get("target"):
            if reference["binding"] == "candidate_requires_search_path":
                potential[reference["target"]].append(number)
            else:
                incoming[reference["target"]].append(number)
        for target in reference.get("candidates", []):
            potential[target].append(number)
    chains = dependency_chains(rows)
    result = []
    for name, decision in plan["assignments"].items():
        blob = blobs[name]
        family = plan["families"][decision["family"]]
        description = source_description(name, texts.get(name, ""))
        ids = incoming[name]
        counts = Counter(rows[number]["scope"] for number in ids)
        uid = None
        if name.endswith((".gd", ".gdshader")):
            uid_name = name + ".uid"
            uid = {"tracked": uid_name in blobs, "path": uid_name if uid_name in blobs else None,
                   "value": texts.get(uid_name, "").strip() or None}
        purpose = family["title"] + ": " + role(name)
        if description["author_description"]:
            purpose += ". " + description["author_description"]
        if name.endswith(".uid"):
            purpose = "Стабильный UID для " + name[:-4]
        result.append({
            "old_path": name, **decision, "stage": family["stage"], "purpose": purpose,
            "git_blob": blob.oid, "sha256": hashes[name], "bytes": blob.size,
            **description, "uid_pair": uid, "reference_ids": ids,
            "potential_reference_ids": potential[name], "reference_scope_counts": dict(sorted(counts.items())),
            "gate_dependency_path": chains.get(name),
            "audit_verification": "full-snapshot-reproduction",
            "execution_claim": "not executed by static audit; see actual gate logs and owner native verifier",
        })
    return result


def directory_counts(blobs: dict, directory: str, source_extensions: set[str]) -> dict:
    """Не смешивает непосредственные файлы, рекурсивное дерево, UID и shader."""
    names = [name for name in blobs if name.startswith(directory + "/")]
    direct = [name for name in names if str(PurePosixPath(name).parent) == directory]
    def count(items):
        suffixes = Counter(PurePosixPath(name).suffix for name in items)
        return {"tracked_files": len(items), "executable_sources": sum(suffixes[k] for k in source_extensions),
                "uid_files": suffixes[".uid"], "shader_sources": suffixes[".gdshader"],
                "bytes": sum(blobs[name].size for name in items), "extensions": dict(sorted(suffixes.items()))}
    return {"immediate": count(direct), "recursive": count(names)}


def cross_family_imports(inventory: list[dict], rows: list[dict]) -> list[dict]:
    """Сильные imports/preload отделяет от файловых путей в source-manifest и истории."""
    owners = {item["old_path"]: item["family"] for item in inventory}
    edges = defaultdict(list)
    for number, row in enumerate(rows):
        first, second = owners.get(row["consumer"]), owners.get(row.get("target"))
        if first and second and first != second and row["kind"] in {"python_import", "godot_resource"}:
            edges[(first, second)].append(number)
    return [{"consumer_family": first, "provider_family": second, "reference_ids": ids}
            for (first, second), ids in sorted(edges.items())]


def other_catalogs(plan: dict, blobs: dict, rows: list[dict], texts: dict) -> list[dict]:
    """Адресные предложения не превращают весь большой каталог в автоматически разрешённый перенос."""
    incoming = defaultdict(list)
    for number, row in enumerate(rows):
        if row.get("target"):
            incoming[row["target"]].append(number)
    result = []
    for decision in plan["other_catalogs"]:
        directory = decision["directory"]
        counts = directory_counts(blobs, directory, set(plan["source_extensions"]))
        selected = []
        for name in sorted(blobs):
            path = PurePosixPath(name)
            if str(path.parent) != directory or not any(fnmatchcase(path.name, pattern) for pattern in decision["selectors"]):
                continue
            target = str(PurePosixPath(decision["target_directory"]) / path.name) if decision.get("target_directory") else name
            uid = name + ".uid"
            selected.append({"old_path": name, "proposed_target": target, "git_blob": blobs[name].oid,
                             "paired_uid": uid if uid in blobs else None, "uid_target": target + ".uid" if uid in blobs else None,
                             "reference_ids": incoming[name]})
        bindings = []
        for name, text in texts.items():
            for number, line in enumerate(text.splitlines(), 1):
                if directory + "/" in line:
                    bindings.append({"consumer": name, "line": number, "text": line.strip()[:240]})
        result.append({**decision, "counts": counts, "selected_sources": selected,
                       "directory_binding_count": len(bindings), "directory_binding_examples": bindings[:12]})
    return result
