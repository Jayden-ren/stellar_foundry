extends Node2D

signal returned_to_pool

@export var speed: float = 80.0
@export var ore_color: Color = Color(0.78, 0.78, 0.80)
@export var lifetime: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var _timer: float = 0.0
var _moving: bool = false

func initialize(pos: Vector2, dir: Vector2, color: Color) -> void:
	global_position = pos
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	ore_color = color

func on_spawn() -> void:
	_timer = lifetime
	_moving = true

func on_despawn() -> void:
	direction = Vector2.ZERO
	ore_color = Color.WHITE
	_moving = false
	_timer = 0.0

func _physics_process(delta: float) -> void:
	if not _moving:
		return
	position += direction * speed * delta
	_timer -= delta
	if _timer <= 0.0:
		_moving = false
		returned_to_pool.emit()
