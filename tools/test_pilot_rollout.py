#!/usr/bin/env python3
"""Отрицательные сценарии первой очереди, полного графа и границ неподтверждённой реализации."""
import copy
import json
import unittest
from pilot_rollout import ROOT,FOLDER,PROGRAM,load,validate,project,frontier,reference,graph_signature


class PilotRolloutTests(unittest.TestCase):
    """Не даёт короткому списку скрыть блокеры, весь каталог контента или неподтверждённый runtime."""
    def setUp(self):
        """Читает отдельные копии текущих исходников, не меняя статусы пользователя."""
        self.plan=load(ROOT/FOLDER/'plan.json');self.program=load(ROOT/PROGRAM)

    def test_live_plan_and_recorded_same_camera(self):
        """План ограничен 52 карточками и ссылается на настоящую неподвижную пару, не новый дизайн."""
        self.assertEqual(validate(self.plan,self.program),[]);self.assertEqual(reference(ROOT),[])
        queue=project(self.plan,self.program);self.assertEqual(len(queue['taskKeys']),52)
        self.assertNotIn('visual--VRELEASE-001',queue['taskKeys'])
        result=frontier(queue,self.program)
        if result['next']:
            row=next(r for r in result['rows'] if r['id']==result['next'])
            self.assertEqual(row['status'],'ready');self.assertEqual(row['blockers'],[])

    def test_complete_transitive_closure_and_topological_order(self):
        """Каждая прямая/добавленная зависимость стоит раньше карточки, кроме явного владельца-планировщика."""
        queue=project(self.plan,self.program);order={k:i for i,k in enumerate(queue['taskKeys'])};by={t['id']:t for t in self.program['tasks']}
        for key,index in order.items():
            task=by[key.split('--')[1]]
            for dep in task['depends_on']+[k.split('--')[1] for k in queue['extraDependencies'].get(key,[])]:
                if dep=='VRELEASE-001':continue
                self.assertLess(order['visual--'+dep],index)

    def test_status_changes_do_not_duplicate_or_stale_queue(self):
        """Очередь не хранит статусы; обновление реальной карточки меняет прогресс, не состав."""
        before=project(self.plan,self.program)
        for task in self.program['tasks']:task['status']='done'
        task=next(t for t in self.program['tasks'] if t['id']=='VBASE-002');task['status']='ready'
        self.assertEqual(frontier(before,self.program)['next'],'VBASE-002')
        task['status']='done'
        self.assertEqual(project(self.plan,self.program),before)
        result=frontier(before,self.program);self.assertIsNone(result['next']);self.assertEqual(result['done'],len(before['taskKeys']))

    def test_missing_source_dependency_does_not_disappear(self):
        """Дополнительный реальный блокер автоматически попадает в граф; старый projection больше не совпадает."""
        old=project(self.plan,self.program);task=next(t for t in self.program['tasks'] if t['id']=='VGROUND-001');task['depends_on'].append('VBASE-006')
        new=project(self.plan,self.program);self.assertIn('visual--VBASE-006',new['taskKeys']);self.assertNotEqual(new['graphSignature'],old['graphSignature'])

    def test_cycle_and_unknown_task_fail(self):
        """Цикл и опечатка не заменяются неполной успешной очередью."""
        self.plan['extra_dependencies']['VBASE-002']=['VBASE-005'];self.plan['extra_dependencies']['VBASE-005']=['VBASE-002']
        self.assertTrue(any('cycle' in e for e in validate(self.plan,self.program)))
        self.plan['extra_dependencies']['VBASE-002']=['UNKNOWN-001']
        self.assertTrue(any('unknown task' in e for e in validate(self.plan,self.program)))

    def test_mass_art_or_full_release_cannot_enter_first_queue(self):
        """Ни одна карточка 837-производственной партии не проходит как условие первого кадра."""
        for tid in ['VICON-001','VACTOR-001','VMAP-001','VRELEASE-010']:
            bad=copy.deepcopy(self.plan);bad['stages'][1]['roots'].append(tid)
            self.assertTrue(validate(bad,self.program),tid)

    def test_too_large_limit_and_partial_completion_rejected(self):
        """Нельзя обойти границу увеличением лимита или закрыть полную карточку частичным срезом."""
        self.plan['limits']['max_tasks']=1000;self.assertTrue(validate(self.plan,self.program))
        self.plan['limits']['max_tasks']=64;self.plan['completion_policy']='pilot-subset-is-done';self.assertTrue(validate(self.plan,self.program))

    def test_fake_done_acceptance_with_open_extra_gates_rejected(self):
        """Глобальный status done не перекрывает непроверенные условия пилота."""
        for task in self.program['tasks']:task['status']='done'
        next(t for t in self.program['tasks'] if t['id']=='VRELEASE-002')['status']='done'
        next(t for t in self.program['tasks'] if t['id']=='VPROP-003')['status']='backlog'
        self.assertTrue(any('open gate' in e for e in validate(self.plan,self.program)))

    def test_props_and_hardware_cannot_be_silently_omitted(self):
        """Витрина сохраняет все общие предметы, а статичный допуск — оборудование и маршруты."""
        next(t for t in self.program['tasks'] if t['id']=='VRELEASE-002')['depends_on'].remove('VPROP-003');self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['extra_dependencies']['VRELEASE-002'].remove('VBASE-002');self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['extra_dependencies']['VGROUND-005']=[];self.assertTrue(validate(self.plan,self.program))

    def test_grid_bridge_and_current_world_height(self):
        """Архивный мастер высотой 1200 не становится физической картой; целый мост остаётся внутри области."""
        self.plan['scope']['world_size'][1]=1200;self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['scope']['world_rect'][0]+=1;self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['scope']['world_rect'][2]=24;self.assertTrue(validate(self.plan,self.program))

    def test_all_epics_have_justified_roles(self):
        """Пять производственных эпиков не потеряны и не объявлены выполненными вне очереди."""
        self.plan['epic_roles'].pop('VACTOR');self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['epic_roles']['VFOLIAGE']['role']='core';self.assertTrue(validate(self.plan,self.program))

    def test_future_projection_and_compatibility_are_not_claimed(self):
        """Текущая неподвижная пара не принимает ни 120%-камеру, ни старый слот, ни рабочее включение."""
        self.plan['target']['accepted']=True;self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['compatibility']['old_slot']['accepted']=True;self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['scope']['views'].append('north');self.assertTrue(validate(self.plan,self.program))

    def test_queue_cannot_recommend_its_own_planning_task(self):
        """Владелец плана — явное внешнее условие, а не самоблокирующаяся строка его очереди."""
        self.plan['stages'][0]['roots'].append('VRELEASE-001');self.assertTrue(validate(self.plan,self.program))

    def test_first_location_cannot_be_replaced_by_mechanics_or_cave_props(self):
        """Пилот ведёт к полной overworld; новые механики и общая партия не подменяют курс."""
        for tid in ['VPROP-001','VPROP-008','VPROP-009','VPROP-010']:
            bad=copy.deepcopy(self.plan);bad['stages'][1]['roots'].append(tid);self.assertTrue(validate(bad,self.program))
        self.plan['focus']['allow_new_mechanics']=True;self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json');self.plan['focus']['final_gate']='VMAP-006';self.assertTrue(validate(self.plan,self.program))
        self.plan=load(ROOT/FOLDER/'plan.json')
        for tid in ['VMAP-004','VRELEASE-006']:
            program=copy.deepcopy(self.program);next(t for t in program['tasks'] if t['id']==tid)['depends_on'].remove('VMAP-003')
            self.assertTrue(any('another location' in e for e in validate(self.plan,program)))

    def test_blocked_status_remains_blocked(self):
        """Внешнее условие карточки не исчезает из-за пустого списка внутренних зависимостей."""
        next(t for t in self.program['tasks'] if t['id']=='VBASE-002')['status']='blocked'
        actual=frontier(project(self.plan,self.program),self.program)
        self.assertNotEqual(actual['next'],'VBASE-002');self.assertFalse(next(r for r in actual['rows'] if r['id']=='VBASE-002')['eligible'])


if __name__=='__main__':unittest.main()
