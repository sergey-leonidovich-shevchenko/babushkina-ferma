extends "res://tests/suites/suite_base.gd"

const Layout := preload("res://scripts/systems/house_furniture_layout_system.gd")
const Art := preload("res://scripts/presentation/house_furniture_visual_system.gd")
const Save := preload("res://scripts/systems/save_system.gd")

## Запускает геометрию комнаты, четыре ракурса, честную установку и миграцию старой мебели.
func run() -> void:
	test_room_grid_and_services()
	test_cardinal_art_and_uniform_scale()
	test_placement_rotation_and_obstacles()
	test_full_wall_cannot_seal_service_routes()
	test_old_furniture_migration_and_save()
	test_no_space_refund_and_invalid_records()

## Сценарий: все постоянные предметы дома используют одинаковые клетки и свободные рабочие подходы.
## Исходное состояние: меблированный дом с кроватью, кухней, шкафом, кругом, стульями и сундуком.
## Ожидаемый результат: основания кратны24, не пересекаются, услуги доступны по непрерывному пути от двери.
func test_room_grid_and_services() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.home_chest_owned=true
	var solids:Array=[]
	for prop in game.InteriorVisualSystem.props(game.current_location):
		var bounds:Rect2=game.InteriorVisualSystem.collision_rect(prop.kind,prop.position,int(prop.direction))
		if bounds.size==Vector2.ZERO: bounds=Layout.rect(prop.kind,prop.position,int(prop.direction))
		for coordinate in [bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y]: expect(is_zero_approx(fposmod(coordinate,24)),"home footprint is on the24px grid: "+prop.kind)
		expect(Layout.Data.FLOOR.encloses(bounds),"whole footprint fits house floor: "+prop.kind)
		if prop.kind=="woven_rug": continue
		for solid in solids: expect(not bounds.intersects(solid),"home furniture does not overlap: "+prop.kind)
		solids.append(bounds)
	expect(Layout.services_reachable(game,[]),"door reaches bed, cabinet, kitchen, alchemy, pottery, cellar and chest")
	for point in [Layout.Data.CABINET_POINT,Layout.Data.BED_POINT,Layout.Data.KITCHEN_POINT,Layout.Data.ALCHEMY_POINT,Layout.Data.POTTERY_POINT]: expect(game.NavigationSystem.is_walkable(game,point),"actual service point stays physically walkable: "+str(point))
	expect(game.StorageSystem.CHEST_POSITION==Layout.Data.CHEST_POSITION,"storage and rendering share the aligned chest position")
	game.free()

## Сценарий: старая мебель не помещается в полностью заполненный дом или содержит неизвестный вид.
## Исходное состояние: старый список содержит40 шкафов; отдельно проверяются неизвестный вид и дробное направление.
## Ожидаемый результат: лишняя мебель возвращается целой без потери количества, некорректный документ отвергается до изменения игры.
func test_no_space_refund_and_invalid_records() -> void:
	var game:=make_game(); var value:Dictionary=game.FarmLifeSystem.state(game)
	var count:int=game.inventory_item_count("wooden_wardrobe")
	value.furniture=[]
	for index in 40: value.furniture.append({"kind":"wooden_wardrobe","position":Vector2(600,360)})
	Layout.migrate(game)
	expect(value.furniture.size()<40 and value.furniture.size()+game.inventory_item_count("wooden_wardrobe")-count==40,"full old house returns whole unplaced furniture without quantity loss")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(Save.snapshot(game)))
	var before:=Save.snapshot(game)
	saved.estate.expansion.furniture=[{"kind":"not_a_furniture","position":[600,384]}]
	expect(not Save.apply(game,saved) and Save.snapshot(game)==before,"unknown furniture cannot partially mutate a save")
	saved.estate.expansion.furniture=[{"kind":"wooden_chair","position":[600,384],"direction":1.5}]
	expect(not Save.apply(game,saved) and Save.snapshot(game)==before,"fractional direction cannot partially mutate a save")
	game.free()

## Сценарий: мебель имеет отдельные прямые ракурсы и не растягивается по двум разным масштабам.
## Исходное состояние: утверждённые изображения А импортированы отдельными компактными текстурами.
## Ожидаемый результат: все четыре ресурса существуют, силуэт целый, пропорции одинаковы у источника и игрового рисунка.
func test_cardinal_art_and_uniform_scale() -> void:
	var game:=make_game()
	for kind in Art.KINDS:
		expect(Art.SPRITES[kind].size()==4,"four separately drawn directions: "+kind)
		for direction in 4:
			var texture:=Art.texture(kind,direction); var source:=Art.source(kind,direction)
			var profile:Dictionary=game.InteriorVisualSystem.profile(kind,direction)
			var target:=Art.destination(kind,Vector2(600,480),profile.visual_size,direction)
			expect(texture.get_width()<=256 and texture.get_height()<=256,"runtime furniture uses compact textures: "+kind)
			expect(source.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(source),"entire silhouette is inside its own texture: "+kind)
			expect(is_equal_approx(source.size.x/target.size.x,source.size.y/target.size.y),"uniform scale preserves furniture proportions: "+kind)
			expect(is_equal_approx(target.end.y,480),"direction keeps bottom anchor: "+kind)
	for kind in ["rustic_table","wooden_chair","wooden_wardrobe"]:
		var front:Vector2=game.FarmLifeVisualSystem.profile(kind,0).collision
		var side:Vector2=game.FarmLifeVisualSystem.profile(kind,1).collision
		expect(side==Vector2(front.y,front.x),"side view rotates the occupied cells: "+kind)
	game.free()

## Сценарий: герой выбирает четыре ракурса и ставит мебель перед собой на разрешённые клетки.
## Исходное состояние: один стол и один стул в рюкзаке, свободная зона слева от гончарного круга.
## Ожидаемый результат: поворот замыкается на четвёртом шаге; препятствие, стена и лестница не расходуют предмет.
func test_placement_rotation_and_obstacles() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.player=Vector2(396,480); game.facing=Vector2.UP
	var life=game.FarmLifeSystem; game.change_inventory_count("rustic_table",1); game.change_inventory_count("wooden_chair",1)
	expect(life.toggle_build_mode(game),"home furniture mode opens")
	for direction in 4:
		var event:=InputEventKey.new(); event.keycode=KEY_R; event.pressed=true
		expect(life.handle_input(game,event) and int(life.state(game).build_direction)==(direction+1)%4,"R selects the next cardinal direction")
	var item:=Layout.candidate(game)
	expect(Layout.can_place(game,item) and life.place_furniture(game),"free whole footprint can be installed")
	expect(game.inventory_item_count("rustic_table")==0 and life.state(game).furniture.size()==1,"successful placement spends exactly one furniture item")
	expect(not life.blocks_position(game,game.player,game.PLAYER_RADIUS),"placing ahead does not embed hero in own furniture")
	game.change_inventory_count("rustic_table",1)
	expect(not life.place_furniture(game) and game.inventory_item_count("rustic_table")==1,"overlapping existing furniture cannot spend another table")
	game.player=Vector2(960,320); game.facing=Vector2.RIGHT
	expect(not life.place_furniture(game),"wall prevents a footprint outside the whole floor")
	game.player=Vector2(744,504)
	expect(not life.place_furniture(game),"cellar hatch stays clear")
	game.player=Vector2(396,480); game.facing=Vector2.UP; life.state(game).build_index=1; life.state(game).build_direction=1
	expect(not life.place_furniture(game),"chair cannot intersect the table installed earlier")
	game.player=Vector2(600,336); game.facing=Vector2.DOWN
	expect(life.place_furniture(game) and int(life.state(game).furniture.back().direction)==1,"placed side-facing chair retains its actual direction")
	game.free()

## Сценарий: новая мебель пытается замкнуть перегородку между входом и левой частью дома.
## Исходное состояние: четыре допустимых стола образуют стену с последним свободным проходом снизу.
## Ожидаемый результат: последний стол не пересекает чужое основание, но запрещён проверкой маршрута; предмет не расходуется.
func test_full_wall_cannot_seal_service_routes() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.player=Vector2(468,516); game.facing=Vector2.LEFT
	var value:Dictionary=game.FarmLifeSystem.state(game); value.build_mode=true; value.furniture=[]
	for y in [336,384,432,480]: value.furniture.append({"kind":"rustic_table","position":Vector2(396,y),"direction":0})
	game.change_inventory_count("rustic_table",1)
	var item:=Layout.candidate(game)
	expect(Layout.fits(game,item,value.furniture),"last wall segment fits its cells without intersecting furniture or reserved approaches")
	expect(not Layout.can_place(game,item) and not game.FarmLifeSystem.place_furniture(game),"placement cannot seal off cabinet and bed behind a complete wall")
	expect(game.inventory_item_count("rustic_table")==1,"route rejection preserves furniture in inventory")
	game.free()

## Сценарий: старое сохранение со свободными координатами получает сетку и новое поле направления.
## Исходное состояние: стол и шкаф записаны в старом формате, один предмет пересекает новую постоянную мебель.
## Ожидаемый результат: ближайшее свободное основание сохраняет каждый предмет, повторная миграция стабильна, направление проходит настоящий JSON.
func test_old_furniture_migration_and_save() -> void:
	var game:=make_game(); var value:Dictionary=game.FarmLifeSystem.state(game)
	value.furniture=[{"kind":"rustic_table","position":Vector2(256,320)},{"kind":"wooden_wardrobe","position":Vector2(190,350)}]
	var counts:Dictionary=game.export_inventory_counts().duplicate(true)
	Layout.migrate(game)
	expect(value.furniture.size()==2 and game.export_inventory_counts()==counts,"migration preserves placed furniture and inventory quantities")
	var restored:Array=[]
	for item in value.furniture:
		expect(item.position==Layout.snap(item.kind,item.position,int(item.direction)) and Layout.fits(game,item,restored),"legacy furniture moves to a free complete footprint")
		restored.append(item)
	var before:Array=value.furniture.duplicate(true); Layout.migrate(game)
	expect(value.furniture==before,"migration is idempotent")
	value.furniture=[{"kind":"wooden_chair","position":Vector2(600,384),"direction":3}]
	Layout.migrate(game)
	var saved:Dictionary=JSON.parse_string(JSON.stringify(Save.snapshot(game)))
	expect(Save.apply(game,saved),"new furniture direction passes real JSON loading")
	expect(game.FarmLifeSystem.state(game).furniture.size()==1 and int(game.FarmLifeSystem.state(game).furniture[0].direction)==3,"loading retains east-facing chair")
	game.free()
