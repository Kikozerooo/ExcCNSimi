extends Node2D

enum TileState {
	NORMAL,
	SELECTED,
	FARM,
	HOUSE
}

var tile_states: Dictionary = {}

var farms: Array = []
var houses: Array = []
var house_rotations: Array = []

var is_dragging := false
var drag_start_tile := Vector2i(-1, -1)
var current_drag_tile := Vector2i(-1, -1)

var current_selection: Array[Vector2i] = []
var current_selection_valid := true
var is_mouse_over_selection := false

var build_preview := false
var preview_tiles: Array[Vector2i] = []
var preview_rotation := 0

var confirm_panel: Panel
var confirm_yes_btn: Button
var confirm_no_btn: Button

var delete_panel: Panel
var delete_yes_btn: Button
var delete_no_btn: Button

var error_panel: Panel
var error_label: Label

var pending_delete_target: Array = []

var characters: Array = []
var character_tiles: Dictionary = {}
var selected_character_index: int = -1

var character_popup: Panel
var create_character_panel: Panel

var _temp_name_input: LineEdit
var _temp_farm_slider: HBoxContainer
var _temp_build_slider: HBoxContainer
var _temp_hunt_slider: HBoxContainer
var _temp_mine_slider: HBoxContainer

func _ready() -> void:
	_init_tile_states()
	_setup_confirm_panel()
	_setup_delete_panel()
	_setup_error_panel()

	GameManager.farm_mode_changed.connect(_on_farm_mode_changed)
	GameManager.build_mode_changed.connect(_on_build_mode_changed)

func _init_tile_states() -> void:
	for x in range(GameManager.MAP_WIDTH):
		for y in range(GameManager.MAP_HEIGHT):
			tile_states[Vector2i(x, y)] = TileState.NORMAL

func _setup_confirm_panel() -> void:
	confirm_panel = Panel.new()
	confirm_panel.visible = false
	add_child(confirm_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_panel.add_child(hbox)

	confirm_yes_btn = Button.new()
	confirm_yes_btn.text = "✓"
	confirm_yes_btn.custom_minimum_size = Vector2(50, 40)
	confirm_yes_btn.pressed.connect(_on_confirm_yes)
	hbox.add_child(confirm_yes_btn)

	confirm_no_btn = Button.new()
	confirm_no_btn.text = "✗"
	confirm_no_btn.custom_minimum_size = Vector2(50, 40)
	confirm_no_btn.pressed.connect(_on_confirm_no)
	hbox.add_child(confirm_no_btn)

func _setup_delete_panel() -> void:
	delete_panel = Panel.new()
	delete_panel.visible = false
	add_child(delete_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_panel.add_child(hbox)

	delete_yes_btn = Button.new()
	delete_yes_btn.text = "删除"
	delete_yes_btn.custom_minimum_size = Vector2(70, 40)
	delete_yes_btn.pressed.connect(_on_delete_yes)
	hbox.add_child(delete_yes_btn)

	delete_no_btn = Button.new()
	delete_no_btn.text = "取消"
	delete_no_btn.custom_minimum_size = Vector2(70, 40)
	delete_no_btn.pressed.connect(_on_delete_no)
	hbox.add_child(delete_no_btn)

func _setup_error_panel() -> void:
	error_panel = Panel.new()
	error_panel.visible = false
	error_panel.custom_minimum_size = Vector2(400, 50)
	error_panel.position = Vector2(760, 80)
	add_child(error_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	error_panel.add_theme_stylebox_override("panel", style)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color.WHITE)
	error_label.add_theme_font_size_override("font_size", 20)
	error_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	error_panel.add_child(error_label)

	_setup_mode_buttons()

func _setup_mode_buttons() -> void:
	var btn_container := CanvasLayer.new()
	add_child(btn_container)

	var farm_btn := Button.new()
	farm_btn.text = "耕种模式 (G)"
	farm_btn.position = Vector2(30, 1000)
	farm_btn.custom_minimum_size = Vector2(160, 60)
	farm_btn.add_theme_font_size_override("font_size", 24)
	farm_btn.pressed.connect(_on_farm_mode_btn_pressed)
	btn_container.add_child(farm_btn)

	var build_btn = Button.new()
	build_btn.text = "建造模式 (J)"
	build_btn.position = Vector2(210, 1000)
	build_btn.custom_minimum_size = Vector2(160, 60)
	build_btn.add_theme_font_size_override("font_size", 24)
	build_btn.pressed.connect(_on_build_mode_btn_pressed)
	btn_container.add_child(build_btn)

	var char_btn := Button.new()
	char_btn.text = "新建人物 (N)"
	char_btn.position = Vector2(390, 1000)
	char_btn.custom_minimum_size = Vector2(160, 60)
	char_btn.add_theme_font_size_override("font_size", 24)
	char_btn.pressed.connect(_on_create_character_btn_pressed)
	btn_container.add_child(char_btn)

	_setup_create_character_panel()

func _on_farm_mode_btn_pressed() -> void:
	if GameManager.farm_mode:
		GameManager.toggle_farm_mode()
	elif not GameManager.build_mode:
		GameManager.toggle_farm_mode()

func _on_build_mode_btn_pressed() -> void:
	if GameManager.build_mode:
		GameManager.toggle_build_mode()
	elif not GameManager.farm_mode:
		GameManager.toggle_build_mode()

func _on_create_character_btn_pressed() -> void:
	_show_create_character_panel()

func _setup_create_character_panel() -> void:
	create_character_panel = Panel.new()
	create_character_panel.size = Vector2(450, 420)
	create_character_panel.position = Vector2(735, 330)
	create_character_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	create_character_panel.add_theme_stylebox_override("panel", style)

	add_child(create_character_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	create_character_panel.add_child(vbox)

	var title_container := CenterContainer.new()
	title_container.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(title_container)

	var title_label := Label.new()
	title_label.text = "新建人物"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_container.add_child(title_label)

	var name_container := HBoxContainer.new()
	name_container.add_theme_constant_override("separation", 15)
	vbox.add_child(name_container)

	var name_label := Label.new()
	name_label.text = "姓名"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.custom_minimum_size = Vector2(70, 0)
	name_container.add_child(name_label)

	_temp_name_input = LineEdit.new()
	_temp_name_input.custom_minimum_size = Vector2(280, 45)
	_temp_name_input.add_theme_font_size_override("font_size", 20)
	_temp_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_container.add_child(_temp_name_input)

	var attrs_label := Label.new()
	attrs_label.text = "属性"
	attrs_label.add_theme_font_size_override("font_size", 20)
	attrs_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(attrs_label)

	var farm_container := CenterContainer.new()
	farm_container.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(farm_container)
	_temp_farm_slider = _create_attribute_slider("耕种")
	_temp_farm_slider.custom_minimum_size = Vector2(340, 40)
	farm_container.add_child(_temp_farm_slider)

	var build_container := CenterContainer.new()
	build_container.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(build_container)
	_temp_build_slider = _create_attribute_slider("建造")
	_temp_build_slider.custom_minimum_size = Vector2(340, 40)
	build_container.add_child(_temp_build_slider)

	var hunt_container := CenterContainer.new()
	hunt_container.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(hunt_container)
	_temp_hunt_slider = _create_attribute_slider("狩猎")
	_temp_hunt_slider.custom_minimum_size = Vector2(340, 40)
	hunt_container.add_child(_temp_hunt_slider)

	var mine_container := CenterContainer.new()
	mine_container.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(mine_container)
	_temp_mine_slider = _create_attribute_slider("采掘")
	_temp_mine_slider.custom_minimum_size = Vector2(340, 40)
	mine_container.add_child(_temp_mine_slider)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(btn_hbox)

	var confirm_btn := Button.new()
	confirm_btn.text = "确定"
	confirm_btn.custom_minimum_size = Vector2(120, 50)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.pressed.connect(_on_create_character_confirmed)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 50)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.pressed.connect(func(): create_character_panel.visible = false)

	btn_hbox.add_child(cancel_btn)
	btn_hbox.add_child(confirm_btn)

func _on_create_character_confirmed() -> void:
	print("Confirm button pressed, name: ", _temp_name_input.text)
	var farm_val = _temp_farm_slider.get_child(1).value
	var build_val = _temp_build_slider.get_child(1).value
	var hunt_val = _temp_hunt_slider.get_child(1).value
	var mine_val = _temp_mine_slider.get_child(1).value
	_create_character(_temp_name_input.text, int(farm_val), int(build_val), int(hunt_val), int(mine_val))

func _create_attribute_slider(attr_name: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = attr_name + ": "
	label.custom_minimum_size = Vector2(80, 30)
	label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(180, 30)
	slider.min_value = 0
	slider.max_value = 5
	slider.value = 3
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = "3"
	value_label.custom_minimum_size = Vector2(30, 30)
	value_label.add_theme_font_size_override("font_size", 16)
	slider.value_changed.connect(func(v): value_label.text = str(v))
	hbox.add_child(value_label)

	return hbox

func _show_create_character_panel() -> void:
	_temp_name_input.text = ""
	for slider_box in [_temp_farm_slider, _temp_build_slider, _temp_hunt_slider, _temp_mine_slider]:
		slider_box.get_child(1).value = 3
		slider_box.get_child(2).text = "3"
	create_character_panel.visible = true

func _create_character(name: String, farm: int, build: int, hunt: int, mine: int) -> void:
	if name.strip_edges() == "":
		_show_error("请输入姓名")
		return

	var tile := _find_empty_tile_for_character()
	print("Creating character at tile: ", tile)
	if tile == Vector2i(-1, -1):
		_show_error("没有空闲位置放置人物")
		return

	var character := {
		"name": name,
		"farm": farm,
		"build": build,
		"hunt": hunt,
		"mine": mine,
		"tile": tile
	}
	characters.append(character)
	var idx := characters.size() - 1
	for dx in range(2):
		for dy in range(2):
			character_tiles[tile + Vector2i(dx, dy)] = idx
	print("Character created: ", characters.size(), " characters total")

	create_character_panel.visible = false
	queue_redraw()

func _find_empty_tile_for_character() -> Vector2i:
	for y in range(GameManager.MAP_HEIGHT - 1):
		for x in range(GameManager.MAP_WIDTH - 1):
			var tile := Vector2i(x, y)
			if _is_tile_available_for_character(tile):
				return tile
	return Vector2i(-1, -1)

func _is_tile_available_for_character(tile: Vector2i) -> bool:
	for dx in range(2):
		for dy in range(2):
			var check_tile := tile + Vector2i(dx, dy)
			if check_tile in character_tiles:
				return false
			for farm in farms:
				if check_tile in farm:
					return false
			for house in houses:
				if check_tile in house:
					return false
	return true

func _on_farm_mode_changed(active: bool) -> void:
	if not active:
		current_selection.clear()
		confirm_panel.visible = false
	queue_redraw()

func _on_build_mode_changed(active: bool) -> void:
	if not active:
		build_preview = false
		preview_tiles.clear()
		current_selection.clear()
		confirm_panel.visible = false
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()
	if build_preview:
		_update_preview_position()
	_update_hover_state()

func _update_preview_position() -> void:
	if not build_preview:
		return

	var anchor := _get_preview_anchor()
	if anchor == Vector2i(-1, -1):
		preview_tiles.clear()
		return

	preview_tiles = _get_rotated_preview_tiles(anchor)
	queue_redraw()

func _update_hover_state() -> void:
	if not GameManager.is_any_mode_active():
		return

	if not current_selection.is_empty():
		var mouse_tile := _get_tile_at_mouse()
		is_mouse_over_selection = mouse_tile in current_selection

		if is_mouse_over_selection:
			_update_confirm_panel_position()
			confirm_panel.visible = true

func _draw() -> void:
	_draw_houses()
	_draw_farms()
	_draw_characters()

	if not GameManager.is_any_mode_active():
		return

	_draw_grid_lines()
	_draw_current_selection()
	_draw_preview()

func _draw_grid_lines() -> void:
	for x in range(GameManager.MAP_WIDTH):
		for y in range(GameManager.MAP_HEIGHT):
			var rect := Rect2(Vector2(x, y) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(rect, Color(0.8, 0.8, 0.8), false, 1.0)

func _draw_current_selection() -> void:
	if current_selection.is_empty():
		return

	var color: Color
	if current_selection_valid:
		color = Color(0.9, 0.7, 0.0, 0.4)
	else:
		color = Color(0.9, 0.2, 0.2, 0.4)

	for tile in current_selection:
		var rect := Rect2(Vector2(tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
		draw_rect(rect, color, true)
		if current_selection_valid:
			draw_rect(rect, Color(0.9, 0.7, 0.0), false, 2.0)
		else:
			draw_rect(rect, Color(0.9, 0.2, 0.2), false, 2.0)

func _draw_farms() -> void:
	for farm in farms:
		for tile in farm:
			var rect := Rect2(Vector2(tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(rect, Color(0.3, 0.7, 0.3, 0.5), true)
			draw_rect(rect, Color(0.2, 0.5, 0.2), false, 2.0)

func _draw_houses() -> void:
	for i in range(houses.size()):
		var house = houses[i]
		var rotation := 0
		if i < house_rotations.size():
			rotation = house_rotations[i]
		
		for tile in house:
			var rect := Rect2(Vector2(tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(rect, Color(0.4, 0.25, 0.1, 0.7), true)
			draw_rect(rect, Color(0.3, 0.15, 0.05), false, 2.0)

		if house.size() >= 6:
			var door_idx := _get_door_index(rotation)
			var door_tile = house[door_idx]
			var door_rect := Rect2(Vector2(door_tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(door_rect, Color(0.9, 0.9, 0.9, 0.8), true)

func _draw_preview() -> void:
	if not build_preview or preview_tiles.is_empty():
		return

	var color := Color(0.9, 0.7, 0.0, 0.4)
	for tile in preview_tiles:
		if GameManager.is_valid_tile(tile):
			var rect := Rect2(Vector2(tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0.9, 0.7, 0.0), false, 2.0)

	if preview_tiles.size() >= 6:
		var door_idx := _get_door_index(preview_rotation)
		var door_tile = preview_tiles[door_idx]
		if GameManager.is_valid_tile(door_tile):
			var door_rect := Rect2(Vector2(door_tile) * GameManager.TILE_SIZE, GameManager.TILE_SIZE)
			draw_rect(door_rect, Color(0.7, 0.7, 0.7, 0.7), true)

func _draw_characters() -> void:
	for i in range(characters.size()):
		var char = characters[i]
		var tile: Vector2i = char["tile"]
		var center := Vector2(tile.x + 1, tile.y + 1) * GameManager.TILE_SIZE
		var radius := GameManager.TILE_SIZE.x

		draw_circle(center, radius, Color.BLACK)

		var font = ThemeDB.fallback_font
		var font_size = 16
		var text = char["name"]
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center - Vector2(text_size.x / 2, -text_size.y / 2 + font_size / 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _get_rotated_preview_tiles(anchor: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	match preview_rotation:
		0:
			for dx in range(3):
				for dy in range(2):
					tiles.append(anchor + Vector2i(dx, dy))
		1:
			for dx in range(2):
				for dy in range(3):
					tiles.append(anchor + Vector2i(dx, dy))
		2:
			for dx in range(3):
				for dy in range(2):
					tiles.append(anchor + Vector2i(2 - dx, dy))
		3:
			for dx in range(2):
				for dy in range(3):
					tiles.append(anchor + Vector2i(dx, 2 - dy))

	return tiles

func _get_door_index(rotation: int) -> int:
	match rotation:
		0:
			return 3
		1:
			return 1
		2:
			return 2
		3:
			return 4
	return 4

func _get_tiles_in_drag_range() -> Array[Vector2i]:
	if drag_start_tile == Vector2i(-1, -1) or current_drag_tile == Vector2i(-1, -1):
		return []

	var tiles: Array[Vector2i] = []
	var min_x: int = min(drag_start_tile.x, current_drag_tile.x)
	var max_x: int = max(drag_start_tile.x, current_drag_tile.x)
	var min_y: int = min(drag_start_tile.y, current_drag_tile.y)
	var max_y: int = max(drag_start_tile.y, current_drag_tile.y)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var tile := Vector2i(x, y)
			if GameManager.is_valid_tile(tile):
				tiles.append(tile)

	return tiles

func _get_tile_at_mouse() -> Vector2i:
	var mouse_pos := get_global_mouse_position()
	var tile := Vector2i(int(mouse_pos.x / GameManager.TILE_SIZE.x), int(mouse_pos.y / GameManager.TILE_SIZE.y))
	if GameManager.is_valid_tile(tile):
		return tile
	return Vector2i(-1, -1)

func _get_preview_anchor() -> Vector2i:
	var mouse_pos := get_global_mouse_position()
	var anchor := Vector2i(
		int(mouse_pos.x / GameManager.TILE_SIZE.x) + 1,
		int(mouse_pos.y / GameManager.TILE_SIZE.y) + 1
	)
	if GameManager.is_valid_tile(anchor):
		return anchor
	return Vector2i(-1, -1)

func _check_farm_selection_valid(selection: Array[Vector2i]) -> String:
	if selection.is_empty():
		return ""

	var min_x: int = 999
	var max_x: int = -999
	var min_y: int = 999
	var max_y: int = -999

	for tile in selection:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
		max_y = max(max_y, tile.y)

	var width := max_x - min_x + 1
	var height := max_y - min_y + 1

	if width < 2 or height < 2:
		return "区域太小，需要至少2x2的面积"

	for farm in farms:
		for farm_tile in farm:
			if farm_tile in selection:
				return "区域内包含已有耕地"

	for farm in farms:
		for farm_tile in farm:
			if _is_adjacent_to_farm(farm_tile, selection):
				return "区域与已有耕地接壤"

	for house in houses:
		for house_tile in house:
			if house_tile in selection:
				return "区域内包含已有住宅"

	return ""

func _check_house_valid(tiles: Array[Vector2i]) -> String:
	if tiles.size() < 6:
		return "住宅需要3x2的面积"

	for tile in tiles:
		if not GameManager.is_valid_tile(tile):
			return "住宅超出地图范围"

	for tile in tiles:
		if tile_states.get(tile, TileState.NORMAL) == TileState.FARM:
			return "住宅不能建造在耕地上"

	for tile in tiles:
		if tile_states.get(tile, TileState.NORMAL) == TileState.HOUSE:
			return "住宅不能建造在住宅上"

	for farm in farms:
		for farm_tile in farm:
			if farm_tile in tiles:
				return "住宅不能建造在耕地上"

	for house in houses:
		for house_tile in house:
			if house_tile in tiles:
				return "住宅区域重叠"

	return ""

func _is_adjacent_to_farm(farm_tile: Vector2i, selection: Array[Vector2i]) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_tile := farm_tile + Vector2i(dx, dy)
			if check_tile in selection:
				return true
	return false

func _update_confirm_panel_position() -> void:
	if current_selection.is_empty():
		return

	var max_x: int = -999
	var max_y: int = -999

	for tile in current_selection:
		max_x = max(max_x, tile.x)
		max_y = max(max_y, tile.y)

	var panel_x := (max_x + 1) * GameManager.TILE_SIZE.x
	var panel_y := (max_y + 1) * GameManager.TILE_SIZE.y
	confirm_panel.position = Vector2(panel_x, panel_y)
	confirm_panel.size = Vector2(105, 42)

	if current_selection_valid:
		confirm_panel.visible = true
	else:
		confirm_panel.visible = false

func _update_delete_panel_position(target: Array) -> void:
	var max_x: int = -999
	var max_y: int = -999

	for tile in target:
		max_x = max(max_x, tile.x)
		max_y = max(max_y, tile.y)

	var panel_x := (max_x + 1) * GameManager.TILE_SIZE.x
	var panel_y := (max_y + 1) * GameManager.TILE_SIZE.y
	delete_panel.position = Vector2(panel_x, panel_y)
	delete_panel.size = Vector2(145, 42)
	delete_panel.visible = true

func _show_error(error_msg: String) -> void:
	error_label.text = error_msg

	error_panel.visible = true
	await get_tree().create_timer(2.0).timeout
	error_panel.visible = false

func _show_character_popup(index: int) -> void:
	if index < 0 or index >= characters.size():
		return

	if character_popup:
		character_popup.queue_free()

	character_popup = Panel.new()
	character_popup.size = Vector2(200, 150)
	add_child(character_popup)

	var char = characters[index]
	var tile: Vector2i = char["tile"]
	character_popup.position = Vector2(tile.x * GameManager.TILE_SIZE.x, (tile.y - 3) * GameManager.TILE_SIZE.y)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	character_popup.add_child(vbox)

	var name_label := Label.new()
	name_label.text = char["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var attrs = ["耕种", "建造", "狩猎", "采掘"]
	var attr_values = [char["farm"], char["build"], char["hunt"], char["mine"]]
	for i in range(attrs.size()):
		var label := Label.new()
		label.text = attrs[i] + ": " + str(attr_values[i])
		label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed:
		return

	if event.keycode == KEY_G:
		if not GameManager.build_mode:
			GameManager.toggle_farm_mode()
	elif event.keycode == KEY_J:
		if not GameManager.farm_mode:
			GameManager.toggle_build_mode()
	elif event.keycode == KEY_Z:
		if GameManager.build_mode:
			_toggle_build_preview()
	elif event.keycode == KEY_R:
		if build_preview:
			preview_rotation = (preview_rotation + 1) % 4
			queue_redraw()
	elif event.keycode == KEY_N:
		_show_create_character_panel()

func _toggle_build_preview() -> void:
	build_preview = not build_preview
	if not build_preview:
		preview_tiles.clear()
		confirm_panel.visible = false
	else:
		preview_rotation = 0
	queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not GameManager.is_any_mode_active():
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tile := _get_tile_at_mouse()
			if tile in character_tiles:
				selected_character_index = character_tiles[tile]
				_show_character_popup(selected_character_index)
				return
		return

	if GameManager.build_mode and build_preview and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var error_msg := _check_house_valid(preview_tiles)
		if error_msg != "":
			_show_error(error_msg)
			return

		if preview_tiles.size() >= 6:
			houses.append(preview_tiles.duplicate())
			house_rotations.append(preview_rotation)
			for tile in preview_tiles:
				tile_states[tile] = TileState.HOUSE

		preview_tiles.clear()
		build_preview = false
		queue_redraw()
		return

	if GameManager.build_mode:
		return

	var tile := _get_tile_at_mouse()

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if tile != Vector2i(-1, -1):
				if GameManager.farm_mode:
					var clicked_farm = _get_farm_containing_tile(tile)
					if not clicked_farm.is_empty():
						_cancel_current_selection()
						pending_delete_target = clicked_farm
						_update_delete_panel_position(clicked_farm)
						confirm_panel.visible = false
						return

				_cancel_current_selection()
				is_dragging = true
				drag_start_tile = tile
				current_drag_tile = tile
				delete_panel.visible = false
		else:
			if is_dragging and tile != Vector2i(-1, -1):
				current_selection = _get_tiles_in_drag_range()
				if GameManager.farm_mode:
					current_selection_valid = _check_farm_selection_valid(current_selection) == ""
				is_mouse_over_selection = true
				_update_confirm_panel_position()
			is_dragging = false

func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if is_dragging and GameManager.is_any_mode_active():
		current_drag_tile = _get_tile_at_mouse()
		current_selection = _get_tiles_in_drag_range()
		if GameManager.farm_mode:
			current_selection_valid = _check_farm_selection_valid(current_selection) == ""

func _cancel_current_selection() -> void:
	current_selection.clear()
	current_selection_valid = true
	is_mouse_over_selection = false
	confirm_panel.visible = false

func _get_farm_containing_tile(tile: Vector2i) -> Array:
	for farm in farms:
		if tile in farm:
			return farm
	return []

func _on_confirm_yes() -> void:
	if GameManager.farm_mode:
		var error_msg := _check_farm_selection_valid(current_selection)
		if error_msg != "":
			_show_error(error_msg)
			_cancel_current_selection()
			return

		if current_selection.is_empty():
			_cancel_current_selection()
			return

		farms.append(current_selection.duplicate())
		for tile in current_selection:
			tile_states[tile] = TileState.FARM

		_cancel_current_selection()
		confirm_panel.visible = false

func _on_confirm_no() -> void:
	_cancel_current_selection()
	confirm_panel.visible = false

func _on_delete_yes() -> void:
	if pending_delete_target.is_empty():
		return

	for tile in pending_delete_target:
		tile_states[tile] = TileState.NORMAL

	if pending_delete_target in farms:
		farms.erase(pending_delete_target)
	elif pending_delete_target in houses:
		var idx := houses.find(pending_delete_target)
		if idx >= 0 and idx < house_rotations.size():
			house_rotations.remove_at(idx)
		houses.erase(pending_delete_target)

	pending_delete_target.clear()
	delete_panel.visible = false

func _on_delete_no() -> void:
	pending_delete_target.clear()
	delete_panel.visible = false
