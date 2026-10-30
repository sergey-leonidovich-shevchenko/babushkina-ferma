"""Preserve the first capture and store actual JPEG bytes without transcoding."""
import json
from pathlib import Path
import shutil
from PIL import Image

R=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm/docs/reports/refactor-03/launch-boundary-review')
shutil.copy2('/private/tmp/refactor03-browser381-retake.json',R/'baseline/retake-header-probe.json')
for name in ['desktop-attempt01','mobile','task']:
    source=R/('browser-'+name+'.png');assert Image.open(source).format=='JPEG'
    source.rename(R/('browser-'+name+'.jpg'))
# The duplicate first desktop is preserved as attempt01; replace only its canonical report name.
assert (R/'browser-desktop.png').read_bytes()==(R/'browser-desktop-attempt01.jpg').read_bytes()
(R/'browser-desktop.png').unlink()
shutil.copy2('/private/tmp/refactor03-browser381-desktop-retake.png',R/'browser-desktop.jpg')
assert Image.open(R/'browser-desktop.jpg').size==(1280,900)
retake=json.loads(Path('/private/tmp/refactor03-browser381-retake.json').read_text())
retake['invalid_PNG_header_probe']=retake.pop('PNG')
retake['accepted_image']={'format':'JPEG','width':1280,'height':900,'transcoded':False}
(R/'browser-retake.json').write_text(json.dumps(retake,indent=2)+'\n')
cleanup=json.loads((R/'browser-cleanup.json').read_text())
cleanup['retake']={'own_server_port':4193,'own_server_PID':80974,'own_server_exit':143,
    'own_tab_closed':'28','viewport_reset':True,'user4175_untouched':True}
(R/'browser-cleanup.json').write_text(json.dumps(cleanup,indent=2)+'\n')
(R/'seal-attempt01.json').write_text(json.dumps({'exit':1,'stage':'report image dimensions',
    'actual_first_desktop':[1024,720],'expected_CSS_viewport':[1280,900],
    'reason':'capture retained previous compositor surface before resize settled',
    'fix':'retake after a separate observation; JPEG signature/size read with Pillow; bytes not edited',
    'product_source_changed':False,'full_gates_changed':False},indent=2)+'\n')
with (R/'README.md').open('a') as stream:
    stream.write('\nSeal-attempt01 остановился на размере первого desktop capture1024×720 при уже наблюдаемом DOM1280×900. Исходный снимок сохранён как browser-desktop-attempt01.jpg. Повтор после отдельного наблюдения дал точные1280×900; JPEG API сохранены с расширением .jpg без перекодирования. Ошибочный пробный разбор JPEG как PNG не используется: действительные формат/размеры прочитаны Pillow. Вторая собственная вкладка28 и сервер4193/PID80974 закрыты, exit143. Код/JSON вход Wiki и результаты полных gates не менялись.\n')
shutil.copy2(__file__,R/'record-browser-retake.py')
print(json.dumps({'desktop':[1280,900],'mobile':[390,844],'image_format':'JPEG','transcoded':False,'original_capture_preserved':True}))
