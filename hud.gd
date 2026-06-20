extends Control
## Screen-space game HUD: compact stat bars + a bottom tool action bar.
## Reads state from the Main node (set as `game`). Draws only during play;
## the menu/board/help text overlays are handled by Main's Label + Dim.

const TOOL_LABELS := ["Hoe", "Seed", "Water", "Hand"]
const TOOL_ICON_NAMES := ["tool_hoe", "tool_seed", "tool_water", "tool_hand"]
const MAX_ENERGY := 100.0
const MAX_WATER := 20.0
const MAX_HP := 50.0

var game: Node = null
var icons := {}


func _ready() -> void:
	for n in TOOL_ICON_NAMES:
		var p: String = "res://assets/" + str(n) + ".png"
		icons[n] = load(p) if ResourceLoader.exists(p) else null


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or not game.is_playing():
		return
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size
	_status(font)
	_actionbar(font, vp)
	_quest(font, vp)
	draw_string(font, Vector2(12, vp.y - 12), "[H] Controls",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.82, 0.88))


func _panel(r: Rect2, fill := Color(0.06, 0.08, 0.12, 0.80)) -> void:
	draw_rect(r, fill)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)


func _bar(font: Font, x: float, y: float, w: float, frac: float, col: Color, label: String) -> void:
	var h := 12.0
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, y, w * clampf(frac, 0.0, 1.0), h), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.20), false, 1.0)
	draw_string(font, Vector2(x + 5, y + h - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))


func _status(font: Font) -> void:
	_panel(Rect2(8, 8, 226, 92))
	var top := "Day %d   %s   %s   $%d" % [game.day, game.season_name(), game.clock_text(), game.money]
	draw_string(font, Vector2(16, 27), top, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.7))
	_bar(font, 16, 40, 202, game.energy / MAX_ENERGY, Color(0.95, 0.8, 0.2), "Energy %d" % int(game.energy))
	_bar(font, 16, 60, 202, float(game.water) / MAX_WATER, Color(0.3, 0.6, 0.95), "Water %d/%d" % [game.water, int(MAX_WATER)])
	_bar(font, 16, 80, 202, game.hp / MAX_HP, Color(0.85, 0.3, 0.35), "HP %d/%d" % [int(game.hp), int(MAX_HP)])


func _actionbar(font: Font, vp: Vector2) -> void:
	var n := 4
	var sw := 46.0
	var gap := 8.0
	var total := n * sw + (n - 1) * gap
	var x0 := (vp.x - total) / 2.0
	var y := vp.y - sw - 16.0

	draw_string(font, Vector2(x0, y - 7), "Q: switch tool", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.85))

	for i in n:
		var rx := x0 + i * (sw + gap)
		var r := Rect2(rx, y, sw, sw)
		var sel: bool = (i == game.current_tool)
		_panel(r, Color(0.24, 0.27, 0.15, 0.95) if sel else Color(0.10, 0.11, 0.16, 0.85))
		if sel:
			draw_rect(r, Color(1, 0.85, 0.25), false, 3.0)
		var ic = icons.get(TOOL_ICON_NAMES[i])
		if ic != null:
			draw_texture_rect(ic, Rect2(rx + 7, y + 5, 32, 32), false)
		else:
			draw_string(font, Vector2(rx + 16, y + 30), TOOL_LABELS[i].substr(0, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
		draw_string(font, Vector2(rx, y + sw - 3), TOOL_LABELS[i],
			HORIZONTAL_ALIGNMENT_CENTER, sw, 10, Color(1, 1, 0.8) if sel else Color(0.78, 0.78, 0.82))

	# Seed chip to the right of the bar.
	var cx := x0 + total + 16.0
	var cr := Rect2(cx, y, 158, sw)
	_panel(cr)
	var sic = icons.get("tool_seed")
	if sic != null:
		draw_texture_rect(sic, Rect2(cx + 7, y + 7, 32, 32), false)
	draw_string(font, Vector2(cx + 46, y + 20), "%s x%d" % [game.selected_seed_name(), game.selected_seed_count()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	var ins: bool = game.selected_seed_in_season()
	draw_string(font, Vector2(cx + 46, y + 37), ("in season" if ins else "out of season") + "  (1/2/3)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.9, 0.5) if ins else Color(1, 0.5, 0.4))


func _quest(font: Font, vp: Vector2) -> void:
	var qt := "Quests %d/%d" % [game._quests_done_count(), game.quest_total()]
	draw_string(font, Vector2(vp.x - 332, 26), qt, HORIZONTAL_ALIGNMENT_RIGHT, 324, 13, Color(1, 1, 1))
	draw_string(font, Vector2(vp.x - 452, 44), game.next_quest_text(), HORIZONTAL_ALIGNMENT_RIGHT, 444, 11, Color(0.85, 0.9, 1))
