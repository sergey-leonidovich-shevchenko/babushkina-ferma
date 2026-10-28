#!/usr/bin/env python3
"""Портит только копии нативного пакета и пересчитывает хеш, проверяя содержимое доказательств."""
import contextlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
from tools.assets.contracts.asset_costs import sha
from tools.build.asset_pack import proof_errors
from tools.assets.contracts.asset_report import ROOT, REPORT
from tools.assets.migration.migration_inventory import git_bytes
from tools.assets.contracts.source_paths import current_source


@contextlib.contextmanager
def packet():
    """Копирует один законченный отчёт и инструменты в отдельную временную папку без игровых файлов."""
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);shutil.copytree(ROOT/REPORT,root/REPORT)
        for name in ['export_presets.cfg','tools/visual_asset_policy.json','tools/asset_pack_probe.gd','tools/asset_game_probe.gd','tools/visual_camera_points.gd','docs/reports/visual-overhaul/vbase-003/camera-points.json']:
            target=current_source(root,name);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(current_source(ROOT,name),target)
        # У временного пакета нет своего Git: читаем настоящую неизменную историю проекта.
        with patch('tools.build.asset_pack.git_bytes',side_effect=lambda _root,commit,name:git_bytes(ROOT,commit,name)):
            yield root,json.loads((root/REPORT/'inventory.json').read_text())


def change(root,name,transform):
    """Пересчитывает публичный хеш намеренно повреждённого JSON, не делая порчу допустимой."""
    path=root/REPORT/name;data=json.loads(path.read_text());transform(data);path.write_text(json.dumps(data))
    manifest=root/REPORT/'proof.json';proof=json.loads(manifest.read_text());proof['artifacts'][name]=sha(path.read_bytes());manifest.write_text(json.dumps(proof))


class ExportProofTests(unittest.TestCase):
    """Доказывает отказ на неполноте, утечке исходников, неверной оценке и изменении настоящего игрового кадра."""
    def test_complete_packet(self):
        """Полная матрица включает обе сцены, все текстуры и настоящий отказ сломанного пакета."""
        self.assertEqual(proof_errors(ROOT,json.loads((ROOT/REPORT/'inventory.json').read_text())),[])

    def test_pack_payload_removed_after_rehash(self):
        """Даже с новым хешем потерянный payload не проходит проверку связей."""
        with packet() as (root,data):
            def mutate(pack):
                target=pack['resources']['assets/game/interiors/furniture_a/rustic_table_south.png']['payloads'][0];del pack['entries'][target]
            change(root,'pack.json',mutate);self.assertTrue(any('missing payload' in e for e in proof_errors(root,data)))

    def test_source_fallback_is_not_pack_success(self):
        """Пакет, которому доступен физический проект, отклоняется независимо от похожей картинки."""
        with packet() as (root,data):
            change(root,'native/pack/capture.json',lambda x:x.update(physical_project_present=True))
            self.assertTrue(any('fall back' in e for e in proof_errors(root,data)))

    def test_missing_native_texture_after_rehash(self):
        """Изъятый из обеих сторон ресурс обнаруживается по независимому полному каталогу."""
        with packet() as (root,data):
            for stage in ['source','pack']:change(root,'native/'+stage+'/capture.json',lambda x:x['textures'].pop(next(iter(x['textures']))))
            self.assertTrue(any('coverage' in e for e in proof_errors(root,data)))

    def test_binary_size_is_not_trusted(self):
        """Поддельная одинаковая оценка бинарного ImageTexture не меняет размеры каталога."""
        with packet() as (root,data):
            for stage in ['source','pack']:
                change(root,'native/'+stage+'/capture.json',lambda x:x['textures']['assets/game/prepared_pixels/grandmother.res'].update(nominal_rgba8_bytes=1))
            self.assertTrue(any('memory differs' in e for e in proof_errors(root,data)))

    def test_negative_loader_cannot_succeed(self):
        """Отрицательный контроль с пустым списком ошибок не считается подтверждённым отказом."""
        with packet() as (root,data):
            change(root,'native/negative/capture.json',lambda x:x.update(errors=[]))
            self.assertTrue(any('did not fail' in e for e in proof_errors(root,data)))

    def test_game_camera_and_state_are_compared(self):
        """Сдвинутая камера или изменение игрового состояния не прячется за зелёным полем errors."""
        with packet() as (root,data):
            change(root,'native/game-pack/capture.json',lambda x:x['scenes']['overworld']['configuration'].update(camera=[99,99]))
            self.assertTrue(any('camera or serialized state' in e for e in proof_errors(root,data)))

    def test_changed_native_game_pixel_after_rehash(self):
        """Один изменённый пиксель полного framebuffer обнаруживается после обновления внешнего SHA."""
        with packet() as (root,data):
            path=root/REPORT/'native/game-pack/overworld.png'
            with Image.open(path) as source:image=source.copy()
            image.putpixel((10,10),(255,0,0,255));image.save(path)
            proof_path=root/REPORT/'proof.json';proof=json.loads(proof_path.read_text());proof['artifacts']['native/game-pack/overworld.png']=sha(path.read_bytes());proof_path.write_text(json.dumps(proof))
            self.assertTrue(any('game image differs' in e for e in proof_errors(root,data)))

    def test_historical_camera_does_not_lock_current_instrument(self):
        """Новая рабочая камера не переписывает экспортный снимок прежнего commit."""
        with packet() as (root,data):
            path=root/'tools/visual_camera_points.gd';path.write_bytes(path.read_bytes()+b'\n# later instrument\n')
            registry=root/'docs/reports/visual-overhaul/vbase-003/camera-points.json';registry.write_bytes(b'{}\n')
            self.assertEqual(proof_errors(root,data),[])

    def test_historical_camera_hash_cannot_be_resigned(self):
        """Подмена хеша в обеих нативных сторонах отвергается даже после обновления внешней подписи."""
        for key in ['points_sha256','registry_sha256']:
            with self.subTest(key=key), packet() as (root,data):
                for stage in ['source','pack']:
                    change(root,'native/game-'+stage+'/capture.json',lambda row:row.update({key:'0'*64}))
                self.assertTrue(any('historical camera instrument/registry differs' in e for e in proof_errors(root,data)))

    def test_missing_history_is_not_current_source_fallback(self):
        """При недоступной истории проверка отказывает, а не использует похожий текущий скрипт."""
        with packet() as (root,data), patch('tools.build.asset_pack.git_bytes',side_effect=OSError('historical source unavailable')):
            self.assertTrue(any('historical source unavailable' in e for e in proof_errors(root,data)))


if __name__=='__main__':unittest.main()
