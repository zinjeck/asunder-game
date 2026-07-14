extends RefCounted
class_name CitizenDebugPanel

const BUTTON_SIZE: Vector2 = Vector2(145.0, 24.0)
const LIST_PANEL_MARGIN: float = 10.0
const LIST_PANEL_SIZE: Vector2 = Vector2(540.0, 300.0)
const PANEL_PADDING: Vector2 = Vector2(12.0, 10.0)
const BODY_TOP: float = 42.0
const BODY_BOTTOM_MARGIN: float = 12.0

var debug_panel_ui: DebugPanel
var text_provider: Callable
var button: Button
var list_panel: Panel
var title_label: Label
var body_label: Label
var is_open: bool = false

#region Setup

func setup(values: Dictionary) -> void:
	if not _has_valid_setup_values(values):
		return

	debug_panel_ui = values["debug_panel"]
	text_provider = values["text_provider"]

	_create_button()
	_create_list_panel()
	_connect_debug_panel_signals()
	refresh()


func _has_valid_setup_values(values: Dictionary) -> bool:
	var required_keys: Array[String] = [
		"debug_panel",
		"text_provider",
	]

	for key in required_keys:
		if not values.has(key):
			push_error(
				"CitizenDebugPanel.setup is missing required key: "
				+ key
			)
			return false

	if not values["debug_panel"] is DebugPanel:
		push_error(
			"CitizenDebugPanel.setup debug_panel must be DebugPanel."
		)
		return false

	if typeof(values["text_provider"]) != TYPE_CALLABLE:
		push_error(
			"CitizenDebugPanel.setup text_provider must be Callable."
		)
		return false

	return true

#endregion

#region UI construction


func _create_button() -> void:
	if debug_panel_ui.panel == null:
		return

	button = Button.new()
	button.text = "Citizens"
	button.size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = WorldData.debug_mode_enabled
	button.pressed.connect(Callable(self, "_toggle_list_panel"))

	debug_panel_ui.panel.add_child(button)
	_layout_button()


func _create_list_panel() -> void:
	if debug_panel_ui.canvas_layer == null:
		return

	list_panel = Panel.new()
	list_panel.visible = false
	list_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.76)
	panel_style.border_color = Color(0.0, 0.55, 1.0, 0.60)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	list_panel.add_theme_stylebox_override("panel", panel_style)

	debug_panel_ui.canvas_layer.add_child(list_panel)

	title_label = Label.new()
	title_label.text = "CITIZENS"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.96, 1.0, 1.0)
	)
	title_label.add_theme_font_size_override("font_size", 15)
	list_panel.add_child(title_label)

	body_label = Label.new()
	body_label.text = ""
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body_label.clip_text = false
	body_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.94, 1.0, 1.0)
	)
	body_label.add_theme_font_size_override("font_size", 12)
	list_panel.add_child(body_label)

	_layout_list_panel()


func _connect_debug_panel_signals() -> void:
	var moved_callable := Callable(
		self,
		"_on_debug_panel_layout_changed"
	)

	if not debug_panel_ui.panel_moved.is_connected(moved_callable):
		debug_panel_ui.panel_moved.connect(moved_callable)

	var minimized_callable := Callable(
		self,
		"_on_debug_panel_minimized_changed"
	)

	if not debug_panel_ui.minimized_changed.is_connected(
		minimized_callable
	):
		debug_panel_ui.minimized_changed.connect(
			minimized_callable
		)

	if debug_panel_ui.panel == null:
		return

	var resized_callable := Callable(
		self,
		"_on_debug_panel_resized"
	)

	if not debug_panel_ui.panel.resized.is_connected(
		resized_callable
	):
		debug_panel_ui.panel.resized.connect(
			resized_callable
		)

#endregion

#region Visibility and layout


func refresh() -> void:
	var is_debug_panel_expanded := (
		WorldData.debug_mode_enabled
		and debug_panel_ui != null
		and not debug_panel_ui.is_minimized
	)

	if button != null:
		button.visible = is_debug_panel_expanded
		button.text = "Hide Citizens" if is_open else "Citizens"
		_layout_button()

	if list_panel == null:
		return

	list_panel.visible = is_debug_panel_expanded and is_open

	if not list_panel.visible:
		return

	_layout_list_panel()
	_refresh_list_text()


func _toggle_list_panel() -> void:
	is_open = not is_open
	refresh()


func _layout_button() -> void:
	if button == null or debug_panel_ui == null:
		return

	var accessory_rect := debug_panel_ui.get_header_accessory_rect()

	button.position = Vector2(
		accessory_rect.end.x - button.size.x,
		accessory_rect.position.y
		+ maxf(
			(accessory_rect.size.y - button.size.y) * 0.5,
			0.0
		)
	)
	button.move_to_front()


func _layout_list_panel() -> void:
	if list_panel == null or debug_panel_ui == null:
		return

	if debug_panel_ui.panel == null:
		return

	list_panel.position = (
		debug_panel_ui.panel.position
		+ Vector2(
			debug_panel_ui.panel.size.x + LIST_PANEL_MARGIN,
			0.0
		)
	)
	list_panel.size = LIST_PANEL_SIZE

	if title_label != null:
		title_label.position = PANEL_PADDING
		title_label.size = Vector2(
			LIST_PANEL_SIZE.x - PANEL_PADDING.x * 2.0,
			24.0
		)

	if body_label != null:
		body_label.position = Vector2(
			PANEL_PADDING.x,
			BODY_TOP
		)
		body_label.size = Vector2(
			LIST_PANEL_SIZE.x - PANEL_PADDING.x * 2.0,
			LIST_PANEL_SIZE.y - BODY_TOP - BODY_BOTTOM_MARGIN
		)


func _refresh_list_text() -> void:
	if body_label == null or not text_provider.is_valid():
		return

	body_label.text = str(text_provider.call())

#endregion

#region Signal callbacks


func _on_debug_panel_layout_changed(
	_new_position: Vector2
) -> void:
	_layout_list_panel()


func _on_debug_panel_minimized_changed(
	_is_minimized: bool
) -> void:
	refresh()


func _on_debug_panel_resized() -> void:
	_layout_button()
	_layout_list_panel()

#endregion
