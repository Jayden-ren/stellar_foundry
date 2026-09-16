extends Control

const TECHS := [
	["basic_mining", "基础采矿", "Ⅰ", 100, "-", "采矿钻"],
	["storage", "仓储技术", "Ⅰ", 150, "basic_mining", "矿仓"],
	["smelting", "熔炼", "Ⅰ", 300, "basic_mining", "熔炉"],
	["conveyor", "传送带", "Ⅰ", 200, "smelting", "传送带"],
	["trade", "贸易", "Ⅰ", 400, "storage", "交易站"],
	["refining", "石油精炼", "Ⅰ", 600, "smelting", "精炼塔"],
	["copper_mining", "铜矿开采", "Ⅰ", 500, "basic_mining", "铜矿钻"],
	["oil_extraction", "石油开采", "Ⅰ", 550, "smelting", "抽油机"],
	["water", "水务", "Ⅰ", 120, "storage", "水井"],
	["wood", "林业", "Ⅰ", 120, "storage", "伐木场"],
	["electrolysis", "电解", "Ⅰ", 800, "refining", "电解槽"],
	["circuitry", "电路技术", "Ⅱ", 2000, "electrolysis", "芯片厂"],
	["assembly", "机械组装", "Ⅱ", 3000, "circuitry", "组装线"],
	["alloy", "合金冶炼", "Ⅱ", 4000, "circuitry", "合成器"],
	["sorting", "分拣系统", "Ⅱ", 5000, "conveyor", "分拣器"],
	["pipelines", "管道网络", "Ⅱ", 3500, "refining", "管道"],
	["teleport", "传送门", "Ⅱ", 8000, "sorting", "传送门"],
	["advanced_lab", "高级科研", "Ⅱ", 12000, "assembly", "高级实验室"],
	["blueprint", "蓝图系统", "Ⅱ", 15000, "sorting", "蓝图保存/复制"],
	["banking", "金融系统", "Ⅱ", 20000, "trade", "银行"],
	["spacefaring", "航天飞行", "Ⅲ", 50000, "advanced_lab", "货运飞船"],
	["power_grid", "电网系统", "Ⅲ", 60000, "advanced_lab", "变电站/变压器"],
	["solar", "太阳能", "Ⅲ", 40000, "circuitry", "太阳能板"],
	["wind", "风能", "Ⅲ", 30000, "power_grid", "风力涡轮"],
	["space_station", "空间站基础", "Ⅲ", 200000, "spacefaring", "空间站"],
	["life_support", "生命维持", "Ⅲ", 150000, "space_station", "生命维持模块"],
	["deep_space_mining", "深空采矿", "Ⅲ", 300000, "space_station", "深空采矿船"],
	["exchange", "期货市场", "Ⅲ", 80000, "trade", "期货交易所"],
	["express", "快递网络", "Ⅲ", 100000, "spacefaring", "快递终端"],
	["nuclear", "核能技术", "Ⅳ", 500000, "power_grid", "核反应堆"],
	["star_capture", "恒星捕获", "Ⅳ", 100000000, "nuclear", "恒星反射镜"],
	["helium3_extract", "氦-3 开采", "Ⅳ", 200000000, "star_capture", "氦-3"],
	["grav_lens", "引力透镜", "Ⅳ", 300000000, "star_capture", "引力线圈"],
	["antimatter", "反物质合成", "Ⅳ", 500000000, "grav_lens", "反物质"],
	["fusion", "核聚变", "Ⅴ", 10000000000, "antimatter", "聚变反应堆"],
	["dyson_engineering", "戴森工程", "Ⅴ", 50000000000, "antimatter", "戴森桁架厂"],
	["dyson_complete", "戴森球完工", "Ⅴ", 1000000000000000, "dyson_engineering", "通关 A"],
	["fusion_tower", "聚变塔启动", "Ⅴ", 100000000000, "fusion", "通关 B"],
]

const STAGES := [
	["Ⅰ", "星球工业", "Planet Industry"], ["Ⅱ", "自动化时代", "Automation Age"],
	["Ⅲ", "星际扩张", "Interstellar"], ["Ⅳ", "恒星工程", "Stellar Engineering"], ["Ⅴ", "戴森纪元", "Dyson Era"],
]

@onready var close_btn: Button = $Center/Panel/Content/Header/CloseBtn
@onready var science_label: Label = $Center/Panel/Content/Header/ScienceLabel
@onready var stages_list: VBoxContainer = $Center/Panel/Content/StagesScroll/StagesList


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	GameData.science_changed.connect(_refresh_science_label)
	_build_stages()


func _process(_delta: float) -> void:
	# Refresh is signal-driven; keep this empty to avoid 60 Hz label writes.
	pass


func _refresh_science_label(_points: int) -> void:
	science_label.text = "🔬 科研点: " + str(GameData.science)


func _build_stages() -> void:
	for child in stages_list.get_children():
		child.queue_free()
	for stage_def in STAGES:
		var stage_card := PanelContainer.new()
		var stage_vbox := VBoxContainer.new()
		stage_vbox.add_theme_constant_override("separation", 4)
		var stage_title := Label.new()
		stage_title.text = "阶段 %s · %s · %s" % [stage_def[0], stage_def[1], stage_def[2]]
		stage_title.add_theme_font_size_override("font_size", 16)
		stage_title.add_theme_color_override("font_color", Color(0.306, 0.804, 0.769))
		var tech_hbox := HBoxContainer.new()
		tech_hbox.add_theme_constant_override("separation", 6)
		for tech in TECHS:
			if tech[2] == stage_def[0]:
				tech_hbox.add_child(_build_tech_node(tech))
		stage_vbox.add_child(stage_title)
		stage_vbox.add_child(tech_hbox)
		stage_card.add_child(stage_vbox)
		stages_list.add_child(stage_card)


func _build_tech_node(tech: Array) -> PanelContainer:
	var id: String = tech[0]
	var cost: int = tech[3]
	var prereq: String = tech[4]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var title_lbl := Label.new()
	title_lbl.text = tech[1]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var desc_lbl := Label.new()
	desc_lbl.text = "解锁: " + str(tech[5])
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.545, 0.58, 0.62))
	var cost_lbl := Label.new()
	cost_lbl.text = "科研点: " + _fmt(cost)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 1))
	var btn := Button.new()
	if GameData.has_tech(id):
		btn.text = "✅ 已解锁"
		btn.disabled = true
	elif prereq != "-" and not GameData.has_tech(prereq):
		btn.text = "🔒 需前置"
		btn.disabled = true
	elif GameData.science < cost:
		btn.text = "研究 🔬" + _fmt(cost)
		btn.disabled = true
	else:
		btn.text = "▶ 研究"
		btn.pressed.connect(_on_research_pressed.bind(id, cost))
	vbox.add_child(title_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(cost_lbl)
	vbox.add_child(btn)
	card.add_child(vbox)
	return card


func _on_research_pressed(id: String, cost: int) -> void:
	if GameData.spend_science(cost) and GameData.unlock_tech(id):
		print("科技已解锁: %s (花费 %s)" % [id, _fmt(cost)])
		_build_stages()


func _on_close() -> void:
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		queue_free()


func _fmt(n: int) -> String:
	if n >= 1_000_000_000_000:
		return "%.2fT" % (float(n) / 1_000_000_000_000.0)
	if n >= 1_000_000_000:
		return "%.2fB" % (float(n) / 1_000_000_000.0)
	if n >= 1_000_000:
		return "%.1fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)
