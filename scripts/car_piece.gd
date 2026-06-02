extends Area2D
class_name CarPiece

signal selected(car: CarPiece)

var car_id := ""
var grid_position := Vector2i.ZERO
var length := 2
var orientation := "h"
var target := false
var cell_size := 88.0

@onready var body := $Body
@onready var label := $Label

func setup(data: Dictionary, size: float) -> void:
	car_id = str(data.get("id", ""))
	grid_position = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	length = int(data.get("length", 2))
	orientation = str(data.get("orientation", "h"))
	target = bool(data.get("target", false))
	cell_size = size
	_refresh_visual()

func grid_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(length):
		var offset := Vector2i(i, 0) if orientation == "h" else Vector2i(0, i)
		cells.append(grid_position + offset)
	return cells

func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell
	position = Vector2(
		grid_position.x * cell_size + cell_size * 0.5,
		grid_position.y * cell_size + cell_size * 0.5
	)

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)

func _refresh_visual() -> void:
	if not is_node_ready():
		return
	var car_size := Vector2(cell_size * length - 10.0, cell_size - 10.0)
	if orientation == "v":
		car_size = Vector2(cell_size - 10.0, cell_size * length - 10.0)
	body.size = car_size
	body.position = -car_size * 0.5
	body.color = Color(0.95, 0.21, 0.19) if target else _color_from_id(car_id)
	label.text = car_id
	label.position = Vector2(-12.0, -13.0)
	set_grid_position(grid_position)

func _color_from_id(id_text: String) -> Color:
	var hue := float(abs(id_text.hash()) % 100) / 100.0
	return Color.from_hsv(hue, 0.62, 0.88)
