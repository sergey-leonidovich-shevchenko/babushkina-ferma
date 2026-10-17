#!/usr/bin/env python3
"""Регрессии полноты и границ аудита VART-009."""
import unittest
from unittest.mock import patch
import hashlib
import json
from pathlib import Path
from visual_reuse import ROOT,REPORT,read,contract_errors,verify,baseline_bytes


class ReuseTests(unittest.TestCase):
    def setUp(self):
        """Загружает отдельные копии источников каждого сценария."""
        self.plan=read(REPORT/'decisions.json');self.inv=read(REPORT/'inventory.json');self.capture=read(REPORT/'native/capture.json');self.manifest=json.loads(baseline_bytes(ROOT/'assets/game/world_sprite_manifest.json',self.plan['manifest_sha256'],self.plan['base_commit']));self.epics=[e['id'] for e in read(ROOT/'docs/epics/visual-overhaul-2026-10/backlog.json')['epics']]

    def errors(self):
        """Проверяет текущую мутацию без записи в репозиторий."""
        return contract_errors(self.plan,self.inv,self.capture,self.manifest,self.epics)

    def test_files(self):
        """Реальные исходники, решения, владельцы и PNG проходят сверку."""
        self.assertEqual(verify(),[])

    def test_missing_family(self):
        """Отсутствие одного семейства нельзя скрыть общим числом записей."""
        self.plan['families'][1]=self.plan['families'][0].copy()
        self.assertIn('family coverage',self.errors())

    def test_empty_decision(self):
        """Метка без причины и будущего владельца не завершает аудит."""
        self.plan['families'][2]['reason']='';self.plan['families'][2]['owner_epics']=['UNKNOWN']
        self.assertIn('decision rationale',self.errors());self.assertIn('work owner',self.errors())

    def test_lost_asset(self):
        """Потерянный файл не исчезает из знаменателя инвентаря."""
        self.inv['files'].pop()
        self.assertIn('inventory coverage',self.errors())

    def test_no_implicit_deletion_or_approval(self):
        """Техническое решение не разрешает удаление и не принимает production-рисунок."""
        self.plan['deletion_authorized']=True;self.plan['families'][0]['new_art_approved']=True
        self.assertIn('audit scope',self.errors());self.assertIn('production approval',self.errors())

    def test_native(self):
        """Headless, уменьшенный PNG и пропущенный фон отклоняются."""
        self.capture['display_server']='headless';self.capture['frames'].pop();self.capture['frames'][0]['size']=[960,540]
        self.assertIn('native profile',self.errors());self.assertIn('frame coverage',self.errors());self.assertIn('readback',self.errors())

    def test_archive_is_not_world(self):
        """Уменьшенный обзор монолитной карты не объявляется мировым сравнением."""
        self.capture['frames'][0]['kind']='world-comparison'
        self.assertIn('frame classification',self.errors())

    def test_future_art_does_not_rewrite_history(self):
        """Позднейший новый PNG не переписывает результат старого аудита и не требует массового отката графики."""
        asset=self.inv['files'][0]
        with patch.object(Path,'read_bytes',return_value=b'later approved art'):
            data=baseline_bytes(ROOT/asset['path'],asset['sha256'],self.plan['base_commit'])
        self.assertEqual(hashlib.sha256(data).hexdigest(),asset['sha256'])


if __name__=='__main__':unittest.main()
