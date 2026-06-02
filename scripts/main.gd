extends Node2D

const CarPieceScene = preload("res://scenes/car_piece.tscn")

var level_index := 1
var max_levels := 3
var level_data: Dictionary = {}
var cars: Array[Node] = []
var selected_car: Node
var cell_size := 88.0
var board_origin := Vector2(96.0, 250.0)
var moves := 0
var completed := false

@onready var board := $Board
@onready var cars_layer := $Cars
@onready var hud := $CanvasLayer/HUD
@onready var title := $CanvasLayer/Title
@onready var message := $CanvasLayer/Message

func _ready() -> void:
	load_level(level_index)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("restart_level"):
		load_level(level_index)
	if completed:
		return
	if selected_car == null:
		return
	if event is InputEventKey and event.pressed:
		var direction := _direction_from_key(event.keycode)
		if direction != 0:
			try_move(selected_car, direction)

func load_level(index: int) -> void:
	completed = false
	moves = 0
	selected_car = null
	cars.clear()
	for child in board.get_children():
		child.queue_free()
	for child in cars_layer.get_children():
		child.queue_free()

	var path := "res://levels/level_%d.json" % index
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse level: %s" % path)
		return
	level_data = parsed
	_build_board()
	_spawn_cars()
	_select_target_car()
	_update_hud()
	message.text = "Red car selected. Use arrows or drag."

func try_move(car: Node, direction: int) -> void:
	var delta := Vector2i(direction, 0) if car.orientation == "h" else Vector2i(0, direction)
	if not _can_move(car, delta):
		message.text = "%s is blocked" % car.car_id
		return
	car.set_grid_position(car.grid_position + delta)
	moves += 1
	message.text = "Moved %s" % car.car_id
	_update_hud()
	_check_win(car)

func _can_move(car: Node, delta: Vector2i) -> bool:
	var width := int(level_data["width"])
	var height := int(level_data["height"])
	for cell in car.grid_cells():
		var next: Vector2i = cell + delta
		if car.target and next.y == int(level_data["exit"]["row"]) and next.x >= width:
			continue
		if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
			return false
		for other in cars:
			if other == car:
				continue
			if other.grid_cells().has(next):
				return false
	return true

func _check_win(car: Node) -> void:
	var width := int(level_data["width"])
	if car.target and car.orientation == "h" and car.grid_position.x + car.length > width:
		completed = true
		message.text = "Escaped"
		await get_tree().create_timer(0.8).timeout
		if level_index < max_levels:
			level_index += 1
			load_level(level_index)
		else:
			message.text = "All lots cleared"

func _build_board() -> void:
	var width := int(level_data["width"])
	var height := int(level_data["height"])
	for y in range(height):
		for x in range(width):
			var tile := ColorRect.new()
			tile.color = Color(0.18, 0.2, 0.23) if (x + y) % 2 == 0 else Color(0.15, 0.17, 0.2)
			tile.size = Vector2(cell_size - 2.0, cell_size - 2.0)
			tile.position = board_origin + Vector2(x * cell_size, y * cell_size)
			board.add_child(tile)

	var exit_row := int(level_data["exit"]["row"])
	var exit_marker := ColorRect.new()
	exit_marker.color = Color(0.16, 0.78, 0.35)
	exit_marker.size = Vector2(42.0, cell_size - 10.0)
	exit_marker.position = board_origin + Vector2(width * cell_size + 8.0, exit_row * cell_size + 5.0)
	board.add_child(exit_marker)

func _spawn_cars() -> void:
	for car_data in level_data["cars"]:
		var car := CarPieceScene.instantiate()
		cars_layer.add_child(car)
		car.setup(car_data, cell_size, board_origin)
		car.selected.connect(_select_car)
		car.drag_requested.connect(try_move)
		cars.append(car)

func _select_target_car() -> void:
	for car in cars:
		if car.target:
			_select_car(car)
			return
	if not cars.is_empty():
		_select_car(cars[0])

func _select_car(car: Node) -> void:
	selected_car = car
	for item in cars:
		item.scale = Vector2.ONE
		item.modulate = Color(0.88, 0.88, 0.88, 1)
	car.scale = Vector2(1.06, 1.06)
	car.modulate = Color(1, 1, 1, 1)
	message.text = "Selected %s" % car.car_id

func _update_hud() -> void:
	title.text = "Parking Jam"
	hud.text = "Level %d/%d   Moves %d   R restart" % [level_index, max_levels, moves]

func _direction_from_key(keycode: Key) -> int:
	if selected_car.orientation == "h":
		if keycode == KEY_LEFT:
			return -1
		if keycode == KEY_RIGHT:
			return 1
	elif selected_car.orientation == "v":
		if keycode == KEY_UP:
			return -1
		if keycode == KEY_DOWN:
			return 1
	return 0
