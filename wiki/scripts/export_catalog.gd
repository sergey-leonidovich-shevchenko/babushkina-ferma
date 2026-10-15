extends SceneTree

const Game := preload("res://scripts/game.gd")
const Actors := preload("res://wiki/scripts/export_actors.gd")
const Content := preload("res://wiki/scripts/export_content.gd")
const World := preload("res://wiki/scripts/export_world.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
var game:Node
var entries:Array=[]
var images:Dictionary={}
var textures:Dictionary={}
var failed:=false
const OUTPUT := "res://wiki/public/generated/"
var output:String=OUTPUT

## Выгружает справочник в отдельном пользовательском каталоге без чтения слотов героя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","MoonValleyWikiExport")
	if not OS.get_environment("WIKI_EXPORT_DIRECTORY").is_empty(): output=OS.get_environment("WIKI_EXPORT_DIRECTORY").trim_suffix("/")+"/"
	_export.call_deferred()

## Собирает фактические каталоги и игровые позы, затем записывает только данные и прозрачные ресурсы сайта.
func _export() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+"sprites"))
	game=Game.new(); game._ready(); game.LocaleSystem.current="ru"
	var errors:Array=game.ContentRegistry.validate()
	if not errors.is_empty(): push_error(str(errors)); game.free(); quit(1); return
	Actors.export_all(self); Content.export_all(self); World.export_all(self)
	var production:=preload("res://wiki/scripts/export_production.gd").build(self)
	var file:=FileAccess.open(output+"catalog.json",FileAccess.WRITE)
	if file==null: push_error("Не удалось записать каталог wiki"); game.free(); quit(1); return
	file.store_string(JSON.stringify({"schema":1,"entries":entries,"images":images,"production":production,"coverage":{"items":game.InventorySystem.ITEM_DATA.size(),"craft":game.CraftingSystem.RECIPES.size(),"npcs":game.QuestSystem.NPCS.size(),"quests":game.QuestSystem.MISSIONS.size(),"stations":preload("res://scripts/systems/basement_data.gd").STATIONS.size()}},"\t")); file.close()
	game.free(); print("WIKI EXPORT: %d articles, %d sprite resources"%[entries.size(),images.size()]); quit(1 if failed else 0)

## Создаёт статью с единым контрактом для поиска, карточек, чисел и перекрёстных ссылок.
func add(category: String, id: String, title: String, summary: String, tags: Array=[], source: String="") -> Dictionary:
	var entry:={"category":category,"id":id,"title":title,"summary":summary,"tags":tags,"facts":[],"sections":[],"relations":[],"ingredients":[],"yields":[],"source":source}
	entries.append(entry); return entry

## Добавляет наблюдаемую характеристику в читаемом виде без утечки внутренних координат или состояний окна.
func fact(entry: Dictionary, label: String, value: Variant) -> void:
	entry.facts.append({"label":label,"value":str(value)})

## Связывает статью с существующим персонажем, предметом, рецептом или локацией.
func link(entry: Dictionary, category: String, id: String, label: String="", group: String="Связано") -> void:
	entry.relations.append({"category":category,"id":id,"label":label,"group":group})

## Получает локализованное название из общего инвентаря, включая все новые расширения ремёсел.
func item_name(kind: String) -> String:
	return game.inventory_item_name(kind)

## Превращает точные количества материалов в строки, связанные с их собственными страницами.
func materials(values: Dictionary) -> Array:
	var result:=[]
	for kind in values: result.append({"id":kind,"name":item_name(kind) if kind!="coins" else "Монеты","count":values[kind]})
	return result

## Сохраняет текстуру один раз и проверяет результат записи, исключая неявное дублирование больших атласов.
func image(texture: Texture2D) -> String:
	if texture==null: return ""
	var key:=str(texture.get_instance_id())
	if textures.has(key): return textures[key]
	var pixels:=texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var png:=pixels.save_png_to_buffer(); var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(png)
	var name:="generated/sprites/"+hash.finish().hex_encode().left(24)+".png"
	if not images.has(name):
		var file:=FileAccess.open(output+name.trim_prefix("generated/"),FileAccess.WRITE)
		if file==null: failed=true; push_error("Не удалось сохранить спрайт wiki: "+name)
		else: file.store_buffer(png); file.close()
	textures[key]=name; images[name]=[pixels.get_width(),pixels.get_height()]; return name

## Передаёт браузеру точную область, опору, масштаб и зеркальность настоящей игровой позы.
func frame(pose: Dictionary) -> Dictionary:
	var texture:Texture2D=pose.texture
	if not pose.get("preserve_alpha",false): texture=Matte.clean_texture(texture)
	var source:Rect2=pose.source; var pivot:Vector2=pose.pivot
	return {"image":image(texture),"rect":[source.position.x,source.position.y,source.size.x,source.size.y],"pivot":[pivot.x,pivot.y],"scale":float(pose.get("scale",1)),"flip":bool(pose.get("flip",false))}

## Даёт обычной статичной картинке тот же безопасный контракт, что и анимационному кадру.
func still(texture: Texture2D, scale_value: float=1.0) -> Dictionary:
	var size:=texture.get_size()
	return frame({"texture":texture,"source":Rect2(Vector2.ZERO,size),"pivot":Vector2(size.x/2,size.y),"scale":scale_value,"preserve_alpha":true})

## Передаёт статье ту же окончательную иконку и окраску, что использует игровой renderer.
func item_icon(entry: Dictionary, kind: String) -> void:
	var visual:Dictionary=game.VisualAssetSystem.item_visual(kind)
	if visual.texture==null: failed=true; push_error("Нет рисунка предмета: "+kind); return
	entry.icon=still(visual.texture)
	if visual.tint!=Color.WHITE: entry.tint=visual.tint.to_html(false)
