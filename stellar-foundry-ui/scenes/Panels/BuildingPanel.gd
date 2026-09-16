extends Control

## Building selection panel.
## Data source: BuildingRegistry + res://data/buildings/building_registry.json

@onready var close_btn: Button = $Center/Panel/Content/Header/CloseBtn
@onready var category_bar: HBoxContainer = $Center/Panel/Content/CategoryBar
@onready var buildings_list: VBoxContainer = $Center/Panel/Content/BuildingsScroll/BuildingsList

var current_category: String = "mining"
var _categories_by_label: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	GameData.money_changed.connect(_refresh_list)
	GameData.technology_changed.connect(_refresh_list)
	_prepare_categories()
	for tab in category_bar.get_children():
		tab.pressed.connect(_on_tab_pressed.bind(tab.text))
	_on_tab_pressed(_first_category_label())

func _prepare_categories() -> void:
	_categories_by_label.clear()
	for category in BuildingRegistry.get_categories():
		var category_id := str(category.get("id", ""))
		var label := str(category.get("label", ""))
		if category_id == "" or label == "":
			continue
		_categories_by_label[label] = category_id

func _on_tab_pressed(tab_text: String) -> void:
	for tab in category_bar.get_children():
		tab.button_pressed = tab.text == tab_text
	current_category = _label_to_category(tab_text)
	_refresh_list()

func _label_to_category(label: String) -> String:
	return str(_categories_by_label.get(label, "mining"))

func _first_category_label() -> String:
	for label in _categories_by_label:
		return label
	return "⛏ 采矿"

func _refresh_list() -> void:
	for c in buildings_list.get_children():
		c.queue_free()

	var items := BuildingRegistry.get_buildings_by_category(current_category)
	if items.is_empty():
		var empty_card := PanelContainer.new()
		var empty_lbl := Label.new()
		empty_lbl.text = "暂无可用建筑"
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68))
		empty_card.add_child(empty_lbl)
		buildings_list.add_child(empty_card)
		return

	for bd in items:
		var cost: int = bd.cost
		var unlocked := bd.req_tech == "" or GameData.has_tech(bd.req_tech)
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		var icon_lbl := Label.new()
		icon_lbl.text = bd.icon
		icon_lbl.custom_minimum_size.x = 32
		icon_lbl.add_theme_font_size_override("font_size", 20)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		var name_lbl := Label.new()
		name_lbl.text = bd.display_name
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		var desc_lbl := Label.new()
		desc_lbl.text = bd.desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.545, 0.58, 0.62))
		var req_lbl := Label.new()
		if bd.req_tech == "":
			req_lbl.text = "✅ 已解锁"
		else:
			req_lbl.text = "✅ 已解锁" if unlocked else "🔒 需要科技: " + bd.req_tech
		req_lbl.add_theme_font_size_override("font_size", 11)
		req_lbl.add_theme_color_override("font_color", Color(0.545, 0.8, 0.545) if unlocked else Color(0.9, 0.5, 0.5))
		info_box.add_child(name_lbl)
		info_box.add_child(desc_lbl)
		info_box.add_child(req_lbl)
		var buy_btn := Button.new()
		buy_btn.text = "$" + _fmt(cost)
		buy_btn.custom_minimum_size = Vector2(80, 32)
		buy_btn.disabled = not unlocked or GameData.money < cost
		buy_btn.pressed.connect(_on_buy_pressed.bind(bd))
		hbox.add_child(icon_lbl)
		hbox.add_child(info_box)
		hbox.add_child(buy_btn)
		card.add_child(hbox)
		buildings_list.add_child(card)

func _on_buy_pressed(building: BuildingData) -> void:
	if GameData.spend_money(building.cost):
		print("购买建筑意图: %s (花费 $%s)" % [building.id, _fmt(building.cost)])
	else:
		push_warning("资金不足，无法购买 %s" % building.id)

func _on_close() -> void:
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		queue_free()

func _fmt(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)
