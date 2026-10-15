#!/usr/bin/env python3
"""Негативные проверки плана: структура не должна ложно обещать готовность или покрытие."""
import copy
import unittest
import visual_backlog as plan


class VisualBacklogTests(unittest.TestCase):
    """Проверяет испорченные копии реальных данных без записи статусов проекта."""

    def setUp(self):
        """Готовит независимый снимок каждой карточки."""
        self.data = copy.deepcopy(plan.load())

    def errors(self):
        """Возвращает ошибки того же валидатора, который запускается перед публикацией."""
        return "\n".join(plan.validate(self.data))

    def test_original_and_archive(self):
        """Сценарий: текущие данные и 31 файл архива имеют корректную структуру и хеши."""
        self.assertEqual([], plan.validate(self.data))
        self.assertEqual([], plan.validate_archive())

    def test_cycle_in_blocked_cards(self):
        """Сценарий: заблокированный статус не скрывает цикл зависимостей."""
        a, b = self.data['tasks'][-2:]
        a['depends_on'] = [b['id']]; b['depends_on'] = [a['id']]
        self.assertIn('cycle:', self.errors())

    def test_unknown_dependency(self):
        """Сценарий: опечатка номера не становится неявным внешним блокером."""
        self.data['tasks'][0]['depends_on'] = ['VBASE-999']
        self.assertIn('unknown dependency', self.errors())

    def test_pending_ready(self):
        """Сценарий: Ready запрещён, пока зависимость не завершена."""
        self.data['tasks'][0]['status'] = 'ready'
        self.data['tasks'][0]['depends_on'] = ['VBASE-002']
        self.assertIn('unfinished dependency', self.errors())

    def test_unproven_done(self):
        """Сценарий: текст карточки не заменяет доказательство результата."""
        self.data['tasks'][0]['status'] = 'done'
        self.data['tasks'][0]['evidence'] = []
        self.assertIn('unproven done', self.errors())

    def test_duplicate_id(self):
        """Сценарий: две карточки не могут разделять один ID."""
        self.data['tasks'][1]['id'] = self.data['tasks'][0]['id']
        self.assertIn('duplicate ID', self.errors())

    def test_missing_source(self):
        """Сценарий: вымышленная сцена не считается существующим исходником."""
        self.data['tasks'][0]['existing_paths'] = ['scenes/nonexistent_visual_world.tscn']
        self.assertIn('missing source', self.errors())

    def test_source_escape(self):
        """Сценарий: системный файл не выдаётся за исходник репозитория."""
        self.data['tasks'][0]['existing_paths'] = ['/etc/hosts']
        self.assertIn('missing source', self.errors())

    def test_item_coverage(self):
        """Сценарий: пропавший предмет обнаруживается даже с обновлённым счётчиком."""
        task = next(t for t in self.data['tasks'] if t['epic'] == 'VICON')
        self.data['tasks'].remove(task); self.data['task_count'] -= 1
        self.assertIn('coverage: items', self.errors())

    def test_shared_hens(self):
        """Сценарий: общий рисунок курочек обязан явно покрывать три игровые записи."""
        for task in self.data['tasks']: task.pop('covers_entities', None)
        self.assertIn('coverage: characters', self.errors())

    def test_imported_mapping(self):
        """Сценарий: нельзя потерять одну из 24 карточек архива."""
        del self.data['imported_task_map']['VFLORA-03']
        self.assertIn('imported mapping incomplete', self.errors())

    def test_single_active(self):
        """Сценарий: одновременно разрешён только один активный пункт."""
        self.data['tasks'][0]['status'] = 'in_progress'
        self.data['tasks'][1]['status'] = 'in_progress'
        self.assertIn('multiple active tasks', self.errors())

    def test_unknown_parent(self):
        """Сценарий: несуществующий владелец не создаёт второй независимый план."""
        self.data['tasks'][0]['parent_owner'] = 'OPT-999'
        self.assertIn('unknown parent', self.errors())

    def test_missing_acceptance(self):
        """Сценарий: карточка без критерия результата неполна."""
        self.data['tasks'][0]['acceptance'] = []
        self.assertIn('missing acceptance', self.errors())


if __name__ == '__main__':
    unittest.main()
