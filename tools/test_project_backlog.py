#!/usr/bin/env python3
"""Проверки плана, блокирующих связей, статусов и читаемых карточек."""

from copy import deepcopy
import unittest

import project_backlog as backlog


class BacklogTests(unittest.TestCase):
    """Отклоняет повреждение плана и неподтверждённую готовность."""

    def setUp(self):
        """Читает независимую копию для отрицательных сценариев."""
        self.plan = backlog.load_plan()

    def test_plan_files_and_topology(self):
        """Сценарий: исходный план. Исходное состояние: текущий код. Ожидаемый результат: все ссылки и зависимости верны."""
        backlog.validate(self.plan)
        seen = set()
        for task in backlog.topological_tasks(self.plan):
            self.assertTrue(set(task['dependencies']).issubset(seen))
            seen.add(task['id'])
        self.assertEqual(50, len(seen))

    def test_duplicate_identifier(self):
        """Сценарий: повтор ID. Исходное состояние: разные задачи. Ожидаемый результат: ошибка до записи плана."""
        self.plan['tasks'][1]['id'] = self.plan['tasks'][0]['id']
        with self.assertRaisesRegex(ValueError, 'Повтор'):
            backlog.validate(self.plan)

    def test_unknown_dependency(self):
        """Сценарий: потерянный блокер. Исходное состояние: чужой ID. Ожидаемый результат: явный отказ."""
        self.plan['tasks'][1]['dependencies'] = ['MISSING-01']
        with self.assertRaisesRegex(ValueError, 'зависимость'):
            backlog.validate(self.plan)

    def test_cycle(self):
        """Сценарий: взаимная блокировка. Исходное состояние: два пункта ждут друг друга. Ожидаемый результат: цикл обнаружен."""
        self.plan['tasks'][0].update(dependencies=['OPT-02'], status='blocked')
        with self.assertRaisesRegex(ValueError, 'Цикл'):
            backlog.validate(self.plan)

    def test_ready_requires_finished_blockers_and_design(self):
        """Сценарий: ложный Ready. Исходное состояние: незакрытый блокер/макет. Ожидаемый результат: оба отклонены."""
        for change in ({'dependencies': ['OPT-02']}, {'needs': ['design']}):
            plan = deepcopy(self.plan)
            plan['tasks'][0].update(change)
            with self.assertRaisesRegex(ValueError, 'блокирующие'):
                backlog.validate(plan)

    def test_completion_unblocks_dependent_without_removing_history(self):
        """Сценарий: блокер завершён. Исходное состояние: записан отчёт. Ожидаемый результат: зависимая задача становится Ready со старой связью."""
        self.plan['tasks'][0].update(status='done', result='Измерения и отрицательные трассы сохранены в отчёте.')
        self.plan['tasks'][1]['status'] = 'ready'
        backlog.validate(self.plan)
        self.assertEqual(['OPT-01'], self.plan['tasks'][1]['dependencies'])

    def test_done_requires_evidence_and_single_active_task(self):
        """Сценарий: ложное завершение или лишний WIP. Исходное состояние: нет отчёта/два исполненных старта. Ожидаемый результат: отказ."""
        self.plan['tasks'][0]['status'] = 'done'
        with self.assertRaisesRegex(ValueError, 'подтверждения'):
            backlog.validate(self.plan)
        self.plan['tasks'][0]['status'] = 'in_progress'
        next(t for t in self.plan['tasks'] if t['id'] == 'SAFE-01')['status'] = 'in_progress'
        with self.assertRaisesRegex(ValueError, 'больше одной'):
            backlog.validate(self.plan)

    def test_bad_destination_file_and_branch(self):
        """Сценарий: повреждённые ссылки. Исходное состояние: чужой repo/путь/ветка. Ожидаемый результат: каждый случай отклонён."""
        changes = [lambda p: p.update(repository='other/repo'),
                   lambda p: p['tasks'][0].update(files=['../../etc/passwd']),
                   lambda p: p['tasks'][0].update(files=['missing-file.gd']),
                   lambda p: p['tasks'][0].update(branch_slug='../../main')]
        for change in changes:
            plan = deepcopy(self.plan)
            change(plan)
            with self.assertRaises(ValueError):
                backlog.validate(plan)

    def test_done_cannot_skip_pending_dependency(self):
        """Сценарий: преждевременное закрытие. Исходное состояние: есть результат, блокер открыт. Ожидаемый результат: завершение отклонено."""
        self.plan['tasks'][1].update(status='done', result='Заявлено завершение без блокера.')
        with self.assertRaisesRegex(ValueError, 'блокирующие'):
            backlog.validate(self.plan)

    def test_truncated_plan_and_acceptance(self):
        """Сценарий: усечение. Исходное состояние: нет задачи/критериев. Ожидаемый результат: ошибка, а не молчаливый успех."""
        plan = deepcopy(self.plan)
        plan['tasks'].pop()
        with self.assertRaises(ValueError):
            backlog.validate(plan)
        self.plan['tasks'][0]['acceptance'] = ['Сделать красиво']
        with self.assertRaises(ValueError):
            backlog.validate(self.plan)

    def test_readable_cards_keep_branch_conditions_and_acceptance(self):
        """Сценарий: читаемый файл. Исходное состояние: 50 открытых задач. Ожидаемый результат: все ветки, критерии и ограничения видимы."""
        document = backlog.render(self.plan)
        self.assertEqual(50, document.count('**Приёмка:**'))
        self.assertIn('codex/opt-02-storage-frame-budget', document)
        self.assertIn('[OPT-01](#opt-01)', document)
        self.assertIn('Выбор дизайна/физический доступ', document)
        self.assertIn('пока нет; задача открыта', document)
        self.assertNotIn('Closes #', document)


if __name__ == '__main__':
    unittest.main()
