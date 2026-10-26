#!/usr/bin/env python3
"""Распределяет весь измеренный реестр по точным художественным партиям без пропусков."""
import json
from pathlib import Path

from tools.common.paths import project_root

ROOT = project_root(__file__)
FOLDER = ROOT / "docs/concepts/visual-polish-2026-10-13/v1"


def batch_for(item, herbs):
    """Разделяет ботанические стадии и ремесленные цепочки, сохраняя хорошие рисунки на проверку."""
    kind = item["id"]
    if kind in herbs:
        return "herbs-fresh", "Свежие травы", "Различимые виды растений, а не два общих пучка."
    for suffix, title in [("dried", "Сушёные травы"), ("powder", "Травяные порошки"), ("juice", "Растительные соки"), ("tincture", "Настойки")]:
        if kind.endswith("_" + suffix) and kind.removesuffix("_" + suffix) in herbs:
            return "herbs-" + suffix, title, "Форма сырья и связь с исходным растением должны читаться без одного только цвета."
    provider = item["provider"]
    if provider == "alchemy":
        return "alchemy-finished", "Алхимия и пасека", "Самостоятельные флаконы, основы, эссенции, масла и продукты; сохранить хорошие рисунки пасеки."
    if provider == "workshop":
        if kind in ["wood_beam", "wood_dowel", "timber_frame", "wood_handle", "sawdust"]:
            return "wood-components", "Древесина и детали", "Брус, рукоять, шканты, рама и опилки с разными силуэтами и фактурой дерева."
        if "glass" in kind or item["family"] in ["workshop-bottle", "workshop-jar", "workshop-pane", "workshop-lens"]:
            return "glass-components", "Стеклодувные изделия", "Толщина и край стекла, пустая/полная тара, различимая форма изделия."
        return "pottery-components", "Гончарная цепочка", "Сырая масса, заготовка, обжиг и глазурь имеют собственные признаки."
    if provider == "furnace":
        return "smelting", "Руда, металл и топливо", "Руда, шлак, слиток, уголь и мусор различаются материалом, не одной окраской."
    if provider == "research":
        return "research", "Изучение и разборка", "Бумага, чернила, осколки, пыль и детали; узнаваемость на маленькой иконке."
    titles = {"tool": "Инструменты", "equipment": "Экипировка", "food": "Еда и урожай", "quest": "Сюжетные вещи", "resource": "Остальные материалы"}
    return "catalog-" + item["category"], titles[item["category"]], "Ручная проверка, сохранить удачные рисунки; исправить масштаб, ореолы или слабую различимость."


def build(audit):
    """Проверяет покрытие каждого вида ровно одной партией и формирует отслеживаемый объём работ."""
    herbs = {item["id"] for item in audit["entries"] if item["family"] in ["herb-leaves", "herb-flower"]}
    batches, mapping = {}, {}
    for item in audit["entries"]:
        if item["id"] in mapping:
            raise ValueError("Повтор предмета: " + item["id"])
        key, title, intent = batch_for(item, herbs)
        batches.setdefault(key, {"id": key, "title": title, "intent": intent, "items": [], "status": "awaiting-style-choice"})["items"].append(item["id"])
        mapping[item["id"]] = key
    if len(mapping) != audit["stats"]["items"]:
        raise ValueError("Неполное покрытие реестра")
    return {"schema": 1, "sourceVersion": audit["version"], "itemBatches": mapping, "batches": list(batches.values()), "world": {"furniture": {"subjects": ["rustic_table", "wooden_chair", "bench", "home_chest", "wooden_wardrobe"], "directions": ["south", "west", "north", "east"], "frames": 20}, "roads": {"regions": 6, "directedTransitions": 16, "modules": ["horizontal", "vertical", "corner", "end", "t", "cross"]}, "workshops": {"stations": 18, "levels": 3, "directions": 4, "constructionDirections": 4}}, "checks": ["прозрачность и края", "32/44/64/96 px", "реестр без пропусков", "иконка и цвет в игре/Wiki", "направления и опоры", "коллизии и подходы", "шесть языков и 120%", "пауза и состояния очередей", "сохранения", "бюджет производительности"]}


if __name__ == "__main__":
    data = build(json.loads((FOLDER / "current/audit.json").read_text(encoding="utf-8")))
    (FOLDER / "backlog.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("ART BACKLOG:", len(data["itemBatches"]), "items in", len(data["batches"]), "complete batches")
