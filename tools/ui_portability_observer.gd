extends "res://scripts/game.gd"

var watched_text := ""
var tutorial_draws: Array[Dictionary] = []


## Передаёт настоящий вызов прежней отрисовке и наблюдает текст, геометрию и выбранные шейпером гарнитуры.
func draw_ui_multiline_string(
	font: Font,
	at: Vector2,
	text: String,
	alignment: HorizontalAlignment,
	width: float,
	height: float,
	font_size: int,
	max_lines: int,
	color: Color
) -> void:
	super.draw_ui_multiline_string(
		font, at, text, alignment, width, height, font_size, max_lines, color
	)
	if text != watched_text:
		return
	var effective := UiScaleSystem.fitted_multiline_font_size(
		self, font, text, width, height, font_size
	)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	paragraph.add_string(text, font, effective)
	var families: Array[String] = []
	var styles: Array[String] = []
	var weights: Array[int] = []
	var server := TextServerManager.get_primary_interface()
	for rid in font.get_rids():
		families.append(server.font_get_name(rid))
		styles.append(server.font_get_style_name(rid))
		weights.append(server.font_get_weight(rid))
	var record := {
		"text": text,
		"position": [at.x, at.y],
		"width": width,
		"height": height,
		"requested_size": font_size,
		"effective_size": effective,
		"max_lines": max_lines,
		"line_count": paragraph.get_line_count(),
		"font_height": font.get_height(effective),
		"ascent": font.get_ascent(effective),
		"descent": font.get_descent(effective),
		"measured": [paragraph.get_size().x, paragraph.get_size().y],
		"families": families,
		"styles": styles,
		"weights": weights,
		"used_faces": glyph_faces(server, paragraph),
		"process_frame": Engine.get_process_frames(),
	}
	tutorial_draws.append(record)


## Читает font RID каждого сформированного глифа, отделяя использованную гарнитуру от запасных.
func glyph_faces(server: TextServer, paragraph: TextParagraph) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for line in paragraph.get_line_count():
		for glyph in server.shaped_text_get_glyphs(paragraph.get_line_rid(line)):
			var rid: RID = glyph.font_rid
			if not rid.is_valid():
				continue
			var face := {
				"family": server.font_get_name(rid),
				"style": server.font_get_style_name(rid),
				"weight": server.font_get_weight(rid),
			}
			var key := JSON.stringify(face)
			if not seen.has(key):
				seen[key] = true
				result.append(face)
	return result
