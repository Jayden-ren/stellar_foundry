extends Node

const REGISTRY_PATH := "res://data/buildings/building_registry.json"

var categories: Array[Dictionary] = []
var resources: Array[MineralData] = []
var buildings: Array[BuildingData] = []

var _registry_raw: Dictionary = {}
var _categories_by_id: Dictionary = {}
var _categories_by_label: Dictionary = {}
var _resources_by_id: Dictionary = {}
var _buildings_by_id: Dictionary = {}
var _building_entries_by_id: Dictionary = {}
var _resource_entries_by_id: Dictionary = {}

func _ready() -> void:
	_load_registry()

func _load_registry() -> void:
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("BuildingRegistry: cannot open %s" % REGISTRY_PATH)
		return

	var parsed := JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_error("BuildingRegistry: invalid JSON in %s" % REGISTRY_PATH)
		return

	_registry_raw = parsed
	_build_categories()
	_build_resources()
	_build_buildings()
	_validate()

func get_resource(id: String) -> MineralData:
	return _resources_by_id.get(id, null)

func get_building(id: String) -> BuildingData:
	return _buildings_by_id.get(id, null)

func get_category(id: String) -> Dictionary:
	return _categories_by_id.get(id, {})

func get_category_label(category_id: String) -> String:
	return str(get_category(category_id).get("label", category_id))

func get_buildings_by_category(category_id: String, include_disabled: bool = false) -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for b in buildings:
		if not include_disabled and not _is_building_enabled(b.id):
			continue
		var raw := _building_entries_by_id.get(b.id, {})
		if str(raw.get("category", "")) == category_id:
			out.append(b)
	return out

func get_game_world_buildings() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	var order := _registry_raw.get("game_world_order", [])
	if order is Array and not (order as Array).is_empty():
		for id in order:
			var b := get_building(str(id))
			if b != null:
				out.append(b)
		return out

	for b in buildings:
		var raw := _building_entries_by_id.get(b.id, {})
		if _is_building_enabled(b.id) and str(raw.get("category", "")) in ["mining", "processing", "logistics", "storage", "trade"]:
			out.append(b)
	return out

func get_categories() -> Array[Dictionary]:
	return categories

func get_all_resources() -> Array[MineralData]:
	return resources

func get_all_buildings() -> Array[BuildingData]:
	return buildings

func get_raw_resource(id: String) -> Dictionary:
	return _resource_entries_by_id.get(id, {})

func get_raw_building(id: String) -> Dictionary:
	return _building_entries_by_id.get(id, {})

func get_raw() -> Dictionary:
	return _registry_raw

func _build_categories() -> void:
	categories.clear()
	_categories_by_id.clear()
	_categories_by_label.clear()
	var raw_categories := _registry_raw.get("categories", [])
	if not (raw_categories is Array):
		return
	for entry in raw_categories:
		if not entry is Dictionary:
			continue
		var category_id := str((entry as Dictionary).get("id", ""))
		var label := str((entry as Dictionary).get("label", ""))
		if category_id == "" or label == "":
			continue
		categories.append(entry)
		_categories_by_id[category_id] = entry
		_categories_by_label[label] = category_id

func _build_resources() -> void:
	resources.clear()
	_resources_by_id.clear()
	_resource_entries_by_id.clear()
	var raw_resources := _registry_raw.get("resources", [])
	if not (raw_resources is Array):
		return
	for entry in raw_resources:
		if not entry is Dictionary:
			continue
		var resource_id := str((entry as Dictionary).get("id", ""))
		var md := MineralData.new()
		md.id = resource_id
		md.display_name = str((entry as Dictionary).get("display_name", ""))
		md.color = _parse_color((entry as Dictionary).get("color"))
		md.spawn_count = int((entry as Dictionary).get("spawn_count", 0))
		md.price = int((entry as Dictionary).get("price", 0))
		md.mine_interval = float((entry as Dictionary).get("mine_interval", 0.0))
		md.yield_per_tick = float((entry as Dictionary).get("yield_per_tick", 0.0))
		md.smelt_output = str((entry as Dictionary).get("smelt_output", ""))
		md.smelt_interval = float((entry as Dictionary).get("smelt_interval", 0.0))
		if resource_id == "":
			continue
		resources.append(md)
		_resources_by_id[resource_id] = md
		_resource_entries_by_id[resource_id] = entry

func _build_buildings() -> void:
	buildings.clear()
	_buildings_by_id.clear()
	_building_entries_by_id.clear()
	var raw_buildings := _registry_raw.get("buildings", [])
	if not (raw_buildings is Array):
		return
	for entry in raw_buildings:
		if not entry is Dictionary:
			continue
		var building_id := str((entry as Dictionary).get("id", ""))
		var bd := BuildingData.new()
		bd.id = building_id
		bd.display_name = str((entry as Dictionary).get("display_name", ""))
		bd.category = str((entry as Dictionary).get("category", ""))
		bd.icon = str((entry as Dictionary).get("icon", ""))
		bd.desc = str((entry as Dictionary).get("desc", ""))
		bd.req_tech = str((entry as Dictionary).get("req_tech", ""))
		bd.cost = int((entry as Dictionary).get("cost", 0))
		bd.color = _parse_color((entry as Dictionary).get("color"))
		bd.size = clampi(int((entry as Dictionary).get("size", 1)), 1, 4)
		bd.cycle_interval = float((entry as Dictionary).get("cycle_interval", 0.0))
		bd.enabled = bool((entry as Dictionary).get("enabled", true))
		if building_id == "":
			continue
		buildings.append(bd)
		_buildings_by_id[building_id] = bd
		_building_entries_by_id[building_id] = entry

func _is_building_enabled(building_id: String) -> bool:
	var entry := _building_entries_by_id.get(building_id, {})
	if not (entry is Dictionary):
		return true
	return bool((entry as Dictionary).get("enabled", true))

func _validate() -> void:
	_check_unique_ids("buildings", _registry_raw.get("buildings", []))
	_check_unique_ids("resources", _registry_raw.get("resources", []))
	_check_category_refs()

func _check_unique_ids(kind: String, entries: Variant) -> void:
	if not entries is Array:
		push_error("BuildingRegistry: %s must be an array" % kind)
		return
	var seen := {}
	for entry in entries:
		if not entry is Dictionary:
			continue
		var id_value := str((entry as Dictionary).get("id", ""))
		if id_value == "":
			push_error("BuildingRegistry: missing id in %s" % kind)
			continue
		if seen.has(id_value):
			push_error("BuildingRegistry: duplicate %s id: %s" % [kind, id_value])
		seen[id_value] = true

func _check_category_refs() -> void:
	var entries := _registry_raw.get("buildings", [])
	if not entries is Array:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var building_id := str((entry as Dictionary).get("id", ""))
		var category_id := str((entry as Dictionary).get("category", ""))
		if category_id == "":
			push_error("BuildingRegistry: missing category on building %s" % building_id)
		elif not _categories_by_id.has(category_id):
			push_error("BuildingRegistry: unknown category %s on building %s" % [category_id, building_id])

func _parse_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array:
		var arr: Array = value
		if arr.size() >= 3:
			var r := float(arr[0])
			var g := float(arr[1])
			var b := float(arr[2])
			var a := float(arr[3]) if arr.size() >= 4 else 1.0
			return Color(r, g, b, a)
	return Color.WHITE
