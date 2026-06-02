extends Node2D

const CarPieceScene = preload("res://scenes/car_piece.tscn")

var level_index := 1
var max_levels := 1
var level_data: Dictionary = {}
var cars: Array[Node] = []
var selected_car: Node
var cell_size := 88.0
var board_origin := Vector2(96.0, 250.0)
var moves := 0
var completed := false
var drive_speed := 185.0
var reverse_speed := 105.0
var turn_speed := 2.8

@onready var board := $Board
@onready var cars_layer := $Cars
@onready var hud := $CanvasLayer/HUD
@onready var title := $CanvasLayer/Title
@onready var message := $CanvasLayer/Message
@onready var goal_hint := $CanvasLayer/GoalHint

func _ready() -> void:
	max_levels = _count_levels()
	load_level(level_index)

func _process(delta: float) -> void:
	if completed or selected_car == null:
		return
	_drive_selected_car(delta)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("restart_level"):
		load_level(level_index)
	if completed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_car_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_select_car_at(event.position)
	if selected_car == null:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB or event.keycode == KEY_SPACE:
			_select_next_car()
		else:
			var number_index := _number_key_index(event.keycode)
			if number_index >= 0 and number_index < cars.size():
				_select_car(cars[number_index])
			elif _is_drive_key(event.keycode):
				message.text = "Driving %s" % selected_car.car_id

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
	message.text = "Drive red car to EXIT"

func _drive_selected_car(delta: float) -> void:
	var throttle := 0.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		throttle -= 1.0

	var steering := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		steering -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		steering += 1.0

	if throttle == 0.0 and steering == 0.0:
		return

	var previous_position: Vector2 = selected_car.position
	var previous_rotation: float = selected_car.rotation
	var speed := drive_speed if throttle > 0.0 else reverse_speed
	var turn_direction := 1.0 if throttle >= 0.0 else -1.0
	selected_car.rotation += steering * turn_speed * turn_direction * delta
	selected_car.position += Vector2.RIGHT.rotated(selected_car.rotation) * throttle * speed * delta

	if _car_is_blocked(selected_car):
		selected_car.position = previous_position
		selected_car.rotation = previous_rotation
		message.text = "%s bumped" % selected_car.car_id
		return

	moves += 1
	_update_hud()
	_check_win(selected_car)

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
	var exit_row := int(level_data["exit"]["row"])
	var exit_y := board_origin.y + (float(exit_row) + 0.5) * cell_size
	var exit_x := board_origin.x + float(width) * cell_size
	if car.target and car.position.x > exit_x + cell_size * 0.35 and abs(car.position.y - exit_y) < cell_size * 0.6:
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
	var lot_size := Vector2(width, height) * cell_size
	var exit_row := int(level_data["exit"]["row"])
	var exit_center := board_origin + Vector2(width * cell_size, (float(exit_row) + 0.5) * cell_size)

	_add_rect(board_origin - Vector2(20.0, 20.0), lot_size + Vector2(40.0, 40.0), Color(0.06, 0.065, 0.075))
	_add_rect(board_origin, lot_size, Color(0.13, 0.145, 0.16))

	for y in range(height):
		for x in range(width):
			var tile := ColorRect.new()
			tile.color = Color(0.155, 0.17, 0.19) if (x + y) % 2 == 0 else Color(0.14, 0.155, 0.175)
			tile.size = Vector2(cell_size - 4.0, cell_size - 4.0)
			tile.position = board_origin + Vector2(x * cell_size, y * cell_size)
			board.add_child(tile)

	_add_parking_lines(width, height)
	_add_lot_border(width, height, exit_row)
	_add_exit_lane(exit_center)
	goal_hint.text = "EXIT ->"
	goal_hint.position = exit_center + Vector2(-44.0, -95.0)

func _add_rect(position: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = position
	rect.size = size
	rect.color = color
	board.add_child(rect)
	return rect

func _add_parking_lines(width: int, height: int) -> void:
	var line_color := Color(0.92, 0.86, 0.52, 0.58)
	for x in range(width + 1):
		_add_rect(board_origin + Vector2(float(x) * cell_size - 1.5, 0.0), Vector2(3.0, float(height) * cell_size), line_color)
	for y in range(height + 1):
		_add_rect(board_origin + Vector2(0.0, float(y) * cell_size - 1.5), Vector2(float(width) * cell_size, 3.0), Color(0.7, 0.72, 0.76, 0.22))

func _add_lot_border(width: int, height: int, exit_row: int) -> void:
	var curb := Color(0.84, 0.86, 0.78)
	var lot_width := float(width) * cell_size
	var lot_height := float(height) * cell_size
	_add_rect(board_origin - Vector2(14.0, 14.0), Vector2(lot_width + 28.0, 14.0), curb)
	_add_rect(board_origin + Vector2(-14.0, lot_height), Vector2(lot_width + 28.0, 14.0), curb)
	_add_rect(board_origin - Vector2(14.0, 0.0), Vector2(14.0, lot_height), curb)

	var top_height := float(exit_row) * cell_size
	var bottom_y := float(exit_row + 1) * cell_size
	_add_rect(board_origin + Vector2(lot_width, 0.0), Vector2(14.0, top_height), curb)
	_add_rect(board_origin + Vector2(lot_width, bottom_y), Vector2(14.0, lot_height - bottom_y), curb)

func _add_exit_lane(exit_center: Vector2) -> void:
	var lane := Polygon2D.new()
	lane.color = Color(0.08, 0.55, 0.24)
	lane.polygon = PackedVector2Array([
		exit_center + Vector2(-cell_size * 0.5, -cell_size * 0.5),
		exit_center + Vector2(cell_size * 1.65, -cell_size * 0.5),
		exit_center + Vector2(cell_size * 1.95, 0.0),
		exit_center + Vector2(cell_size * 1.65, cell_size * 0.5),
		exit_center + Vector2(-cell_size * 0.5, cell_size * 0.5)
	])
	board.add_child(lane)

	for i in range(3):
		var arrow := Polygon2D.new()
		arrow.color = Color(1.0, 1.0, 1.0, 0.82)
		var center := exit_center + Vector2(float(i) * 42.0 + 12.0, 0.0)
		arrow.polygon = PackedVector2Array([
			center + Vector2(-14.0, -18.0),
			center + Vector2(16.0, 0.0),
			center + Vector2(-14.0, 18.0),
			center + Vector2(-5.0, 0.0)
		])
		board.add_child(arrow)

func _spawn_cars() -> void:
	for car_data in level_data["cars"]:
		var car := CarPieceScene.instantiate()
		cars_layer.add_child(car)
		car.setup(car_data, cell_size, board_origin)
		car.selected.connect(_select_car)
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
	hud.text = "Level %d/%d   Drive ticks %d   R restart" % [level_index, max_levels, moves]

func _select_car_at(screen_position: Vector2) -> void:
	for i in range(cars.size() - 1, -1, -1):
		var car := cars[i]
		if _car_contains_point(car, screen_position):
			_select_car(car)
			return

func _car_contains_point(car: Node, screen_position: Vector2) -> bool:
	var car_size := Vector2(cell_size * car.length - 10.0, cell_size - 10.0)
	if car.orientation == "v":
		car_size = Vector2(cell_size - 10.0, cell_size * car.length - 10.0)
	var rect := Rect2(car.position - car_size * 0.5, car_size)
	return rect.has_point(screen_position)

func _select_next_car() -> void:
	if cars.is_empty():
		return
	var current_index := cars.find(selected_car)
	var next_index := (current_index + 1) % cars.size()
	_select_car(cars[next_index])

func _number_key_index(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode - KEY_1)
	return -1

func _is_drive_key(keycode: Key) -> bool:
	return keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]

func _count_levels() -> int:
	var dir := DirAccess.open("res://levels")
	if dir == null:
		return 1
	var count := 0
	for file_name in dir.get_files():
		if file_name.begins_with("level_") and file_name.ends_with(".json"):
			count += 1
	return max(count, 1)

func _car_is_blocked(car: Node) -> bool:
	if not _car_stays_in_lot(car):
		return true
	for other in cars:
		if other == car:
			continue
		if _car_rect(car).intersects(_car_rect(other)):
			return true
	return false

func _car_stays_in_lot(car: Node) -> bool:
	var width := int(level_data["width"])
	var height := int(level_data["height"])
	var lot_rect := Rect2(board_origin, Vector2(width, height) * cell_size)
	var rect := _car_rect(car)
	if car.target and _is_near_exit(car):
		var expanded := lot_rect.grow(cell_size * 0.4)
		expanded.size.x += cell_size * 1.4
		return expanded.encloses(rect)
	return lot_rect.encloses(rect)

func _is_near_exit(car: Node) -> bool:
	var exit_row := int(level_data["exit"]["row"])
	var exit_y := board_origin.y + (float(exit_row) + 0.5) * cell_size
	return abs(car.position.y - exit_y) < cell_size * 0.65 and cos(car.rotation) > 0.35

func _car_rect(car: Node) -> Rect2:
	var half: Vector2 = car.car_size * 0.5
	var points := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	]
	var first: Vector2 = car.position + points[0].rotated(car.rotation)
	var rect := Rect2(first, Vector2.ZERO)
	for point in points:
		rect = rect.expand(car.position + point.rotated(car.rotation))
	return rect
