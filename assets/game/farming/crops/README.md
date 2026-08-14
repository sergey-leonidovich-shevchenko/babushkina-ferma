# Производственные атласы культур

Все игровые кадры имеют прозрачность, ячейку `64×64`, нижнюю центральную опору и пять стадий слева направо. Мастер-файлы хранятся в `source/`, нормализованные игровые атласы — в `atlases/`.

| Атлас | Ряды сверху вниз |
|---|---|
| `annual_a.png` | морковь, томат, капуста, пшеница |
| `annual_b.png` | кукуруза, картофель, лук, тыква |
| `annual_c.png` | свёкла, перец, огурец, подсолнух |
| `annual_d.png` | хлопок, дыня |
| `strawberry_seasons.png` | весна, лето, осень, зима |
| `herbs_seasons.png` | весна, лето, осень, зима |

Клубника и лечебные травы после сбора остаются на грядке и переходят к повторному циклу. Зимой их отдельные кадры показывают покой, а рост останавливается. Старые грядки без `crop_kind` мигрируют в морковь.

## Точные ImageGen-промпты

Режим: встроенная генерация изображений, `stylized-concept`.

### Морковь, томат, капуста, пшеница

```text
Use case: stylized-concept
Asset type: production crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 4-row atlas showing five clearly progressive growth stages for four field crops.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and four equal rows. Each row is one crop; columns left-to-right are stage 1 freshly planted seed mound/tiny sprout, stage 2 small seedling, stage 3 leafy juvenile, stage 4 flowering or forming produce, stage 5 fully harvest-ready plant with recognizable produce. Every plant is isolated, centered, bottom-anchored, same ground baseline, generous identical padding, and cannot cross cell edges.
Rows top-to-bottom: carrot, tomato, cabbage, wheat. Carrot ends with orange roots visibly cresting the soil; tomato ends with red tomatoes; cabbage ends as a full green head; wheat ends with golden grain heads.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects, or duplicate plants. Do not use #FF00FF inside any plant. Technical sprite sheet with exactly 20 nonempty cells.
```

### Кукуруза, картофель, лук, тыква

```text
Use case: stylized-concept
Asset type: production crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 4-row atlas showing five clearly progressive growth stages for four field crops.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and four equal rows. Each row is one crop; columns left-to-right are stage 1 freshly planted seed mound/tiny sprout, stage 2 small seedling, stage 3 leafy juvenile, stage 4 flowering or forming produce, stage 5 fully harvest-ready plant with recognizable produce. Every plant is isolated, centered, bottom-anchored, same ground baseline, generous identical padding, and cannot cross cell edges.
Rows top-to-bottom: corn, potato, onion, pumpkin. Corn ends with tall stalks and yellow cobs; potato ends with lush foliage and several brown tubers cresting the soil; onion ends with strong green tops and golden bulbs cresting soil; pumpkin ends with a compact vine and orange pumpkins.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects, or duplicate plants. Do not use #FF00FF inside any plant. Technical sprite sheet with exactly 20 nonempty cells.
```

### Свёкла, перец, огурец, подсолнух

```text
Use case: stylized-concept
Asset type: production crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 4-row atlas showing five clearly progressive growth stages for four field crops.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and four equal rows. Each row is one crop; columns left-to-right are stage 1 freshly planted seed mound/tiny sprout, stage 2 small seedling, stage 3 leafy juvenile, stage 4 flowering or forming produce, stage 5 fully harvest-ready plant with recognizable produce. Every plant is isolated, centered, bottom-anchored, same ground baseline, generous identical padding, and cannot cross cell edges.
Rows top-to-bottom: beetroot, sweet red pepper, cucumber, sunflower. Beetroot ends with purple-red roots cresting soil; pepper ends with bright red peppers; cucumber ends as a compact vine with green cucumbers and yellow blossoms; sunflower ends with one large golden flower head and mature seed disk.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects, or duplicate plants. Do not use #FF00FF inside any plant. Technical sprite sheet with exactly 20 nonempty cells.
```

### Хлопок и дыня

```text
Use case: stylized-concept
Asset type: production crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 2-row atlas showing five clearly progressive growth stages for two field crops.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and two equal rows. Each row is one crop; columns left-to-right are stage 1 freshly planted seed mound/tiny sprout, stage 2 small seedling, stage 3 leafy juvenile, stage 4 flowering or forming produce, stage 5 fully harvest-ready plant with recognizable produce. Every plant is isolated, centered, bottom-anchored, same ground baseline, generous identical padding, and cannot cross cell edges.
Rows top-to-bottom: cotton, golden melon. Cotton ends with multiple fluffy white cotton bolls; melon ends with compact vines and ripe round golden-yellow melons, clearly different from watermelon.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects, or duplicate plants. Do not use #FF00FF inside any plant. Technical sprite sheet with exactly 10 nonempty cells.
```

### Сезонная клубника

```text
Use case: stylized-concept
Asset type: production seasonal crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 4-row atlas of one perennial strawberry plant, with five growth stages in every season.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and four equal rows. Columns left-to-right are stage 1 planted mound/tiny crown, stage 2 small seedling, stage 3 leafy juvenile, stage 4 flowering/forming fruit, stage 5 harvest-ready or seasonally dormant adult. Every plant isolated, centered, bottom-anchored, same ground baseline, identical padding, cannot cross cell edges.
Rows top-to-bottom: spring, summer, autumn, winter. Spring has fresh pale leaves and white blossoms, with only stage 5 showing a few early red berries. Summer is lush dark green and stage 5 has many ripe red strawberries. Autumn foliage shifts toward muted gold and burgundy with a smaller late harvest. Winter shows the same persistent crown dormant under a little clean snow/frost; it remains recognizable as a strawberry plant but has no berries or flowers in any winter cell.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects. Do not use #FF00FF inside the plant. Technical sprite sheet with exactly 20 nonempty cells.
```

### Сезонные лечебные травы

```text
Use case: stylized-concept
Asset type: production seasonal crop growth sprite atlas for the 32-bit-style pixel-art farming RPG “Бабушкина ферма”
Primary request: draw an exact 5-column by 4-row atlas of one perennial medicinal herb patch, with five growth stages in every season.
Scene/backdrop: perfectly flat uniform chroma-key magenta #FF00FF, with no texture, shadows, grid, or lighting variation outside the plants.
Style/medium: polished warm crisp 32-bit-era pixel art, readable when reduced to a 48×48 game tile, matching a lush fairy-tale farm. Dark green-brown pixel outlines, controlled highlights, no photorealism.
Composition: exactly five equal columns and four equal rows. Columns left-to-right are stage 1 planted mound/tiny shoots, stage 2 small herbs, stage 3 leafy juvenile patch, stage 4 budding/flowering patch, stage 5 harvest-ready adult patch. Every patch isolated, centered, bottom-anchored, same ground baseline, identical padding, cannot cross cell edges.
Subject: a recognizable cultivated blend of chamomile, lavender and mint, kept compact as one crop tile rather than a bouquet.
Rows top-to-bottom: spring, summer, autumn, winter. Spring has tender pale mint leaves and small chamomile buds; summer is lush green with white chamomile and purple lavender flowers; autumn has muted sage, amber and burgundy leaves with dried seed heads; winter remains a dormant perennial root crown with short brown stems and clean frost/snow, no flowers.
Constraints: no text, letters, numbers, labels, UI, grid lines, borders, pots, bags, tools, people, watermark, logo, cast shadow, background objects. Do not use #FF00FF inside plants. Technical sprite sheet with exactly 20 nonempty cells.
```
