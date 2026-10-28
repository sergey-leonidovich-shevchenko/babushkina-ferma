#!/usr/bin/env python3
"""Намеренно повреждает отдельные копии политики, импорта и числовых доказательств."""
import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from tools.assets.contracts.texture_intents import ROOT, POLICY, HELPER, REPORT, DATA_IMPORT, MODES, bundle_errors, digest, fixtures, import_errors, numeric_errors, pixels, proof_errors, read, validate, write
from tools.assets.contracts.source_paths import current_source


class TextureIntentTests(unittest.TestCase):
    """Держит все отрицательные сценарии вне игровых файлов и сохранений."""

    def setUp(self):
        """Копирует только проверяемый паспорт и маленький архив доказательств."""
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup); self.root=Path(self.temp.name)
        for relative in [POLICY,HELPER,"tools/texture_data_probe.gd","tools/texture_data_room_capture.gd","scripts/systems/visual_resource_catalog.gd","assets/game/visual_resources.json"]:
            path=current_source(self.root,relative); path.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(current_source(ROOT,relative),path)
        for entry in read(ROOT/"assets/game/visual_resources.json")["textures"].values():
            path=entry["file"][6:]; target=self.root/path; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/(path+".import"),Path(str(target)+".import"))
        shutil.copytree(ROOT/REPORT,self.root/REPORT)

    def test_valid_policy_and_all_native_proof(self):
        """Действующий паспорт, полный импорт и три настоящих режима GPU проходят вместе."""
        self.assertEqual(validate(self.root),[]); self.assertEqual(proof_errors(self.root),[])
        tracked={str(p.relative_to(self.root)) for p in (self.root/REPORT).rglob("*") if p.is_file()}
        self.assertEqual(bundle_errors(self.root,tracked),[])
        for missing in ["numeric/depth.png.import","numeric/mobile-hdr.log","after/capture.json"]:
            self.assertTrue(bundle_errors(self.root,tracked-{REPORT+"/"+missing}),missing)

    def test_missing_or_numerical_role_on_visual_drawing(self):
        """Рисунок не получает роль по имени файла и не может стать числовой маской."""
        path=self.root/"assets/game/visual_resources.json"; original=read(path)
        for value in [None,"data_rgba8","unknown"]:
            data=copy.deepcopy(original); entry=next(iter(data["textures"].values()))
            if value is None: entry.pop("intent")
            else: entry["intent"]=value
            write(path,data); self.assertTrue(any("must declare color_srgb" in e for e in validate(self.root)))

    def test_destructive_data_options_and_boolean_types(self):
        """Ни одна разрушающая RGBA настройка не проходит как допустимый числовой профиль."""
        path=self.root/POLICY; original=read(path)
        for key,value in DATA_IMPORT.items():
            data=copy.deepcopy(original); data["profiles"]["data_rgba8"]["import"][key]=not value if type(value) is bool else value+1
            write(path,data); self.assertTrue(validate(self.root),key)
        data=copy.deepcopy(original); data["profiles"]["data_rgba8"]["source_color"]=0
        write(path,data); self.assertTrue(validate(self.root),"JSON boolean must remain boolean")

    def test_actual_import_and_duplicate_option(self):
        """Подмена настоящего импорта обнаруживается даже при правильной декларации паспорта."""
        entry=next(iter(read(self.root/"assets/game/visual_resources.json")["textures"].values()))
        path=Path(str(self.root/entry["file"][6:])+".import")
        path.write_text(path.read_text().replace("mipmaps/generate=false","mipmaps/generate=true"))
        self.assertTrue(any("import mismatch" in e for e in validate(self.root)))
        numeric=self.root/REPORT/"numeric/depth.png"
        Path(str(numeric)+".import").write_text(Path(str(numeric)+".import").read_text()+"\nprocess/premult_alpha=false\n")
        self.assertTrue(import_errors(numeric,DATA_IMPORT))

    def test_fresh_deterministic_fixture_and_no_overwrite(self):
        """Два новых стенда получают одинаковые байты; существующий стенд не перезаписывается."""
        a=self.root/"a"; b=self.root/"b"; fixtures(a); fixtures(b)
        for name in ["depth","flex","color","negative-alpha"]:
            self.assertEqual((a/(name+".png")).read_bytes(),(b/(name+".png")).read_bytes())
        self.assertEqual(digest(a/HELPER),digest(ROOT/HELPER))
        with self.assertRaisesRegex(ValueError,"must be new"): fixtures(a)

    def test_imported_hidden_rgb_and_alpha_are_exact(self):
        """Изменение скрытого RGB или альфы в readback импорта не маскируется видимым изображением."""
        original=read(self.root/REPORT/"numeric/mobile-hdr/readback.json")
        for channel in [0,3]:
            data=copy.deepcopy(original); data["cpu"][0]["rgba"][channel]+=1
            self.assertTrue(any("imported RGBA changed" in e for e in numeric_errors(data,"mobile-hdr")[0]))

    def test_alpha_border_negative_control_is_required(self):
        """Отрицательный импорт обязан на самом деле изменить скрытые значения."""
        data=read(self.root/REPORT/"numeric/compatibility/readback.json")
        data["cpu"][3]["rgba"]=[v for row in pixels("negative-alpha") for v in row]
        self.assertTrue(any("negative control failed" in e for e in numeric_errors(data,"compatibility")[0]))

    def test_gamma_negative_and_guard_cannot_be_faked(self):
        """Без разницы между правильной и ошибочной HDR-выборкой либо без отказа фабрики приёмки нет."""
        original=read(self.root/REPORT/"numeric/mobile-hdr/readback.json")
        data=copy.deepcopy(original); data["gpu"][1]["pixels"]=data["gpu"][0]["pixels"]
        self.assertTrue(any("negative control was not visible" in e for e in numeric_errors(data,"mobile-hdr")[0]))
        data=copy.deepcopy(original); data["guard_refused_wrong"]=False
        self.assertTrue(any("factory allowed" in e for e in numeric_errors(data,"mobile-hdr")[0]))

    def test_incomplete_nan_and_wrong_framebuffer(self):
        """Матрица обязана содержать все texel и конечные значения в настоящем формате выбранного режима."""
        original=read(self.root/REPORT/"numeric/mobile-hdr/readback.json")
        for change in [lambda d:d["gpu"][0]["pixels"].pop(),lambda d:d["gpu"][0]["pixels"][0].__setitem__(0,float("nan")),lambda d:d["gpu"][0].__setitem__("format",5),lambda d:d.__setitem__("requested_hdr",False)]:
            data=copy.deepcopy(original); change(data); self.assertTrue(numeric_errors(data,"mobile-hdr")[0])

    def test_changed_mask_even_with_new_checksum(self):
        """Изменённый тестовый PNG не принимается после простой перезаписи его контрольной суммы."""
        path=self.root/REPORT/"numeric/depth.png"
        with Image.open(path) as source: image=source.copy()
        image.putpixel((0,0),(255,0,0,0)); image.save(path)
        proof_path=self.root/REPORT/"numeric-proof.json"; proof=read(proof_path); proof["files"]["depth.png"]=digest(path); write(proof_path,proof)
        self.assertTrue(any("fixture pixels differ" in e for e in proof_errors(self.root)))

    def test_changed_native_pixel_and_full_room_rgb(self):
        """Полностью непрозрачные кадры сравниваются по RGB, а не только по неизменной альфе."""
        path=self.root/REPORT/"after/room.png"
        with Image.open(path) as source: image=source.copy()
        image.putpixel((500,400),(255,0,0,255)); image.save(path)
        room_path=self.root/REPORT/"room-comparison.json"; room=read(room_path); room["after_sha256"]=digest(path); write(room_path,room)
        self.assertTrue(any("every RGBA pixel" in e for e in proof_errors(self.root)))

    def test_shader_provenance_and_room_state_are_locked(self):
        """Смена фабрики или игрового состояния делает старую приёмку явно устаревшей."""
        catalog=self.root/"scripts/systems/visual_resource_catalog.gd"
        catalog.write_text(catalog.read_text()+"\n# future unrelated catalogue change\n")
        self.assertEqual(proof_errors(self.root),[],"historical room proof does not freeze future catalogue implementations")
        (self.root/HELPER).write_text((self.root/HELPER).read_text()+"\n# changed\n")
        self.assertTrue(any("proof is stale" in e for e in proof_errors(self.root)))
        state_path=self.root/REPORT/"after/capture.json"; state=read(state_path); state["minutes"]+=1; write(state_path,state)
        self.assertTrue(any("configuration/state differs" in e for e in proof_errors(self.root)))


if __name__=="__main__": unittest.main()
