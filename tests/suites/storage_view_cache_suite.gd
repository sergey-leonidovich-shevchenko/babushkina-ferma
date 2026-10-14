extends "res://tests/suites/suite_base.gd"

const View := preload("res://scripts/presentation/storage_view_cache.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const Actions := preload("res://scripts/systems/storage_actions_system.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")

class CountGame extends "res://scripts/game.gd":
	var count_calls:=0
	## Считает обходы количества без нестабильных временных порогов на машинах CI.
	func inventory_item_count(kind: String) -> int:
		count_calls+=1
		return super.inventory_item_count(kind)

## Проверяет точность снимка, его инвалидацию и безопасность пакетного порядка отрисовки.
func run() -> void:
	test_unchanged_frames_and_scroll_do_not_rescan_inventory()
	test_transfers_direct_state_and_unique_weapons_refresh_counts()
	test_query_sort_locale_slots_and_separate_games_refresh_lists()
	test_chest_counts_actions_and_return_to_world()
	test_batched_layers_do_not_overlap_neighbouring_content()

## Открывает шкаф в изолированной модели без чтения или записи пользовательского слота.
func prepare(game: Node) -> void:
	game.title_screen=false; game.language_screen=false; game.current_location="cottage_interior"; game.player=Cabinet.POSITION
	game.FarmLifeSystem.state(game).first_day=6; game.FarmLifeSystem.state(game).cutscene=""
	Cabinet.open(game)

## Сценарий: неподвижный каталог и прокрутка не меняют инвентарь, фильтр или порядок предметов.
## Исходное состояние: открытый полный шкаф, снимок прогрет, счётчик чтений количества сброшен.
## Ожидаемый результат: повторные кадры и смена фокуса не обходят реестр, а карточка использует текущий выбор.
func test_unchanged_frames_and_scroll_do_not_rescan_inventory() -> void:
	var game:=CountGame.new(); game._ready(); prepare(game)
	var original:=View.snapshot(game,true); game.count_calls=0
	for _frame in 60: View.snapshot(game,true)
	expect(game.count_calls==0 and View.statistics(game,true).builds==1,"sixty unchanged storage frames do not rescan any item count")
	Grid.scroll(game,true,1,1); Grid.select(game,true,1,20,false); game.count_calls=0
	var current:=View.snapshot(game,true)
	expect(game.count_calls==0 and View.selected(game,true,current)==Cabinet.items(game)[20] and original.items==current.items,"scroll and focus reuse item lists while detail follows the selected kind")
	game.free()

## Сценарий: предметы передаются в обе стороны, старое состояние меняется напрямую, получено единичное оружие.
## Исходное состояние: прогретый снимок шкафа и двадцать досок в рюкзаке.
## Ожидаемый результат: каждый видимый остаток точен, общий запас сохраняется, единичный предмет становится недоступен повторно.
func test_transfers_direct_state_and_unique_weapons_refresh_counts() -> void:
	var game:=make_game(); prepare(game); game.change_inventory_count("plank",20)
	var before:=View.snapshot(game,true); var total:int=before.counts[0].plank+before.counts[1].plank
	Grid.select(game,true,1,Cabinet.items(game).find("plank")); Grid.transfer(game,true,10)
	var after:=View.snapshot(game,true)
	expect(after.counts[0].plank==30 and after.counts[1].plank==989 and after.counts[0].plank+after.counts[1].plank==total,"withdraw refreshes both cached quantities without duplication")
	game.state.inventory.counts.plank=7; Cabinet.state(game).stock.plank=12
	after=View.snapshot(game,true)
	expect(after.counts[0].plank==7 and after.counts[1].plank==12,"legacy direct dictionary changes cannot leave stale counts")
	game.has_bow=false; View.snapshot(game,true); game.has_bow=true
	expect(View.snapshot(game,true).counts[0].bow==1,"legacy unique weapon flags invalidate the visible quantity")
	expect(before.counts[0].plank==20 and before.counts[1].plank==999,"later changes cannot mutate an earlier render snapshot")
	game.free()

## Сценарий: изменены язык, поиск, сортировка, порядок слотов и открыта другая новая игра.
## Исходное состояние: шкаф с полным каталогом и несколькими видами в рюкзаке.
## Ожидаемый результат: обе колонки совпадают с живыми API, история поиска не накапливает снимки и игры не разделяют кеш.
func test_query_sort_locale_slots_and_separate_games_refresh_lists() -> void:
	var game:=make_game(); prepare(game); game.change_inventory_count("plank",20); game.change_inventory_count("apple",9)
	View.snapshot(game,true); game.inventory_slots.reverse()
	expect(View.snapshot(game,true).items[0]==game.StorageSystem.inventory_items(game),"direct slot reordering refreshes the cached bag order")
	preload("res://scripts/systems/dev_cabinet_input.gd").query(game,"plank")
	expect(View.snapshot(game,true).items[1]==["plank"],"search refreshes the catalog without filtering the hero bag")
	preload("res://scripts/systems/dev_cabinet_input.gd").query(game,"")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false); Actions.sort_container(game,true)
		expect(View.snapshot(game,true).items[1]==Cabinet.items(game),"localized sorted snapshot matches live catalog: "+locale)
	game.LocaleSystem.set_locale("ru",false)
	var other:=make_game(); prepare(other)
	expect(View.snapshot(other,true).counts[0].plank==0 and View.snapshot(game,true).counts[0].plank==20,"separate games cannot share retained storage snapshots")
	other.free(); game.free()

## Сценарий: сундук пополнен, сопоставляющий перенос изменился, окно закрыто, затем открыт редактор.
## Исходное состояние: герой дома с установленным сундуком и доступным шкафом разработки.
## Ожидаемый результат: быстрые кнопки совпадают с действующими правилами, отсекается только закрытый непрозрачным окном мир.
func test_chest_counts_actions_and_return_to_world() -> void:
	var game:=make_game(); prepare(game); Cabinet.close(game); game.home_chest_owned=true; game.StorageSystem.open(game)
	game.change_inventory_count("plank",3); game.home_chest_counts.plank=7
	var data:=View.snapshot(game,false)
	expect(data.all==not Actions.candidates(game,false,false).is_empty() and data.matching==not Actions.candidates(game,false,true).is_empty(),"cached bulk action availability matches the transfer rules")
	game.home_chest_counts.clear(); data=View.snapshot(game,false)
	expect(not data.matching and data.items[1].is_empty(),"emptying the chest removes its rows and disables matching deposit")
	expect(game.RenderSystem.opaque_storage(game),"opaque home chest omits only the fully covered world")
	game.storage_open=false
	expect(not game.RenderSystem.opaque_storage(game),"closing storage restores world rendering immediately")
	game.storage_open=true; game.set_meta("capture_first_level_clean",true)
	expect(not game.RenderSystem.opaque_storage(game),"clean world capture retains its original rendering route")
	game.remove_meta("capture_first_level_clean"); game.storage_open=false; Cabinet.open(game)
	expect(game.RenderSystem.opaque_storage(game),"development cabinet shares the opaque rendering route")
	game.FarmLifeSystem.state(game).photo_mode=true
	expect(not game.RenderSystem.opaque_storage(game),"photo mode still shows the world while hiding interface panels")
	game.FarmLifeSystem.state(game).photo_mode=false; Cabinet.close(game); game.LevelEditorSystem.toggle(game)
	expect(not game.RenderSystem.opaque_storage(game),"editor retains its full world and panel rendering route")
	game.free()

## Сценарий: рамки, иконки и числа ячеек рисуются отдельными пакетами одного типа.
## Исходное состояние: обе пятистрочные сетки и неизменная принятая геометрия.
## Ожидаемый результат: рисунок и число принадлежат своей ячейке, не пересекаются между собой и соседями.
func test_batched_layers_do_not_overlap_neighbouring_content() -> void:
	for side in 2:
		for index in Layout.columns(side)*Layout.ROWS:
			var slot:=Layout.slot(side,index); var icon:=Layout.icon(side,index); var count:=Layout.count(side,index)
			expect(slot.encloses(icon) and slot.encloses(count) and not icon.intersects(count),"batched icon and count retain independent non-overlapping regions")
			for neighbour in range(index+1,Layout.columns(side)*Layout.ROWS):
				expect(not slot.intersects(Layout.slot(side,neighbour)),"reordering independent slot layers cannot cover a neighbouring cell")
