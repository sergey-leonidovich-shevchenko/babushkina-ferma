#!/usr/bin/env python3
"""Проверяет граф и правила миграции на копиях; рабочая графика не меняется."""
import copy
import json
import os
from pathlib import Path
from common.paths import project_root
import subprocess
import tempfile
import unittest
from asset_migration import default_plan,validate_plan,switch_errors,RETIRE_GATES
from migration_inventory import build,historical_errors,candidates,runtime_names
from migration_fixture import phase


class MigrationPlanTests(unittest.TestCase):
    """Не позволяет превратить подготовку в неявное удаление или изменение владельца."""

    def setUp(self):
        """Собирает два переставленных семейства с одним общим файлом и настоящий паспорт трёх видов."""
        self.inventory={'base_commit':'a'*40,'files':{'assets/game/shared.png':{}}}
        self.manifest={'entries':[{'id':'WS-002','family':'Second','assets':[{'path':'assets/game/shared.png'}]},{'id':'WS-001','family':'First','assets':[{'path':'assets/game/shared.png'}]}]}
        self.decisions={'families':[{'id':'WS-001','decision':'reuse','owner_epics':['VPIPELINE']},{'id':'WS-002','decision':'redraw','owner_epics':['VGROUND']}]}
        self.plan=default_plan(self.inventory,self.manifest,self.decisions)
        self.before=json.loads((project_root(__file__)/'assets/game/visual_resources.json').read_text())
        self.after=copy.deepcopy(self.before);self.old=[row['file'] for row in self.before['textures'].values()]
        for row in self.after['textures'].values():row['file']=row['file'].replace('/furniture_a/','/migration_pilot/')
        self.available=set(self.old)|{row['file'] for row in self.after['textures'].values()}

    def errors(self):
        """Проверяет правила на независимых данных, не заменяя результат самой реализацией."""
        return validate_plan(self.plan,self.inventory,self.manifest,self.decisions,set(RETIRE_GATES))

    def test_family_join_is_by_id_and_shared_file_has_one_owner(self):
        """Несовпадающий порядок входных семейств не назначает им чужие задачи и решения."""
        self.assertEqual(self.errors(),[])
        self.assertEqual(self.plan['families'][0]['decision'],'reuse')
        self.assertEqual(self.plan['file_owners']['assets/game/shared.png'],{'primary_epic':'VPIPELINE','families':['WS-001','WS-002']})

    def test_missing_family_file_or_owner_is_rejected(self):
        """Потеря любого семейства, его файла или одного владельца блокируется."""
        for mutation in ['family','file','owner']:
            with self.subTest(mutation=mutation):
                saved=copy.deepcopy(self.plan)
                if mutation=='family':self.plan['families'].pop()
                elif mutation=='file':self.plan['families'][0]['assets']=[]
                else:self.plan['file_owners']={}
                self.assertTrue(self.errors());self.plan=saved

    def test_scope_order_retirement_and_production_adapter_are_explicit(self):
        """План не может разрешить удаление, переставить зависимость или объявить прототип готовым runtime."""
        for mutation in ['scope','order','gate','adapter']:
            saved=copy.deepcopy(self.plan)
            if mutation=='scope':self.plan['deletion_authorized']=True
            elif mutation=='order':self.plan['steps'][0]['after']=['retire']
            elif mutation=='gate':self.plan['retirement_gates']=[]
            else:self.plan['pilot']['production_adapter_implemented']=True
            self.assertTrue(self.errors(),mutation);self.plan=saved

    def test_staged_copy_preserves_ids_geometry_and_old_paths(self):
        """Одновременное существование старого и нового пути с адаптером проходит rename-only контракт."""
        self.assertEqual(switch_errors(self.before,self.after,self.old,self.available,adapter=True),[])

    def test_missing_old_path_or_adapter_blocks_switch(self):
        """Сохранённый черновик и его адресная фильтрация защищены независимо от существования нового PNG."""
        self.assertTrue(any('adapter' in row for row in switch_errors(self.before,self.after,self.old,self.available)))
        self.available.remove(self.old[0])
        self.assertTrue(any('saved F12 path' in row for row in switch_errors(self.before,self.after,self.old,self.available,adapter=True)))

    def test_renamed_id_footprint_or_pixels_are_not_a_rename(self):
        """Подмена ID, основания и размеров не проходит под видом простого переноса файла."""
        for mutation in ['id','footprint','pixels']:
            after=copy.deepcopy(self.after)
            if mutation=='id':after['resources']['different']=after['resources'].pop('prop.rustic_table')
            elif mutation=='footprint':after['resources']['prop.rustic_table']['views']['south']['footprint_size']=[1,1]
            else:after['textures']['oak_table_south']['pixels']=[1,1]
            self.assertTrue(switch_errors(self.before,after,self.old,self.available,adapter=True),mutation)

    def test_destination_escape_missing_texture_and_retirement_are_rejected(self):
        """Новый адрес обязан оставаться в runtime, существовать и не включать удаление."""
        self.after['textures']['oak_table_south']['file']='res://assets/game/../../outside.png'
        self.assertTrue(any('unsafe' in row for row in switch_errors(self.before,self.after,self.old,self.available,adapter=True)))
        self.assertTrue(any('retirement' in row for row in switch_errors(self.before,self.before,self.old,self.available,allow_retire=True)))

    def test_exact_template_and_prefix_consumers_are_conservative(self):
        """Форматные имена и корень каталога защищают все совпавшие пути, но не похожий префикс."""
        names={'assets/game/items/apple.png','assets/game/items/pear.png','assets/game/items2/apple.png'}
        rows=candidates('load("res://assets/game/items/%s.png"); scan("res://assets/game/items/")',names)
        self.assertEqual({row[0] for row in rows},{'assets/game/items/apple.png','assets/game/items/pear.png'})
        self.assertEqual({row[1] for row in rows},{'template','prefix'})

    def test_source_barrier_excludes_nested_source_only(self):
        """Барьер закрывает поддерево исходника, сохраняя соседнюю папку с похожим именем."""
        files=['assets/game/source/.gdignore','assets/game/source/a.png','assets/game/source2/a.png']
        self.assertEqual(runtime_names(files,{'non_runtime_roots':[]}),['assets/game/source2/a.png'])

    def test_fixture_mutation_cannot_run_inside_repository(self):
        """Операции стенда отказывают на корне настоящего проекта до записи каких-либо файлов."""
        with self.assertRaisesRegex(ValueError,'external isolated'):phase(project_root(__file__),'retired')


class ConsumerGraphTests(unittest.TestCase):
    """Проверяет историю и полноту реального Git-снимка в отдельном временном репозитории."""

    def setUp(self):
        """Изолирует Git-переменные hook и создаёт реальные literal/UID/динамические потребители."""
        self.temporary=tempfile.TemporaryDirectory(prefix='farm-migration-test-');self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name);self.env={k:v for k,v in os.environ.items() if not k.startswith('GIT_')}
        files={'assets/game/a.png':b'fixture texture','assets/game/a.png.import':b'[remap]\nuid="uid://example"\n','scripts/use.gd':b'load("res://assets/game/a.png")\nload(variable)\n','main.tscn':b'[ext_resource type="Texture2D" uid="uid://example" path="res://assets/game/a.png" id="1"]','tools/visual_asset_policy.json':b'{"non_runtime_roots":[]}'}
        for name,raw in files.items():path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
        self.git('init','--initial-branch=main');self.git('add','.')
        self.git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','baseline')
        self.base=self.git('rev-parse','HEAD').strip();self.data=build(self.root,self.base)

    def git(self,*args):
        """Выполняет команды только своего временного репозитория без пользовательских hooks."""
        return subprocess.check_output(['git','-c','core.hooksPath='+str(self.root/'no-hooks'),'-C',str(self.root),*args],env=self.env,text=True,stderr=subprocess.DEVNULL)

    def test_actual_graph_contains_literal_uid_and_unknown_loader(self):
        """Снимок различает потенциальную ссылку и вычисляемую загрузку без вывода о неиспользовании."""
        self.assertEqual(historical_errors(self.root,self.data),[])
        self.assertEqual({row['kind'] for row in self.data['files']['assets/game/a.png']['consumers']},{'literal','uid'})
        self.assertTrue(any(row['source']=='scripts/use.gd' for row in self.data['unresolved_calls']))

    def test_removed_or_new_art_uses_read_only_historical_baseline(self):
        """Исторический отчёт продолжает проверяться после будущей согласованной замены без восстановления файла."""
        (self.root/'assets/game/a.png').unlink()
        self.assertEqual(historical_errors(self.root,self.data),[])
        self.assertFalse((self.root/'assets/game/a.png').exists())

    def test_omitted_file_source_or_consumer_is_rejected(self):
        """Нельзя получить чистый граф, удалив неудобный исходник или одну из его ссылок из JSON."""
        for mutation in ['file','source','consumer']:
            data=copy.deepcopy(self.data)
            if mutation=='file':data['files'].pop('assets/game/a.png')
            elif mutation=='source':data['sources'].pop('scripts/use.gd')
            else:data['files']['assets/game/a.png']['consumers'].pop()
            self.assertTrue(historical_errors(self.root,data),mutation)

    def test_tampered_snapshot_hash_is_rejected(self):
        """Подпись другого рисунка не принимается ни из текущего файла, ни из исходного Git commit."""
        self.data['files']['assets/game/a.png']['sha256']='0'*64
        self.assertTrue(any('baseline source differs' in row for row in historical_errors(self.root,self.data)))

    def test_hidden_dynamic_reader_or_import_uid_is_rejected(self):
        """Граф не может скрыть вычисляемый load или подменить UID в читаемой записи импорта."""
        for mutation in ['dynamic','uid']:
            data=copy.deepcopy(self.data)
            if mutation=='dynamic':data['unresolved_calls']=[]
            else:data['files']['assets/game/a.png.import']['uid']='uid://different'
            self.assertTrue(historical_errors(self.root,data),mutation)

    def test_shallow_clone_requires_explicit_baseline_fetch(self):
        """Повторяет CI: shallow checkout получает точный исходный commit до офлайн-проверки истории."""
        (self.root/'assets/game/a.png').write_bytes(b'future art')
        self.git('add','.');self.git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','next')
        clone=self.root/'shallow'
        subprocess.run(['git','clone','--depth=1',self.root.as_uri(),str(clone)],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
        self.assertTrue(any('baseline commit missing' in row for row in historical_errors(clone,self.data)))
        subprocess.run(['git','-C',str(clone),'fetch','--depth=1','origin',self.base],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
        self.assertEqual(historical_errors(clone,self.data),[])


if __name__=='__main__':unittest.main()
