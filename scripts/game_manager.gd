extends Node

const TILE_SIZE := Vector2(64, 64)
const MAP_WIDTH := 30
const MAP_HEIGHT := 17

var farm_mode := false
var build_mode := false

var selected_tiles: Array[Vector2i] = []

signal farm_mode_changed(visible: bool)
signal build_mode_changed(visible: bool)
signal selection_changed(tiles: Array[Vector2i])
signal create_character_requested()

func _ready() -> void:
	print("GameManager initialized - 按G键进入耕种模式，按J键进入建造模式，按N新建人物")

func toggle_farm_mode() -> void:
	farm_mode = not farm_mode
	if farm_mode and build_mode:
		build_mode = false
		build_mode_changed.emit(false)
	farm_mode_changed.emit(farm_mode)

func toggle_build_mode() -> void:
	build_mode = not build_mode
	if build_mode and farm_mode:
		farm_mode = false
		farm_mode_changed.emit(false)
	build_mode_changed.emit(build_mode)

func is_any_mode_active() -> bool:
	return farm_mode or build_mode

func set_selected_tiles(tiles: Array[Vector2i]) -> void:
	selected_tiles = tiles.duplicate()
	selection_changed.emit(selected_tiles)

func clear_selection() -> void:
	selected_tiles.clear()
	selection_changed.emit(selected_tiles)

func is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < MAP_WIDTH and tile.y >= 0 and tile.y < MAP_HEIGHT
