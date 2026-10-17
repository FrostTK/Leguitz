class_name PlayerList
extends Control
## Who plays (multiplayer, step 2), shown while its key is held
## (InputBindings.PLAYER_LIST, when `can_show` allows): a card, its header
## the count and the server (grey), then each player in the order they
## came (this player in amber), their role on a small tag (admin amber,
## moderator steel, visitor grey) and how long their messages take there
## and back, in signal bars (Msg.PLAYERS: Peers.roster).

## A ping under these (milliseconds) is good, fair; slower is poor.
const GOOD_PING := 80
const FAIR_PING := 200
const GOOD := UiTheme.SUCCESS
const FAIR := UiTheme.ACCENT
const POOR := UiTheme.DANGER
## The roles' tags: their words and colors.
const TAGS := {
	Access.Role.ADMIN: ["PLAYERS_ADMIN", UiTheme.ACCENT],
	Access.Role.MODERATOR: ["PLAYERS_MODERATOR", UiTheme.STEEL],
	Access.Role.VISITOR: ["PLAYERS_VISITOR", UiTheme.MUTED],
}
## The signal bars: how many, how wide and how far apart (UI units).
const BARS := 3
const BAR_WIDTH := 1.0
const BAR_STEP := 2.0

## Who plays: [{id, name, ping, admin}].
var roster: Array = []
var player_id := -1
## The server ("address:port"; "": solo).
var server := ""
## Whether it may show now (no screen over the world).
var can_show := func() -> bool: return true

var _title := Label.new()
var _where := Label.new()
var _grid := GridContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.position.y = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 180
	panel.add_child(box)
	var head := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_where.add_theme_color_override("font_color", UiTheme.MUTED)
	head.add_child(_where)
	box.add_child(head)
	box.add_child(HSeparator.new())
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)
	panel.resized.connect(func() -> void: panel.position.x = -panel.size.x * 0.5)


func _process(_delta: float) -> void:
	var wanted: bool = Input.is_action_pressed(InputBindings.PLAYER_LIST) and can_show.call()
	if wanted and not visible:
		_fill()
	visible = wanted


## The roster as the server tells it.
func set_roster(players: Array) -> void:
	roster = players
	if visible:
		_fill()


## Whether the local player is one of the server's admins.
func is_admin() -> bool:
	for entry: Dictionary in roster:
		if entry.get("id") == player_id:
			return entry.get("admin", false)
	return false


func _fill() -> void:
	_title.text = tr("PLAYERS_TITLE") % roster.size()
	_where.text = server if server != "" else tr("PLAYERS_SOLO")
	for child in _grid.get_children():
		child.queue_free()
	for entry: Dictionary in roster:
		var name := Label.new()
		name.text = str(entry.get("name", ""))
		if entry.get("id") == player_id:
			name.add_theme_color_override("font_color", UiTheme.ACCENT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name)
		var role := int(entry.get("role", Access.Role.PLAYER))
		if entry.get("admin", false):
			role = Access.Role.ADMIN
		_grid.add_child(_tag(role))
		_grid.add_child(_ping(int(entry.get("ping", 0))))


## A role's small tag (none for a plain player).
static func _tag(role: int) -> Control:
	if not TAGS.has(role):
		return Control.new()
	var color: Color = TAGS[role][1]
	var tag := PanelContainer.new()
	var look := UiTheme.box(Color(color, 0.16), Color(color, 0.5), 2, 0.0)
	look.content_margin_left = 3.0
	look.content_margin_right = 3.0
	tag.add_theme_stylebox_override("panel", look)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var words := UiTheme.label(TAGS[role][0])
	words.add_theme_font_size_override("font_size", UiTheme.SMALL_FONT_SIZE)
	words.add_theme_color_override("font_color", color)
	tag.add_child(words)
	return tag


## How long a player's messages take: signal bars and the milliseconds
## (nothing known yet: none).
func _ping(ms: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_END
	if ms <= 0:
		return row
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(BAR_STEP * (BARS - 1) + BAR_WIDTH, BARS + 1.0)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars.draw.connect(_draw_bars.bind(bars, ms))
	row.add_child(bars)
	var words := UiTheme.label(tr("PLAYERS_PING") % ms)
	words.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(words)
	return row


## The bars, rising, as many lit as the ping is good.
static func _draw_bars(bars: Control, ms: int) -> void:
	var lit := 3 if ms < GOOD_PING else (2 if ms < FAIR_PING else 1)
	var color := _ping_color(ms)
	for bar in BARS:
		var height := bar + 2.0
		var rect := Rect2(bar * BAR_STEP, bars.size.y - height, BAR_WIDTH, height)
		bars.draw_rect(rect, color if bar < lit else UiTheme.LINE_STRONG)


static func _ping_color(ms: int) -> Color:
	if ms < GOOD_PING:
		return GOOD
	return FAIR if ms < FAIR_PING else POOR
