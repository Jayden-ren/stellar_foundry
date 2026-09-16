extends Node2D

const WORLD_W := 60
const WORLD_H := 40
const TILE_SIZE := 32

const TERRAINS := [Color(0.36, 0.42, 0.33), Color(0.45, 0.50, 0.36), Color(0.30, 0.33, 0.29), Color(0.42, 0.43, 0.45)]
const CONVEYOR_DIRS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
const PREVIEW_ALPHA := 0.55
const DEMOLISH_RATIO := 0.5

@onready var info_label: Label = $HUD/InfoLabel
@onready var legend_list: VBoxContainer = $HUD/PanelBox/VBox/LegendList
@onready var back_btn: Button = $HUD/BackBtn
@onready var building_type_label: Label = $HUD/BuildingTypeLabel
@onready var nav_demolish: Button = $HUD/NavBar/NavBarHBox/NavDemolish
@onready var sub_menu: PanelContainer = $HUD/SubMenu

enum ToolMode { BUILD, DEMOLISH }

var terrain: Array = []
var resource_nodes: Array = []
var placed_buildings: Array = []
var place_count: int = 0

var current_building_type: int = 0
var current_mode: int = ToolMode.BUILD
var _conveyor_direction: int = 0
var _mouse_world_pos: Vector2 = Vector2.ZERO
var _mouse_tile: Vector2i = Vector2i(-1, -1)
var _in_world_bounds: bool = false
var _hover_building: Dictionary = {}
var _placed_by_pos: Dictionary = {}
var _occupied_tiles: Dictionary = {}
var _resource_defs_by_id: Dictionary = {}

func _ready() -> void:
	back_btn.pressed.connect(_on_back_to_menu)
	nav_demolish.pressed.connect(_on_toggle_demolish)
	nav_demolish.pressed.connect(_refresh_nav_style)
	_load_resources()
	_generate_world()
	_spawn_resource_nodes()
	_build_legend()
	_refresh_nav_style()
	_update_info()
	_update_building_label()

func _load_resources() -> void:
	_resource_defs_by_id.clear()
	for md in BuildingRegistry.get_all_resources():
		if md and md.id != "":
			_resource_defs_by_id[md.id] = md

func _get_resource_by_smelt_output(output_id: String) -> MineralData:
	for rd in BuildingRegistry.get_all_resources():
		if rd and rd.smelt_output == output_id:
			return rd
	return null

func _generate_world() -> void:
	terrain.clear()
	for y in range(WORLD_H):
		var row: Array = []
		for x in range(WORLD_W):
			row.append(int(randf() * 3.0))
		terrain.append(row)

func _spawn_resource_nodes() -> void:
	resource_nodes.clear()
	var attempts := 0
	for md in BuildingRegistry.get_all_resources():
		if not md or md.spawn_count <= 0:
			continue
		for _i in range(md.spawn_count):
			while attempts < 10000:
				attempts += 1
				var pos := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
				if _is_tile_in_bounds(pos.x, pos.y) and terrain[pos.y][pos.x] == 0 and not _occupied_tiles.has(pos):
					_occupied_tiles[pos] = true
					resource_nodes.append({"pos": pos, "def": md, "claimed": false})
					break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_world_pos = get_global_mouse_position()
		_update_mouse_tile()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_click_at_mouse()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_right_click()
	elif event is InputEventKey and event.pressed and not (event.ctrl_pressed or event.meta_pressed):
		if event.keycode == KEY_ESCAPE:
			_on_escape()
		elif event.keycode == KEY_R and current_mode == ToolMode.BUILD:
			_conveyor_direction = (_conveyor_direction + 1) % 4
			_update_building_label()
			queue_redraw()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5 and current_mode == ToolMode.BUILD:
			var buildings := BuildingRegistry.get_game_world_buildings()
			var idx := int(event.keycode) - int(KEY_1)
			if idx < buildings.size():
				current_building_type = idx
				_update_building_label()
				queue_redraw()

func _update_mouse_tile() -> void:
	var tile := Vector2i(int(floorf(_mouse_world_pos.x / TILE_SIZE)), int(floorf(_mouse_world_pos.y / TILE_SIZE)))
	_mouse_tile = tile
	_in_world_bounds = _is_tile_in_bounds(tile.x, tile.y)
	_hover_building = _get_building_at_tile(tile)

func _physics_process(_delta: float) -> void:
	_tick_buildings()
	_update_info()

func _tick_buildings() -> void:
	var advanced := false
	for b in placed_buildings:
		var bd := b.get("def") as BuildingData
		if not bd or bd.cycle_interval <= 0.0:
			continue
		var timer := float(b.get("timer", 0.0)) + 1.0 / 60.0
		while timer >= bd.cycle_interval:
			timer -= bd.cycle_interval
			_process_building(b)
			advanced = true
			break
		b.timer = timer
	if advanced:
		queue_redraw()

func _process_building(b: Dictionary) -> void:
	var bd := b.get("def") as BuildingData
	if not bd:
		return
	match bd.id:
		"mining_drill":
			var md := b.get("mineral_def") as MineralData
			if md and _has_claimed_node_near(b):
				GameData.add_resource(md.id, max(1, int(round(md.yield_per_tick))))
		"smelter":
			_try_smelt()
		"trading_post":
			_try_sell()

func _has_claimed_node_near(b: Dictionary) -> bool:
	var pos: Vector2i = b.pos
	for node in resource_nodes:
		if node.claimed and node.def != b.get("mineral_def"):
			continue
		if abs(node.pos.x - pos.x) < 3 and abs(node.pos.y - pos.y) < 3:
			return true
	return false

func _try_smelt() -> void:
	for output_id in ["steel", "copper"]:
		var source := _get_resource_by_smelt_output(output_id)
		if source == null or not GameData.consume_resource(source.id, 1):
			continue
		GameData.add_resource(output_id, 1)

func _try_sell() -> void:
	var sold := 0
	for rd in BuildingRegistry.get_all_resources():
		var md: MineralData = rd
		if not md:
			continue
		var amount := int(GameData.resources.get(md.id, 0))
		if GameData.consume_resource(md.id, amount):
			sold += amount * md.price
	if sold > 0:
		GameData.add_money(sold)

func _on_click_at_mouse() -> void:
	if not _in_world_bounds:
		return
	if current_mode == ToolMode.DEMOLISH:
		_demolish_hover_building()
		return
	var bd := _current_building_def()
	if not bd:
		return
	if bd.id == "mining_drill":
		_place_mining_drill(_mouse_tile, bd)
	else:
		_place_building(_mouse_tile, bd)
	_update_info()
	queue_redraw()

func _on_right_click() -> void:
	if sub_menu.visible:
		sub_menu.visible = false
	if current_mode == ToolMode.DEMOLISH:
		current_mode = ToolMode.BUILD
		_refresh_nav_style()
	_update_building_label()
	queue_redraw()

func _on_escape() -> void:
	if sub_menu.visible:
		sub_menu.visible = false
		return
	if current_mode == ToolMode.DEMOLISH:
		current_mode = ToolMode.BUILD
		_refresh_nav_style()
	_update_building_label()
	queue_redraw()

func _on_toggle_demolish() -> void:
	current_mode = ToolMode.DEMOLISH if current_mode != ToolMode.DEMOLISH else ToolMode.BUILD
	_refresh_nav_style()
	_update_building_label()
	queue_redraw()

func _refresh_nav_style() -> void:
	nav_demolish.button_pressed = current_mode == ToolMode.DEMOLISH
	sub_menu.visible = current_mode == ToolMode.BUILD

func _draw() -> void:
	_draw_terrain()
	_draw_resource_nodes()
	_draw_buildings()
	_draw_hover()
	_draw_preview()

func _draw_terrain() -> void:
	for y in range(WORLD_H):
		for x in range(WORLD_W):
			var rect := Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, TERRAINS[int(terrain[y][x])])
			draw_rect(rect, Color(0, 0, 0, 0.10), false, 1.0)

func _draw_resource_nodes() -> void:
	for node in resource_nodes:
		if node.claimed:
			continue
		var pos := Vector2(node.pos.x * TILE_SIZE, node.pos.y * TILE_SIZE)
		var rect := Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE)).grow(-3)
		var md := node.def as MineralData
		draw_rect(rect, md.color if md else Color.WHITE)
		draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0)

func _draw_buildings() -> void:
	for b in placed_buildings:
		var pos := Vector2(b.pos.x * TILE_SIZE, b.pos.y * TILE_SIZE)
		var sz: int = int(b.get("size", 1))
		var rect := Rect2(pos, Vector2(TILE_SIZE * sz, TILE_SIZE * sz))
		draw_rect(rect, b.get("color", Color.WHITE))
		draw_rect(rect, Color(1, 1, 1, 0.45), false, 2.0)
		_draw_building_details(b, pos, sz)

func _draw_hover() -> void:
	if current_mode != ToolMode.DEMOLISH or _hover_building.is_empty() or not _in_world_bounds:
		return
	var b := _hover_building
	var pos := Vector2(int(b.pos.x) * TILE_SIZE, int(b.pos.y) * TILE_SIZE)
	var sz: int = int(b.get("size", 1))
	var rect := Rect2(pos, Vector2(TILE_SIZE * sz, TILE_SIZE * sz))
	draw_rect(rect, Color(1, 0.25, 0.25, 0.35))
	draw_rect(rect, Color(1, 0.35, 0.35, 1.0), false, 3.0)
	var center := pos + Vector2(TILE_SIZE * sz * 0.5, TILE_SIZE * sz * 0.5)
	draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), Color(1, 1, 1, 0.9), 3.0)
	draw_line(center + Vector2(8, -8), center + Vector2(-8, 8), Color(1, 1, 1, 0.9), 3.0)

func _draw_preview() -> void:
	if current_mode != ToolMode.BUILD or not _in_world_bounds:
		return
	var bd := _current_building_def()
	if not bd:
		return
	var pos := Vector2(_mouse_tile.x * TILE_SIZE, _mouse_tile.y * TILE_SIZE)
	var sz: int = bd.size
	var rect := Rect2(pos, Vector2(TILE_SIZE * sz, TILE_SIZE * sz))
	var valid := _can_place(_mouse_tile, sz) and GameData.money >= bd.cost and _preview_valid_for_special(bd)
	var fill := Color(bd.color.r, bd.color.g, bd.color.b, PREVIEW_ALPHA) if valid else Color(1, 0.3, 0.3, 0.35)
	draw_rect(rect, fill)
	draw_rect(rect, Color(1, 1, 1, 0.8 if valid else 0.6), false, 2.0)
	_draw_building_details({
		"id": bd.id,
		"size": sz,
		"timer": 0.0,
		"direction": _conveyor_direction,
		"mineral_def": _preview_mineral_def(bd)
	}, pos, sz)

func _draw_building_details(b: Dictionary, pos: Vector2, sz: int) -> void:
	match b.get("id"):
		"conveyor":
			_draw_conveyor_arrows(pos, Color(0.15, 0.50, 0.50), int(b.get("direction", 0)))
		"mining_drill":
			_draw_mining_drill(pos, sz, b.get("mineral_def") as MineralData)
		"smelter":
			_draw_smelter_flame(pos, true)
		"storage":
			_draw_storage_pattern(pos)
		"trading_post":
			_draw_trading_post(pos, true)

func _draw_conveyor_arrows(pos: Vector2, clr: Color, direction: int) -> void:
	var center := pos + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	var dir_vec: Vector2 = CONVEYOR_DIRS[_clamp_int(direction, 0, 3)]
	var perp := Vector2(-dir_vec.y, dir_vec.x)
	for i in range(3):
		var ax: Vector2 = center + dir_vec * (i - 1) * TILE_SIZE * 0.30
		draw_line(ax - perp * 5.0, ax + dir_vec * 5.0, clr, 2.0)
		draw_line(ax + dir_vec * 5.0, ax + perp * 5.0, clr, 2.0)

func _draw_mining_drill(pos: Vector2, sz: int, md: MineralData) -> void:
	var bs: float = TILE_SIZE * sz
	var center := pos + Vector2(bs * 0.5, bs * 0.5)
	var r: float = bs * 0.3
	draw_line(center + Vector2(-r, -r), center + Vector2(r, r), Color(0.20, 0.20, 0.20), 3.0)
	draw_line(center + Vector2(r, -r), center + Vector2(-r, r), Color(0.20, 0.20, 0.20), 3.0)
	draw_circle(center, r * 0.4, Color(0.20, 0.20, 0.20))
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2(6, 6)), md.color if md else Color(0.78, 0.78, 0.80))

func _draw_smelter_flame(pos: Vector2, active: bool) -> void:
	var center := pos + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	draw_colored_polygon([Vector2(center.x, pos.y + 6), center + Vector2(8, TILE_SIZE - 10), center + Vector2(-8, TILE_SIZE - 10)], Color(1.0, 0.6, 0.2, 0.8 if active else 0.3))

func _draw_storage_pattern(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(4, 4), Vector2(TILE_SIZE - 8, TILE_SIZE - 8)), Color(0.45, 0.45, 0.48), false, 1.0)

func _draw_trading_post(pos: Vector2, active: bool) -> void:
	var center := pos + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.2) if active else Color(0.6, 0.5, 0.15))
	draw_rect(Rect2(center + Vector2(-6, 4), Vector2(12, 10)), Color(0.3, 0.5, 0.7, 0.5), false, 1.0)

func _build_legend() -> void:
	for child in legend_list.get_children():
		child.queue_free()
	for rd in BuildingRegistry.get_all_resources():
		var md: MineralData = rd
		if not md:
			continue
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.color = md.color
		swatch.custom_minimum_size = Vector2(14, 14)
		var lbl := Label.new()
		lbl.text = md.display_name
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		hbox.add_child(swatch)
		hbox.add_child(lbl)
		legend_list.add_child(hbox)

func _update_info() -> void:
	var iron := int(GameData.resources.get("iron_ore", 0))
	var copper := int(GameData.resources.get("copper_ore", 0))
	var coal := int(GameData.resources.get("coal", 0))
	var steel := int(GameData.resources.get("steel", 0))
	var copper_ingot := int(GameData.resources.get("copper", 0))
	info_label.text = "$%d | 铁:%d 铜:%d 煤:%d | 钢:%d 铜锭:%d | 建筑:%d" % [GameData.money, iron, copper, coal, steel, copper_ingot, place_count]

func _current_building_def() -> BuildingData:
	var buildings := BuildingRegistry.get_game_world_buildings()
	if current_building_type < 0 or current_building_type >= buildings.size():
		return null
	return buildings[current_building_type]

func _update_building_label() -> void:
	if current_mode == ToolMode.DEMOLISH:
		building_type_label.text = "拆除模式: 点击建筑拆除，可返还 50% 花费"
		return
	var bd := _current_building_def()
	if not bd:
		building_type_label.text = "当前: 无"
		return
	var extra := ""
	if bd.id == "conveyor":
		extra = " · 方向:" + ["→右", "↓下", "←左", "↑上"][_conveyor_direction] + " (R旋转)"
	building_type_label.text = "当前: %s [%d] %d×%d · $%d%s" % [bd.display_name, current_building_type + 1, bd.size, bd.size, bd.cost, extra]

func _get_building_at_tile(tile: Vector2i) -> Dictionary:
	var b := _placed_by_pos.get(tile, {})
	if not b is Dictionary:
		return {}
	return b

func _preview_valid_for_special(bd: BuildingData) -> bool:
	if bd.id != "mining_drill":
		return true
	var md := _try_claim_node_for_drill(_mouse_tile, bd.size, false)
	return md != null

func _preview_mineral_def(bd: BuildingData) -> MineralData:
	if bd and bd.id == "mining_drill":
		return _try_claim_node_for_drill(_mouse_tile, bd.size, false)
	return null

func _demolish_hover_building() -> void:
	var b := _hover_building
	if b.is_empty():
		return
	var bd := b.get("def") as BuildingData
	if bd == null:
		return
	var refund := int(bd.cost * DEMOLISH_RATIO)
	GameData.add_money(refund)
	_remove_building(b)
	_update_info()
	queue_redraw()

func _remove_building(b: Dictionary) -> void:
	var idx := placed_buildings.find(b)
	if idx == -1:
		return
	placed_buildings.remove_at(idx)
	place_count = max(place_count - 1, 0)
	var pos: Vector2i = b.pos
	var sz: int = int(b.get("size", 1))
	var owned_tiles := []
	for x in range(pos.x, pos.x + sz):
		for y in range(pos.y, pos.y + sz):
			var tile := Vector2i(x, y)
			owned_tiles.append(tile)
	for tile in owned_tiles:
		if _placed_by_pos.get(tile) == b:
			_placed_by_pos.erase(tile)
		_occupied_tiles.erase(tile)

func _place_mining_drill(tile: Vector2i, bd: BuildingData) -> void:
	if not _can_place(tile, bd.size) or GameData.money < bd.cost:
		return
	var md := _try_claim_node_for_drill(tile, bd.size, true)
	if md == null:
		return
	var b := {"pos": tile, "id": bd.id, "color": bd.color, "size": bd.size, "timer": 0.0, "def": bd, "mineral_def": md}
	_add_placed_building(b)
	GameData.spend_money(bd.cost)
	_update_info()

func _try_claim_node_for_drill(tile: Vector2i, size: int, commit: bool) -> MineralData:
	var md := null
	var nearest_dist := 99999.0
	for node in resource_nodes:
		if node.claimed:
			continue
		var np: Vector2i = node.pos
		var dist := Vector2(np - tile).length()
		if np.x >= tile.x and np.x < tile.x + size and np.y >= tile.y and np.y < tile.y + size and dist < nearest_dist:
			nearest_dist = dist
			md = node.def
	if md == null or not commit:
		return md
	for node in resource_nodes:
		if node.def == md and not node.claimed:
			node.claimed = true
			return md
	return md

func _place_building(tile: Vector2i, bd: BuildingData) -> void:
	if not _can_place(tile, bd.size) or GameData.money < bd.cost:
		return
	var b := {"pos": tile, "id": bd.id, "color": bd.color, "size": bd.size, "timer": 0.0, "def": bd}
	if bd.id == "conveyor":
		b["direction"] = _conveyor_direction
	_add_placed_building(b)
	GameData.spend_money(bd.cost)
	_update_info()

func _add_placed_building(b: Dictionary) -> void:
	placed_buildings.append(b)
	place_count += 1
	var pos: Vector2i = b.pos
	var sz: int = int(b.get("size", 1))
	for x in range(pos.x, pos.x + sz):
		for y in range(pos.y, pos.y + sz):
			var tile := Vector2i(x, y)
			_placed_by_pos[tile] = b
			_occupied_tiles[tile] = true

func _can_place(pos: Vector2i, size: int) -> bool:
	for x in range(pos.x, pos.x + size):
		for y in range(pos.y, pos.y + size):
			var tile := Vector2i(x, y)
			if not _is_tile_in_bounds(x, y) or terrain[y][x] == 3 or _occupied_tiles.has(tile) or _placed_by_pos.has(tile):
				return false
	return true

func _on_back_to_menu() -> void:
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")

func _is_tile_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WORLD_W and y < WORLD_H

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return max(min_value, min(max_value, value))
