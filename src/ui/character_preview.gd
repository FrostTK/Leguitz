class_name CharacterPreview
extends TextureRect
## The player's body as the inventory shows it (EquipmentCard, beside the
## armor): a PlayerModel of its own in a little world of its own (a
## SubViewport drawn only while it shows), lit from the front, wearing the
## armor worn and holding what is in hand (`show_player`), turned three
## quarters; dragged with the mouse, it turns.

## Its size (UI units) and texels per unit.
const SIZE := Vector2(44.0, 83.0)
const TEXELS := 2
## How much the view takes in (local units, top to bottom) and where it
## looks; how the body stands and turns with a drag (radians per unit).
const VIEW_HEIGHT := 2.95
const LOOK_AT := Vector3(0.0, 1.22, 0.0)
const REST_YAW := -0.45
const TURN := 0.04

var library: ItemLibrary

var _viewport := SubViewport.new()
var _model := PlayerModel.new()
var _armor: Array[int] = []
var _held := -1
var _turning := false


func _ready() -> void:
	custom_minimum_size = SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_viewport.size = Vector2i(SIZE * TEXELS)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT
	camera.position = LOOK_AT + Vector3(0.0, 0.35, 4.0)
	camera.rotation.x = -atan2(0.35, 4.0)
	_viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-25.0), 0.0)
	sun.light_energy = 1.05
	_viewport.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.84, 0.9)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	_viewport.add_child(_model)
	_model.rotation.y = REST_YAW
	_model.set_sky_light(1.0)
	texture = _viewport.get_texture()


## Dresses the body: the armor worn (Armor.Piece order) and what is in
## hand (only when they change).
func show_player(armor: Array[int], held: int) -> void:
	if armor != _armor:
		_armor = armor.duplicate()
		_model.set_armor(_armor)
	if held != _held and library != null:
		_held = held
		_model.hold_item(held, library)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_turning = button.pressed
		accept_event()
	elif motion != null and _turning:
		_model.rotation.y += motion.relative.x * TURN
		accept_event()
