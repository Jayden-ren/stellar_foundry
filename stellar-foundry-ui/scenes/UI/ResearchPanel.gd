extends Control

const TECHS := [
	["power_generator", "发电机组", 500, "研究电力系统\n解锁发电机组建筑"],
	["advanced_miner", "高级矿机", 1200, "解锁2×2高效采矿钻\n产量翻倍"],
	["power_storage", "储能电池", 800, "研究储能系统\n解锁能量存储建筑"],
	["auto_transfer", "自动运输", 1000, "研究自动化运输\n传送带速度提升50%"],
	["advanced_smelter", "高级熔炉", 1500, "研究高级冶炼\n熔炉产量翻倍"],
	["mass_storage", "海量仓储", 2000, "研究高效存储\n仓库容量x3"],
	["research_lab", "实验室", 3000, "建造实验室\n解锁后续所有科技"],
	["automation_core", "自动核心", 5000, "终极科技\n建筑自动升级"],
]

@onready var close_btn: Button = $PanelContainer/VBox/CloseBtn
@onready var tech_grid: GridContainer = $PanelContainer/VBox/TechGrid
@onready var desc_label: Label = $PanelContainer/VBox/DescLabel

signal back_requested

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	GameData.money_changed.connect(_refresh_buttons)
	GameData.technology_changed.connect(_refresh_buttons)
	_build_tech_tree()

func _on_close() -> void:
	back_requested.emit()

func _build_tech_tree() -> void:
	for c in tech_grid.get_children():
		c.queue_free()
	desc_label.text = "选择一项科技进行研究。"
	for tech in TECHS:
		var tid: String = tech[0]
		var btn := Button.new()
		btn.name = tid
		btn.custom_minimum_size = Vector2(180, 60)
		btn.tooltip_text = str(tech[3])
		btn.pressed.connect(_on_tech_pressed.bind(tid, tech[2]))
		tech_grid.add_child(btn)
	_refresh_buttons()

func _refresh_buttons(_value: int = 0) -> void:
	for child in tech_grid.get_children():
		var btn := child as Button
		if not btn:
			continue
		var id := btn.name
		var tech = _find_tech(id)
		if tech.is_empty():
			continue
		var cost: int = tech[2]
		var unlocked := GameData.has_tech(id)
		if unlocked:
			btn.text = "%s\n✓ 已解锁" % tech[1]
			btn.disabled = true
		else:
			btn.text = "%s\n$%d" % [tech[1], cost]
			btn.disabled = GameData.money < cost

func _on_tech_pressed(id: String, cost: int) -> void:
	if GameData.spend_money(cost) and GameData.unlock_tech(id):
		var tech = _find_tech(id)
		if not tech.is_empty():
			desc_label.text = "已解锁: %s" % tech[1]
		_refresh_buttons()
	else:
		push_warning("无法研究科技 %s" % id)

func _find_tech(id: String) -> Array:
	for tech in TECHS:
		if tech[0] == id:
			return tech
	return []
