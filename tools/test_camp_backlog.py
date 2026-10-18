#!/usr/bin/env python3
"""Отрицательные проверки целостности предметного плана, без фиктивной игровой приёмки."""

import copy
import json
import unittest
import camp_backlog as plan


class CampPlanTests(unittest.TestCase):
    """Защищает предметы, источники открытия, зависимости и правдивость статусов."""

    def setUp(self):
        """Каждый сценарий получает независимую копию принятого источника."""
        self.data = plan.read_plan()
        source = json.loads((plan.ROOT / 'docs/epics/visual-overhaul-2026-10/backlog.json').read_text())
        self.external = {t['id']: t for t in source['tasks']}
        self.snapshot = json.loads((plan.PLAN_DIR / 'catalog-snapshot.json').read_text())

    def errors(self):
        """Собирает отказ для изменённого плана без записи документов."""
        return '\n'.join(plan.validate(self.data, self.external, self.snapshot))

    def test_current_plan(self):
        """Сценарий: полный план; исходно 100 открытых задач; ожидается корректный граф."""
        self.assertEqual(self.errors(), '')
        self.assertEqual(sum(t['craft']['station'] == 'field' for t in self.data['tasks']), 66)

    def test_eligible_owner_can_start(self):
        """Сценарий: владелец наблюдений готов; исходно нет блокеров; ручной статус разрешён."""
        self.data['tasks'][70]['status'] = 'in_progress'
        self.assertEqual(self.errors(), '')

    def test_missing_or_duplicate_item(self):
        """Сценарий: потерян или скопирован предмет; исходно полный план; ожидается отказ."""
        self.data['tasks'].pop()
        self.assertIn('exactly 100', self.errors())
        self.data = plan.read_plan()
        self.data['tasks'][1]['item'] = self.data['tasks'][0]['item']
        self.assertIn('duplicate item', self.errors())

    def test_unknown_material_and_planned_source(self):
        """Сценарий: выдумано сырьё/убран владелец ветки; исходно рабочий рецепт; ожидается отказ."""
        self.data['tasks'][0]['craft']['inputs']['imaginary_oil'] = 1
        self.assertIn('unknown material', self.errors())
        self.data['tasks'][0]['depends_on'].remove('VTREE-014')
        self.assertIn('planned material without dependency', self.errors())

    def test_recipe_producer_and_common_owner(self):
        """Сценарий: пропущены готовая смесь/общий владелец; исходно зависимости есть; ожидается отказ."""
        task = self.data['tasks'][36]
        task['depends_on'].remove('CAMP-036')
        self.assertIn('missing item producer', self.errors())
        task['depends_on'].remove('CAMP-033')
        self.assertIn('missing common owner', self.errors())

    def test_cycles_include_other_plans(self):
        """Сценарий: межплановый цикл; исходно VIS не ссылается на CAMP; ожидается отказ."""
        self.external = copy.deepcopy(self.external)
        self.external['VTREE-014']['depends_on'].append('CAMP-001')
        self.assertIn('dependency cycle', self.errors())

    def test_blueprint_recovery(self):
        """Сценарий: убрана гарантированная копия чертежа; исходно источник задан; ожидается отказ."""
        self.data['tasks'][10]['unlock']['fallback'] = ''
        self.assertIn('guaranteed fallback', self.errors())

    def test_unaccepted_ready_and_false_done(self):
        """Сценарий: закрытые блокеры не приняты; исходно задача открыта; Ready/Done отклоняются."""
        task = self.data['tasks'][10]
        task['status'] = 'ready'
        self.assertIn('unaccepted blocker', self.errors())
        task['status'] = 'done'
        self.assertIn('done needs acceptance', self.errors())

    def test_existing_item_classification_and_quantities(self):
        """Сценарий: повязка названа новой/дробные затраты; исходно реальные данные; ожидается отказ."""
        self.data['tasks'][30]['kind'] = 'new'
        self.data['tasks'][30]['craft']['inputs']['cloth'] = 0.5
        self.assertIn('classification conflicts', self.errors())
        self.assertIn('invalid ingredient quantity', self.errors())

    def test_food_hp_energy_order_and_batch_budget(self):
        """Сценарий: HP перепутано с энергией; исходно реальный эффект пайка; ожидается отказ."""
        self.assertEqual(plan.plain_effect(['item_effect_heal_energy',65,10]), {'hp':65,'energy':10,'mana':0})
        self.data['tasks'][59]['prototype_effect'] = {'hp':10,'energy':65,'mana':0}
        self.assertIn('food batch exceeds', self.errors())
        self.assertIn('changed existing food effect', self.errors())

    def test_render_is_read_only_and_current(self):
        """Сценарий: генерация карточек; исходно JSON принят; ожидаются те же статусы и точные файлы."""
        before = copy.deepcopy(self.data)
        files = plan.documents(self.data)
        self.assertEqual(len(files), 11)
        self.assertEqual(self.data, before)
        for name, content in files.items():
            self.assertEqual((plan.PLAN_DIR / name).read_text(), content, name)
        count = sum(content.count('<a id="camp-') for content in files.values())
        self.assertEqual(count, 100)


if __name__ == '__main__':
    unittest.main()
