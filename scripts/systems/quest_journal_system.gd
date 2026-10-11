extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const PAGE_SIZE := 3
const PREV := Rect2(278,582,44,36)
const NEXT := Rect2(1074,582,44,36)

## Собирает журнал из сохранённых состояний миссий и глав, сохраняя завершённые поручения после сдачи ресурсов.
static func records(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var chapter: Dictionary = game.FirstChapterSystem.state(game)
	result.append({"id":"chapter_one","group":"story","status":"completed" if chapter.completed else "active","title":game.FirstChapterSystem.word(game,"title"),"description":game.FirstChapterSystem.objective(game),"progress":"%d / %d"%[chapter.stage,game.FirstChapterSystem.MILESTONES.size()],"ratio":float(chapter.stage)/game.FirstChapterSystem.MILESTONES.size()})
	if game.quest_active or game.quest_complete:
		result.append({"id":"grandmother","group":"side","status":"completed" if game.quest_complete else "active","title":game.LocaleSystem.ui("hud_grandmother_quest"),"description":game.LocaleSystem.ui("hud_carrot_progress",[10 if game.quest_complete else mini(game.carrots,10),10]),"progress":"10 / 10" if game.quest_complete else "%d / 10"%mini(game.carrots,10),"ratio":1.0 if game.quest_complete else float(mini(game.carrots,10))/10.0})
	for mission_id in game.QuestSystem.ordered_mission_ids(game):
		var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
		var status: String = game.QuestSystem.mission_state(game,mission_id)
		var count := mini(game.inventory_item_count(String(mission.item)),int(mission.count))
		result.append({"id":mission_id,"group":"story" if game.QuestSystem.is_story_mission(mission_id) else "side","status":status,"title":mission.title,"description":mission.description,"progress":game.QuestSystem.objective_text(game,mission_id),"ratio":1.0 if status=="completed" else float(count)/maxi(1,int(mission.count)),"reward":"%d XP · %d ●"%[mission.xp,mission.coins]})
	var campaign: Dictionary = game.state.world.castle_campaign
	if game.CastleCampaignSystem.available(game) or campaign.completed:
		result.append({"id":"castle_campaign","group":"story","status":"completed" if campaign.completed else "active","title":game.LocaleSystem.ui("hud_story_objective"),"description":game.CastleCampaignSystem.objective(game),"progress":"%d / 5"%mini(5,int(campaign.stage)),"ratio":clampf(float(campaign.stage)/5,0,1)})
	return result

## Возвращает выбранную сюжетную группу и статус; завершённые записи никогда не превращаются обратно в активные.
static func filtered(game: Node) -> Array[Dictionary]:
	var group := String(game.get_meta("journal_group","story"))
	var status := String(game.get_meta("journal_status","active"))
	var result: Array[Dictionary] = []
	for record in records(game):
		if record.group==group and (status=="all" or record.status==status): result.append(record)
	return result

## Возвращает количество страниц текущей группы, включая пустое состояние.
static func page_count(game: Node) -> int:
	return maxi(1,ceili(float(filtered(game).size())/PAGE_SIZE))

## Возвращает области боковой группы и верхнего фильтра для всех устройств ввода.
static func group_rect(index: int) -> Rect2:
	return Rect2(28,139+index*58,216,44)

## Возвращает область одного фильтра по статусу задания.
static func status_rect(index: int) -> Rect2:
	return Rect2(278+index*162,95,152,32)

## Рисует полноэкранный журнал с отдельным сюжетом, поручениями и архивом выполненных заданий.
static func draw(game: Node) -> void:
	game.draw_rect(Rect2(0,0,1152,648),MoonStyle.BACKGROUND)
	MoonStyle.title(game,Rect2(28,95,216,28),game.LocaleSystem.ui("quest_log"),22)
	for index in 2:
		var group := "story" if index==0 else "side"
		MoonStyle.button(game,group_rect(index),MoonStyle.word(game,group),game.get_meta("journal_group","story")==group)
	for index in 3:
		var status: String = ["active","history","all"][index]
		MoonStyle.button(game,status_rect(index),MoonStyle.word(game,status),game.get_meta("journal_status","active")==["active","completed","all"][index])
	var entries := filtered(game)
	game.quest_log_page = clampi(game.quest_log_page,0,page_count(game)-1)
	for index in PAGE_SIZE:
		var absolute: int = game.quest_log_page*PAGE_SIZE+index
		if absolute<entries.size(): draw_record(game,Rect2(278,145+index*139,840,123),entries[absolute])
	if entries.is_empty(): MoonStyle.text(game,Rect2(278,240,840,100),MoonStyle.word(game,"empty"),17,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	MoonStyle.button(game,PREV,"←",false,game.quest_log_page>0)
	MoonStyle.button(game,NEXT,"→",false,game.quest_log_page+1<page_count(game))
	MoonStyle.text(game,Rect2(332,582,732,36),game.LocaleSystem.ui("quest_page",[game.quest_log_page+1,page_count(game)]),12,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	MoonStyle.text(game,Rect2(28,578,216,40),"↑ ↓  ·  F / Y",11,MoonStyle.MUTED)

## Рисует одну сохранённую запись с текущей целью или отметкой выполненного задания.
static func draw_record(game: Node, rect: Rect2, record: Dictionary) -> void:
	MoonStyle.panel(game,rect)
	MoonStyle.title(game,Rect2(rect.position+Vector2(18,13),Vector2(615,27)),String(record.title),18)
	var status: String = String(record.status)
	MoonStyle.text(game,Rect2(rect.position+Vector2(654,13),Vector2(165,25)),MoonStyle.sentence_case(game.LocaleSystem.ui(status)),MoonStyle.LABEL_SIZE,MoonStyle.ACCENT if status=="completed" else MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	game.draw_ui_multiline_string(game.UI_FONT,rect.position+Vector2(18,57),String(record.description),HORIZONTAL_ALIGNMENT_LEFT,800,34,MoonStyle.BODY_SIZE,2,MoonStyle.MUTED)
	var track := Rect2(rect.position+Vector2(18,93),Vector2(470,3))
	game.draw_rect(track,MoonStyle.INSET); game.draw_rect(Rect2(track.position,Vector2(track.size.x*float(record.ratio),3)),MoonStyle.ACCENT)
	MoonStyle.text(game,Rect2(rect.position+Vector2(18,100),Vector2(560,17)),String(record.progress),MoonStyle.LABEL_SIZE,MoonStyle.MUTED)
	MoonStyle.text(game,Rect2(rect.position+Vector2(602,88),Vector2(218,25)),String(record.get("reward","")),MoonStyle.LABEL_SIZE,MoonStyle.ACCENT,HORIZONTAL_ALIGNMENT_RIGHT)

## Меняет группу, фильтр и страницу; выбор не принимает и не завершает задание.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	for index in 2:
		if group_rect(index).has_point(point): game.set_meta("journal_group","story" if index==0 else "side"); game.quest_log_page=0; game.queue_redraw(); return true
	for index in 3:
		if status_rect(index).has_point(point): game.set_meta("journal_status",["active","completed","all"][index]); game.quest_log_page=0; game.queue_redraw(); return true
	if PREV.has_point(point): game.quest_log_page=maxi(0,game.quest_log_page-1); return true
	if NEXT.has_point(point): game.quest_log_page=mini(page_count(game)-1,game.quest_log_page+1); return true
	return false

## Переключает сюжетную группу и архив клавиатурой или геймпадом без доступа к боевым действиям.
static func handle_input(game: Node, event: InputEvent) -> bool:
	var group_change: bool = false
	var status_change: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		group_change=event.keycode in [KEY_UP,KEY_DOWN]
		status_change=event.keycode==KEY_F
	if event is InputEventJoypadButton and event.pressed:
		group_change=event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]
		status_change=event.button_index==JOY_BUTTON_Y
	if group_change: game.set_meta("journal_group","side" if game.get_meta("journal_group","story")=="story" else "story")
	if status_change:
		var statuses := ["active","completed","all"]
		game.set_meta("journal_status",statuses[posmod(statuses.find(game.get_meta("journal_status","active"))+1,3)])
	if group_change or status_change: game.quest_log_page=0; game.queue_redraw(); return true
	return false
