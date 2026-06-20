extends Node2D
## StardewLike — vertical-slice farming + combat prototype.
## Everything is drawn procedurally (colored rectangles) so the project runs
## with zero art assets. Swap in real sprites later; the game logic stays put.

const GRID_W := 16
const GRID_H := 12
const TILE := 32
const PLAYER_SPEED := 95.0

const MAX_ENERGY := 100.0
const MAX_WATER := 20
const MAX_HP := 50.0
const SAVE_PATH := "user://savegame.json"

# Clock: game minutes. Day runs 6:00 AM (360) to 2:00 AM next day (1560).
const DAY_START := 360
const DAY_END := 1560
const TIME_RATE := 10.0  # game-minutes per real second

const CLEAR_COST := 6.0
const CLEAR_REWARD := 8

const WELL_POS := Vector2i(1, 1)
const BOARD_POS := Vector2i(14, 1)
const MINE_POS := Vector2i(1, 10)
const DUNGEON_POS := Vector2i(14, 10)
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]

# Combat tuning.
const ATTACK_REACH := 44.0
const ATTACK_COOLDOWN := 0.35
const SWORD_DMG := 25
const ENEMY_SPEED := 46.0
const ENEMY_TOUCH := 22.0
const ENEMY_HIT_CD := 1.0
const ENEMY_BASE_DMG := 7
const ORE_HP := 50
const ORE_REWARD := 25
const DUNGEON_FLOORS := 3
const DUNGEON_CLEAR_REWARD := 200

enum State { TITLE, PLAY, BOARD, COMBAT }
enum Soil { GRASS, TILLED, WATERED }
enum Tool { HOE, SEED, WATER, HAND }

const TOOL_NAMES := ["Hoe", "Seeds", "Watering Can", "Hand"]
const TOOL_COST := {Tool.HOE: 4.0, Tool.SEED: 1.0, Tool.WATER: 2.0, Tool.HAND: 1.0}

const CROPS := [
	{"name": "Parsnip", "stages": 3, "value": 35, "color": Color(0.92, 0.86, 0.55), "seasons": [0, 1]},
	{"name": "Potato", "stages": 5, "value": 90, "color": Color(0.74, 0.55, 0.35), "seasons": [1, 2]},
	{"name": "Cauliflower", "stages": 7, "value": 200, "color": Color(0.95, 0.96, 0.88), "seasons": [2, 3, 0]},
]
const SEED_PRICE := [20, 50, 80]

const QUESTS := [
	{"desc": "Harvest your first crop", "kind": "harvest_any", "target": 1, "reward": 30},
	{"desc": "Harvest 5 crops", "kind": "harvest_any", "target": 5, "reward": 60},
	{"desc": "Harvest 20 crops", "kind": "harvest_any", "target": 20, "reward": 150},
	{"desc": "Harvest 50 crops", "kind": "harvest_any", "target": 50, "reward": 300},
	{"desc": "Plant 5 seeds", "kind": "planted", "target": 5, "reward": 30},
	{"desc": "Plant 25 seeds", "kind": "planted", "target": 25, "reward": 120},
	{"desc": "Water crops 10 times", "kind": "watered", "target": 10, "reward": 40},
	{"desc": "Water crops 40 times", "kind": "watered", "target": 40, "reward": 120},
	{"desc": "Clear 3 trees or rocks", "kind": "cleared", "target": 3, "reward": 40},
	{"desc": "Clear 10 trees or rocks", "kind": "cleared", "target": 10, "reward": 120},
	{"desc": "Harvest 10 Parsnips", "kind": "harvest_type", "type": 0, "target": 10, "reward": 80},
	{"desc": "Harvest 5 Potatoes", "kind": "harvest_type", "type": 1, "target": 5, "reward": 150},
	{"desc": "Harvest 3 Cauliflowers", "kind": "harvest_type", "type": 2, "target": 3, "reward": 250},
	{"desc": "Defeat 5 enemies", "kind": "kills", "target": 5, "reward": 60},
	{"desc": "Defeat 25 enemies", "kind": "kills", "target": 25, "reward": 150},
	{"desc": "Reach mine floor 5", "kind": "depth", "target": 5, "reward": 200},
	{"desc": "Survive to Day 7 (a full week)", "kind": "day", "target": 7, "reward": 120},
	{"desc": "Earn $300 from crops", "kind": "earned", "target": 300, "reward": 100},
	{"desc": "Earn $1000 from crops -- WIN!", "kind": "earned", "target": 1000, "reward": 500, "win": true},
]

var state: int = State.TITLE

# Farm grids.
var soil := []
var crop_type := []
var crop_stage := []
var crop_watered := []
var obstacle := []

var player_pos := Vector2(256, 192)
var facing := Vector2(0, 1)
var current_tool: int = Tool.HOE
var selected_seed: int = 0
var seeds := [5, 0, 0]

var day := 1
var money := 0
var energy := MAX_ENERGY
var water := MAX_WATER
var hp := MAX_HP
var clock: float = DAY_START
var won := false

var c_harvested := 0
var c_harvested_type := [0, 0, 0]
var c_earned := 0
var c_cleared := 0
var c_planted := 0
var c_watered := 0
var c_kills := 0
var c_deepest := 0

var quest_done := []

# Optional sprite textures, loaded from res://assets/<name>.png if present.
# When a texture is missing the renderer falls back to procedural rectangles,
# so the game runs identically with or without art.
const TEX_NAMES := ["grass", "tilled", "watered", "tree", "rock", "well", "board", "mine", "dungeon", "player"]
var tex := {}

# Combat state (transient — not saved).
var cb_mode := "mine"
var cb_floor := 1
var cb_walls := []        # [y][x] bool
var cb_ore := []          # [y][x] int hp (0 = none)
var cb_stairs := Vector2i(8, 6)
var cb_player := Vector2(80, 80)
var enemies := []         # [{pos, hp, maxhp, cd, dmg}]
var attack_cd := 0.0
var swing_timer := 0.0

var show_help := false

@onready var hud: Label = $HUD/Label
@onready var dim: ColorRect = $HUD/Dim
@onready var hud_ui: Control = $HUD/Hud


func _ready() -> void:
	quest_done.resize(QUESTS.size())
	_load_textures()
	hud_ui.game = self
	_reset_progress()
	_init_grids()
	state = State.TITLE
	_update_hud()
	queue_redraw()


func _reset_progress() -> void:
	for i in QUESTS.size():
		quest_done[i] = false
	day = 1
	money = 0
	energy = MAX_ENERGY
	water = MAX_WATER
	hp = MAX_HP
	clock = DAY_START
	won = false
	current_tool = Tool.HOE
	selected_seed = 0
	seeds = [5, 0, 0]
	player_pos = Vector2(256, 192)
	c_harvested = 0
	c_harvested_type = [0, 0, 0]
	c_earned = 0
	c_cleared = 0
	c_planted = 0
	c_watered = 0
	c_kills = 0
	c_deepest = 0


func _start_game(do_continue: bool) -> void:
	_reset_progress()
	_init_grids()
	if do_continue:
		_load_game()
	state = State.PLAY
	_check_quests()
	_update_hud()
	queue_redraw()


func _init_grids() -> void:
	soil.clear()
	crop_type.clear()
	crop_stage.clear()
	crop_watered.clear()
	obstacle.clear()
	soil.resize(GRID_H)
	crop_type.resize(GRID_H)
	crop_stage.resize(GRID_H)
	crop_watered.resize(GRID_H)
	obstacle.resize(GRID_H)
	for y in GRID_H:
		var rs := []
		var rt := []
		var rg := []
		var rw := []
		var ro := []
		rs.resize(GRID_W)
		rt.resize(GRID_W)
		rg.resize(GRID_W)
		rw.resize(GRID_W)
		ro.resize(GRID_W)
		for x in GRID_W:
			rs[x] = Soil.GRASS
			rt[x] = -1
			rg[x] = 0
			rw[x] = false
			ro[x] = 0
		soil[y] = rs
		crop_type[y] = rt
		crop_stage[y] = rg
		crop_watered[y] = rw
		obstacle[y] = ro
	_scatter_obstacles()


func _scatter_obstacles() -> void:
	var spawn := Vector2i(8, 6)
	var reserved := [WELL_POS, BOARD_POS, MINE_POS, DUNGEON_POS]
	var placed := 0
	while placed < 16:
		var x := randi_range(0, GRID_W - 1)
		var y := randi_range(0, GRID_H - 1)
		if absi(x - spawn.x) <= 1 and absi(y - spawn.y) <= 1:
			continue
		if Vector2i(x, y) in reserved:
			continue
		if obstacle[y][x] != 0:
			continue
		obstacle[y][x] = 1 if randf() < 0.5 else 2
		placed += 1


# ----------------------------------------------------------------------------
# MAIN LOOP
# ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.PLAY:
		_process_farm(delta)
	elif state == State.COMBAT:
		_process_combat(delta)


func _process_farm(delta: float) -> void:
	clock += TIME_RATE * delta
	if clock >= DAY_END:
		_sleep(true)
		return
	var dir := _move_dir()
	if dir != Vector2.ZERO:
		facing = dir
		var nx := player_pos.x + dir.x * PLAYER_SPEED * delta
		if not _is_blocked(nx, player_pos.y):
			player_pos.x = clampf(nx, 0.0, float(GRID_W * TILE))
		var ny := player_pos.y + dir.y * PLAYER_SPEED * delta
		if not _is_blocked(player_pos.x, ny):
			player_pos.y = clampf(ny, 0.0, float(GRID_H * TILE))
	queue_redraw()


func _move_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	return dir


func _is_blocked(px: float, py: float) -> bool:
	var tx := int(px / TILE)
	var ty := int(py / TILE)
	if tx < 0 or ty < 0 or tx >= GRID_W or ty >= GRID_H:
		return false
	var here := Vector2i(tx, ty)
	if here == WELL_POS or here == BOARD_POS or here == MINE_POS or here == DUNGEON_POS:
		return true
	return obstacle[ty][tx] != 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc == KEY_F11:  # fullscreen toggle works in any state
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	match state:
		State.TITLE:
			if kc == KEY_ENTER or kc == KEY_KP_ENTER:
				_start_game(true)
			elif kc == KEY_N:
				_start_game(false)
		State.BOARD:
			if kc == KEY_T or kc == KEY_ESCAPE:
				state = State.PLAY
				_update_hud()
				queue_redraw()
		State.PLAY:
			_play_input(kc)
		State.COMBAT:
			_combat_input(kc)


func _play_input(kc: int) -> void:
	match kc:
		KEY_Q:
			current_tool = (current_tool + 1) % TOOL_NAMES.size()
			_update_hud()
		KEY_1:
			selected_seed = 0
			_update_hud()
		KEY_2:
			selected_seed = 1
			_update_hud()
		KEY_3:
			selected_seed = 2
			_update_hud()
		KEY_B:
			_buy_seed()
		KEY_C:
			_clear_obstacle()
		KEY_R:
			_refill_water()
		KEY_T:
			_try_open_board()
		KEY_G:
			_try_enter_combat()
		KEY_H:
			show_help = not show_help
			_update_hud()
		KEY_ESCAPE:
			if show_help:
				show_help = false
				_update_hud()
			else:
				state = State.TITLE
				_update_hud()
				queue_redraw()
		KEY_E, KEY_SPACE:
			_use_tool()
		KEY_ENTER, KEY_KP_ENTER:
			_sleep(false)


# ----------------------------------------------------------------------------
# FARM HELPERS
# ----------------------------------------------------------------------------

func _current_tile() -> Vector2i:
	return Vector2i(
		clampi(int(player_pos.x / TILE), 0, GRID_W - 1),
		clampi(int(player_pos.y / TILE), 0, GRID_H - 1))


func _facing_tile() -> Vector2i:
	var t := _current_tile()
	return Vector2i(
		clampi(t.x + int(round(facing.x)), 0, GRID_W - 1),
		clampi(t.y + int(round(facing.y)), 0, GRID_H - 1))


func _near(pos: Vector2i) -> bool:
	var t := _current_tile()
	return absi(t.x - pos.x) <= 1 and absi(t.y - pos.y) <= 1


func _is_ripe(x: int, y: int) -> bool:
	var ct: int = crop_type[y][x]
	return ct >= 0 and crop_stage[y][x] >= CROPS[ct]["stages"]


func _season_index() -> int:
	@warning_ignore("integer_division")
	return ((day - 1) / 7) % 4


func _seed_in_season(idx: int) -> bool:
	return _season_index() in CROPS[idx]["seasons"]


func _try_open_board() -> void:
	if _near(BOARD_POS):
		state = State.BOARD
		_update_hud()
		queue_redraw()


func _try_enter_combat() -> void:
	if _near(MINE_POS):
		_enter_combat("mine")
	elif _near(DUNGEON_POS):
		_enter_combat("dungeon")


func _buy_seed() -> void:
	var price: int = SEED_PRICE[selected_seed]
	if money >= price:
		money -= price
		seeds[selected_seed] += 1
		_update_hud()


func _refill_water() -> void:
	if _near(WELL_POS):
		water = MAX_WATER
		_update_hud()


func _clear_obstacle() -> void:
	if energy < CLEAR_COST:
		return
	var t := _facing_tile()
	if obstacle[t.y][t.x] != 0:
		obstacle[t.y][t.x] = 0
		money += CLEAR_REWARD
		energy -= CLEAR_COST
		c_cleared += 1
		_check_quests()
		_update_hud()
		queue_redraw()


func _use_tool() -> void:
	var cost: float = TOOL_COST[current_tool]
	if energy < cost:
		return
	var t := _current_tile()
	var x := t.x
	var y := t.y
	if obstacle[y][x] != 0:
		return
	var did_work := false
	match current_tool:
		Tool.HOE:
			if soil[y][x] == Soil.GRASS:
				soil[y][x] = Soil.TILLED
				did_work = true
		Tool.SEED:
			if soil[y][x] != Soil.GRASS and crop_type[y][x] == -1 \
					and seeds[selected_seed] > 0 and _seed_in_season(selected_seed):
				crop_type[y][x] = selected_seed
				crop_stage[y][x] = 0
				seeds[selected_seed] -= 1
				c_planted += 1
				did_work = true
		Tool.WATER:
			if soil[y][x] != Soil.GRASS and water > 0:
				soil[y][x] = Soil.WATERED
				water -= 1
				if crop_type[y][x] >= 0:
					crop_watered[y][x] = true
					c_watered += 1
				did_work = true
		Tool.HAND:
			if _is_ripe(x, y):
				var val: int = CROPS[crop_type[y][x]]["value"]
				money += val
				c_earned += val
				c_harvested += 1
				c_harvested_type[crop_type[y][x]] += 1
				crop_type[y][x] = -1
				crop_stage[y][x] = 0
				crop_watered[y][x] = false
				did_work = true
	if did_work:
		energy -= cost
		_check_quests()
		_update_hud()
		queue_redraw()


func _sleep(collapsed: bool) -> void:
	for y in GRID_H:
		for x in GRID_W:
			if crop_type[y][x] >= 0 and not _is_ripe(x, y) and crop_watered[y][x]:
				crop_stage[y][x] += 1
			crop_watered[y][x] = false
			if soil[y][x] == Soil.WATERED:
				soil[y][x] = Soil.TILLED
	day += 1
	clock = DAY_START
	water = MAX_WATER
	hp = MAX_HP  # a good night's rest heals you
	energy = MAX_ENERGY * (0.6 if collapsed else 1.0)
	_check_quests()
	_save_game()
	_update_hud()
	queue_redraw()


# ----------------------------------------------------------------------------
# COMBAT
# ----------------------------------------------------------------------------

func _enter_combat(mode: String) -> void:
	cb_mode = mode
	cb_floor = 1
	_gen_floor()
	state = State.COMBAT
	_update_hud()
	queue_redraw()


func _gen_floor() -> void:
	cb_walls.clear()
	cb_ore.clear()
	cb_walls.resize(GRID_H)
	cb_ore.resize(GRID_H)
	for y in GRID_H:
		var rw := []
		var ro := []
		rw.resize(GRID_W)
		ro.resize(GRID_W)
		for x in GRID_W:
			# Solid border wall, open interior.
			rw[x] = (x == 0 or y == 0 or x == GRID_W - 1 or y == GRID_H - 1)
			ro[x] = 0
		cb_walls[y] = rw
		cb_ore[y] = ro

	cb_player = Vector2(2 * TILE + TILE / 2.0, 2 * TILE + TILE / 2.0)
	var start_tile := Vector2i(2, 2)

	# Stairs: a random open tile away from the start.
	cb_stairs = _random_open_tile(start_tile, 5, [])

	# A few interior rocks (treated as walls), kept sparse to stay traversable.
	var rocks := 5
	while rocks > 0:
		var rx := randi_range(2, GRID_W - 3)
		var ry := randi_range(2, GRID_H - 3)
		var rt := Vector2i(rx, ry)
		if rt == start_tile or rt == cb_stairs or cb_walls[ry][rx]:
			continue
		cb_walls[ry][rx] = true
		rocks -= 1

	# Ore nodes (mine only).
	if cb_mode == "mine":
		var nodes := 3
		while nodes > 0:
			var t := _random_open_tile(start_tile, 3, [cb_stairs])
			if cb_ore[t.y][t.x] == 0:
				cb_ore[t.y][t.x] = ORE_HP
				nodes -= 1

	# Enemies scale with floor.
	enemies.clear()
	var count: int = mini(3 + cb_floor, 8)
	var ehp: int = 30 + (cb_floor - 1) * 12
	var edmg: int = ENEMY_BASE_DMG + cb_floor
	for i in count:
		var t := _random_open_tile(start_tile, 4, [cb_stairs])
		enemies.append({
			"pos": Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0),
			"hp": ehp, "maxhp": ehp, "cd": 0.0, "dmg": edmg,
		})


func _random_open_tile(avoid: Vector2i, min_dist: int, extra: Array) -> Vector2i:
	for attempt in 200:
		var x := randi_range(1, GRID_W - 2)
		var y := randi_range(1, GRID_H - 2)
		var t := Vector2i(x, y)
		if cb_walls[y][x]:
			continue
		if absi(x - avoid.x) + absi(y - avoid.y) < min_dist:
			continue
		if t in extra:
			continue
		return t
	return Vector2i(GRID_W - 2, GRID_H - 2)


func _combat_input(kc: int) -> void:
	match kc:
		KEY_E, KEY_SPACE:
			_attack()
		KEY_G:
			_descend()
		KEY_ESCAPE:
			_exit_combat(false)


func _cb_blocked(px: float, py: float) -> bool:
	var tx := int(px / TILE)
	var ty := int(py / TILE)
	if tx < 0 or ty < 0 or tx >= GRID_W or ty >= GRID_H:
		return true
	if cb_walls[ty][tx]:
		return true
	return cb_ore[ty][tx] > 0


func _cb_tile() -> Vector2i:
	return Vector2i(int(cb_player.x / TILE), int(cb_player.y / TILE))


func _process_combat(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	swing_timer = maxf(0.0, swing_timer - delta)

	# Player movement.
	var dir := _move_dir()
	if dir != Vector2.ZERO:
		facing = dir
		var nx := cb_player.x + dir.x * PLAYER_SPEED * delta
		if not _cb_blocked(nx, cb_player.y):
			cb_player.x = nx
		var ny := cb_player.y + dir.y * PLAYER_SPEED * delta
		if not _cb_blocked(cb_player.x, ny):
			cb_player.y = ny

	# Enemy AI: drift toward the player, bite on contact.
	for e in enemies:
		e["cd"] = maxf(0.0, e["cd"] - delta)
		var p: Vector2 = e["pos"]
		var to: Vector2 = cb_player - p
		var dist := to.length()
		if dist > ENEMY_TOUCH:
			var step: Vector2 = to.normalized() * ENEMY_SPEED * delta
			if not _cb_blocked(p.x + step.x, p.y):
				p.x += step.x
			if not _cb_blocked(p.x, p.y + step.y):
				p.y += step.y
			e["pos"] = p  # write the Vector2 back (it's a value type)
		elif e["cd"] <= 0.0:
			hp -= e["dmg"]
			e["cd"] = ENEMY_HIT_CD
			if hp <= 0.0:
				_exit_combat(true)
				return
	queue_redraw()


func _attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = ATTACK_COOLDOWN
	swing_timer = 0.15

	# Hit enemies in front within reach.
	var survivors := []
	for e in enemies:
		var to: Vector2 = e["pos"] - cb_player
		var d := to.length()
		var in_arc := d < 18.0 or (d <= ATTACK_REACH and facing.dot(to.normalized()) > 0.2)
		if in_arc:
			e["hp"] -= SWORD_DMG
		if e["hp"] > 0:
			survivors.append(e)
		else:
			c_kills += 1
			money += 5  # small drop
	if survivors.size() != enemies.size():
		enemies = survivors
		_check_quests()

	# Mine ore in the facing tile.
	var ft := Vector2i(
		clampi(int(cb_player.x / TILE) + int(round(facing.x)), 0, GRID_W - 1),
		clampi(int(cb_player.y / TILE) + int(round(facing.y)), 0, GRID_H - 1))
	if cb_ore[ft.y][ft.x] > 0:
		cb_ore[ft.y][ft.x] -= SWORD_DMG
		if cb_ore[ft.y][ft.x] <= 0:
			cb_ore[ft.y][ft.x] = 0
			money += ORE_REWARD
	_update_hud()
	queue_redraw()


func _descend() -> void:
	var t := _cb_tile()
	var on_stairs := absi(t.x - cb_stairs.x) <= 1 and absi(t.y - cb_stairs.y) <= 1
	if not on_stairs:
		return
	if cb_mode == "dungeon":
		if not enemies.is_empty():
			return  # clear the floor first
		if cb_floor >= DUNGEON_FLOORS:
			money += DUNGEON_CLEAR_REWARD
			_exit_combat(false)
			return
	cb_floor += 1
	c_deepest = maxi(c_deepest, cb_floor)
	_check_quests()
	_gen_floor()
	_update_hud()
	queue_redraw()


func _exit_combat(defeated: bool) -> void:
	if defeated:
		money = maxi(0, money - 50)
		hp = MAX_HP * 0.5
	state = State.PLAY
	_save_game()
	_update_hud()
	queue_redraw()


# ----------------------------------------------------------------------------
# QUESTS
# ----------------------------------------------------------------------------

func _quest_value(q: Dictionary) -> int:
	match q["kind"]:
		"harvest_any": return c_harvested
		"harvest_type": return c_harvested_type[q["type"]]
		"earned": return c_earned
		"cleared": return c_cleared
		"planted": return c_planted
		"watered": return c_watered
		"kills": return c_kills
		"depth": return c_deepest
		"day": return day
	return 0


func _check_quests() -> void:
	for i in QUESTS.size():
		if not quest_done[i] and _quest_value(QUESTS[i]) >= QUESTS[i]["target"]:
			quest_done[i] = true
			money += QUESTS[i]["reward"]
			if QUESTS[i].get("win", false):
				won = true


func _quests_done_count() -> int:
	var n := 0
	for i in QUESTS.size():
		if quest_done[i]:
			n += 1
	return n


# ----------------------------------------------------------------------------
# DRAW
# ----------------------------------------------------------------------------

func _load_textures() -> void:
	for n in TEX_NAMES:
		var p: String = "res://assets/" + str(n) + ".png"
		tex[n] = load(p) if ResourceLoader.exists(p) else null


func _blit(name: String, rect: Rect2) -> bool:
	# Draw the named sprite into rect; return false if no texture is loaded
	# so callers can fall back to procedural drawing.
	var t = tex.get(name)
	if t == null:
		return false
	draw_texture_rect(t, rect, false)
	return true


func _draw() -> void:
	if state == State.COMBAT:
		_draw_combat()
		return
	_draw_farm()


func _draw_farm() -> void:
	for y in GRID_H:
		for x in GRID_W:
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			var col := Color(0.36, 0.62, 0.30)
			if soil[y][x] == Soil.TILLED:
				col = Color(0.47, 0.32, 0.21)
			elif soil[y][x] == Soil.WATERED:
				col = Color(0.30, 0.20, 0.13)
			var gname := "grass"
			if soil[y][x] == Soil.TILLED:
				gname = "tilled"
			elif soil[y][x] == Soil.WATERED:
				gname = "watered"
			if not _blit(gname, rect):
				draw_rect(rect, col)
				draw_rect(rect, Color(0, 0, 0, 0.10), false, 1.0)

			var here := Vector2i(x, y)
			if here == WELL_POS:
				if not _blit("well", rect):
					draw_rect(Rect2(x * TILE + 4, y * TILE + 4, TILE - 8, TILE - 8), Color(0.35, 0.30, 0.28))
					draw_rect(Rect2(x * TILE + 8, y * TILE + 8, TILE - 16, TILE - 16), Color(0.25, 0.55, 0.85))
				continue
			if here == BOARD_POS:
				if not _blit("board", rect):
					draw_rect(Rect2(x * TILE + 4, y * TILE + 6, TILE - 8, TILE - 14), Color(0.55, 0.40, 0.22))
					draw_rect(Rect2(x * TILE + 13, y * TILE + 18, 6, 12), Color(0.35, 0.24, 0.12))
				continue
			if here == MINE_POS:
				if not _blit("mine", rect):
					draw_rect(Rect2(x * TILE + 3, y * TILE + 3, TILE - 6, TILE - 6), Color(0.30, 0.28, 0.30))
					draw_circle(Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0 + 3), 8.0, Color(0.05, 0.05, 0.08))
				continue
			if here == DUNGEON_POS:
				if not _blit("dungeon", rect):
					draw_rect(Rect2(x * TILE + 3, y * TILE + 3, TILE - 6, TILE - 6), Color(0.32, 0.22, 0.30))
					draw_circle(Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0 + 3), 8.0, Color(0.08, 0.03, 0.10))
				continue

			var ob: int = obstacle[y][x]
			if ob == 1:
				if not _blit("tree", rect):
					draw_rect(Rect2(x * TILE + 13, y * TILE + 16, 6, 14), Color(0.40, 0.26, 0.13))
					draw_circle(Vector2(x * TILE + TILE / 2.0, y * TILE + 13), 12.0, Color(0.16, 0.45, 0.20))
			elif ob == 2:
				if not _blit("rock", rect):
					draw_rect(Rect2(x * TILE + 7, y * TILE + 10, 18, 15), Color(0.55, 0.55, 0.62))
			else:
				var ct: int = crop_type[y][x]
				if ct >= 0:
					var max_stage: int = CROPS[ct]["stages"]
					var tt := float(crop_stage[y][x]) / float(max_stage)
					var crop_col := Color(0.20, 0.55, 0.20).lerp(CROPS[ct]["color"], tt)
					var sz := lerpf(8.0, 26.0, tt)
					draw_rect(Rect2(
						x * TILE + (TILE - sz) / 2.0,
						y * TILE + (TILE - sz) / 2.0,
						sz, sz), crop_col)
					if _is_ripe(x, y):
						draw_rect(rect, Color(1, 0.9, 0.2, 0.9), false, 2.0)

	if not _blit("player", Rect2(player_pos.x - 16, player_pos.y - 24, 32, 32)):
		draw_rect(Rect2(player_pos.x - 9, player_pos.y - 13, 18, 26), Color(0.88, 0.28, 0.28))
		draw_circle(player_pos + facing * 14.0, 3.0, Color(1, 1, 0.4))
	var ot := _current_tile()
	draw_rect(Rect2(ot.x * TILE, ot.y * TILE, TILE, TILE), Color(1, 1, 1, 0.9), false, 2.0)


func _draw_combat() -> void:
	for y in GRID_H:
		for x in GRID_W:
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if cb_walls[y][x]:
				draw_rect(rect, Color(0.22, 0.22, 0.26))
			else:
				draw_rect(rect, Color(0.13, 0.12, 0.15))
			draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)
			if cb_ore[y][x] > 0:
				draw_rect(Rect2(x * TILE + 6, y * TILE + 6, TILE - 12, TILE - 12), Color(0.62, 0.45, 0.30))
				draw_rect(Rect2(x * TILE + 11, y * TILE + 11, 8, 8), Color(0.85, 0.75, 0.40))

	# Stairs.
	var locked := cb_mode == "dungeon" and not enemies.is_empty()
	var stair_col := Color(0.4, 0.4, 0.45) if locked else Color(0.95, 0.85, 0.30)
	draw_rect(Rect2(cb_stairs.x * TILE + 4, cb_stairs.y * TILE + 4, TILE - 8, TILE - 8), stair_col)

	# Enemies with hp bars.
	for e in enemies:
		draw_circle(e["pos"], 11.0, Color(0.75, 0.20, 0.25))
		draw_circle(e["pos"], 11.0, Color(0, 0, 0, 0.4))
		var frac := float(e["hp"]) / float(e["maxhp"])
		draw_rect(Rect2(e["pos"].x - 11, e["pos"].y - 18, 22, 3), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(e["pos"].x - 11, e["pos"].y - 18, 22.0 * frac, 3), Color(0.3, 0.9, 0.3))

	# Player + swing arc.
	draw_rect(Rect2(cb_player.x - 9, cb_player.y - 13, 18, 26), Color(0.30, 0.55, 0.90))
	if swing_timer > 0.0:
		draw_circle(cb_player + facing * 22.0, 10.0, Color(1, 1, 0.7, 0.7))
	else:
		draw_circle(cb_player + facing * 14.0, 3.0, Color(1, 1, 0.4))


# ----------------------------------------------------------------------------
# HUD TEXT
# ----------------------------------------------------------------------------

func _clock_string() -> String:
	var total := int(clock) % 1440
	@warning_ignore("integer_division")
	var h := total / 60
	var m := total % 60
	var ampm := "PM" if h >= 12 else "AM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]


func _title_text() -> String:
	var save_note := "Save found -- ENTER to continue." if FileAccess.file_exists(SAVE_PATH) \
		else "No save yet -- press ENTER or N to begin."
	return ("STARDEW-LIKE   (prototype)\n\n" + \
		"   ENTER  -  Continue / Start\n" + \
		"   N      -  New Game\n\n" + \
		"Farm by day; brave the Mines and Dungeon for combat.\n" + \
		"Visit the Quest Board (walk up + press T) for missions.\n" + \
		"Build a $1000 farm to win.\n\n" + save_note)


func _board_text() -> String:
	var in_season := []
	for i in CROPS.size():
		if _seed_in_season(i):
			in_season.append(CROPS[i]["name"])
	var season_line := "%s -- plantable now: %s\n\n" % \
		[SEASON_NAMES[_season_index()], ", ".join(in_season) if in_season.size() > 0 else "nothing"]
	var txt := "QUEST BOARD     (%d/%d complete)     [T or ESC to close]\n\n" % \
		[_quests_done_count(), QUESTS.size()]
	txt += season_line
	for i in QUESTS.size():
		var q: Dictionary = QUESTS[i]
		var box := "[x]" if quest_done[i] else "[ ]"
		txt += "%s %s   (%d/%d)   +$%d\n" % [box, q["desc"], _quest_value(q), q["target"], q["reward"]]
	return txt


# --- HUD accessors used by hud.gd ---

func is_playing() -> bool:
	return state == State.PLAY

func set_tool(i: int) -> void:
	current_tool = clampi(i, 0, TOOL_NAMES.size() - 1)
	_update_hud()

func cycle_seed() -> void:
	selected_seed = (selected_seed + 1) % CROPS.size()
	_update_hud()

func structure_prompt() -> String:
	if _near(MINE_POS):
		return "Press G to enter the Mine"
	if _near(DUNGEON_POS):
		return "Press G to enter the Dungeon"
	if _near(BOARD_POS):
		return "Press T to open the Quest Board"
	if _near(WELL_POS):
		return "Press R to refill your Watering Can"
	return ""

func season_name() -> String:
	return SEASON_NAMES[_season_index()]

func clock_text() -> String:
	return _clock_string()

func selected_seed_name() -> String:
	return CROPS[selected_seed]["name"]

func selected_seed_count() -> int:
	return seeds[selected_seed]

func selected_seed_in_season() -> bool:
	return _seed_in_season(selected_seed)

func quest_total() -> int:
	return QUESTS.size()

func next_quest_text() -> String:
	if won:
		return "*** YOU WIN! ***"
	for i in QUESTS.size():
		if not quest_done[i]:
			var q: Dictionary = QUESTS[i]
			return "Next: %s  (%d/%d)  +$%d" % [q["desc"], _quest_value(q), q["target"], q["reward"]]
	return "All quests complete!"


func _controls_help_text() -> String:
	return ("CONTROLS      [H or Esc to close]\n\n" + \
		"Move           WASD / Arrows\n" + \
		"Use tool       E or Space\n" + \
		"Switch tool    Q\n" + \
		"Select seed    1 / 2 / 3\n" + \
		"Buy seed       B\n" + \
		"Clear tree/rock   C\n" + \
		"Refill water (at well)   R\n" + \
		"Quest board (near it)    T\n" + \
		"Enter mine/dungeon (near it)   G\n" + \
		"Sleep          Enter\n" + \
		"Menu           Esc")


func _combat_text() -> String:
	var loc := "MINE" if cb_mode == "mine" else "DUNGEON"
	var header := "%s -- Floor %d     HP %d/%d     $%d     Enemies left: %d\n" % \
		[loc, cb_floor, int(hp), int(MAX_HP), money, enemies.size()]
	var help := "Move: WASD/Arrows     Attack: E/Space (face enemy or ore)\n"
	if cb_mode == "mine":
		help += "Stand on the gold stairs + G to go deeper.   ESC to leave the mine.\n"
		help += "Smash ore nodes for $%d each. Deeper = tougher enemies." % ORE_REWARD
	else:
		var gate := "Clear all enemies, then" if not enemies.is_empty() else "Stairs open --"
		help += "%s stand on the stairs + G to descend.   ESC to flee.\n" % gate
		help += "Reach floor %d and clear it for a $%d reward." % [DUNGEON_FLOORS, DUNGEON_CLEAR_REWARD]
	return header + help


func _update_hud() -> void:
	match state:
		State.TITLE:
			hud.text = _title_text()
		State.BOARD:
			hud.text = _board_text()
		State.COMBAT:
			hud.text = _combat_text()
		_:  # PLAY — rich HUD is drawn by hud.gd; Label only used for the help overlay
			hud.text = _controls_help_text() if show_help else ""
	dim.visible = state == State.TITLE or state == State.BOARD or (state == State.PLAY and show_help)


# ----------------------------------------------------------------------------
# SAVE / LOAD
# ----------------------------------------------------------------------------

func _save_game() -> void:
	var data := {
		"day": day, "money": money, "energy": energy, "water": water, "hp": hp, "won": won,
		"seeds": seeds,
		"c_harvested": c_harvested, "c_harvested_type": c_harvested_type,
		"c_earned": c_earned, "c_cleared": c_cleared,
		"c_planted": c_planted, "c_watered": c_watered,
		"c_kills": c_kills, "c_deepest": c_deepest,
		"quest_done": quest_done,
		"soil": soil, "crop_type": crop_type, "crop_stage": crop_stage,
		"crop_watered": crop_watered, "obstacle": obstacle,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	day = int(data.get("day", 1))
	money = int(data.get("money", 0))
	energy = float(data.get("energy", MAX_ENERGY))
	water = int(data.get("water", MAX_WATER))
	hp = float(data.get("hp", MAX_HP))
	won = bool(data.get("won", false))

	c_harvested = int(data.get("c_harvested", 0))
	c_earned = int(data.get("c_earned", 0))
	c_cleared = int(data.get("c_cleared", 0))
	c_planted = int(data.get("c_planted", 0))
	c_watered = int(data.get("c_watered", 0))
	c_kills = int(data.get("c_kills", 0))
	c_deepest = int(data.get("c_deepest", 0))

	var cht = data.get("c_harvested_type", [0, 0, 0])
	if cht.size() == 3:
		for i in 3:
			c_harvested_type[i] = int(cht[i])

	var sv = data.get("seeds", [5, 0, 0])
	if sv.size() == 3:
		for i in 3:
			seeds[i] = int(sv[i])

	var qd = data.get("quest_done", [])
	if qd.size() == QUESTS.size():
		for i in QUESTS.size():
			quest_done[i] = bool(qd[i])

	var s = data.get("soil", [])
	var rt = data.get("crop_type", [])
	var rg = data.get("crop_stage", [])
	var rw = data.get("crop_watered", [])
	var ro = data.get("obstacle", [])
	if s.size() != GRID_H or rt.size() != GRID_H:
		return false
	for y in GRID_H:
		for x in GRID_W:
			soil[y][x] = int(s[y][x])
			crop_type[y][x] = int(rt[y][x])
			crop_stage[y][x] = int(rg[y][x])
			crop_watered[y][x] = bool(rw[y][x])
			if ro.size() == GRID_H:
				obstacle[y][x] = int(ro[y][x])
	return true
