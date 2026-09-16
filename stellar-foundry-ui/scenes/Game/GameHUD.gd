extends Control

signal money_changed_from_hud
signal science_changed_from_hud

@onready var money_label: Label = $Layout/TopBar/TopHBox/MoneyLabel
@onready var science_label: Label = $Layout/TopBar/TopHBox/ScienceLabel
@onready var time_label: Label = $Layout/TopBar/TopHBox/TimeLabel
@onready var stage_label: Label = $Layout/TopBar/TopHBox/StageInfo/StageLabel
@onready var dyson_bar: ProgressBar = $Layout/TopBar/TopHBox/DysonBox/DysonBar
@onready var resource_list: VBoxContainer = $Layout/Middle/LeftPanel/LeftVBox/ResourceList
@onready var objective_list: VBoxContainer = $Layout/Middle/RightPanel/RightVBox/ObjectiveList
@onready var btn_pause: Button = $Layout/BottomBar/BottomHBox/SpeedBox/BtnPause
@onready var btn_1x: Button = $Layout/BottomBar/BottomHBox/SpeedBox/Btn1x
@onready var btn_2x: Button = $Layout/BottomBar/BottomHBox/SpeedBox/Btn2x
@onready var btn_4x: Button = $Layout/BottomBar/BottomHBox/SpeedBox/Btn4x
@onready var btn_16x: Button = $Layout/BottomBar/BottomHBox/SpeedBox/Btn16x
@onready var speed_label: Label = $Layout/BottomBar/BottomHBox/SpeedLabel

var active_panel: Node = null
var _resource_labels: Dictionary = {}
var _pending_resource_ids: Dictionary = {}

const RESOURCE_DISPLAY := [
	["iron_ore", "铁矿", "⛏"], ["copper_ore", "铜矿", "🟧"], ["coal", "煤炭", "⚫"],
	["oil", "石油", "🛢"], ["water", "水", "💧"], ["steel", "钢锭", "⬜"], ["copper", "铜锭", "🟫"],
	["gasoline", "汽油", "🟡"], ["wire", "电线", "🔌"], ["circuit", "电路板", "🟩"],
	["controller", "控制器", "🖥"], ["reactor_core", "反应堆", "☢"], ["helium3", "氦-3", "💎"],
	["antimatter", "反物质", "🟣"], ["dyson_truss", "戴森桁架", "🌌"],
]

const STAGE_TEXTS := {
	1: "🏆 阶段 Ⅰ · 星球工业", 2: "⚙ 阶段 Ⅱ · 自动化时代", 3: "🚀 阶段 Ⅲ · 星际扩张",
	4: "⭐ 阶段 Ⅳ · 恒星工程", 5: "🌌 阶段 Ⅴ · 戴森纪元",
}

func _ready() -> void:
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_1x.pressed.connect(_on_speed_1x)
	btn_2x.pressed.connect(_on_speed_2x)
	btn_4x.pressed.connect(_on_speed_4x)
	btn_16x.pressed.connect(_on_speed_16x)
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnMining.pressed.connect(_on_open_building_panel.bind("mining"))
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnProcessing.pressed.connect(_on_open_building_panel.bind("processing"))
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnLogistics.pressed.connect(_on_open_building_panel.bind("logistics"))
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnTech.pressed.connect(_on_open_tech_panel)
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnMarket.pressed.connect(_on_open_market_panel)
	$Layout/BottomBar/BottomHBox/CategoryBox/BtnSettings.pressed.connect(_on_open_settings_panel)
	$Layout/BottomBar/BottomHBox/BackToMenu.pressed.connect(_on_back_to_menu)
	GameData.money_changed.connect(_on_money_changed)
	GameData.science_changed.connect(_on_science_changed)
	GameData.resource_changed.connect(_on_resource_changed)
	GameData.speed_changed.connect(_on_speed_changed)
	GameData.time_tick.connect(_on_time_tick)
	_build_resource_list()
	_build_objective_list()
	_refresh_top_bar()

func _process(_delta: float) -> void:
	# 资源信号可能每帧多次触发；按 ID 去重后一次性刷 Label，避免大量 add/consume 导致 UI 抖动。
	if _pending_resource_ids.is_empty():
		return
	var ids := _pending_resource_ids.keys()
	for id in ids:
		if _resource_labels.has(id):
			_resource_labels[id].text = str(GameData.resources.get(id, 0))
	_pending_resource_ids.clear()

func _build_resource_list() -> void:
	for row in RESOURCE_DISPLAY:
		var id: String = row[0]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		var emoji_lbl := Label.new()
		emoji_lbl.text = row[2]
		emoji_lbl.custom_minimum_size.x = 22
		var name_lbl := Label.new()
		name_lbl.text = row[1]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		var amount_lbl := Label.new()
		amount_lbl.text = "0"
		amount_lbl.add_theme_color_override("font_color", Color(0.933, 0.835, 0.18))
		amount_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(emoji_lbl)
		hbox.add_child(name_lbl)
		hbox.add_child(amount_lbl)
		resource_list.add_child(hbox)
		_resource_labels[id] = amount_lbl

func _on_resource_changed(id: String, _amount: int) -> void:
	_pending_resource_ids[id] = true

func _build_objective_list() -> void:
	for text in ["🎯  建造第一座钢铁精炼塔", "🎯  开启自动化贸易", "🎯  完成阶段 Ⅰ 全部条件"]:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 13)
		objective_list.add_child(lbl)

func _refresh_top_bar() -> void:
	money_label.text = "💰 $" + _format_money(GameData.money)
	science_label.text = "🔬 " + str(GameData.science) + " SP"
	stage_label.text = STAGE_TEXTS.get(GameData.stage, "阶段 ?")
	dyson_bar.value = GameData.dyson_progress * 100.0
	_refresh_speed_indicator()

func _on_money_changed(_amount: int) -> void:
	money_label.text = "💰 $" + _format_money(GameData.money)
	money_changed_from_hud.emit()

func _on_science_changed(_points: int) -> void:
	science_label.text = "🔬 " + str(GameData.science) + " SP"
	science_changed_from_hud.emit()

func _on_time_tick(elapsed: float) -> void:
	var total := int(elapsed)
	time_label.text = "⏱ %02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]

func _on_pause_pressed() -> void:
	GameData.toggle_pause()

func _on_speed_1x() -> void:
	GameData.set_speed(1)

func _on_speed_2x() -> void:
	GameData.set_speed(2)

func _on_speed_4x() -> void:
	GameData.set_speed(4)

func _on_speed_16x() -> void:
	GameData.set_speed(16)

func _on_speed_changed(_speed: int) -> void:
	_refresh_speed_indicator()

func _refresh_speed_indicator() -> void:
	speed_label.text = " 速度: " + ("⏸" if GameData.paused else str(GameData.time_speed) + "×")
	btn_pause.text = "▶" if GameData.paused else "⏸"

func _close_active_panel() -> void:
	if active_panel and is_instance_valid(active_panel):
		active_panel.queue_free()
	active_panel = null

func _on_open_building_panel(_category: String) -> void:
	_close_active_panel()
	active_panel = preload("res://scenes/Panels/BuildingPanel.tscn").instantiate()
	add_child(active_panel)

func _on_open_tech_panel() -> void:
	_close_active_panel()
	active_panel = preload("res://scenes/Panels/TechTree.tscn").instantiate()
	add_child(active_panel)

func _on_open_market_panel() -> void:
	_close_active_panel()
	active_panel = preload("res://scenes/Panels/Market.tscn").instantiate()
	add_child(active_panel)

func _on_open_settings_panel() -> void:
	_close_active_panel()
	active_panel = preload("res://scenes/Panels/Settings.tscn").instantiate()
	add_child(active_panel)

func _on_back_to_menu() -> void:
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_on_pause_pressed()
	elif event.is_action_pressed("speed_1x"):
		_on_speed_1x()
	elif event.is_action_pressed("speed_2x"):
		_on_speed_2x()
	elif event.is_action_pressed("speed_4x"):
		_on_speed_4x()
	elif event.is_action_pressed("speed_16x"):
		_on_speed_16x()
	elif event.is_action_pressed("open_tech"):
		_on_open_tech_panel()
	elif event.is_action_pressed("open_market"):
		_on_open_market_panel()
	elif event.is_action_pressed("toggle_panel"):
		_close_active_panel()

func _format_money(n: int) -> String:
	if n >= 1_000_000_000_000:
		return "%.2fT" % (float(n) / 1_000_000_000_000.0)
	if n >= 1_000_000_000:
		return "%.2fB" % (float(n) / 1_000_000_000.0)
	if n >= 1_000_000:
		return "%.2fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)
