extends Node2D

const WORLD_W := 60
const WORLD_H := 40
const TILE_SIZE := 32
const NODE_COUNT := 900
const CHUNK_POOL_SIZE := 1200

const TERRAINS := [Color(0.36, 0.42, 0.33), Color(0.45, 0.50, 0.36), Color(0.30, 0.33, 0.29), Color(0.42, 0.43, 0.45)]
const CONVEYOR_DIRS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]

@onready var world_container: Control = $WorldContainer
@onready var info_label: Label = $UI/HUDLeft/InfoLabel
@onready var legend_list: VBoxContainer = $UI/HUDLeft/LegendList
@onready var sub_menu: HBoxContainer = $UI/HUDRight/SubMenu
@onready var building_type_label: Label = $UI/HUDRight/BuildingLabel
@onready var build_button: Button = $UI/HUDRight/BuildButton

var terrain: Array = []
var resource_nodes: Array = []
var chunks: Array = []
var placed_buildings: Array = []
var place_count: int = 0

var current_building_type: int = 0
var _conveyor_direction: int = 0
var _drag_placing: bool = false
var _drag_preview_pos: Vector2i = Vector2i(-1, -1)
var _chunk_index: int = 0
var _pool_in_use: Array = []
var _placed_by_pos: Dictionary = {}
var _occupied_tiles: Dictionary = {}
var _resource_defs_by_id: Dictionary = {}
var _research_panel: Node = null

func _ready() -> void:
	_load_resources()
	_generate_world()
	_spawn_resource_nodes()
	world_container.gui_input.connect(_on_world_input)
	if not GameData.has_save():
		GameData.start_new_game()
		GameData.money = 1000
		GameData.add_resource("iron_ore", 5)
	else:
		GameData.load_game()
	_build_legend()
	_update_info()
	_update_building_label()

func _load_resources() -> void:
	_resource_defs_by_id.clear()
	var resources := BuildingRegistry.get_all_resources()
	var buildings := BuildingRegistry.get_game_world_buildings()
	for md in resources:
		if md and md.id != "":
			_resource_defs_by_id[md.id] = md
	for bd in buildings:
		if not bd or bd.id == "":
			continue
		GameData.building_types.append({"id": bd.id, "name": bd.display_name, "color": bd.color, "size": bd.size, "def": bd})

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
	var placed := 0
	var attempts := 0
	var defs := BuildingRegistry.get_all_resources()
	for md in defs:
		if not md or md.spawn_count <= 0:
			continue
		for _i in range(md.spawn_count):
			while attempts < 10000:
				attempts += 1
				var pos := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
				if _is_tile_in_bounds(pos.x, pos.y) and terrain[pos.y][pos.x] == 0 and not _occupied_tiles.has(pos):
					_occupied_tiles[pos] = true
					resource_nodes.append({"pos": pos, "def": md, "claimed": false})
					placed += 1
					break

func _on_world_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_close_overlays()
	if event is InputEventMouseMotion:
		if _drag_placing:
			_try_place_at_mouse()

func _physics_process(delta: float) -> void:
	_tick_buildings(delta)
	_update_info()

func _tick_buildings(delta: float) -> void:
	for b in placed_buildings:
		var bd := b.get("def") as BuildingData
		if not bd or bd.cycle_interval <= 0.0:
			continue
		b.timer = float(b.get("timer", 0.0)) + delta
		while float(b.get("timer", 0.0)) >= bd.cycle_interval:
			b.timer = float(b.get("timer", 0.0)) - bd.cycle_interval
			_process_building(b)
			break

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
	queue_redraw()

func _has_claimed_node_near(b: Dictionary) -> bool:
	var pos: Vector2i = b.pos
	for node in resource_nodes:
		if node.claimed and node.def != b.get("mineral_def"):
			continue
		if abs(node.pos.x - pos.x) < 3 and abs(node.pos.y - pos.y) < 3:
			return true
	return false

func _try_smelt() -> void:
	var output_ids := ["steel", "copper"]
	for output_id in output_ids:
		var source := _get_resource_by_smelt_output(output_id)
		if source == null or not GameData.consume_resource(source.id, 1):
			continue
		GameData.add_resource(output_id, 1)

func _try_sell() -> void:
	var sold: int = 0
	for rd in BuildingRegistry.get_all_resources():
		var md: MineralData = rd
		if not md:
			continue
		if GameData.consume_resource(md.id, int(GameData.resources.get(md.id, 0))):
			sold += int(GameData.resources.get(md.id, 0)) * md.price
	if sold > 0:
		GameData.add_money(sold)

func _draw() -> void:
	_draw_terrain()
	_draw_resource_nodes()
	_draw_buildings()
	_draw_drag_preview()

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
		var center := pos + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		draw_colored_polygon([center + Vector2(0, -8), center + Vector2(8, 0), center + Vector2(0, 8), center + Vector2(-8, 0)], Color(1, 1, 1, 0.15))

func _draw_buildings() -> void:
	for b in placed_buildings:
		var pos := Vector2(b.pos.x * TILE_SIZE, b.pos.y * TILE_SIZE)
		var sz: int = int(b.get("size", 1))
		var rect := Rect2(pos, Vector2(TILE_SIZE * sz, TILE_SIZE * sz))
		draw_rect(rect, b.get("color", Color.WHITE))
		draw_rect(rect, Color(1, 1, 1, 0.7 if float(b.get("timer", 0.0)) < 1.0 else 0.4), false, 2.0)
		match b.get("id"):
			"conveyor":
				_draw_conveyor_arrows(pos, Color(0.15, 0.50, 0.50), int(b.get("direction", 0)))
			"mining_drill":
				_draw_mining_drill(pos, sz, b.get("mineral_def") as MineralData)
			"smelter":
				_draw_smelter_flame(pos, float(b.get("timer", 0.0)) < 1.0)
			"storage":
				_draw_storage_pattern(pos)
			"trading_post":
				_draw_trading_post(pos, float(b.get("timer", 0.0)) < 1.0)

func _draw_drag_preview() -> void:
	if not _drag_placing or _drag_preview_pos.x < 0:
		return
	var bd := _current_building_def()
	if not bd or bd.id != "conveyor":
		return
	var pos := Vector2(_drag_preview_pos.x * TILE_SIZE, _drag_preview_pos.y * TILE_SIZE)
	var rect := Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
	draw_rect(rect, Color(0.3, 0.8, 0.77, 0.3))
	draw_rect(rect, Color(1, 1, 1, 0.5), false, 2.0)
	_draw_conveyor_arrows(pos, Color(0.15, 0.50, 0.50, 0.9), _conveyor_direction)

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
	var building := BuildingRegistry.get_game_world_buildings()
	if current_building_type < 0 or current_building_type >= building.size():
		return null
	return building[current_building_type]

func _update_building_label() -> void:
	var bd := _current_building_def()
	if not bd:
		building_type_label.text = "当前: 无"
		return
	var extra: String = ""
	if bd.id == "conveyor":
		extra = " · 方向:" + ["→右", "↓下", "←左", "↑上"][_conveyor_direction] + " (R旋转)"
	building_type_label.text = "当前: %s [%d] %d×%d · $%d%s" % [bd.display_name, current_building_type + 1, bd.size, bd.size, bd.cost, extra]

func _close_overlays() -> void:
	if _research_panel and _research_panel.visible:
		_on_research_close()
	if sub_menu.visible:
		sub_menu.visible = false

func _on_sub_menu_select(idx: int) -> void:
	var building := BuildingRegistry.get_game_world_buildings()
	if idx >= 0 and idx < building.size():
		current_building_type = idx
		_update_building_label()
		sub_menu.visible = false

func _try_place_at_mouse() -> void:
	var tp := Vector2i(int(get_global_mouse_position().x / TILE_SIZE), int(get_global_mouse_position().y / TILE_SIZE))
	if not _is_tile_in_bounds(tp.x, tp.y):
		_drag_preview_pos = Vector2i(-1, -1)
		queue_redraw()
		return
	_drag_preview_pos = tp
	var bd := _current_building_def()
	if not bd or GameData.money < bd.cost:
		queue_redraw()
		return
	if bd.id == "mining_drill":
		_place_mining_drill(tp, bd)
	else:
		_place_building(tp, bd)
	queue_redraw()
	_update_info()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_overlays()
		return
	if event is InputEventKey and event.pressed and not (event.ctrl_pressed or event.meta_pressed):
		match event.keycode:
			KEY_R:
				_conveyor_direction = (_conveyor_direction + 1) % 4
				_update_building_label()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var building := BuildingRegistry.get_game_world_buildings()
				if int(event.keycode) - int(KEY_1) < building.size():
					current_building_type = int(event.keycode) - int(KEY_1)
					_update_building_label()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_placing = true
			_try_place_at_mouse()
		else:
			_drag_placing = false
			_drag_preview_pos = Vector2i(-1, -1)
			queue_redraw()
		return

func _place_mining_drill(tp: Vector2i, bd: BuildingData) -> void:
	if not _can_place(tp, bd.size):
		return
	if _try_claim_node_for_drill(tp, bd.size):
		var b := {"pos": tp, "id": bd.id, "color": bd.color, "size": bd.size, "timer": 0.0, "def": bd}
		_add_placed_building(b)
		GameData.spend_money(bd.cost)

func _try_claim_node_for_drill(tp: Vector2i, size: int) -> MineralData:
	var md := null
	var nearest_dist := 99999.0
	for node in resource_nodes:
		if node.claimed:
			continue
		var np: Vector2i = node.pos
		var dist := Vector2(np - tp).length()
		if np.x >= tp.x and np.x < tp.x + size and np.y >= tp.y and np.y < tp.y + size and dist < nearest_dist:
			nearest_dist = dist
			md = node.def
	if md != null:
		for node in resource_nodes:
			if node.def == md and not node.claimed:
				node.claimed = true
				return md
	return md

func _place_building(tp: Vector2i, bd: BuildingData) -> void:
	if not _can_place(tp, bd.size):
		return
	var building_data := {"pos": tp, "id": bd.id, "color": bd.color, "size": bd.size, "timer": 0.0, "def": bd}
	if bd.id == "conveyor":
		building_data["direction"] = _conveyor_direction
	_add_placed_building(building_data)
	GameData.spend_money(bd.cost)

func _add_placed_building(b: Dictionary) -> void:
	placed_buildings.append(b)
	place_count += 1
	var bpos: Vector2i = b.pos
	var bsz: int = int(b.get("size", 1))
	for x in range(bpos.x, bpos.x + bsz):
		for y in range(bpos.y, bpos.y + bsz):
			_placed_by_pos[Vector2i(x, y)] = b
			_occupied_tiles[Vector2i(x, y)] = true

func _can_place(pos: Vector2i, size: int) -> bool:
	for x in range(pos.x, pos.x + size):
		for y in range(pos.y, pos.y + size):
			var tile := Vector2i(x, y)
			if not _is_tile_in_bounds(x, y) or terrain[y][x] == 3 or _occupied_tiles.has(tile) or _placed_by_pos.has(tile):
				return false
	return true

func _is_tile_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WORLD_W and y < WORLD_H

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return max(min_value, min(max_value, value))
