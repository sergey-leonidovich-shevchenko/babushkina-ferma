# Светлый интерфейс B

Пользователь выбрал светлый пергаментный диалог B и попросил распространить его на остальные окна. [Исходные варианты](../../concepts/compact-dialogue-2026-10-14/v1/README.md) сохранены отдельно от игровых ресурсов.

Тема собирается из независимых программных панелей, слотов, рамок, кнопок и текста. Это не одна растянутая картинка. `PaperThemePalette` задаёт светлый фон и тёмный текст; `MoonTheme` и совместимый `UiKitSystem` используют одни роли. Акцентная заливка и цвет акцентной подписи разделены для читаемости. Активный текст имеет контраст не ниже4,5:1 на обычной, вложенной и выбранной поверхности; недоступная кнопка остаётся различимой. Числа героя находятся над заполнением шкал.

## Нативные кадры до и после

Кадры1152×648 получены `tools/paper_theme_capture.gd` из `main.tscn` в отдельном userdata. Для исходного шкафа/сундука, чертежа и улья использованы уже сохранённые нативные кадры предыдущих профильных отчётов. Картинки не обрабатывались после отрисовки; игровые слоты пользователя не читались и не менялись.

| Окно | Было | Светлый B |
|---|---|---|
| Рюкзак | [Кадр](before/inventory.png) | [Кадр](after/inventory.png) |
| Шкаф | [Кадр](before/cabinet.png) | [Кадр](after/cabinet.png) |
| Сундук | [Кадр](before/storage.png) | [Кадр](after/storage.png) |
| Кухня | [Кадр](before/kitchen.png) | [Кадр](after/kitchen.png) |
| Алхимия | [Кадр](before/alchemy.png) | [Кадр](after/alchemy.png) |
| Исследование | [Кадр](before/study.png) | [Кадр](after/study.png) |
| Горн | [Кадр](before/furnace.png) | [Кадр](after/furnace.png) |
| Крафт | [Кадр](before/crafting.png) | [Кадр](after/crafting.png) |
| Лавка | [Кадр](before/shop.png) | [Кадр](after/shop.png) |
| Кузница | [Кадр](before/forge.png) | [Кадр](after/forge.png) |
| Журнал | [Кадр](before/quest-log.png) | [Кадр](after/quest-log.png) |
| Герой и таланты | [Кадр](before/talent-tree.png) | [Кадр](after/talent-tree.png) |
| Карта | [Кадр](before/world-map.png) | [Кадр](after/world-map.png) |
| Календарь | [Кадр](before/calendar.png) | [Кадр](after/calendar.png) |
| Бестиарий | [Кадр](before/bestiary.png) | [Кадр](after/bestiary.png) |
| Рецепты | [Кадр](before/recipes.png) | [Кадр](after/recipes.png) |
| Энциклопедия | [Кадр](before/compendium.png) | [Кадр](after/compendium.png) |
| Создание героя | [Кадр](before/creation.png) | [Кадр](after/creation.png) |
| Диалог | [Кадр](before/dialogue.png) | [Кадр](after/dialogue.png) |
| Длинная реплика120% | [Кадр](before/dialogue-long.png) | [Кадр](after/dialogue-long.png) |
| Чертёж подвала | [Кадр](before/basement.png) | [Кадр](after/basement.png) |
| Размещение в подвале | [Кадр](before/basement-placement.png) | [Кадр](after/basement-placement.png) |
| Улей | [Кадр](before/apiary.png) | [Кадр](after/apiary.png) |
| Контракты | [Кадр](before/contracts.png) | [Кадр](after/contracts.png) |
| Рыбалка | [Кадр](before/fishing.png) | [Кадр](after/fishing.png) |
| Пауза | [Кадр](before/pause.png) | [Кадр](after/pause.png) |
| Настройки | [Кадр](before/settings.png) | [Кадр](after/settings.png) |
| Языки | [Кадр](before/language.png) | [Кадр](after/language.png) |
| Главное меню | [Кадр](before/title.png) | [Кадр](after/title.png) |
| Рюкзак DE120% | [Кадр](before/inventory-de-120.png) | [Кадр](after/inventory-de-120.png) |
| Шкаф DE120% | [Кадр](before/cabinet-de-120.png) | [Кадр](after/cabinet-de-120.png) |
| HUD | [Кадр](before/hud.png) | [Кадр](after/hud.png) |

## Проверки

`PaperThemeSuite` проверяет контраст и общие роли. Профиль `tools/paper_theme_review.gd` дополнительно запускает локализованную геометрию, меню, диалоги, корабль и арену. Профильный результат:490 утверждений,0 отказов. Полный игровой gate выполняется перед коммитом.

Визуальные эталоны обновляются через штатные `--capture-*` профили: `tools/paper_theme_reference_capture.gd` изолирует пользовательские файлы и даёт нативный viewport. Манифест пересчитывается существующим `tools/update_ui_visual_manifest.py`; список эталонов и пороги не ослабляются.

Wiki использует ту же палитру: светлая навигация, карточки, поиск и просмотр анимаций. Дополнительный Node-тест сверяет роли CSS с игрой и контраст подписей. В браузере проверены русский поиск, переход к статье, запуск/пауза и смена направления.

[Главная wiki](wiki.jpg) · [Просмотр анимаций](wiki-animation.jpg).
