"""Воспроизводит измеренные AtlasTexture без изменения пикселей утверждённых атласов."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
REGIONS = ROOT / 'docs/design/kitchen-station-2026-10-13/atlas-regions.json'


# Перезаписывает только метаданные текстур; выбранные прозрачные изображения остаются нетронутыми.
def main():
    for name, rectangle in json.loads(REGIONS.read_text()).items():
        atlas = 'station_atlas_a.png' if name.startswith('kitchen_') else ('fire_atlas_a.png' if name.startswith('fire_') else 'food_atlas_a.png')
        resource = ('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                    f'[ext_resource type="Texture2D" path="res://assets/game/kitchen/{atlas}" id="1"]\n\n'
                    '[resource]\natlas = ExtResource("1")\n'
                    f'region = Rect2({", ".join(map(str, rectangle))})\nfilter_clip = true\n')
        (ROOT / 'assets/game/kitchen' / (name + '.tres')).write_text(resource)
    print('KITCHEN ATLAS: 24 measured regions written; source pixels unchanged')


if __name__ == '__main__':
    main()
