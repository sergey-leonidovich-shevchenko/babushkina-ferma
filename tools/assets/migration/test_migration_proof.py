#!/usr/bin/env python3
"""Портит отдельные копии GPU-пакета, не трогая игру или принятые кадры."""
import json
from pathlib import Path
from tools.common.paths import project_root
import shutil
import tempfile
import unittest
from PIL import Image
from tools.assets.migration.migration_inventory import sha
from tools.assets.migration.migration_proof import REPORT, comparisons, validate, fixture_bytes
from tools.assets.contracts.source_paths import current_source

ROOT=project_root(__file__)


class MigrationProofTests(unittest.TestCase):
    """Проверяет смысл доказательств даже после пересчёта всех зависимых хешей."""

    def setUp(self):
        """Копирует пакет и ограниченные исходные зависимости в новый временный корень."""
        self.temporary=tempfile.TemporaryDirectory(prefix='farm-migration-proof-');self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name);self.report=self.root/REPORT
        shutil.copytree(ROOT/REPORT,self.report)
        inventory=json.loads((self.report/'fixture-sources.json').read_text())
        for name,digest in inventory['files'].items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True)
            raw=fixture_bytes(ROOT, inventory['base_commit'], name, digest)
            path.write_bytes(raw)
        capture = current_source(self.root, 'tools/migration_capture.gd')
        capture.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(current_source(ROOT, 'tools/migration_capture.gd'), capture)

    def save(self,name,data):
        """Сохраняет испорченную копию и обновляет её подпись, чтобы не ограничиться проверкой хеша."""
        path=self.report/name;path.write_text(json.dumps(data,indent=2)+'\n')

    def refresh(self):
        """Пересчитывает SHA и измерения как при возможном ошибочном повторном оформлении пакета."""
        proof=json.loads((self.report/'proof.json').read_text())
        for phase in ['baseline','dual','unadapted','retired','rollback']:
            path=self.report/'native'/phase/'capture.json';data=json.loads(path.read_text())
            data['frames']={name:sha((path.parent/(name+'.png')).read_bytes()) for name in ['dark','light']}
            self.save('native/'+phase+'/capture.json',data)
        proof['files']={name:sha((self.report/name).read_bytes()) for name in proof['files']}
        proof['comparisons']=comparisons(self.report)
        self.save('proof.json',proof)

    def test_real_packet_passes(self):
        """Настоящие кадры, геометрия и документы проходят на независимой копии."""
        self.assertEqual(validate(self.root),[])

    def test_changed_pixel_fails_after_rehash(self):
        """Различие в положительном переносе не скрывается новыми подписями и пересчитанной метрикой."""
        path=self.report/'native/dual/dark.png'
        with Image.open(path) as source:image=source.copy()
        image.putpixel((192,180),(255,0,0,255));image.save(path)
        self.refresh()
        self.assertTrue(any('equality/negative control' in row for row in validate(self.root)))

    def test_negative_control_cannot_be_replaced_by_good_frame(self):
        """Потеря наблюдаемого отказа блокируется даже при согласованном JSON."""
        shutil.copyfile(self.report/'native/baseline/dark.png',self.report/'native/unadapted/dark.png')
        self.refresh()
        self.assertTrue(any('equality/negative control' in row for row in validate(self.root)))

    def test_old_uid_or_changed_note_cannot_be_hidden(self):
        """Новый файл не получает прежний UID, а заметка старого черновика переживает перенос."""
        name='native/dual/capture.json';original=json.loads((self.report/name).read_text())
        for mutation in ['uid','note']:
            data=json.loads(json.dumps(original))
            if mutation=='uid':data['rows'][0]['uid']=data['rows'][0]['old_uid']
            else:data['document']['objects'][0]['notes']='lost note'
            self.save(name,data);self.refresh()
            self.assertTrue(validate(self.root),mutation)
        self.save(name,original)

    def test_missing_view_or_wrong_target_is_rejected(self):
        """Все три ракурса и настоящий фиксированный framebuffer обязательны."""
        name='native/dual/capture.json';original=json.loads((self.report/name).read_text())
        for mutation in ['view','target']:
            data=json.loads(json.dumps(original))
            if mutation=='view':data['rows'].pop()
            else:data['framebuffer']=[3584,2240]
            self.save(name,data);self.refresh()
            self.assertTrue(validate(self.root),mutation)
        self.save(name,original)

    def test_wiki_or_production_change_is_not_accepted_as_unchanged(self):
        """Сохранность игровых статей и отсутствие production-переноса проверяются отдельно от рисунка."""
        for name in ['wiki-contract.json','production-unchanged.json']:
            original=json.loads((self.report/name).read_text());data=json.loads(json.dumps(original))
            if name.startswith('wiki'):data['after']['keys'].pop()
            else:data['runtime_file_changes']=['assets/game/moved.png']
            self.save(name,data);self.refresh();self.assertTrue(validate(self.root),name)
            self.save(name,original)

    def legacy_import(self):
        """Находит единственный исходный компаньон, отсутствующий в старом Git commit."""
        name = "assets/generated/level_drafts/water_navigation_ingame_preview.png.import"
        sources = json.loads((self.report / "fixture-sources.json").read_text())
        digest = sources["files"][name]
        return self.root / name, self.report / "historical-inputs" / (digest + ".import")

    def test_regenerated_import_uses_exact_archived_original(self):
        """Новый автоматический UID checkout не меняет исторические байты доказательства."""
        current, archive = self.legacy_import()
        current.write_bytes(b"platform-regenerated import")
        self.assertTrue(archive.is_file())
        self.assertEqual(validate(self.root), [])

    def test_missing_generated_import_uses_exact_archived_original(self):
        """Чистый checkout без игнорируемого компаньона получает проверенный оригинал."""
        current, _ = self.legacy_import()
        current.unlink()
        self.assertEqual(validate(self.root), [])

    def test_corrupt_import_archive_is_rejected(self):
        """Изменённый архивный компаньон не проходит даже при наличии файла по нужному SHA-имени."""
        current, archive = self.legacy_import()
        current.write_bytes(b"regenerated")
        archive.write_bytes(b"corrupt archive")
        self.assertTrue(any("fixture source differs" in row for row in validate(self.root)))

    def test_missing_import_archive_is_rejected(self):
        """Утраченный оригинал остаётся ошибкой, а не разрешением пропустить проверку."""
        current, archive = self.legacy_import()
        current.write_bytes(b"regenerated")
        archive.unlink()
        self.assertTrue(validate(self.root))

    def test_png_cannot_use_import_archive_fallback(self):
        """Для PNG и кода сохраняется прежняя привязка к checkout или настоящему Git baseline."""
        name = "assets/game/interiors/furniture_a/rustic_table_south.png"
        (self.root / name).write_bytes(b"changed PNG")
        self.assertTrue(any("fixture source unavailable" in row for row in validate(self.root)))


if __name__=='__main__':unittest.main()
