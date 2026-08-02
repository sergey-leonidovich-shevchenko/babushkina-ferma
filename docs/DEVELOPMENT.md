# Разработка

## Требования

- macOS, Linux или Windows;
- Godot 4.7.1;
- Git;
- Python 3 для проверки документации и воспроизводимой генерации аудиоресурсов.

На macOS совместимая сборка Godot уже может находиться в `tools/Godot.app`. В CI бинарник 4.7.1 загружается явно, поэтому локальная и серверная среды используют одну версию движка.

## Запуск проекта

Из редактора откройте `project.godot` и запустите `main.tscn`. Из терминала на macOS:

```bash
tools/Godot.app/Contents/MacOS/Godot --path .
```

Специальные режимы помогают проверять интерфейс без ручного прохождения стартовых экранов:

```bash
# Титульный экран
tools/Godot.app/Contents/MacOS/Godot --path . -- --title-preview

# Заполненный рюкзак
tools/Godot.app/Contents/MacOS/Godot --path . -- --inventory-preview

# Деревенские здания без стартовых экранов
tools/Godot.app/Contents/MacOS/Godot --path . -- --buildings-preview

# Тюрьма с тремя кандидатами и лидерством 2
tools/Godot.app/Contents/MacOS/Godot --path . -- --companions-preview

# Витрина пяти уровней врагов, статичных угроз и облика героя 20 уровня
tools/Godot.app/Contents/MacOS/Godot --path . -- --enemy-levels-preview

# Установленный домашний сундук с заполненными колонками
tools/Godot.app/Contents/MacOS/Godot --path . -- --storage-preview

# Окно улучшений у наковальни кузницы
tools/Godot.app/Contents/MacOS/Godot --path . -- --forge-preview

# Три ежедневных заказа и прогресс репутации гильдии
tools/Godot.app/Contents/MacOS/Godot --path . -- --contracts-preview

# Журнал основной истории и побочных заданий
tools/Godot.app/Contents/MacOS/Godot --path . -- --story-preview

# Меню паузы поверх тестового мира
tools/Godot.app/Contents/MacOS/Godot --path . -- --pause-preview

# Страница пользовательских настроек
tools/Godot.app/Contents/MacOS/Godot --path . -- --settings-preview

# Автоматическое движение для benchmark
tools/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 --quit-after 480 --print-fps -- --autoplay

# Финальная встреча приключения Лунной поляны
tools/Godot.app/Contents/MacOS/Godot --path . -- --moon-glade-preview
```

## Обязательная проверка

Перед каждым коммитом выполните:

```bash
tools/check_architecture.sh
./run_tests.sh
```

Первая команда контролирует размеры слоёв, утечки отрисовки в фасад, пробельные ошибки, обязательные документы и локальные Markdown-ссылки. Вторая импортирует ресурсы в headless-редакторе и запускает все GDScript-наборы. Успех подтверждается строкой `TESTS: 1327 passed, 0 failed`.

Git hook `pre-commit` повторяет quality gate, а `post-commit` отправляет успешный коммит в GitHub. GitHub Actions запускает те же проверки на push и pull request.

## Как добавить игровую механику

1. Определите единственного владельца правил в `scripts/systems` или создайте новую узкую систему.
2. Храните изменяемые данные в подходящей модели `scripts/state`, а статический контент — в data-driven каталоге.
3. Подключите операцию через `game.gd` и `game_context.gd`, не перенося правила в обработчик клавиш или renderer.
4. Добавьте автотест в тематический suite. Он должен описывать сценарий, исходное состояние и ожидаемый результат.
5. Добавьте шаг во внутриигровое обучение и [ручной QA-маршрут](../QA_CHECKLIST.md).
6. Обновите [руководство игрока](GAME_GUIDE.md), если изменилось видимое поведение.
7. Выполните quality gate и, для графических изменений, визуальную проверку в окне игры.

## Контракты кода

- Все методы GDScript имеют непосредственно над объявлением русский комментарий `##`.
- Тестовый метод имеет три строки: `Сценарий`, `Исходное состояние`, `Ожидаемый результат`.
- Система не читает ввод и не рисует; renderer не меняет игровое состояние.
- Предмет регистрируется один раз в `InventorySystem.ITEM_DATA`; другие системы используют его идентификатор.
- Изменение формата сохранения требует новой версии, миграции и теста повреждённых данных.
- Новый suite не превышает 350 исполняемых строк; ограничения фасада и renderer проверяются автоматически.

Подробные владельцы ответственностей и поток кадра описаны в [ARCHITECTURE.md](../ARCHITECTURE.md).

## Аудиоресурсы

Саундтрек и сигналы генерируются без сторонних семплов:

```bash
python3 tools/generate_audio_assets.py
```

После регенерации запустите тесты и вручную проверьте громкость, зацикливание и смену музыки между локациями.

## Производительность

Эталонный замер ограничен 60 FPS и длится 480 кадров. Запускайте его после изменений обновления кадра, навигации, отрисовки, анимации или большого объёма контента. Результат и условия заносите в [PERFORMANCE.md](../PERFORMANCE.md).

Для прямого визуального просмотра новых NPC, дыхания в покое и движения напарников используйте `tools/Godot.app/Contents/MacOS/Godot --path . -- --animation-preview`.

[К архитектуре](../ARCHITECTURE.md) · [К документации](README.md)
