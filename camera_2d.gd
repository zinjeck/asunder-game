extends Camera2D

@export var move_speed := 500.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.4
@export var max_zoom := 3.0

func _ready():
	position = Vector2(1200, 800)

func _process(delta):
	var direction := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	position += direction.normalized() * move_speed * delta

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_speed, zoom_speed)

		zoom.x = clamp(zoom.x, min_zoom, max_zoom)
		zoom.y = clamp(zoom.y, min_zoom, max_zoom)
