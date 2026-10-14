extends RefCounted

const Hero := preload("res://scripts/systems/hero_visual_system.gd")
const Actions := preload("res://scripts/systems/hero_action_visual_system.gd")
const Combat := preload("res://scripts/systems/hero_combat_visual_system.gd")
const Grandma := preload("res://scripts/systems/grandmother_visual_system.gd")
const Resident := preload("res://scripts/systems/resident_visual_system.gd")
const Enemy := preload("res://scripts/systems/enemy_animation_library.gd")
const Wildlife := preload("res://scripts/systems/wildlife_visual_system.gd")
const Boss := preload("res://scripts/systems/cave_boss_art_system.gd")
const BossData := preload("res://scripts/systems/cave_boss_data.gd")
const Livestock := preload("res://scripts/systems/livestock_visual_system.gd")
const Farm := preload("res://scripts/systems/livestock_data.gd")
const Slime := preload("res://scripts/systems/animation_renderer.gd")
const DIRECTIONS := {"south":Vector2.DOWN,"south-west":Vector2(-1,1),"west":Vector2.LEFT,"north-west":Vector2(-1,-1),"north":Vector2.UP,"north-east":Vector2(1,-1),"east":Vector2.RIGHT,"south-east":Vector2(1,1)}
const CARDINAL := ["south","west","east","north"]
const BIOS := {
	"miron":"Староста деревни и глава гильдии. Отправляет героя за Лунной реликвией и помогает восстановить защитную печать долины.",
	"agafya":"Травница, которая заботится о лекарственном саде. Ей нужны цветы для настоя и редкое семя хищного растения.",
	"varvara":"Рыбачка у речной переправы. Собирает рыбу для рабочих и готовит свежую уху для рыбаков.",
	"gavrila":"Кузнец ремесленного двора. Делает деревенские инструменты и испытывает новые металлические сплавы.",
	"dunya":"Повариха торговой слободы. Готовит праздничные пироги и общий стол к празднику урожая.",
	"saveliy":"Охотник в лесу. Собирает шкуры, чтобы деревенские жители получили тёплые зимние плащи.",
	"zlata":"Шахтёр на каменистой окраине. Просит помочь с добычей красных кристаллов.",
	"elizar":"Архивариус руин. Изучает древний ключ и восстанавливает летопись старого гарнизона.",
	"radomir":"Капитан, расследующий нападения орков. По клейму клинка ищет тех, кто разрушает печать долины.",
	"lada":"Ведунья проклятых земель. Проводит обряд очищения, готовит защитный настой и исследует Сердце затмения.",
	"tikhon":"Стеклодув, работающий с лунным стеклом. Его рассветное стекло помогает закрыть разлом.",
	"elena":"Штурман «Чёрной сельди». Выясняет, что тревожит море, и ищет проклятый компас Утопшего капитана.",
}

## Выгружает каждого героя, жителя, напарника, противника, призванное существо и животное.
static func export_all(ctx: Object) -> void:
	hero(ctx); residents(ctx); companions(ctx); enemies(ctx); wildlife(ctx); farm_animals(ctx); cave_boss(ctx); slime(ctx)

## Передаёт только существующие игровые направления и кадры, без выдуманных диагоналей или атак.
static func clip(ctx: Object, id: String, title: String, directions: Array, count: int, fps: float, pose: Callable) -> Dictionary:
	var frames:={}
	for direction in directions:
		frames[direction]=[]
		for index in count: frames[direction].append(ctx.frame(pose.call(String(direction),index)))
	return {"id":id,"title":title,"fps":fps,"frames":frames}

## Прикрепляет к странице анимацию и спокойный кадр для поисковой карточки.
static func finish(entry: Dictionary, clips: Array) -> void:
	entry.animation={"clips":clips}; entry.icon=clips[0].frames.values()[0][0]

## Собирает ходьбу, мотыгу, инструменты и все нарисованные виды боевых действий главного героя.
static func hero(ctx: Object) -> void:
	var entry:Dictionary=ctx.add("characters","hero","Главный герой","Возвращается на бабушкину ферму, выращивает урожай, осваивает ремёсла и раскрывает тайну Лунной долины.",["Герой"],"scripts/systems/hero_visual_system.gd")
	ctx.fact(entry,"Начальное здоровье",100); ctx.fact(entry,"Мана",40); ctx.fact(entry,"Энергия",12)
	var clips:=[clip(ctx,"idle","Покой",CARDINAL,1,1,func(dir,_i): return Hero.walk_pose(DIRECTIONS[dir],0,false)),clip(ctx,"walk","Ходьба",CARDINAL,4,8,func(dir,i): return Hero.walk_pose(DIRECTIONS[dir],(i+0.05)/8.0,true))]
	clips.append(clip(ctx,"hoe","Мотыга",CARDINAL,4,6,func(dir,i): return Hero.hoe_pose(DIRECTIONS[dir],[0.02,0.3,0.65,0.99][i])))
	for kind in ["pickaxe","axe","watering","fishing","hammer","staff"]:
		var title:String={"pickaxe":"Кирка","axe":"Топор","watering":"Полив","fishing":"Удочка","hammer":"Молоток","staff":"Посох"}[kind]
		clips.append(clip(ctx,kind,title,CARDINAL,4,6,func(dir,i): return Actions.pose(kind,DIRECTIONS[dir],[0.05,0.3,0.68,0.95][i])))
	for kind in ["blade","spear","bow"]:
		clips.append(clip(ctx,kind,{"blade":"Удар мечом","spear":"Удар копьём","bow":"Выстрел из лука"}[kind],CARDINAL,4,6,func(dir,i): return Combat.pose(kind,DIRECTIONS[dir],[0.05,0.3,0.68,0.95][i])))
	finish(entry,clips)

## Выбирает настоящую библиотеку костюма: бабушка имеет четыре стороны, остальные подготовленные жители восемь.
static func resident_pose(ctx: Object, sprite: int, direction: String, index: int, moving: bool) -> Dictionary:
	var texture:Texture2D=ctx.game.DirectionalCharacterSystem.NPC_TEXTURES[sprite]
	var pose:Dictionary
	if sprite==0: pose=Grandma.pose(DIRECTIONS[direction],(index+0.05)/8.0,moving); pose.texture=Grandma.texture()
	else: pose=Resident.pose(texture,DIRECTIONS[direction],(index+0.05)/8.0,moving)
	pose.preserve_alpha=true; return pose

## Добавляет всех двенадцать жителей, бабушку, адреса, домашний распорядок, любимые подарки и задания.
static func residents(ctx: Object) -> void:
	var grandma:Dictionary=ctx.add("characters","grandmother","Бабушка","Встречает героя у дома, помогает начать фермерскую жизнь и просит принести первый урожай моркови.",["Жители"],"scripts/systems/grandmother_visual_system.gd")
	ctx.link(grandma,"locations","overworld","","Где найти"); ctx.link(grandma,"missions","chapter-0","","Первая встреча")
	finish(grandma,[clip(ctx,"idle","Покой",CARDINAL,1,1,func(dir,i): return resident_pose(ctx,0,dir,i,false)),clip(ctx,"walk","Ходьба",CARDINAL,4,8,func(dir,i): return resident_pose(ctx,0,dir,i,true))])
	for id in ctx.game.QuestSystem.NPCS:
		var data:Dictionary=ctx.game.QuestSystem.NPCS[id]; var directions:Array=CARDINAL if data.sprite==0 else DIRECTIONS.keys()
		var entry:Dictionary=ctx.add("characters",id,ctx.game.QuestSystem.npc_name(id),BIOS.get(id,"Житель Лунной долины. Здесь указаны его поручения, место встречи и доступные игровые анимации."),["Жители"],"scripts/systems/quest_system.gd")
		entry.tint=data.tint.to_html(false)
		var workplace:String=ctx.game.NpcMovementSystem.VILLAGE_WORK.get(id,data.location)
		ctx.link(entry,"locations",data.location,"","Дневное место" if workplace==data.location else "Утром и вечером")
		if workplace!=data.location: ctx.link(entry,"locations",workplace,"","Дневное место")
		if ctx.game.NpcMovementSystem.VILLAGE_HOME.has(id): ctx.link(entry,"locations",ctx.game.NpcMovementSystem.VILLAGE_HOME[id],"","Ночью и в непогоду")
		for mission in data.missions: ctx.link(entry,"missions",mission,"","Поручения")
		if ctx.game.VillageLifeSystem.PREFERENCES.has(id):
			for item in ctx.game.VillageLifeSystem.PREFERENCES[id].loves: ctx.link(entry,"items",item,"","Любимые подарки")
			for item in ctx.game.VillageLifeSystem.PREFERENCES[id].likes: ctx.link(entry,"items",item,"","Хорошие подарки")
			ctx.link(entry,"missions","personal-"+id,"","Личное поручение")
		finish(entry,[clip(ctx,"idle","Покой",directions,1,1,func(dir,i): return resident_pose(ctx,data.sprite,dir,i,false)),clip(ctx,"walk","Ходьба",directions,4,8,func(dir,i): return resident_pose(ctx,data.sprite,dir,i,true))])

## Передаёт трёх напарников с реальной ценой освобождения, лидерством и боевыми особенностями.
static func companions(ctx: Object) -> void:
	for id in ctx.game.CompanionSystem.COMPANIONS:
		var data:Dictionary=ctx.game.CompanionSystem.COMPANIONS[id]; var texture:Texture2D=ctx.game.DirectionalCharacterSystem.COMPANION_TEXTURES[id]
		var entry:Dictionary=ctx.add("characters",id,ctx.game.CompanionSystem.name(ctx.game,id),"Напарник, которого можно освободить в тюрьме. Следует за героем и помогает в путешествиях и бою.",["Напарники"],"scripts/systems/companion_system.gd")
		for key in ["price","leadership","damage","defense","heal"]: ctx.fact(entry,{"price":"Цена освобождения","leadership":"Нужное лидерство","damage":"Урон","defense":"Защита","heal":"Лечение"}[key],data[key])
		ctx.link(entry,"locations","prison_interior","","Где найти")
		var pose:=func(dir,i):
			var value:Dictionary=Resident.pose(texture,DIRECTIONS[dir],(i+0.05)/8.0,true); value.preserve_alpha=true; return value
		finish(entry,[clip(ctx,"idle","Покой",DIRECTIONS.keys(),1,1,pose),clip(ctx,"walk","Ходьба",DIRECTIONS.keys(),4,8,pose)])

## Сохраняет все семейства противников, места обитания, уровни, добычу и реальные атакующие позы.
static func enemies(ctx: Object) -> void:
	for kind in ctx.game.CombatSystem.TYPES:
		var data:Dictionary=ctx.game.CombatSystem.TYPES[kind]
		var entry:Dictionary=ctx.add("characters",kind,data.name,"Противник Лунной долины. Характеристики ниже относятся к первому уровню; с ростом уровня враг становится сильнее.",["Враги"],"scripts/systems/combat_system.gd")
		for key in ["hp","damage","xp","speed","range"]: ctx.fact(entry,{"hp":"Здоровье","damage":"Урон","xp":"Опыт за победу","speed":"Скорость","range":"Дальность атаки"}[key],data[key])
		entry.yields=ctx.materials(data.loot); var seen:={}
		for enemy in ctx.game.CombatSystem.default_enemies():
			if enemy.kind==kind and not seen.has(enemy.location): seen[enemy.location]=true; ctx.link(entry,"locations",enemy.location,"","Где встречается")
		if kind not in Enemy.CORE_FAMILIES+Enemy.PIRATE_FAMILIES:
			var texture:Texture2D=ctx.game.ENEMY_RANK_ATLAS; var size:=Vector2(texture.get_size())/Vector2(5,3)
			var pose:={"texture":texture,"source":Rect2(Vector2.ZERO,size),"pivot":Vector2(size.x/2,size.y),"scale":0.6,"preserve_alpha":true}
			finish(entry,[clip(ctx,"idle","Покой",["south"],1,1,func(_dir,_i): return pose)]); continue
		if kind=="cave_guardian":
			var still:={"texture":Enemy.GUARDIAN_BODY,"source":Enemy.source_rect(kind,Vector2.DOWN,0),"pivot":Enemy.GUARDIAN_PIVOT,"scale":0.375,"preserve_alpha":true}
			ctx.fact(entry,"Графика","Временная цельная поза; подробный набор анимаций готовится")
			finish(entry,[clip(ctx,"idle","Покой",["south"],1,1,func(_dir,_i): return still)]); continue
		var pose:=func(dir,i): return {"texture":Enemy.walk_texture(kind),"source":Enemy.source_rect(kind,DIRECTIONS[dir],i),"pivot":Vector2(64,128),"scale":0.75,"preserve_alpha":true}
		var action:=func(dir,i):
			var value:Dictionary=Enemy.action_pose(kind,DIRECTIONS[dir],i)
			value.merge({"pivot":Vector2(64,128),"scale":0.75,"preserve_alpha":true}); return value
		var title:String={"melee":"Удар","shoot":"Выстрел","cast":"Заклинание","slam":"Удар по земле"}[Enemy.action_kind(kind)]
		finish(entry,[clip(ctx,"idle","Покой",DIRECTIONS.keys(),1,1,func(dir,_i): return pose.call(dir,1)),clip(ctx,"walk","Ходьба",DIRECTIONS.keys(),3,7,pose),clip(ctx,"attack",title,DIRECTIONS.keys(),3,6,action)])

## Использует тот же выбор согласованных столбцов и зеркальности зверей, что и игровой рендерер.
static func wildlife(ctx: Object) -> void:
	for kind in ctx.game.WildlifeSystem.TYPES:
		var data:Dictionary=ctx.game.WildlifeSystem.TYPES[kind]
		var entry:Dictionary=ctx.add("characters",kind,ctx.game.LocaleSystem.entity(kind),"Дикий обитатель долины. Его поведение и добыча связаны с охотой и исследованием природы.",["Дикие животные"],"scripts/systems/wildlife_system.gd")
		ctx.fact(entry,"Здоровье",data.hp); entry.yields=ctx.materials(data.loot)
		var pose:=func(dir,i):
			var packet:Dictionary=Wildlife.frame_packet(ctx.game,{"kind":kind,"position":Vector2.ZERO,"direction":DIRECTIONS[dir],"animation":(i+0.05)/6.0,"moving":true,"visual_state":"walk"})
			var source:Rect2=packet.source
			return {"texture":packet.texture,"source":source,"pivot":Vector2(source.size.x/2,source.size.y),"scale":packet.scale,"flip":packet.destination.size.x<0,"preserve_alpha":true}
		finish(entry,[clip(ctx,"idle","Покой",CARDINAL,1,1,pose),clip(ctx,"walk","Движение",CARDINAL,4,6,pose)])
		var seen:={}
		for animal in ctx.game.WildlifeSystem.SPAWNS:
			if animal.kind==kind and not seen.has(animal.location): seen[animal.location]=true; ctx.link(entry,"locations",animal.location,"","Где встречается")

## Показывает всех фермерских животных, включая каждую курочку, их настоящие кадры и продукты.
static func farm_animals(ctx: Object) -> void:
	for data in Farm.ANIMALS:
		var entry:Dictionary=ctx.add("characters",data.id,data.name,"Домашнее животное фермы. Кормите, поите и ухаживайте за ним, чтобы получать продукты.",["Ферма"],"scripts/systems/livestock_data.gd")
		ctx.link(entry,"items",data.product,"","Продукт"); ctx.link(entry,"locations","overworld","","Где живёт"); ctx.fact(entry,"Продукция, интервал в днях",data.interval)
		var pose:=func(dir,i):
			var value:Dictionary=Livestock.frame(data.kind,i); var texture:Texture2D=load(Livestock.ROOT+value.sprite)
			return {"texture":texture,"source":Rect2(Vector2.ZERO,texture.get_size()),"pivot":Vector2(value.pivot[0],value.pivot[1]),"scale":1.0,"flip":dir=="east","preserve_alpha":true}
		finish(entry,[clip(ctx,"idle","Покой",["west","east"],1,1,pose),clip(ctx,"walk","Движение",["west","east"],2,3,pose)])

## Передаёт измеренную позу Хранителя или нежити с фактической опорой авторского атласа.
static func boss_pose(kind: String, row: int, column: int, height: float) -> Dictionary:
	var value:Dictionary=Boss.frame(kind,row,column); var source:Rect2=value.source
	return {"texture":Boss.texture(kind),"source":source,"pivot":source.size*Vector2(value.pivot),"scale":height/source.size.y,"preserve_alpha":true}

## Собирает три стадии Хранителя, все двенадцать атак и отдельные появления призванных существ.
static func cave_boss(ctx: Object) -> void:
	var entry:Dictionary=ctx.add("characters","deep_guardian","Хранитель святилища","Босс Глубинного святилища. Пробуждается у алтаря, меняет набор атак по мере потери здоровья и призывает скелетов, зомби и вампиров.",["Боссы"],"scripts/systems/cave_boss_data.gd")
	ctx.fact(entry,"Здоровье",BossData.MAX_HP); ctx.fact(entry,"Вторая стадия", "120 HP и ниже"); ctx.fact(entry,"Третья стадия","60 HP и ниже"); ctx.fact(entry,"Одновременные призывы",BossData.MINION_LIMIT)
	ctx.link(entry,"locations",BossData.LOCATION,"","Арена"); ctx.link(entry,"missions","story_relic","","Связанное задание")
	var clips:=[clip(ctx,"idle","Покой",["south"],1,1,func(_dir,_i): return boss_pose("guardian",0,3,200))]
	for id in BossData.ATTACKS:
		var value:Dictionary=BossData.ATTACKS[id]; var phase:=1
		for index in BossData.PHASES.size():
			if id in BossData.PHASES[index]: phase=index+1
		var title:String=BossData.NAMES[id][0]
		clips.append(clip(ctx,id,"%d · %s"%[phase,title],["south"],4,4,func(_dir,i): return boss_pose("guardian",value.row,i,200)))
		entry.sections.append({"title":"Стадия %d · %s"%[phase,title],"text":"Урон: %d. Подготовка: %.2f сек. Длительность: %.2f сек. Передышка: %.2f сек."%[value.damage,value.windup,value.duration,value.recovery]})
	finish(entry,clips)
	for kind in ["skeleton","zombie","vampire"]:
		var actor:Dictionary=ctx.add("characters","summon-"+kind,{"skeleton":"Призванный скелет","zombie":"Призванный зомби","vampire":"Призванный вампир"}[kind],"Призванное существо Хранителя. Появляется в святилище во время боя с боссом.",["Призывы"],"scripts/systems/cave_boss_renderer.gd")
		var actions:=[]
		for row in 4: actions.append(clip(ctx,"action-"+str(row),["Появление","Движение","Атака","Поражение"][row],["south"],Boss.count(kind,row),7,func(_dir,i): return boss_pose(kind,row,i,84)))
		finish(actor,actions); ctx.link(actor,"characters","deep_guardian","","Призывает")

## Передаёт все самостоятельные состояния сюжетного слизня с фактическим количеством кадров.
static func slime(ctx: Object) -> void:
	var entry:Dictionary=ctx.add("characters","slime","Слизень","Первый боевой противник на дикой окраине деревни. У него есть отдельные фазы покоя, атаки, получения урона и поражения.",["Враги"],"scripts/systems/animation_renderer.gd")
	var clips:=[]
	for id in ["idle","attack","hurt","death"]:
		var texture:Texture2D={"idle":Slime.SLIME_IDLE,"attack":Slime.SLIME_ATTACK,"hurt":Slime.SLIME_HURT,"death":Slime.SLIME_DEATH}[id]
		var count:int={"idle":6,"attack":8,"hurt":6,"death":10}[id]
		count=mini(count,texture.get_width()/64)
		clips.append(clip(ctx,id,{"idle":"Покой","attack":"Атака","hurt":"Получение урона","death":"Поражение"}[id],["south"],count,11,func(_dir,i): return {"texture":texture,"source":Rect2(i*64,0,64,64),"pivot":Vector2(32,64),"scale":1.0,"preserve_alpha":true}))
	finish(entry,clips); ctx.link(entry,"locations","overworld","","Где встречается")
