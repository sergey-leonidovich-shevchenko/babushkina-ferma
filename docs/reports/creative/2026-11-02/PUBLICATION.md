# Публикация IDEA-REVIEW-20261102

[Draft PR](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/40) base main. Первый проверенный head `b754cde4c86f0ef06a8184225d6c3a89e3ecf563`, base `ebf2779fdd721676bb05614c7e2cfd172349d8b3`. Карточка in_progress до независимого exact-head ревью, успешных обязательных проверок и решения Team Lead. Автор main не вливает.

[Первый checkpoint](checkpoint-1/gates.json): metadata406, architecture 113/1505, Game 53549/0, normal/F10 90/90, Wiki 151/0. Frozen SHA сверяются с первым commit. Новый полный неизменённый hook создаст отдельный publish-1/gates.json для metadata407 только после успеха. Final SHA будет закреплён в PR/Tech Lead после commit/push, не как циклический собственный SHA.

[Протокол](publication.json). Capture-only helpers вызывают настоящий pre-commit без пропуска quality, architecture или Game. Четыре lossless receipts каждого epoch добавляются после успеха. Forwarder сохраняет engine/argv, lock изолирует только cooperating save fixtures. Исторические источники/отчёты других PR сохранены.

**Нерешённый обязательный performance gate.** [Сравнение](performance-comparison.json): три полные серии по6 запусков завершены с exit1/budget=false, в том числе отдельный кандидат406 и чистая принятая405. Runtime code одинаков, кроме metadata. Причина не изолирована, пороги/engine не менялись ради зелёного результата. Это не новая native FPS приёмка и не авторское разрешение игнорировать отказ. Draft передаётся Tech Lead/Team Lead для решения и адресного владельца проблемы; игровое исправление Creative не пишет.

[Actual producer self-review](quality-self-review.json) — main405/14 команд с настоящим linked worktree и чужими Git/environment. [Smoke](smoke-first.log.gz) —180. [16 браузерных проверок](browser/verified/manifest.json) относятся к406: десять статей, шесть оценок, настоящие зависимости, поиск/Tab,390px и консоль0. После публикационных изменений отдельно проверяются обзор/редакционная карточка/metadata407, неизменные статьи повторно не объявляются новым полным browser epoch.

10 идей / 10 эпиков / 52 будущие карточки,19 взрослых /35 узлов /105 ответов /60 будущих F только написаны. Математические свидетели334 на10/11 сдвигов — проверка ограниченного дизайна, не игровой сценарий. Game scripts/scenes/assets/tools/tests/hooks неизменны, project.godot только metadata. Новые механики ждут VMAP-003 и своих зависимостей.
