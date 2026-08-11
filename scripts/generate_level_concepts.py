from __future__ import annotations

import math
import os
import random
from dataclasses import dataclass
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / 'assets' / 'generated' / 'level_drafts'
OUT_DIR.mkdir(parents=True, exist_ok=True)

WORLD_W, WORLD_H = 2400, 1200
TILE_SIZE = 24

# Используем игровые ассеты относительно корня клонированного проекта.
GRASS = [
    Image.open(ROOT / 'assets/game/tiles/grass.png').convert('RGBA'),
    Image.open(ROOT / 'assets/game/tiles/grass_var_1.png').convert('RGBA'),
    Image.open(ROOT / 'assets/game/tiles/grass_var_2.png').convert('RGBA'),
]
ROAD = Image.open(ROOT / 'assets/game/tiles/road-brick.png').convert('RGBA')
WATER = Image.open(ROOT / 'assets/game/fishing/Water Tile.png').convert('RGBA')
CAVE_FLOOR = Image.open(ROOT / 'assets/game/tiles/cave-floor.png').convert('RGBA')
STONE = Image.open(ROOT / 'assets/game/resources/rock.png').convert('RGBA')
FOREST_TREE = Image.open(ROOT / 'assets/game/environment/forest_tree.png').convert('RGBA')
RED_MUSH = Image.open(ROOT / 'assets/game/environment/red_mushrooms.png').convert('RGBA')
VILLAGE_PROPS = Image.open(ROOT / 'assets/game/environment/village_prop_atlas.png').convert('RGBA')
BUILDINGS = Image.open(ROOT / 'assets/game/buildings/building_atlas.png').convert('RGBA')


def hash01(x: float, y: float, seed: float = 0.0) -> float:
    return abs(math.sin((x * 127.1 + y * 311.7) + seed) * 43758.5453123) % 1.0


def frac(x: float) -> float:
    return x - math.floor(x)


def distance_to_segment(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    (px, py), (ax, ay), (bx, by) = p, a, b
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    vv = vx * vx + vy * vy
    if vv <= 1e-6:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / vv))
    qx, qy = ax + t * vx, ay + t * vy
    return math.hypot(px - qx, py - qy)


def tile_is_water(x: float, y: float, seed_shift: float, river: list[tuple[float, float]], half_width: float) -> bool:
    # meandering river
    # Ищем ближайший сегмент polyline.
    min_d = 10_000.0
    for i in range(len(river) - 1):
        d = distance_to_segment((x, y), river[i], river[i + 1])
        if d < min_d:
            min_d = d
    return min_d < half_width + seed_shift


def point_in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float, margin=0.0) -> bool:
    nx = (x - cx) / (rx + margin)
    ny = (y - cy) / (ry + margin)
    return nx * nx + ny * ny < 1.0


def flood_seed(x: int, y: int, river: list[tuple[float, float]]) -> bool:
    # лёгкая мягкая шумающая маска для вариации
    return hash01(x * 0.23, y * 0.17, 4.2) < 0.38


def draw_textured_rect(canvas: Image.Image, tex: Image.Image, rect: tuple[int, int, int, int], alpha: float = 1.0) -> None:
    x, y, w, h = rect
    if w <= 0 or h <= 0:
        return
    for yy in range(y, y + h, tex.height):
        for xx in range(x, x + w, tex.width):
            cw = min(tex.width, x + w - xx)
            ch = min(tex.height, y + h - yy)
            crop = tex.crop((0, 0, cw, ch)).convert('RGBA')
            if alpha < 0.999:
                a = int(255 * alpha)
                if a < 255:
                    r, g, b, aa = crop.split()
                    aa = aa.point(lambda p: (p * alpha))
                    crop = Image.merge('RGBA', (r, g, b, aa))
            canvas.paste(crop, (xx, yy), crop)


def draw_tiled(canvas: Image.Image, tex: Image.Image, dest: tuple[int, int, int, int], tint: tuple[int, int, int, int] | None = None):
    x0, y0, w, h = dest
    for y in range(y0, y0 + h, tex.height):
        for x in range(x0, x0 + w, tex.width):
            layer = tex
            if tint:
                r, g, b, a = tint
                # apply tint by multiply
                tmp = Image.new('RGBA', tex.size)
                mr = tex.split()
                # rough tint with per-channel multiply for visible texture
                tmp = Image.merge(
                    'RGBA',
                    [
                        Image.eval(mr[0], lambda p, rr=r: int(p * rr / 255)),
                        Image.eval(mr[1], lambda p, gg=g: int(p * gg / 255)),
                        Image.eval(mr[2], lambda p, bb=b: int(p * bb / 255)),
                        mr[3],
                    ],
                )
                layer = tmp
            crop = layer.crop((0, 0, min(tex.width, x0 + w - x), min(tex.height, y0 + h - y)))
            canvas.paste(crop, (x, y), crop)


def color_tint_color(col1, t):
    # t in [0..1]
    r, g, b, a = col1
    return (int(r * t), int(g * t), int(b * t), a)


def collect_components(img: Image.Image, min_size=120) -> list[tuple[int, int, int, int]]:
    rgba = img.split()[3]
    w, h = img.size
    px = img.load()
    alpha = img.split()[3]
    data = alpha.load()
    visited = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if visited[y][x] or data[x, y] == 0:
                continue
            stack = [(x, y)]
            visited[y][x] = True
            minx = maxx = x
            miny = maxy = y
            cnt = 0
            while stack:
                cx, cy = stack.pop()
                cnt += 1
                if cx < minx:
                    minx = cx
                elif cx > maxx:
                    maxx = cx
                if cy < miny:
                    miny = cy
                elif cy > maxy:
                    maxy = cy

                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and data[nx, ny] > 0:
                        visited[ny][nx] = True
                        stack.append((nx, ny))
            area = (maxx - minx + 1) * (maxy - miny + 1)
            if cnt >= min_size:
                comps.append((minx, miny, maxx - minx + 1, maxy - miny + 1, cnt, area))
    comps.sort(key=lambda v: v[4], reverse=True)
    return [(x, y, w, h) for x, y, w, h, _, _ in comps]


building_components = collect_components(BUILDINGS)
prop_components = collect_components(VILLAGE_PROPS)
print('building components:', building_components)
print('prop components:', prop_components)


def crop_component(img: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    x, y, w, h = rect
    return img.crop((x, y, x + w, y + h)).convert('RGBA')


# Взяты из BuildingSystem в world.
building_defs = {
    'cottage': ((330, 950), (300, 300)),
    'shop': ((1050, 370), (300, 300)),
    'guild': ((1450, 370), (330, 310)),
    'forge': ((760, 470), (300, 300)),
    'chapel': ((610, 470), (290, 300)),
}


@dataclass
class Layout:
    name: str
    palette: tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]
    river_amp: float
    farm_push: float
    bridge_x_shift: float
    dusk: bool = False
    frost: bool = False
    bridge_gap: int = 0
    seed: int = 42


def render_layout(cfg: Layout, out_path: Path) -> None:
    rnd = random.Random(cfg.seed)
    canvas = Image.new('RGBA', (WORLD_W, WORLD_H), (255, 255, 255, 255))
    draw = ImageDraw.Draw(canvas)

    grass1, grass2, grass3 = cfg.palette[:3]
    river_center = [
        (0, 640), (260, 665), (520, 635), (800, 665),
        (1080, 690), (1350, 675), (1600, 705), (1840, 665),
        (2140, 645), (2400, 620)
    ]
    # Слегка сдвигаем реку в каждом варианте.
    for i in range(len(river_center)):
        river_center[i] = (river_center[i][0] + cfg.bridge_x_shift, river_center[i][1] + cfg.river_amp * 6.0)

    # Фоновая сетка.
    for row in range(0, WORLD_H, TILE_SIZE):
        for col in range(0, WORLD_W, TILE_SIZE):
            cx = col + TILE_SIZE * 0.5
            cy = row + TILE_SIZE * 0.5

            in_river = tile_is_water(cx, cy, cfg.river_amp, river_center, 36.0 + cfg.bridge_gap)
            in_pond = point_in_ellipse(cx, cy, 1550 - cfg.bridge_x_shift, 965 + cfg.bridge_gap, 185 + cfg.farm_push, 108 + cfg.farm_push // 2)

            in_border = col < 20 or col > WORLD_W - 44 or row < 50 or row > WORLD_H - 44
            in_farm = (490 < cx < 850 and 805 < cy < 1120)
            in_market = (850 < cx < 1650 and 250 < cy < 580)
            in_guild = (1240 < cx < 1670 and 250 < cy < 560)

            v = hash01(col * 0.11, row * 0.17, cfg.seed)
            if in_border:
                tex = STONE
            elif in_river or in_pond:
                draw_textured_rect(canvas, WATER, (col, row, TILE_SIZE, TILE_SIZE), alpha=1.0)
                continue
            elif in_farm:
                # мягкий ухоженный дворик не квадратом.
                if abs((col / TILE_SIZE) - 36) < 8 and abs((row / TILE_SIZE) - 45) < 14:
                    tex = CAVE_FLOOR
                else:
                    tex = GRASS[int((col + row) % 3)]
            elif in_market or in_guild:
                tex = ROAD if (v < 0.7) else GRASS[0]
            else:
                tex = GRASS[int((col * 31 + row * 17 + int(cfg.farm_push)) % 3)]

            if tex is not None:
                if tex == ROAD:
                    draw_textured_rect(canvas, ROAD, (col, row, TILE_SIZE, TILE_SIZE), alpha=0.9)
                else:
                    draw_textured_rect(canvas, tex, (col, row, TILE_SIZE, TILE_SIZE), alpha=1.0)

    # Добавим мягкие лоскуты луга по-пятам, чтобы убрать строгость сетки.
    for _ in range(int(500 + cfg.seed % 7 * 20)):
        x = rnd.randint(40, WORLD_W - 60)
        y = rnd.randint(60, WORLD_H - 80)
        r = rnd.randint(18, 72)
        c = (int(grass2[0] + cfg.river_amp * 8), int(grass2[1] + 4), int(grass2[2] + 2), 128)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=c)

    # Река полупрозрачным цветом.
    for i in range(len(river_center) - 1):
        p0 = river_center[i]
        p1 = river_center[i + 1]
        draw.line((p0[0], p0[1], p1[0], p1[1]), fill=(int(68 + cfg.river_amp * 12), int(130 + cfg.bridge_gap * 2), int(150 + cfg.river_amp * 10), 150), width=80)

    # Перепады и русло.
    for angle_index in range(14):
        x = 40 + angle_index * 172
        y = river_center[min(angle_index // 1, len(river_center) - 1)][1] + rnd.uniform(-24, 24)
        size = rnd.randint(3, 9) + cfg.bridge_gap // 4
        draw.arc((x - 45, y - 22, x + 45, y + 22), start=0, end=180, fill=(90, 150, 170, 180), width=size)

    # Дороги как живая кривая, не прямоугольники.
    routes = [
        [(330, 950), (430, 900), (670, 820), (805, 745), (805, 610), (940, 555), (1200, 515), (1450, 515), (1650, 530)],
        [(670, 1085), (670, 820)],
        [(1050, 515), (1050, 370)],
        [(1450, 515), (1450, 370)],
        [(1200, 515), (930, 420), (650, 350), (390, 315), (180, 280)],
        [(1450, 515), (1650, 530), (1790, 610), (1790, 740), (1990, 695), (2200, 760)],
        [(1790, 740), (1660, 825), (1550, 825)],
        [(1200, 515), (1240, 560)],
    ]

    for road in routes:
        pts = road
        # base dirt stroke
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            dx, dy = x1 - x0, y1 - y0
            length = max(1.0, math.hypot(dx, dy))
            steps = int(length / 12)
            for s in range(steps + 1):
                t = s / max(1, steps)
                rx = x0 + dx * t + rnd.uniform(-3, 3)
                ry = y0 + dy * t + rnd.uniform(-4, 4)
                # тёплый кирпич на дороге
                canvas.paste(ROAD, (int(rx - ROAD.width / 2), int(ry - ROAD.height / 2)), ROAD)
                if s % 4 == 0:
                    # пыль/травяные кромки
                    ox = int(rx + rnd.uniform(-20, 20))
                    oy = int(ry + rnd.uniform(-12, 12))
                    c = (130 + rnd.randint(-20, 20), 112 + rnd.randint(-10, 25), 84 + rnd.randint(-10, 20), 100)
                    draw.ellipse((ox, oy, ox + 5, oy + 5), fill=c)

    # Зонтик центральной площади и гильдии.
    if cfg.name == 'A':
        accent_rect = (820, 250, 820, 380)
        draw.rectangle((850, 370, 1650, 600), fill=(163, 126, 84, 100), outline=(145, 112, 80, 180), width=3)
    elif cfg.name == 'B':
        draw.ellipse((860, 260, 1640, 560), fill=(153, 124, 96, 95), outline=(127, 97, 71, 200), width=3)
    else:
        draw.rounded_rectangle((870, 365, 1648, 602), radius=16, fill=(149, 113, 73, 96), outline=(115, 93, 72, 140), width=3)

    # Дома из atlas.
    building_ids = [0, 1, 2, 4, 5]  # несколько различных.
    for idx, bidx in enumerate(building_ids):
        if bidx >= len(building_components):
            continue
        comp = building_components[bidx]
        sprite = crop_component(BUILDINGS, comp)
        if cfg.name == 'C' and idx == 1:
            # более тёмный акцент для этого варианта
            r, g, b, a = sprite.split()
            sprite = Image.merge('RGBA', [Image.eval(r, lambda p: p - 20), Image.eval(g, lambda p: p - 15), Image.eval(b, lambda p: p - 10), a])

        # Ставим на места ключевых локационных зданий.
        if idx == 0:
            # cottage
            x, y = 330, 950
            sx, sy = 300, 300
        elif idx == 1:
            x, y = 1050, 370
            sx, sy = 300, 300
        elif idx == 2:
            x, y = 1450, 370
            sx, sy = 330, 310
        elif idx == 3:
            x, y = 1710, 470
            sx, sy = 300, 300
        else:
            x, y = 760, 470
            sx, sy = 300, 300

        w = sx
        h = sy
        target_rect = sprite.resize((int(w * 0.95), int(h * 0.94)), Image.Resampling.BILINEAR)
        # Рисуем чуть по центру.
        px = int(x - w * 0.5)
        py = int(y - h + 30)
        canvas.paste(target_rect, (px, py), target_rect)

        # лёгкая тень
        draw.ellipse((px + 12, py + h - 16, px + w - 10, py + h + 10), fill=(30, 28, 28, 60))

    # Добавим несколько пропов и декора как отсылки.
    # Сборка из components props atlas для лавок/знаков/фонарей.
    for i, comp in enumerate(prop_components[:6]):
        sp = crop_component(VILLAGE_PROPS, comp).convert('RGBA')
        scale = 0.22 + 0.12 * (i % 3)
        tw, th = sp.size
        ww = max(16, int(tw * scale))
        hh = max(16, int(th * scale))
        sp = sp.resize((ww, hh), Image.Resampling.BILINEAR)
        px = rnd.randint(200, WORLD_W - ww - 200)
        py = rnd.randint(250, WORLD_H - hh - 260)
        # держим вне воды и ферм
        if tile_is_water(px, py, cfg.river_amp, river_center, 56):
            continue
        canvas.paste(sp, (px, py), sp)

    # Деревья как живой бордюр и лесной акцент.
    tree_sprite = FOREST_TREE.crop((40, 19, 40 + 174, 19 + 217)).convert('RGBA')
    for y0 in range(100, WORLD_H - 80, 86):
        for x0 in range(40, WORLD_W - 120, 150):
            if 650 < x0 < 1800 and 260 < y0 < 820:
                continue
            jitterx = rnd.randint(-20, 20)
            jittery = rnd.randint(-12, 12)
            tx, ty = x0 + jitterx, y0 + jittery
            s = 0.55 + hash01(tx, ty, cfg.seed) * 0.5
            ww = int(tree_sprite.width * s)
            hh = int(tree_sprite.height * s)
            timg = tree_sprite.resize((ww, hh), Image.Resampling.BILINEAR)
            if ty + hh < WORLD_H and tx + ww < WORLD_W and tx > -ww and ty > -hh:
                # не на дорогах
                if distance_to_segment((tx, ty), (330, 950), (1650, 530)) < 80:
                    continue
                canvas.paste(timg, (int(tx), int(ty)), timg)

    # Плотная лесная зона справа
    for i in range(28):
        x = rnd.randint(1700, WORLD_W - 40)
        y = rnd.randint(320, WORLD_H - 250)
        if tile_is_water(x, y, cfg.river_amp, river_center, 68):
            continue
        size = rnd.randint(20, 40)
        mush = RED_MUSH.resize((size, size), Image.Resampling.BILINEAR)
        draw.arc((x, y, x + 50, y + 33), 10, 230, fill=(120 + rnd.randint(-20, 20), 70, 60, 180), width=2)
        canvas.paste(mush, (x, y), mush)

    # Декоративные мосты.
    # Лёгкие деревянные мостики через реку в двух местах.
    bridge1 = ((760, 560), (900, 600))
    bridge2 = ((1760, 580), (1895, 655))
    for bx0, by0, bx1, by1 in [
        (bridge1[0][0], bridge1[0][1], bridge1[1][0], bridge1[1][1]),
        (bridge2[0][0], bridge2[0][1], bridge2[1][0], bridge2[1][1]),
    ]:
        draw.rounded_rectangle((bx0, by0, bx1, by1), 12, fill=(150, 126, 96, 220), outline=(94, 73, 45, 220), width=3)
        for i in range(8):
            yy = by0 + 8 + i * 14
            draw.line((bx0 + 8, yy, bx1 - 8, yy), fill=(128, 95, 66, 175), width=2)

    # Финальный атмосферный слой
    if cfg.dusk:
        overlay = Image.new('RGBA', (WORLD_W, WORLD_H), (40, 25, 52, 90))
        canvas.alpha_composite(overlay)
    if cfg.frost:
        overlay = Image.new('RGBA', (WORLD_W, WORLD_H), (180, 200, 220, 60))
        canvas.alpha_composite(overlay)

    # Заголовок-лейбл локации для теста.
    txt_color = (245, 227, 184, 235)
    if cfg.dusk:
        txt_color = (255, 228, 190, 235)
    # Без шрифтового рендера: рисуем простые прямоугольники как аккуратный баннер.
    banner = Image.new('RGBA', (900, 54), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(banner)
    bdraw.rounded_rectangle((0, 0, 899, 53), radius=12, fill=(50, 41, 30, 170), outline=(235, 198, 125, 220), width=2)
    canvas.paste(banner, (40, 20), banner)

    # Небольшие маркеры мест.
    for i, (sx, sy, tx, ty, clr) in enumerate([
        (850, 370, 1060, 365, (255, 255, 255, 180)),
        (1450, 370, 1160, 500, (255, 255, 255, 180)),
        (330, 950, 1080, 920, (240, 240, 220, 160)),
    ]):
        draw.ellipse((sx - 4, sy - 4, sx + 4, sy + 4), fill=clr)

    # Стихийный эффект
    for i in range(220):
        x = rnd.randint(0, WORLD_W)
        y = rnd.randint(0, WORLD_H)
        a = rnd.randint(8, 24)
        c = (255, 255, 255, rnd.randint(4, 18))
        if tile_is_water(x, y, cfg.river_amp, river_center, 24):
            c = (220, 240, 245, rnd.randint(8, 22))
            draw.point((x, y), fill=c)
        elif rnd.random() < 0.5:
            draw.point((x, y), fill=c)

    # Рамка мира.
    draw.rectangle((0, 0, WORLD_W - 1, WORLD_H - 1), outline=(66, 50, 35, 200), width=2)

    # Подпись
    banner_text = 'Локация: «' + cfg.name + '»'
    # Рисуем текст без шрифта не поддерживаем, оставляем текстовой барьер.
    bdraw = ImageDraw.Draw(canvas)
    bdraw.rectangle((44, 26, 230, 52), fill=(0, 0, 0, 0))

    canvas.save(out_path)


def build_variants() -> None:
    variants = [
        Layout(name='A', palette=((85, 145, 74), (102, 165, 80), (181, 130, 80), (98, 78, 56)), river_amp=0.0, farm_push=0.0, bridge_x_shift=0.0, dusk=False, frost=False, seed=7),
        Layout(name='B', palette=((90, 140, 84), (114, 170, 86), (186, 128, 90), (107, 90, 62)), river_amp=1.2, farm_push=10.0, bridge_x_shift=-14.0, dusk=True, frost=False, seed=17),
        Layout(name='C', palette=((82, 132, 90), (96, 159, 89), (174, 119, 80), (104, 88, 61)), river_amp=2.2, farm_push=16.0, bridge_x_shift=24.0, dusk=False, frost=False, seed=31),
        Layout(name='D', palette=((99, 154, 92), (118, 188, 97), (181, 126, 86), (101, 82, 58)), river_amp=1.0, farm_push=6.0, bridge_x_shift=-28.0, dusk=False, frost=True, seed=91),
    ]
    for v in variants:
        out = OUT_DIR / f'level_first_step_concept_{v.name}.png'
        render_layout(v, out)
        print(out)


if __name__ == '__main__':
    build_variants()
