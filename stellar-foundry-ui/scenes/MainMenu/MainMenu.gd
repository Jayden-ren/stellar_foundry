extends Control

@onready var btn_new_game: Button = $Center/MenuBox/ButtonBox/NewGame
@onready var btn_continue: Button = $Center/MenuBox/ButtonBox/Continue
@onready var btn_settings: Button = $Center/MenuBox/ButtonBox/Settings
@onready var btn_quit: Button = $Center/MenuBox/ButtonBox/Quit
@onready var version_label: Label = $VersionLabel

var _settings_panel: Control = null

func _ready() -> void:
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	_refresh_continue_state()
	version_label.text = "v0.2 Reviewed · " + _format_date()

func _refresh_continue_state() -> void:
	var has_save := GameData.has_save()
	btn_continue.text = "↺  继续游戏" if has_save else "·  无存档"
	btn_continue.disabled = not has_save

func _on_new_game_pressed() -> void:
	GameData.start_new_game()
	get_tree().change_scene_to_file("res://scenes/Game/GameWorld.tscn")

func _on_continue_pressed() -> void:
	if GameData.load_game():
		get_tree().change_scene_to_file("res://scenes/Game/GameWorld.tscn")
	else:
		push_warning("读取存档失败。")

func _on_settings_pressed() -> void:
	if _settings_panel and is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = preload("res://scenes/Panels/Settings.tscn").instantiate()
	add_child(_settings_panel)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _format_date() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]
