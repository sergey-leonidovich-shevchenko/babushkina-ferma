#!/usr/bin/env python3
"""Проверяет отдельный визуальный план и собирает его читаемые карточки без изменения статусов."""
from __future__ import annotations

import argparse
import collections
import hashlib
import html
import json
import re
import zipfile
from pathlib import Path

from tools.common.paths import project_root

ROOT = project_root(__file__)
FOLDER = ROOT / "docs/epics/visual-overhaul-2026-10"


def load(folder: Path = FOLDER) -> dict:
    """Читает единственный источник статусов и описаний нового плана."""
    return json.loads((folder / "backlog.json").read_text(encoding="utf-8"))


def validate(data: dict, root: Path = ROOT) -> list[str]:
    """Проверяет граф, покрытие каталога, честность статусов и существующие исходники."""
    errors = []
    tasks = data.get("tasks", [])
    by = {t["id"]: t for t in tasks}
    epics = {e["id"] for e in data.get("epics", [])}
    original = json.loads((root / "docs/backlog/2026-10/backlog.json").read_text())
    external = {t["id"] for t in original["tasks"]} | {f"WATER-{i:02}" for i in range(1, 16)}
    if len(by) != len(tasks): errors.append("duplicate ID")
    if data.get("task_count") != len(tasks): errors.append("task_count mismatch")
    if not data.get("planning_only"): errors.append("planning_only required")
    active = [t for t in tasks + original["tasks"] if t["status"] == "in_progress"]
    water = (root / "docs/epics/water-2026-10/README.md").read_text()
    active_water = sum("Статус: `in_progress`" in section for section in water.split("\n### WATER-")[1:])
    if len(active) + active_water > 1: errors.append("multiple active tasks")
    for t in tasks:
        tid = t["id"]
        if not re.fullmatch(r"V[A-Z]+-\d{3}", tid): errors.append(f"bad ID: {tid}")
        if t["epic"] not in epics: errors.append(f"unknown epic: {tid}")
        for field in ["title", "goal", "acceptance", "verification", "existing_paths", "risk", "rollback", "estimate", "branch"]:
            if not t.get(field): errors.append(f"missing {field}: {tid}")
        if not t.get("branch", "").startswith("codex/" + tid.lower() + "-"): errors.append(f"bad branch: {tid}")
        if t.get("parent_owner") and t["parent_owner"] not in external: errors.append(f"unknown parent: {tid}")
        if t["status"] not in ["backlog", "ready", "blocked", "in_progress", "done"]: errors.append(f"bad status: {tid}")
        if t["status"] == "done" and not t.get("evidence"): errors.append(f"unproven done: {tid}")
        for path in t.get("existing_paths", []):
            candidate = (root / path).resolve()
            if not candidate.is_relative_to(root.resolve()) or not candidate.exists(): errors.append(f"missing source: {tid}: {path}")
        for dep in t.get("depends_on", []):
            if dep not in by: errors.append(f"unknown dependency: {tid}: {dep}")
            elif t["status"] in ["ready", "in_progress", "done"] and by[dep]["status"] != "done": errors.append(f"unfinished dependency: {tid}: {dep}")
    visiting, visited = set(), set()

    def visit(tid: str) -> None:
        """Находит цикл, в том числе внутри ещё заблокированных производственных карточек."""
        if tid in visiting: errors.append(f"cycle: {tid}"); return
        if tid in visited or tid not in by: return
        visiting.add(tid)
        for dep in by[tid].get("depends_on", []): visit(dep)
        visiting.remove(tid); visited.add(tid)

    for tid in by: visit(tid)
    folder = root / "docs/epics/visual-overhaul-2026-10"
    inventory = json.loads((folder / "inventory.json").read_text())
    for category in ["items", "characters", "plants", "buildings", "locations"]:
        expected = {category + "/" + e["id"] for e in inventory["entries"] if e["category"] == category}
        actual = set()
        for t in tasks:
            e = t.get("entity", {})
            if e.get("category") == category: actual.add(category + "/" + e["id"])
            actual.update(x for x in t.get("covers_entities", []) if x.startswith(category + "/"))
        if actual != expected: errors.append(f"coverage: {category}: missing={sorted(expected-actual)} extra={sorted(actual-expected)}")
    imported = json.loads((folder / "imported-plan.json").read_text())
    mapping = data.get("imported_task_map", {})
    if set(mapping) != {t["id"] for t in imported["tasks"]}: errors.append("imported mapping incomplete")
    for origin, targets in mapping.items():
        if not targets or any(t not in by for t in targets): errors.append(f"invalid imported mapping: {origin}")
    return errors


def validate_archive(folder: Path = FOLDER) -> list[str]:
    """Проверяет каждый исходный файл архива без извлечения и исполнения его кода."""
    errors = []
    archive = folder / "source-packet.zip"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != "615880cd55580a6d13f9a743a5f35b7521bbfc6ddcc83961fc2050e2538e23f5": errors.append("archive hash mismatch")
    manifest = json.loads((folder / "source-manifest.json").read_text())
    with zipfile.ZipFile(archive) as z:
        for entry in manifest["files"]:
            name = "babushkina_ferma_all_files/" + entry["path"]
            if name not in z.namelist(): errors.append("archive missing " + name); continue
            raw = z.read(name)
            if len(raw) != entry["bytes"] or hashlib.sha256(raw).hexdigest() != entry["sha256"]: errors.append("archive content mismatch " + name)
    return errors


def markdown(data: dict) -> dict[str, str]:
    """Создаёт отдельные документы эпиков с полными карточками и списком зависимостей."""
    files = {}
    index = ["# Карточки визуального плана", "", "Источник: [backlog.json](backlog.json). Статусы редактировать в JSON; генерация не закрывает задачи.", "", "| Эпик | Задач | Назначение |", "|---|---:|---|"]
    for epic in data["epics"]:
        tasks = [t for t in data["tasks"] if t["epic"] == epic["id"]]
        name = "epics/" + epic["id"].lower() + ".md"
        index.append(f'| [{epic["id"]}]({name}) | {len(tasks)} | {epic["title"]} |')
        lines = ["# " + epic["id"] + " · " + epic["title"], "", "[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)", ""]
        for t in tasks:
            lines += ['<a id="' + t['id'].lower() + '"></a>', '']
            lines += [f'## {t["id"]} — {t["title"]}', "", f'Статус: `{t["status"]}` · {t["priority"]} · этап `{t["phase"]}` · `{t["kind"]}`', "", t["goal"], "", "Ветка: `" + t["branch"] + "`.", "", "Зависимости: " + (", ".join(t["depends_on"]) or "нет") + "."]
            if t.get("parent_owner"): lines += ["", "Единый владелец пересечения: **" + t["parent_owner"] + "**. Эта карточка уточняет работу владельца, не закрывает его автоматически."]
            if t.get("blocked_reason"): lines += ["", t["blocked_reason"]]
            if t.get("approval"): lines += ["", t["approval"]]
            lines += ["", "Исходники:", ""] + [f'- [{p}](../../../../{p})' for p in t["existing_paths"]]
            output_label = "Результаты: " if t.get("evidence") else "Результат / новые пути (пока не существуют): "
            lines += ["", output_label + ", ".join("`" + p + "`" for p in t["proposed_outputs"]) + "."]
            context = t.get("context", {})
            if context.get("clips"): lines += ["", "Исходные клипы: `" + json.dumps(context["clips"], ensure_ascii=False) + "`."]
            if context.get("facts"): lines += ["", "Данные каталога: " + "; ".join(str(x["label"]) + ": " + str(x["value"]) for x in context["facts"]) + "."]
            lines += ["", "Критерии:", ""] + ["- " + x for x in t["acceptance"]]
            lines += ["", "Проверка:", ""] + ["- " + x for x in t["verification"]]
            lines += ["", "Риск: " + t["risk"], "", "Откат: " + t["rollback"], "", f'Оценка: {t["estimate"]["range_days"]} рабочих дней, уверенность {t["estimate"]["confidence"]}. ' + t["estimate"]["basis"], "", "Доказательства: " + (", ".join(t["evidence"]) or "пока отсутствуют; задача не выполнена") + ".", ""]
        files[name] = "\n".join(lines)
    files["TASKS.md"] = "\n".join(index) + "\n"
    return files


def browser_index(data: dict) -> str:
    """Собирает автономный поисковый указатель; полные карточки остаются в Markdown."""
    entries = [{k:t[k] for k in ["id", "epic", "title", "status", "phase", "priority", "goal", "depends_on", "parent_owner"]} for t in data["tasks"]]
    payload = json.dumps(entries, ensure_ascii=False).replace("<", "\\u003c")
    options = ''.join('<option value="'+html.escape(e['id'])+'">'+html.escape(e['id']+' · '+e['title'])+'</option>' for e in data['epics'])
    return '''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Лунная долина · визуальный план</title>
<style>body{margin:0;background:#f5f2e9;color:#292b2e;font:16px/1.5 system-ui}header,main{max-width:1200px;margin:auto;padding:24px}h1{font-size:30px;margin:0}a{color:#375968}label{display:block}input,select,button{font:inherit;padding:10px;border:1px solid #8b8e8c;border-radius:6px;background:white;color:#292b2e;max-width:100%;box-sizing:border-box}input{width:100%}.filters{display:grid;grid-template-columns:2fr 2fr 1fr;gap:16px;margin:24px 0}article{padding:18px 0;border-bottom:1px solid #cfcec7}h2{font-size:19px;margin:0}small{color:#555b61}p{margin:8px 0}.meta{font-size:13px;color:#555b61}button{margin:20px 0}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #357eae} @media(max-width:650px){.filters{grid-template-columns:1fr}header,main{padding:16px}}</style>
<header><p>Лунная долина · VIS-00 · 15 октября 2026</p><h1>Новый облик игры</h1><p>25 эпиков · 1037 задач: 200 системных и 837 карточек производства и переноса. Текущие статусы — в карточках.</p><p><a href="AUDIT.md">Аудит</a> · <a href="MVP.md">С чего начать</a> · <a href="TASKS.md">Полные карточки</a> · <a href="README.md">Правила работы</a></p>
<div class="filters"><label>Поиск по ID, названию и описанию<input id="query" type="search" placeholder="Например: скелет, вода, VART-001"></label><label>Эпик<select id="epic"><option value="">Все эпики</option>'''+options+'''</select></label><label>Этап<select id="phase"><option value="">Все этапы</option><option value="foundation">Основание</option><option value="pilot">Эталонный участок</option><option value="content">Контент</option><option value="rollout">Перенос и приёмка</option></select></label></div><p id="count" aria-live="polite"></p></header><main><div id="results"></div><button id="more" type="button">Показать ещё 40</button></main>
<script type="application/json" id="data">'''+payload+'''</script><script>
const data=JSON.parse(document.getElementById('data').textContent),query=document.getElementById('query'),epic=document.getElementById('epic'),phase=document.getElementById('phase'),results=document.getElementById('results'),count=document.getElementById('count'),more=document.getElementById('more');let limit=40;
const stateNames={backlog:'В очереди',blocked:'Ждёт зависимостей',ready:'Можно готовить',in_progress:'В работе',done:'Принято'};
function render(){const words=query.value.toLocaleLowerCase('ru').split(/\s+/).filter(Boolean);const found=data.filter(t=>(!epic.value||t.epic===epic.value)&&(!phase.value||t.phase===phase.value)&&words.every(w=>(t.id+' '+t.title+' '+t.goal).toLocaleLowerCase('ru').includes(w)));results.replaceChildren();for(const t of found.slice(0,limit)){const row=document.createElement('article'),heading=document.createElement('h2'),link=document.createElement('a'),meta=document.createElement('p'),goal=document.createElement('p'),deps=document.createElement('p');link.href='epics/'+t.epic.toLowerCase()+'.md#'+t.id.toLowerCase();link.textContent=t.id+' · '+t.title;heading.append(link);meta.className='meta';meta.textContent=t.priority+' · '+stateNames[t.status]+' · '+t.phase+(t.parent_owner?' · Владелец: '+t.parent_owner:'');goal.textContent=t.goal;deps.className='meta';deps.textContent='Зависимости: '+(t.depends_on.join(', ')||'нет');row.append(heading,meta,goal,deps);results.append(row)}count.textContent='Найдено '+found.length+' · показано '+Math.min(found.length,limit);more.hidden=found.length<=limit;}
for(const control of [query,epic,phase])control.addEventListener('input',()=>{limit=40;render()});more.addEventListener('click',()=>{limit+=40;render()});render();
</script></html>'''


def main() -> int:
    """Проверяет вход и воспроизводимость документов либо явно пересобирает производные файлы."""
    parser = argparse.ArgumentParser(); parser.add_argument("--write", action="store_true"); args = parser.parse_args()
    data = load(); errors = validate(data) + validate_archive()
    if errors: print("\n".join(errors)); return 1
    files = markdown(data); files["index.html"] = browser_index(data)
    for name, text in files.items():
        path = FOLDER / name
        if args.write: path.parent.mkdir(exist_ok=True, parents=True); path.write_text(text, encoding="utf-8")
        elif not path.exists() or path.read_text(encoding="utf-8") != text: errors.append("stale generated file: " + name)
    if errors: print("\n".join(errors)); return 1
    print(f'VISUAL BACKLOG: {len(data["epics"])} epics, {len(data["tasks"])} tasks, graph/coverage/archive/documents valid')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
