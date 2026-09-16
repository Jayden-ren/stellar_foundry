class_name BuildingData
extends Resource

@export var id: String = "smelter"
@export var display_name: String = "熔炉"
@export var category: String = "processing"
@export var icon: String = "🔥"
@export var desc: String = "基础加工建筑"
@export var req_tech: String = ""
@export var cost: int = 250
@export var color: Color = Color(0.80, 0.35, 0.25)
@export_range(1, 4) var size: int = 1
@export_range(0.0, 10.0, 0.1) var cycle_interval: float = 3.0
@export var enabled: bool = true
