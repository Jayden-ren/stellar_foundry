extends Control

const GOODS := [
	["iron_ore", "⛏ 铁矿", 1], ["copper_ore", "🟧 铜矿", 2], ["coal", "⚫ 煤炭", 3],
	["oil", "🛢 石油", 5], ["water", "💧 水", 1], ["steel", "⬜ 钢锭", 15], ["copper", "🟫 铜锭", 20],
	["gasoline", "🟡 汽油", 25], ["wire", "🔌 电线", 250], ["circuit", "🟩 电路板", 800],
	["controller", "🖥 控制器", 20000], ["reactor_core", "☢ 反应堆核心", 800000],
	["helium3", "💎 氦-3", 5000000000], ["antimatter", "🟣 反物质", 20000000000], ["dyson_truss", "🌌 戴森桁架", 1000000000000],
]

enum Tab { AUTO, EXCHANGE, EXPRESS }

@onready var close_btn: Button = $Center/Panel/Content/Header/CloseBtn
@onready var money_label: Label = $Center/Panel/Content/Header/MoneyLabel
@onready var tab_auto: Button = $Center/Panel/Content/Tabs/TabAutoSell
@onready var tab_ex: Button = $Center/Panel/Content/Tabs/TabExchange
@onready var tab_express: Button = $Center/Panel/Content/Tabs/TabExpress
@onready var goods_list: VBoxContainer = $Center/Panel/Content/MarketScroll/GoodsList

var current_tab: int = Tab.AUTO
var exchange_prices: Dictionary = {}
var exchange_timer: float = 0.0

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	tab_auto.pressed.connect(_on_tab_pressed.bind(Tab.AUTO))
	tab_ex.pressed.connect(_on_tab_pressed.bind(Tab.EXCHANGE))
	tab_express.pressed.connect(_on_tab_pressed.bind(Tab.EXPRESS))
	GameData.money_changed.connect(_refresh_money_label)
	_init_exchange_prices()
	_on_tab_pressed(Tab.AUTO)

func _process(delta: float) -> void:
	exchange_timer += delta
	if exchange_timer >= 3.0:
		exchange_timer = 0.0
		_refresh_exchange_prices()
		if current_tab == Tab.EXCHANGE:
			_refresh_list()

func _init_exchange_prices() -> void:
	for row in GOODS:
		exchange_prices[row[0]] = row[2]

func _refresh_exchange_prices() -> void:
	for id in exchange_prices:
		exchange_prices[id] = _clamp_min(1, int(exchange_prices[id] * (1.0 + randf_range(-0.4, 0.4))))

func _on_tab_pressed(tab: int) -> void:
	current_tab = tab
	tab_auto.button_pressed = tab == Tab.AUTO
	tab_ex.button_pressed = tab == Tab.EXCHANGE
	tab_express.button_pressed = tab == Tab.EXPRESS
	_refresh_list()

func _refresh_list() -> void:
	for c in goods_list.get_children():
		c.queue_free()
	if current_tab == Tab.EXPRESS:
		_refresh_express_orders()
		return
	for row in GOODS:
		var id: String = row[0]
		var base: int = row[2]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var item_lbl := Label.new()
		item_lbl.text = row[1]
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 13)
		var qty = GameData.resources.get(id, 0)
		var qty_lbl := Label.new()
		qty_lbl.text = str(qty)
		qty_lbl.custom_minimum_size.x = 80
		qty_lbl.add_theme_font_size_override("font_size", 13)
		var price: int = base if current_tab == Tab.AUTO else int(exchange_prices.get(id, base))
		var price_lbl := Label.new()
		price_lbl.text = "$" + _fmt(price)
		price_lbl.custom_minimum_size.x = 100
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.add_theme_color_override("font_color", Color(0.933, 0.835, 0.18))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 30)
		if qty <= 0:
			btn.text = "无货"
			btn.disabled = true
		else:
			btn.text = "卖出"
			btn.pressed.connect(_on_sell_pressed.bind(id, price))
		hbox.add_child(item_lbl)
		hbox.add_child(qty_lbl)
		hbox.add_child(price_lbl)
		hbox.add_child(btn)
		goods_list.add_child(hbox)

func _refresh_express_orders() -> void:
	var orders := [
		["运送 100 钢锭到 深空交易所", 100000, "steel", 100],
		["运送 50 电路板到 殖民地", 25000, "circuit", 50],
		["运送 5 反应堆到 空间站", 5000000, "reactor_core", 5],
	]
	for order in orders:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		var desc_lbl := Label.new()
		desc_lbl.text = order[0]
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 13)
		var reward_lbl := Label.new()
		reward_lbl.text = "💰 $" + _fmt(order[1])
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", Color(0.933, 0.835, 0.18))
		var have: int = int(GameData.resources.get(order[2], 0))
		var ok: bool = have >= order[3]
		var btn := Button.new()
		btn.text = "接单" if ok else "库存不足"
		btn.disabled = not ok
		btn.custom_minimum_size = Vector2(100, 30)
		if ok:
			btn.pressed.connect(_on_accept_order.bind(order[1], order[2], order[3]))
		hbox.add_child(desc_lbl)
		hbox.add_child(reward_lbl)
		hbox.add_child(btn)
		card.add_child(hbox)
		goods_list.add_child(card)

func _on_sell_pressed(id: String, price: int) -> void:
	if GameData.consume_resource(id, 1):
		GameData.add_money(price)
		print("售出 %s × 1 → $%s" % [id, _fmt(price)])
		_refresh_list()

func _on_accept_order(reward: int, resource_id: String, required: int) -> void:
	if GameData.consume_resource(resource_id, required):
		GameData.add_money(reward)
		print("快递订单完成，收入 $%s" % _fmt(reward))
	else:
		push_warning("订单库存不足: %s × %d" % [resource_id, required])
		_refresh_list()

func _refresh_money_label(_amount: int) -> void:
	money_label.text = "💰 $" + _fmt(GameData.money)

func _on_close() -> void:
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		queue_free()

func _clamp_min(value: int, min_value: int) -> int:
	return max(min_value, value)

func _fmt(n: int) -> String:
	if n >= 1_000_000_000_000:
		return "%.2fT" % (float(n) / 1_000_000_000_000.0)
	if n >= 1_000_000_000:
		return "%.2fB" % (float(n) / 1_000_000_000.0)
	if n >= 1_000_000:
		return "%.2fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)
