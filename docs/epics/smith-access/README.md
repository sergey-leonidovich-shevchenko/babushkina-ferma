# SMITH — Городские кузницы и право работать у мастера

Прямое поручение владельца 19 ноября 2026. Это согласованные задачи, не предложения IDEA. Игровая реализация после VMAP-003; подготовка не объявляет механику работающей.

[Общий игровой договор](../smith-access/DESIGN.md) · [Квесты](../smith-stories/QUESTS.md) · [Канонические карточки](backlog.json) · [Статья Wiki](../../../wiki/articles/blacksmith-services.md).

| Задача | Результат | Статус |
|---|---|---|
| [SMITH-00](#/development/tasks/smith-access--SMITH-00) | Поставить кузницы, заточку, заказы и личные истории мастеров | done |
| [SMITH-01](#/development/tasks/smith-access--SMITH-01) | Задать паспорта кузниц, мастеров и доступных операций | blocked |
| [SMITH-02](#/development/tasks/smith-access--SMITH-02) | Перенести кузнечные свойства на конкретный экземпляр | blocked |
| [SMITH-03](#/development/tasks/smith-access--SMITH-03) | Подключить платный доступ и личное разрешение | blocked |
| [SMITH-04](#/development/tasks/smith-access--SMITH-04) | Свести навык игрока и постоянное улучшение | blocked |
| [SMITH-05](#/development/tasks/smith-access--SMITH-05) | Открывать домашнюю кузницу позднее по освоению ремесла | blocked |
| [SMITH-06](#/development/tasks/smith-access--SMITH-06) | Принять полный путь кузнечного ремесла | blocked |

## Приёмка постановки

SMITH-00 принята 20 ноября 2026 через [PR №76](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/76): head `b19d0508b6819199528f6e52e00e4b2899f9f3a8`, [независимое APPROVED](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/76#pullrequestreview-5984244824), решение Team Lead и обычный merge `4ef296745c99474b56fd3ddef0ab6ddfaf62e0ee`. Дерево `e0c80d8544da206232e188d2f8ebd9e073ce8aa6` совпало с одобренным.

Приняты четыре эпика, подробный договор и три цепочки кузнечных квестов. Все 22 задачи реализации остаются `blocked` за VMAP-003 и полными предметными зависимостями. Постановка не меняет состав демо и не означает готовность кузниц, заточки, заказов или новых историй в игре.

Проверки принятого head: Wiki 167/167, каталог 177 эпиков/2091 задача без циклов, сохранность прежних 173 эпиков/2068 задач и пользовательского планирования; независимые Node planning 15/15. Полный локальный hook: quality/architecture PASS, Game 53693/0, normal/F10 по 90/0. [CI](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/76/checks) — 8/8: в обоих основных прогонах Game 53711/0, normal/F10 по 90/0, smoke 180 и по шесть performance-серий PASS.

Браузером проверены поиск, четыре эпика, зависимости и настоящий переход PR №76 из активной карточки; при 390 CSS px переполнения нет. Оба замечания к навигации закрыты независимым ревью. После merge документы [DESIGN](DESIGN.md) и [QUESTS](../smith-stories/QUESTS.md) доступны в принятой `main`; исходные неудачные проверки сохранены в истории PR.
