extends RefCounted

const LOCATION := "cave_sanctum"
const MAX_HP := 120
const MINION_LIMIT := 4
const ARENA := Rect2(1044, 336, 960, 696)
const PHASES := [
	["slam", "fan", "charge", "fissure"],
	["rockfall", "burst", "sweep", "prison"],
	["cross", "spiral", "triple_charge", "pulse"],
]
const ATTACKS := {
	"slam":{"windup":1.0,"duration":1.45,"recovery":1.3,"damage":16,"row":0,"effect":0},
	"fan":{"windup":0.9,"duration":1.25,"recovery":1.2,"damage":12,"row":1,"effect":1},
	"charge":{"windup":1.0,"duration":1.6,"recovery":1.5,"damage":18,"row":2,"effect":0},
	"fissure":{"windup":0.9,"duration":2.05,"recovery":1.2,"damage":13,"row":0,"effect":1},
	"rockfall":{"windup":1.0,"duration":2.1,"recovery":1.2,"damage":17,"row":3,"effect":2},
	"burst":{"windup":1.1,"duration":1.5,"recovery":1.1,"damage":13,"row":3,"effect":1},
	"sweep":{"windup":0.95,"duration":1.4,"recovery":1.3,"damage":19,"row":1,"effect":0},
	"prison":{"windup":1.2,"duration":2.2,"recovery":1.35,"damage":12,"row":3,"effect":1},
	"cross":{"windup":1.1,"duration":1.55,"recovery":1.1,"damage":20,"row":0,"effect":1},
	"spiral":{"windup":1.0,"duration":2.6,"recovery":1.1,"damage":12,"row":3,"effect":3},
	"triple_charge":{"windup":1.0,"duration":3.8,"recovery":1.6,"damage":18,"row":2,"effect":0},
	"pulse":{"windup":1.2,"duration":2.45,"recovery":1.4,"damage":20,"row":3,"effect":3},
}
const NAMES := {
	"slam":["Удар землёй","Ground slam","Golpe sísmico","Bodenschlag","Frappe au sol","震地猛击"],
	"fan":["Веер осколков","Shard fan","Abanico de fragmentos","Splitterfächer","Éventail d’éclats","碎晶扇射"],
	"charge":["Каменный рывок","Stone charge","Embestida pétrea","Steinansturm","Charge de pierre","岩石冲锋"],
	"fissure":["Разлом","Fissure","Fisura","Spalte","Fissure","裂地波"],
	"rockfall":["Обвал","Rockfall","Derrumbe","Steinschlag","Éboulement","落石"],
	"burst":["Кристальный залп","Crystal burst","Ráfaga cristalina","Kristallsalve","Salve de cristal","晶体齐射"],
	"sweep":["Широкий взмах","Wide sweep","Barrido amplio","Weiter Schwung","Large balayage","横扫"],
	"prison":["Клетка кристаллов","Crystal cage","Jaula de cristal","Kristallkäfig","Cage de cristal","晶体牢笼"],
	"cross":["Крест разломов","Cross quake","Sismo en cruz","Kreuzbeben","Séisme en croix","十字震波"],
	"spiral":["Спиральный залп","Spiral volley","Salva espiral","Spiralsalve","Salve en spirale","螺旋齐射"],
	"triple_charge":["Тройной рывок","Triple charge","Triple embestida","Dreifachansturm","Triple charge","三连冲锋"],
	"pulse":["Лунная волна","Moon pulse","Pulso lunar","Mondwelle","Onde lunaire","月光冲击环"],
	"stage":["СТАДИЯ %d / 3","PHASE %d / 3","FASE %d / 3","PHASE %d / 3","PHASE %d / 3","阶段 %d / 3"],
	"summon":["Призыв нежити","Undead summoning","Invocación de muertos","Untotenbeschwörung","Invocation de morts","召唤亡灵"],
	"flies":["Муха кусает: %.1f с","Biting fly: %.1f s","Mosca: %.1f s","Fliegenbisse: %.1f s","Mouche : %.1f s","苍蝇叮咬：%.1f秒"],
	"victory":["Хранитель повержен","Guardian defeated","Guardián derrotado","Wächter besiegt","Gardien vaincu","守护者已击败"],
}

## Определяет три стадии по точным порогам двух третей и одной трети здоровья.
static func phase(hp: int, maximum: int = MAX_HP) -> int:
	if hp * 3 <= maximum: return 3
	return 2 if hp * 3 <= maximum * 2 else 1

## Переносит прежний процент здоровья стража в новый бой и сохраняет точный HP новых сохранений.
static func restored_hp(saved: Dictionary, legacy_maximum: int) -> int:
	var maximum := maxf(1.0,float(saved.get("max_hp",legacy_maximum)))
	return clampi(roundi(float(saved.hp) / maximum * MAX_HP),0,MAX_HP)

## Возвращает перевод боевой подсказки на текущем языке игры.
static func word(game: Node, key: String, values: Array = []) -> String:
	var result: String = game.LocaleSystem.translated(NAMES, key, key)
	return result % values if not values.is_empty() else result

## Создаёт несохраняемое состояние текущего боя без изменения постоянного здоровья босса.
static func default_state() -> Dictionary:
	return {"active":false,"phase":1,"clock":0.0,"recovery":1.5,"cycle":0,"attack":{},"zones":[],"projectiles":[],"effects":[],"minions":[],"summon_timer":12.0,"summoning":0.0,"fly_timer":0.0,"fly_tick":0.0,"hit_cooldown":0.0,"victory":0.0}
