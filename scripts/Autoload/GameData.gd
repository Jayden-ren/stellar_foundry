extends Node

signal money_changed(amount: int)
signal science_changed(points: int)
signal stage_changed(stage: int)
signal resource_changed(id: String, amount: int)
signal speed_changed(speed: int)
signal time_tick(elapsed: float)
signal technology_changed(id: String)

enum Stage { PLANET_INDUSTRY = 1, AUTOMATION_AGE = 2, INTERSTELLAR = 3, STELLAR_ENG = 4, DYSON_ERA = 5 }

const VALID_TIME_SPEEDS: Array[int] = [1, 2, 4, 16]
const SAVE_PATH: String = "user://save.sav"

var money: int = 1000000
var science: int = 0
var stage: int = Stage.PLANET_INDUSTRY
var stage_progress: float = 0.0
var dyson_progress: float = 0.0
var time_speed: int = 1
var paused: bool = false
var elapsed_time: float = 0.0
var last_speed: int = 1

var resources: Dictionary = {
	"iron_ore": 0, "copper_ore": 0, "coal": 0, "oil": 0, "water": 0,
	"steel": 0, "copper": 0, "gasoline": 0, "wire": 0, "circuit": 0,
	"controller": 0, "reactor_core": 0, "helium3": 0, "antimatter": 0,
	"dyson_truss": 0,
}

var unlocked_tech: Array[String] = ["basic_mining", "storage", "conveyor", "smelting", "trade"]
var milestones_done: Array[String] = []
var _tick_accumulator: float = 0.0

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return max(min_value, min(max_value, value))

func _clamp_min(value: int, min_value: int) -> int:
	return max(min_value, value)

func _clamp_float(value: float, min_value: float, max_value: float) -> float:
	return maxf(min_value, minf(max_value, value))

func _process(delta: float) -> void:
	if paused or time_speed <= 0:
		return
	elapsed_time += delta * time_speed
	add_money(int(5 * time_speed * delta), false)
	_emit_periodic(delta)

func _emit_periodic(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < 1.0:
		return
	_tick_accumulator = 0.0
	time_tick.emit(elapsed_time)
	money_changed.emit(money)

func add_money(amount: int, emit_signal: bool = true) -> void:
	money = _clamp_int(money + amount, 0, 9_000_000_000_000)
	if emit_signal:
		money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

func add_resource(id: String, amount: int, emit_signal: bool = true) -> void:
	if id.is_empty() or amount <= 0:
		return
	resources[id] = _clamp_int(int(resources.get(id, 0)) + amount, 0, 9_000_000_000_000)
	if emit_signal:
		resource_changed.emit(id, resources[id])

func consume_resource(id: String, amount: int) -> bool:
	if amount < 0 or int(resources.get(id, 0)) < amount:
		return false
	resources[id] = _clamp_int(int(resources[id]) - amount, 0, 9_000_000_000_000)
	resource_changed.emit(id, resources[id])
	return true

func add_science(amount: int, emit_signal: bool = true) -> void:
	if amount <= 0:
		return
	science = _clamp_int(science + amount, 0, 9_000_000_000_000)
	if emit_signal:
		science_changed.emit(science)

func spend_science(amount: int) -> bool:
	if amount < 0 or science < amount:
		return false
	science -= amount
	science_changed.emit(science)
	return true

func set_speed(s: int) -> void:
	if s == 0:
		toggle_pause()
		return
	if not VALID_TIME_SPEEDS.has(s):
		return
	paused = false
	time_speed = s
	last_speed = s
	speed_changed.emit(time_speed)

func toggle_pause() -> void:
	if paused:
		paused = false
		time_speed = _clamp_int(last_speed, 1, 16)
		if not VALID_TIME_SPEEDS.has(time_speed):
			time_speed = 1
	else:
		paused = true
		last_speed = time_speed
	speed_changed.emit(time_speed)

func unlock_tech(id: String) -> bool:
	if id.is_empty() or unlocked_tech.has(id):
		return false
	unlocked_tech.append(id)
	technology_changed.emit(id)
	return true

func has_tech(id: String) -> bool:
	return unlocked_tech.has(id)

func complete_milestone(id: String) -> void:
	if not id.is_empty() and not milestones_done.has(id):
		milestones_done.append(id)

func start_new_game() -> void:
	money = 1000000
	science = 0
	stage = Stage.PLANET_INDUSTRY
	stage_progress = 0.0
	dyson_progress = 0.0
	time_speed = 1
	paused = false
	elapsed_time = 0.0
	for key in resources:
		resources[key] = 0
	unlocked_tech = ["basic_mining", "storage", "conveyor", "smelting", "trade"]
	milestones_done = []
	_tick_accumulator = 0.0

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var data := {
		"version": 1,
		"money": money, "science": science, "stage": stage,
		"stage_progress": stage_progress, "dyson_progress": dyson_progress,
		"elapsed": elapsed_time, "time_speed": time_speed, "paused": paused,
		"resources": resources, "unlocked_tech": unlocked_tech, "milestones_done": milestones_done,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("无法写入存档: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档解析失败，保留当前状态。")
		return false
	var data: Dictionary = parsed
	money = int(data.get("money", money))
	science = int(data.get("science", science))
	stage = _clamp_int(int(data.get("stage", stage)), 1, int(Stage.DYSON_ERA))
	stage_progress = _clamp_float(float(data.get("stage_progress", stage_progress)), 0.0, 1.0)
	dyson_progress = _clamp_float(float(data.get("dyson_progress", dyson_progress)), 0.0, 1.0)
	elapsed_time = maxf(float(data.get("elapsed", elapsed_time)), 0.0)
	paused = bool(data.get("paused", paused))
	time_speed = _clamp_int(int(data.get("time_speed", time_speed)), 1, 16)
	last_speed = time_speed if not paused else _clamp_int(last_speed, 1, 16)
	for key in resources:
		resources[key] = _clamp_min(int(data.get("resources", {}).get(key, 0)), 0)
	var loaded_tech: Array = []
	for item in data.get("unlocked_tech", []):
		var tech_id := str(item)
		if not loaded_tech.has(tech_id):
			loaded_tech.append(tech_id)
	unlocked_tech = loaded_tech
	var loaded_milestones: Array = []
	for item in data.get("milestones_done", []):
		var milestone_id := str(item)
		if not loaded_milestones.has(milestone_id):
			loaded_milestones.append(milestone_id)
	milestones_done = loaded_milestones
	return true
