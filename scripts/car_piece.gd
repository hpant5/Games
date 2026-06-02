extends Area2D
class_name CarPiece

signal selected(car: CarPiece)
signal drag_requested(car: CarPiece, direction: int)

var car_id := ""
var grid_position := Vector2i.ZERO
var length := 2
var orientation := "h"
var target := false
var cell_size := 88.0
var board_origin := Vector2.ZERO
var drag_start := Vector2.ZERO

@onready var body := $Body as Polygon2D
@onready var windshield := $Windshield as Polygon2D
@onready var wheel_1 := $Wheel1 as ColorRect
@onready var wheel_2 := $Wheel2 as ColorRect
@onready var wheel_3 := $Wheel3 as ColorRect
@onready var wheel_4 := $Wheel4 as ColorRect
@onready var label := $Label
@onready var collision := $CollisionShape2D as CollisionShape2D

func setup(data: Dictionary, size: float, origin: Vector2) -> void:
	car_id = str(data.get("id", ""))
	grid_position = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	length = int(data.get("length", 2))
	orientation = str(data.get("orientation", "h"))
	target = bool(data.get("target", false))
	cell_size = size
	board_origin = origin
	_refresh_visual()

func grid_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(length):
		var offset := Vector2i(i, 0) if orientation == "h" else Vector2i(0, i)
		cells.append(grid_position + offset)
	return cells

func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell
	position = board_origin + Vector2(
		grid_position.x * cell_size + cell_size * 0.5,
		grid_position.y * cell_size + cell_size * 0.5
	)

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_start = event.position
		selected.emit(self)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var drag: Vector2 = event.position - drag_start
		_emit_drag_if_clear(drag)
	elif event is InputEventScreenTouch and event.pressed:
		drag_start = event.position
		selected.emit(self)
	elif event is InputEventScreenTouch and not event.pressed:
		var drag: Vector2 = event.position - drag_start
		_emit_drag_if_clear(drag)

func _emit_drag_if_clear(drag: Vector2) -> void:
	if drag.length() < 18.0:
		return
	var direction := 0
	if orientation == "h" and abs(drag.x) > abs(drag.y):
		direction = 1 if drag.x > 0.0 else -1
	elif orientation == "v" and abs(drag.y) > abs(drag.x):
		direction = 1 if drag.y > 0.0 else -1
	if direction != 0:
		drag_requested.emit(self, direction)

func _refresh_visual() -> void:
	if not is_node_ready():
		return
	var car_size := Vector2(cell_size * length - 10.0, cell_size - 10.0)
	if orientation == "v":
		car_size = Vector2(cell_size - 10.0, cell_size * length - 10.0)
	body.polygon = _rounded_car_polygon(car_size)
	body.color = Color(0.95, 0.21, 0.19) if target else _color_from_id(car_id)
	windshield.polygon = _windshield_polygon(car_size)
	windshield.color = Color(0.75, 0.9, 1.0, 0.82)
	_place_wheels(car_size)
	(collision.shape as RectangleShape2D).size = car_size
	label.text = car_id
	label.position = Vector2(-12.0, -13.0)
	set_grid_position(grid_position)

func _color_from_id(id_text: String) -> Color:
	var hue := float(abs(id_text.hash()) % 100) / 100.0
	return Color.from_hsv(hue, 0.62, 0.88)

func _rounded_car_polygon(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	var cut := 13.0
	return PackedVector2Array([
		Vector2(-half.x + cut, -half.y),
		Vector2(half.x - cut, -half.y),
		Vector2(half.x, -half.y + cut),
		Vector2(half.x, half.y - cut),
		Vector2(half.x - cut, half.y),
		Vector2(-half.x + cut, half.y),
		Vector2(-half.x, half.y - cut),
		Vector2(-half.x, -half.y + cut)
	])

func _windshield_polygon(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	if orientation == "h":
		var front := half.x - 34.0
		return PackedVector2Array([
			Vector2(front - 38.0, -half.y + 15.0),
			Vector2(front, -half.y + 15.0),
			Vector2(front + 10.0, half.y - 15.0),
			Vector2(front - 48.0, half.y - 15.0)
		])
	var front_y := -half.y + 34.0
	return PackedVector2Array([
		Vector2(-half.x + 15.0, front_y),
		Vector2(half.x - 15.0, front_y),
		Vector2(half.x - 15.0, front_y + 48.0),
		Vector2(-half.x + 15.0, front_y + 38.0)
	])

func _place_wheels(size: Vector2) -> void:
	var half := size * 0.5
	var wheel_size := Vector2(15.0, 26.0)
	if orientation == "v":
		wheel_size = Vector2(26.0, 15.0)
	var offsets: Array[Vector2] = []
	if orientation == "h":
		offsets = [
			Vector2(-half.x + 28.0, -half.y - 4.0),
			Vector2(half.x - 42.0, -half.y - 4.0),
			Vector2(-half.x + 28.0, half.y - 22.0),
			Vector2(half.x - 42.0, half.y - 22.0)
		]
	else:
		offsets = [
			Vector2(-half.x - 4.0, -half.y + 28.0),
			Vector2(-half.x - 4.0, half.y - 42.0),
			Vector2(half.x - 22.0, -half.y + 28.0),
			Vector2(half.x - 22.0, half.y - 42.0)
		]
	var wheels := [wheel_1, wheel_2, wheel_3, wheel_4]
	for i in range(wheels.size()):
		wheels[i].color = Color(0.03, 0.035, 0.045)
		wheels[i].size = wheel_size
		wheels[i].position = offsets[i]
