"""Собирает подписанное сравнение нативных кадров без изменения рисунка спрайтов."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent
canvas = Image.new("RGB", (2384, 1528), "#111720")
draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 28)
small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
draw.text((24, 22), "Пещера с боссом · проектные варианты на текущих спрайтах", font=font, fill="#dbe6ee")
for column, variant in enumerate(("a", "b")):
    x = 24 + column * 1180
    title = "A · Сердце глубин — рекомендую" if variant == "a" else "B · Затопленное святилище"
    draw.text((x, 76), title, font=font, fill="#add4e2")
    for row, stage in enumerate(("overview", "windup")):
        image = Image.open(root / (variant + "-" + stage + ".png")).convert("RGB")
        image = image.resize((1152, 648), Image.Resampling.LANCZOS)
        canvas.paste(image, (x, 120 + row * 688))
        if row == 0:
            draw.text((x, 776), "Общий план · вход слева, выход на севере", font=small, fill="#a1b6c4")
draw.text((24, 1480), "Нижний ряд — макет первого удара в масштабе игры. Бой ещё не внедрён.", font=small, fill="#a1b6c4")
canvas.save(root / "comparison.png")
