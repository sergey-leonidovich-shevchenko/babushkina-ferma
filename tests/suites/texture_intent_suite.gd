extends "res://tests/suites/suite_base.gd"

const Intents := preload("res://scripts/presentation/texture_intent_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const HEADER := "shader_type canvas_item; render_mode unshaded; "

## Запускает контракт назначения цвета и данных до компиляции материала.
func run() -> void:
	test_roles_keep_exact_shared_pixels()
	test_invalid_declarations_and_bindings_are_refused()
	test_material_and_catalog_preserve_source_ownership()

## Сценарий: один источник связывается как цвет и как тестовые числовые данные.
## Исходное состояние: независимая текстура с непрозрачными и скрытыми под альфой значениями.
## Ожидаемый результат: выбор роли не преобразует пиксели; несовместимая подсказка отклоняется.
func test_roles_keep_exact_shared_pixels() -> void:
	var image := Image.create(2,1,false,Image.FORMAT_RGBA8)
	image.set_pixel(0,0,Color8(128,64,192,0)); image.set_pixel(1,0,Color8(1,255,0,128))
	var texture := ImageTexture.create_from_image(image)
	for intent in ["color_srgb","data_rgba8"]:
		var bindings := {"map":Intents.binding(texture,intent)}
		var hint := "source_color, " if intent=="color_srgb" else ""
		var code := HEADER+"uniform sampler2D map : "+hint+"filter_nearest, repeat_disable;"
		expect(Intents.errors(code,bindings).is_empty(),"explicit valid sampler: "+intent)
		expect(not Intents.errors(code.replace(hint+"filter_nearest",("source_color, " if hint=="" else "")+"filter_nearest"),bindings).is_empty(),"wrong transfer is rejected: "+intent)
		expect(bindings.map.texture==texture and texture.get_image().get_data()==image.get_data(),"roles share pixels including transparent RGB: "+intent)
	var policy := Intents.profile("data_rgba8"); policy.source_color=true
	expect(not Intents.profile("data_rgba8").source_color,"external policy mutation cannot change the data role")
	expect(Intents.profile("missing").is_empty(),"unknown intent has no guessed default")

## Сценарий: объявление шейдера или набор текстур нарушает явный контракт.
## Исходное состояние: корректный числовой источник и изолированные строки некорректных объявлений.
## Ожидаемый результат: пропуски, обёртки, неизвестные формы и скрытые ограничения явно отклоняются.
func test_invalid_declarations_and_bindings_are_refused() -> void:
	var texture := Resources.texture("prop.rustic_table")
	var bindings := {"map":Intents.binding(texture,"data_rgba8")}
	var declaration := "uniform sampler2D map : filter_linear, repeat_disable;"
	for invalid in [declaration.replace("repeat_disable","repeat_enable"),declaration.replace("filter_linear","filter_linear_mipmap"),declaration.replace("filter_linear","filter_linear, filter_nearest"),declaration.replace("map :","map[2] :"),declaration.replace("repeat_disable","repeat_disable, repeat_disable"),declaration+declaration,"uniform samplerCube map;", "#include \"unknown.gdshaderinc\"\n"+declaration]:
		expect(not Intents.errors(HEADER+invalid,bindings).is_empty(),"invalid sampler contract refused: "+invalid)
	expect(not Intents.errors(HEADER+declaration,{}).is_empty(),"missing sampler binding refused")
	expect(not Intents.errors(HEADER+declaration,{"map":17}).is_empty(),"untyped binding refused")
	expect(not Intents.errors(HEADER+declaration,{"map":{"texture":texture,"intent":"guess"}}).is_empty(),"unknown binding role refused")
	expect(not Intents.errors(HEADER+declaration,{"map":bindings.map,"extra":bindings.map}).is_empty(),"extra binding refused")
	expect(not Intents.errors("shader_type spatial; "+declaration,bindings).is_empty(),"unsupported shader type refused")
	expect(not Intents.errors(HEADER+"uniform lowp sampler2D map;",{}).is_empty(),"unsupported precision syntax cannot bypass the contract with empty bindings")
	expect(not Intents.errors(HEADER+"#define IMAGE sampler2D\nuniform IMAGE map;",{}).is_empty(),"preprocessor aliases cannot hide an unchecked sampler")
	expect(Intents.errors(HEADER+"/* uniform samplerCube hidden; */\n"+declaration+" // source_color",bindings).is_empty(),"comments do not create samplers or hints")
	var atlas := AtlasTexture.new(); atlas.atlas=texture; atlas.region=Rect2(0,0,16,16)
	var canvas := CanvasTexture.new(); canvas.diffuse_texture=texture
	for invalid_texture in [null,atlas,canvas]:
		expect(Intents.binding(invalid_texture,"data_rgba8").is_empty(),"raw shader samplers refuse missing texture or wrappers")

## Сценарий: паспорт отдаёт рисунок стола будущему шейдеру во всех трёх разрешённых ракурсах.
## Исходное состояние: действующие исходники и материал с явной цветовой подсказкой.
## Ожидаемый результат: материал использует тот же источник, числовая роль не подменяет рисунок и геометрию.
func test_material_and_catalog_preserve_source_ownership() -> void:
	var shader := Shader.new()
	shader.code=HEADER+"uniform sampler2D map : source_color, filter_linear, repeat_disable; void fragment(){ COLOR=texture(map,UV); }"
	for side in ["south","west","east"]:
		var view := Resources.describe("prop.rustic_table",side)
		var binding := Resources.shader_binding("prop.rustic_table",side)
		var material := Intents.material(shader,{"map":binding})
		expect(view.texture_intent=="color_srgb" and binding.intent=="color_srgb","catalog exposes explicit color role: "+side)
		expect(material!=null and material.shader==shader and material.get_shader_parameter("map")==Resources.texture("prop.rustic_table",side),"shader shares existing source without wrapper or copy: "+side)
		expect(Intents.material(shader,{"map":Intents.binding(binding.texture,"data_rgba8")})==null,"factory refuses source_color on data: "+side)
		var broken := Resources.catalog(); broken.textures["oak_table_"+side].intent="data_rgba8"
		expect(Resources.resolve(broken,"prop.rustic_table",side).is_empty(),"color catalogue refuses numerical intent: "+side)
	expect(Resources.shader_binding("missing").is_empty() and Intents.material(null,{})==null,"missing resource and shader remain explicitly absent")
