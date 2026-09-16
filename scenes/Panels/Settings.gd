extends Control

const CONFIG_PATH := "user://settings.cfg"

@onready var close_btn: Button = $Center/Panel/Content/Header/CloseBtn
@onready var fullscreen_toggle: CheckButton = $Center/Panel/Content/FullscreenRow/FullscreenToggle
@onready var music_slider: HSlider = $Center/Panel/Content/MusicRow/MusicSlider
@onready var music_value: Label = $Center/Panel/Content/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Center/Panel/Content/SFXRow/SFXSlider
@onready var sfx_value: Label = $Center/Panel/Content/SFXRow/SFXValue
@onready var font_slider: HSlider = $Center/Panel/Content/FontRow/FontSlider
@onready var font_value: Label = $Center/Panel/Content/FontRow/FontValue
@onready var save_btn: Button = $Center/Panel/Content/Footer/SaveBtn
@onready var back_btn: Button = $Center/Panel/Content/Footer/BackToMenu

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	save_btn.pressed.connect(_on_save)
	back_btn.pressed.connect(_on_back_to_menu)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	font_slider.value_changed.connect(_on_font_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_load_settings()

func _load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	fullscreen_toggle.set_pressed_no_signal(bool(data.get("fullscreen", false)))
	music_slider.set_value_no_signal(_clamp_float(float(data.get("music", 70)), 0.0, 100.0))
	sfx_slider.set_value_no_signal(_clamp_float(float(data.get("sfx", 80)), 0.0, 100.0))
	font_slider.set_value_no_signal(_clamp_float(float(data.get("font_size", 16)), 10.0, 32.0))
	_refresh_labels()
	ApplyFullscreen(bool(data.get("fullscreen", false)))

func _on_save() -> void:
	var data := {
		"fullscreen": fullscreen_toggle.button_pressed,
		"music": int(music_slider.value),
		"sfx": int(sfx_slider.value),
		"font_size": int(font_slider.value),
	}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	else:
		push_error("无法保存设置")
		return
	ApplyFullscreen(fullscreen_toggle.button_pressed)
	ApplyDefaultFontSize(int(font_slider.value))
	save_btn.text = "✅ 已保存"

func _on_music_changed(v: float) -> void:
	music_value.text = str(int(v)) + "%"

func _on_sfx_changed(v: float) -> void:
	sfx_value.text = str(int(v)) + "%"

func _on_font_changed(v: float) -> void:
	font_value.text = str(int(v)) + "px"

func _on_fullscreen_toggled(checked: bool) -> void:
	ApplyFullscreen(checked)

func _refresh_labels() -> void:
	music_value.text = str(int(music_slider.value)) + "%"
	sfx_value.text = str(int(sfx_slider.value)) + "%"
	font_value.text = str(int(font_slider.value)) + "px"

func ApplyFullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func ApplyDefaultFontSize(size_px: int) -> void:
	ProjectSettings.set_setting("gui/theme/default_font_size", size_px)
	get_tree().root.call_deferred("notification", NOTIFICATION_THEME_CHANGED)

func _on_close() -> void:
	queue_free()

func _on_back_to_menu() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		queue_free()

func _clamp_float(value: float, min_value: float, max_value: float) -> float:
	return maxf(min_value, minf(max_value, value))
