# REFACTOR-03 — доработка P2 producer внешнего стенда

Основание: CHANGES REQUESTED review5676955759 и решение Team Lead для PR21/head48ac944b5bda5a5183b3678a7a8329ed49b8f28c.365 не принят; main/baseD609,03in_progress/PRdraft/06blocked. Доработка остаётся в текущей03; после полного закрытия задачи — остановка пользователя, без новых задач и графики.

Producer ошибочно применил current_source к адресу записи внешнего проекта. Он создал только `target/tools`, затем попытался записать probe в `target/tools/assets/migration`; project/case/draft не успели появиться. Даже создание canonical parents не сохраняет протокол `res://tools/migration_capture.gd`.

Сначала сохранить принятый source/raw и независимые receipts, воспроизвести отказ настоящим create. Вернуть прежний адрес записи collector внутри внешнего проекта; читать его реальные неизменные байты из нового соседнего файла. Не менять closure, фазовую логику, probe, runtime/assets, прежние reports/pins/UID и методы proof-проверок.

Добавить отдельный regression suite с настоящими live/Git create, проверкой probe/project/case/draft и пяти фаз, существующих/внутренних целей, неизвестной фазы и чужого GIT-контекста. Существующие proof-тесты оставлять: они проверяют readers самостоятельно собранных копий и не заменяют producer. Выполнить настоящий свежий Godot import/parse/headless collector по пяти фазам отдельного внешнего проекта, отрицательные output/profile-контроли; без новой GPU/FPS-приёмки и без переписи старой native кампании.

Новая версия366, отдельные raw red/green/profile и полные architecture/Game/normal/F10/Wiki, scope/документация/каталог. Затем отдельный обычный commit/push в том же PR21, точный новый SHA Tech Lead для повторного ревью. Отказ48ac не снимается авторским локальным PASS; merge запрещён до независимой приёмки всей03.
