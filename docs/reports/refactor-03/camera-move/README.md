# REFACTOR-03 — перенос camera40, 0.0.374

Принятая промежуточная база — `d2ff4bde558196f808bef0486db1c0aaa0302ab9`: SOURCE PASS review5692493268, Team Lead и фактически завершившийся CI8/8. Новая версия требует собственного exact-head ревью/CI. Вся03 остаётся in_progress/PR21draft до полного бюджета≤30 и финальной приёмки.

Переносятся40 source (22Python,17GDScript,1Swift),2 tracked UID и15 ignored UID. Root285→245. Две общие строки принятой карты — `visual_camera_points.gd` и `encode_coordinate_video.swift` — отложены до связанных пакетов их потребителей; они и UID points побайтно прежние. Это временный порядок пакетов, а не их окончательное исключение или уменьшение объёма03. Исходная карта не переписана. Новый closed source map содержит прежние91 назначения и ровно42 camera назначения (40source+2UID).

Живые Python imports, GDScript preload и команды идут по canonical путям. Свежий collector хеширует и копирует canonical inputs, сохраняя прежние logical SOURCES/LEGACY_SOURCES/TOOLS и архивные назначения. Ранее frozen descriptors не переподписаны. Timing native URI привязан к полному known source_paths; отсутствие карты означает только прежний URI, полная карта — новый URI. Unknown/partial/mismatched metadata отклоняется; метрики и бюджеты прежние.

Один новый test SHA `6b3388d8bfa7dd4c83d74d91c50726edd3e9d0362d19d55facf9d0ea932a090e`: red6fail/1error → green3/0. Проверяются настоящая свежая сборка с missing canonical и stale old файлом, явный fake-child (не запускается в исправленной ветке), реальные old timing archives и их reader/metadata/launch checks. Прежние12 producer-context тестов и их assertions сохранены с адаптацией только input paths. Resume-фикстуры зеркалируют прежние runtime bytes в отдельные canonical current inputs, сохраняя сам proof archive.

Реальные before/after включают22 CLI,17 compile-only Godot и1 AVFoundation decoder.11 исторических CLI stdout совпали побайтно,9 прежних negative suites и12 context-сценариев прошли.16 кадров из прежних MP4 заново декодированы: размеры/RGBA/PNG SHA и contact sheet побайтно/попиксельно равны. Input MP4 SHA прежние. Check-only не создаёт Game/сцену; offline decode не является новым игровым native/GPU/FPS допуском. Полный Game/normal/F10 проверяется отдельно обязательным TESTING.

Первый after-профиль сохранён: after-015.txt выявил старое физическое чтение декодера в `test_decoded_video_review_provenance`. Адрес декодера исправлен; его bytes прежние. Старый plot SHA закреплён через проверенный Git blob `d609ab4fa6d82d6d013265183f018b8836abf7cc:tools/pose_video_strip.py` (SHA89d6198c…), без live fallback. Старый source.json и assertions не переписаны. Авторитетный повтор — after-profile.json / after-attempt02-*.

Сохранены также подготовительные отказы: неполная исходная схема UID не содержала sha256; в неё добавлены фактические bytes/mode, частичная ведомость проверена по принятому Git. Первая частная версия layout-test затем получила устойчивую source anchor и resolve временной папки до повторного red того же финального source. Эти исправления стенда происходили до правки продукта; raw и прежние версии сохранены.

Полные gates/Wiki/браузер обязательны перед commit/push, затем Tech Lead→Team Lead. Task-Complete/полного merge здесь нет. Отдельный план07, остальные карточки, исходные raw/планы/контракты/UID и пользовательская Wiki4175 сохраняются.
