#!/usr/bin/env python3
"""Проверяет контроль полноты и целостности художественной ревизии на повреждённых копиях."""
import copy
import json
import unittest
from check_art_review import FOLDER, validate


class ArtReviewTests(unittest.TestCase):
    """Гарантирует, что ревизия не скрывает пропуск предмета или некорректный рисунок."""

    def setUp(self):
        """Читает самостоятельные копии замороженного снимка и состава партий."""
        self.audit = json.loads((FOLDER / "current/audit.json").read_text(encoding="utf-8"))
        self.backlog = json.loads((FOLDER / "backlog.json").read_text(encoding="utf-8"))

    # Сценарий: полный реестр выгружен вместе с исходными PNG.
    # Исходное состояние: текущий снимок и точные партии.
    # Ожидаемый результат: все файлы, хеши, цвета, границы и количества проверены.
    def test_complete_snapshot(self):
        self.assertEqual(validate(self.audit, self.backlog), (386, 300, 16))

    # Сценарий: одна партия потеряла предмет или повторила его.
    # Исходное состояние: независимые повреждённые копии плана.
    # Ожидаемый результат: оба дефекта блокируют признание полного покрытия.
    def test_missing_and_duplicate_item(self):
        for duplicate in [False, True]:
            broken = copy.deepcopy(self.backlog)
            items = broken["batches"][0]["items"]
            if duplicate:
                items.append(items[0])
            else:
                items.pop()
            with self.assertRaisesRegex(ValueError, "партиях"):
                validate(self.audit, broken)

    # Сценарий: испорчены цвет, ссылка на изображение или границы исходника.
    # Исходное состояние: корректный снимок с одной изменённой записью.
    # Ожидаемый результат: ни один дефект не выдаётся за готовый материал ревизии.
    def test_bad_visual_fields(self):
        for field in ["tint", "path", "bounds"]:
            broken = copy.deepcopy(self.audit)
            item = broken["entries"][0]
            if field == "tint":
                item["tint"] = "invalid"
            elif field == "path":
                item["icon"]["image"] = "../outside.png"
            else:
                item["icon"]["rect"][2] = 999999
            with self.assertRaises(ValueError):
                validate(broken, self.backlog)


if __name__ == "__main__":
    unittest.main()
