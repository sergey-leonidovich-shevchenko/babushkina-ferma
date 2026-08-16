extends RefCounted

const MANIFEST_PATH := "res://assets/generated/ui/visual_regression_manifest.json"
const REFERENCE_DIRECTORY := "res://assets/generated/ui/"
const LOCALIZED_CONTROL_CONTRACTS := {
	"title":{"width":694.0,"size":54}, "title_subtitle":{"width":630.0,"size":24},
	"continue_game":{"width":198.0,"size":21}, "new_game":{"width":198.0,"size":21}, "settings":{"width":240.0,"size":21}, "exit_game":{"width":198.0,"size":21},
	"resume":{"width":340.0,"size":16}, "save_game":{"width":340.0,"size":16}, "load_game":{"width":340.0,"size":16}, "return_main_menu":{"width":340.0,"size":16},
	"master_volume":{"width":196.0,"size":8}, "music_volume":{"width":196.0,"size":8}, "sfx_volume":{"width":196.0,"size":8}, "sound_enabled":{"width":196.0,"size":8},
	"fullscreen":{"width":196.0,"size":8}, "vsync":{"width":196.0,"size":8}, "reduced_motion":{"width":196.0,"size":8}, "screen_shake":{"width":196.0,"size":8},
	"high_contrast":{"width":196.0,"size":8}, "control_preset":{"width":196.0,"size":8}, "text_scale":{"width":196.0,"size":8}, "touch_scale":{"width":196.0,"size":8}, "language_option":{"width":196.0,"size":8}
}


## Загружает версионированный список визуальных эталонов либо возвращает пустой документ при повреждении файла.
static func manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if parsed is Dictionary else {}


## Проверяет существование, размер, пропорции, содержательность и точную контрольную сумму каждого UI-эталона.
static func validate_references() -> Array[String]:
	var errors: Array[String] = []; var document := manifest()
	if int(document.get("schema",0)) != 1: return ["visual manifest schema"]
	var design_size:=Vector2i(int(document.get("design_viewport",[0,0])[0]),int(document.get("design_viewport",[0,0])[1]))
	for entry in document.get("references",[]):
		var path := REFERENCE_DIRECTORY+String(entry.file)
		if not FileAccess.file_exists(path): errors.append("missing:%s"%entry.file); continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image==null: errors.append("invalid:%s"%entry.file); continue
		if image.get_width()!=int(entry.width) or image.get_height()!=int(entry.height): errors.append("size:%s"%entry.file)
		if image.get_size()!=design_size: errors.append("viewport:%s"%entry.file)
		if absf(float(image.get_width())/maxf(image.get_height(),1)-16.0/9.0)>0.01: errors.append("aspect:%s"%entry.file)
		if sampled_contrast(image)<0.08: errors.append("blank:%s"%entry.file)
		if FileAccess.get_sha256(path)!=String(entry.sha256): errors.append("hash:%s"%entry.file)
	return errors


## Измеряет диапазон яркости по равномерной сетке, чтобы пустой или одноцветный кадр не прошёл gate.
static func sampled_contrast(image: Image, samples: int = 24) -> float:
	var minimum := 1.0; var maximum := 0.0
	for row in samples:
		for column in samples:
			var x := mini(roundi((column+0.5)*image.get_width()/samples),image.get_width()-1); var y := mini(roundi((row+0.5)*image.get_height()/samples),image.get_height()-1)
			var color := image.get_pixel(x,y); var luminance := color.r*0.2126+color.g*0.7152+color.b*0.0722
			minimum=minf(minimum,luminance); maximum=maxf(maximum,luminance)
	return maximum-minimum


## Возвращает нормализованную среднюю разницу двух кадров по одинаковой сетке контрольных точек.
static func visual_difference(first: Image, second: Image, samples: int = 32) -> float:
	if first==null or second==null or first.get_size()!=second.get_size(): return 1.0
	var total := 0.0
	for row in samples:
		for column in samples:
			var x := mini(roundi((column+0.5)*first.get_width()/samples),first.get_width()-1); var y := mini(roundi((row+0.5)*first.get_height()/samples),first.get_height()-1)
			var a:=first.get_pixel(x,y); var b:=second.get_pixel(x,y); total+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
	return total/(samples*samples)


## Проверяет все варианты ключевых кнопок во всех локалях реальной метрикой текущего шрифта и контейнера.
static func validate_localized_controls(game: Node) -> Array[String]:
	var errors: Array[String] = []
	for key in LOCALIZED_CONTROL_CONTRACTS:
		var values: Array = game.LocaleSystem.UI.get(key,[]); var contract: Dictionary = LOCALIZED_CONTROL_CONTRACTS[key]
		if values.size()!=game.LocaleSystem.LOCALES.size(): errors.append("locale-count:%s"%key); continue
		for locale_index in values.size():
			var size: int = game.UiScaleSystem.fitted_font_size(game,game.UI_FONT,String(values[locale_index]),float(contract.width),int(contract.size))
			if size<6: errors.append("overflow:%s:%s"%[key,game.LocaleSystem.LOCALES[locale_index]])
	return errors
