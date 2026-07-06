extends Camera2D

@export var move_speed := 650.0
@export var zoom_speed := 0.15
@export var min_zoom := 0.4
@export var max_zoom := 3.0
@export var edge_scroll_speed := 700.0
@export var edge_scroll_margin := 25.0

func _ready():
	position = Vector2(1200, 880)

func _process(delta):
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		direction.y -= 1

	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()

	if mouse_position.x <= edge_scroll_margin:
		direction.x -= 1
	elif mouse_position.x >= viewport_size.x - edge_scroll_margin:
		direction.x += 1

	if mouse_position.y <= edge_scroll_margin:
		direction.y -= 1
	elif mouse_position.y >= viewport_size.y - edge_scroll_margin:
		direction.y += 1

	position += direction.normalized() * edge_scroll_speed * delta

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var mouse_world_before_zoom := get_global_mouse_position()

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(zoom_speed, zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom -= Vector2(zoom_speed, zoom_speed)

			zoom.x = clamp(zoom.x, min_zoom, max_zoom)
			zoom.y = clamp(zoom.y, min_zoom, max_zoom)

			var mouse_world_after_zoom := get_global_mouse_position()
			position += mouse_world_before_zoom - mouse_world_after_zoom
