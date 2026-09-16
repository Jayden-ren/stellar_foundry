class_name MineralData
extends Resource

@export var id: String = "iron_ore"
@export var display_name: String = "铁矿"
@export var color: Color = Color(0.78, 0.78, 0.80)
@export_range(0, 1000) var spawn_count: int = 25
@export_range(1, 1000) var price: int = 5
@export_range(0.0, 10.0, 0.1) var mine_interval: float = 5.0
@export_range(0.0, 10.0, 0.05) var yield_per_tick: float = 1.0
@export var smelt_output: String = ""
@export_range(0.0, 10.0, 0.1) var smelt_interval: float = 3.0
@export var enabled: bool = true
