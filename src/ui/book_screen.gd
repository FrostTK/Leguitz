class_name BookScreen
extends Control
## The player's book, open (what it says: GuideBook): two pages at a time
## between leather covers, chapter tabs along the top, a title page and
## the contents first, page numbers and arrows. Pages turn with the arrows,
## the wheel, the movement keys or a stick; LB/RB jump between chapters;
## Esc, E, the book's key (0) or a right click close it. The name of an
## item drawn (recipes, tools, fuels) shows beside the mouse over it. The
## world goes on behind it. Drawn in UI units.

signal close_requested

const PAGE_SIZE := Vector2(150, 188)
const COVER := 6.0
const SPINE := 4.0
const TAB_SIZE := Vector2(56, 13)
## Inside a page: the margins around the text, and the room at the bottom
## for the page number.
const MARGIN := Vector2(10, 10)
const FOOTER := 16.0
const TITLE_SIZE := 11
const HEADING_SIZE := 8
const BODY_SIZE := 7
const SMALL_SIZE := 6
## Space after an entry, and around the keys' names on their caps.
const GAP := 3.0
const KEY_PADDING := 3.0
const ICON := 16.0
## A recipe's cells, and how often a cell of a group (any planks...) shows
## its next item.
const RECIPE_CELL := 12.0
const CYCLE_MSEC := 1000
const LEATHER := Color("6e2b1c")
const LEATHER_DARK := Color("47180e")
const GOLD := Color("d8a640")
const PAPER := Color("f4e4c0")
const PAPER_SHADE := Color("dcc79d")
const KEY_FILL := Color("fbf1da")

var library: ItemLibrary

## Pages of entries (GuideBook): the title page and the contents (drawn on
## their own), then the chapters.
var _pages: Array[Array] = []
## The first page of each chapter.
var _starts: Array[int] = []
## The pages shown: 2 * _spread on the left, the next one on the right.
var _spread := 0
## What can be clicked, found while drawing: [Rect2, action, value].
var _hits: Array[Array] = []
var _hover := -1
## The items drawn, found while drawing: [Rect2, item]; and the mouse.
var _named: Array[Array] = []
var _pointer := -Vector2.ONE


## Splits chapters into pages `height` tall, each chapter from a new page;
## `measure(entry)` gives an entry's height. A heading never ends a page.
## Returns [pages, the first page of each chapter].
static func paginate(chapters: Array, measure: Callable, height: float) -> Array:
	var pages: Array[Array] = []
	var starts: Array[int] = []
	for entries: Array in chapters:
		starts.append(pages.size())
		var page := []
		var used := 0.0
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var entry_height: float = measure.call(entry)
			var needed := entry_height
			if entry["kind"] == GuideBook.Kind.HEADING and i + 1 < entries.size():
				needed += measure.call(entries[i + 1])
			if not page.is_empty() and used + needed > height:
				pages.append(page)
				page = []
				used = 0.0
			page.append(entry)
			used += entry_height
		pages.append(page)
	return [pages, starts]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Opens the book where it was left (its text is laid out again: the
## language or the controls may have changed).
func open() -> void:
	_rebuild()
	_hover = -1
	visible = true


func close() -> void:
	if visible:
		visible = false
		close_requested.emit()


## Shows the spread `step` spreads further (-1: back).
func turn(step: int) -> void:
	var spread := clampi(_spread + step, 0, _last_spread())
	if spread != _spread:
		_spread = spread
		queue_redraw()


## Shows the spread where a chapter begins.
func show_chapter(chapter: int) -> void:
	if chapter >= 0 and chapter < _starts.size():
		_spread = _starts[chapter] / 2
		queue_redraw()


func _rebuild() -> void:
	var laid_out := paginate(GuideBook.chapters(), _entry_height, _text_area(0).size.y)
	_pages = [[], []]
	_pages.append_array(laid_out[0])
	_starts.clear()
	for start: int in laid_out[1]:
		_starts.append(start + 2)
	_spread = clampi(_spread, 0, _last_spread())
	queue_redraw()


func _last_spread() -> int:
	return maxi(0, (_pages.size() - 1) / 2)


## The chapter shown (the right page's: a chapter may begin there; -1 for
## the title page and the contents).
func _chapter_shown() -> int:
	var chapter := -1
	for i in _starts.size():
		if _starts[i] <= 2 * _spread + 1:
			chapter = i
	return chapter


func _notification(what: int) -> void:
	# (Also sent when entering the tree, before _ready hides the book.)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_rebuild()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Drawn again every frame: the icons arrive after the game starts.
	queue_redraw()
	if Input.is_action_just_pressed(InputBindings.MOVE_LEFT):
		turn(-1)
	elif Input.is_action_just_pressed(InputBindings.MOVE_RIGHT):
		turn(1)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event.is_action_pressed(InputBindings.PAUSE)
		or event.is_action_pressed(InputBindings.INVENTORY)
		or event.is_action_pressed(InputBindings.HOTBAR_BOOK)
		or event.is_action_pressed(&"ui_cancel")
	):
		close()
	elif event.is_action_pressed(InputBindings.HOTBAR_NEXT):
		show_chapter(_chapter_shown() + 1)
	elif event.is_action_pressed(InputBindings.HOTBAR_PREVIOUS):
		show_chapter(maxi(_chapter_shown() - 1, 0))
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
		var hover := _hit_at(motion.position)
		if hover != _hover:
			_hover = hover
			queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	accept_event()
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			turn(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			turn(1)
		MOUSE_BUTTON_RIGHT:
			close()
		MOUSE_BUTTON_LEFT:
			var hit := _hit_at(button.position)
			if hit >= 0:
				_act(_hits[hit][1], _hits[hit][2])
			elif not _book_rect().grow_side(SIDE_TOP, TAB_SIZE.y).has_point(button.position):
				close()


func _act(action: String, value: int) -> void:
	match action:
		"chapter":
			show_chapter(value)
		"turn":
			turn(value)
		"close":
			close()


func _hit_at(point: Vector2) -> int:
	for i in _hits.size():
		var rect: Rect2 = _hits[i][0]
		if rect.has_point(point):
			return i
	return -1


## Records something clickable; returns whether the mouse is over it.
func _hit(rect: Rect2, action: String, value: int) -> bool:
	var hovered := _hover == _hits.size()
	_hits.append([rect, action, value])
	return hovered


func _book_rect() -> Rect2:
	var book := Vector2(PAGE_SIZE.x * 2.0 + SPINE + COVER * 2.0, PAGE_SIZE.y + COVER * 2.0)
	return Rect2(((size - book + Vector2(0.0, TAB_SIZE.y)) * 0.5).floor(), book)


## A page (0: left, 1: right).
func _page_rect(side: int) -> Rect2:
	var offset := Vector2(COVER + side * (PAGE_SIZE.x + SPINE), COVER)
	return Rect2(_book_rect().position + offset, PAGE_SIZE)


## Where a page's text goes.
func _text_area(side: int) -> Rect2:
	var page := _page_rect(side)
	return Rect2(
		page.position + MARGIN,
		Vector2(PAGE_SIZE.x - MARGIN.x * 2.0, PAGE_SIZE.y - MARGIN.y - FOOTER)
	)


func _draw() -> void:
	_hits.clear()
	_named.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.45))
	var font := get_theme_default_font()
	var book := _book_rect()
	_draw_tabs(font, book)
	draw_rect(book.grow(1.0), LEATHER_DARK)
	draw_rect(book, LEATHER)
	draw_rect(book.grow(-2.0), GOLD, false, 1.0)
	draw_rect(
		Rect2(book.get_center().x - SPINE * 0.5 - 1.0, book.position.y, SPINE + 2.0, book.size.y),
		LEATHER_DARK
	)
	for side in 2:
		var page := _page_rect(side)
		# The pages under this one show at its edge.
		draw_rect(Rect2(page.position + Vector2(0.0, 2.0), page.size), PAPER_SHADE.darkened(0.3))
		draw_rect(Rect2(page.position + Vector2(0.0, 1.0), page.size), PAPER_SHADE)
		draw_rect(page, PAPER)
		# The paper darkens into the fold.
		for i in 4:
			var x := page.end.x - 1.0 - i if side == 0 else page.position.x + i
			var shade := Color(PAPER_SHADE.darkened(0.1), 0.9 - i * 0.22)
			draw_rect(Rect2(x, page.position.y, 1.0, page.size.y), shade)
		_draw_page(font, 2 * _spread + side, side)
	_draw_arrows()
	_draw_close(book)
	for spot: Array in _named:
		var rect: Rect2 = spot[0]
		if rect.has_point(_pointer):
			ItemSlot.draw_name(self, spot[1], _pointer)
			break


func _draw_tabs(font: Font, book: Rect2) -> void:
	var shown := _chapter_shown()
	var count := GuideBook.CHAPTERS.size()
	var tab := Vector2(minf(TAB_SIZE.x, (book.size.x - 24.0) / count - 2.0), TAB_SIZE.y)
	for i in count:
		var at := book.position + Vector2(12.0 + i * (tab.x + 2.0), 1.0 - tab.y)
		var rect := Rect2(at, tab + Vector2(0.0, 4.0))
		var hovered := _hit(rect, "chapter", i)
		var fill := PAPER_SHADE.darkened(0.12)
		if i == shown:
			fill = PAPER
		elif hovered:
			fill = PAPER_SHADE
		draw_rect(rect, fill)
		draw_rect(rect, LEATHER_DARK, false, 1.0)
		var baseline := at.y + 3.0 + font.get_ascent(SMALL_SIZE)
		draw_string(
			font,
			Vector2(at.x, baseline),
			tr(GuideBook.CHAPTERS[i]),
			HORIZONTAL_ALIGNMENT_CENTER,
			tab.x,
			SMALL_SIZE,
			UiTheme.INK
		)


func _draw_page(font: Font, index: int, side: int) -> void:
	if index >= _pages.size():
		return
	var area := _text_area(side)
	if index == 0:
		_draw_title_page(font, area)
	elif index == 1:
		_draw_contents(font, area)
	else:
		var y := area.position.y
		for entry: Dictionary in _pages[index]:
			_draw_entry(font, entry, Vector2(area.position.x, y), area.size.x)
			y += _entry_height(entry)
		var page := _page_rect(side)
		draw_string(
			font,
			Vector2(page.position.x, page.end.y - 6.0),
			str(index + 1),
			HORIZONTAL_ALIGNMENT_CENTER,
			page.size.x,
			SMALL_SIZE,
			UiTheme.WOOD
		)


func _draw_title_page(font: Font, area: Rect2) -> void:
	var y := area.position.y + 16.0
	var size_big := TITLE_SIZE + 3
	draw_string(
		font,
		Vector2(area.position.x, y + font.get_ascent(size_big)),
		tr("BOOK_TITLE"),
		HORIZONTAL_ALIGNMENT_CENTER,
		area.size.x,
		size_big,
		UiTheme.INK
	)
	y += font.get_height(size_big) + 8.0
	var icon := library.icon(Items.Id.GUIDE_BOOK) if library != null else null
	if icon != null:
		draw_texture_rect(
			icon, Rect2(Vector2(area.get_center().x - 16.0, y), Vector2(32, 32)), false
		)
	y += 42.0
	draw_multiline_string(
		font,
		Vector2(area.position.x, y + font.get_ascent(BODY_SIZE)),
		tr("BOOK_INTRO"),
		HORIZONTAL_ALIGNMENT_CENTER,
		area.size.x,
		BODY_SIZE,
		-1,
		UiTheme.INK
	)


func _draw_contents(font: Font, area: Rect2) -> void:
	var title := {"kind": GuideBook.Kind.TITLE, "text": tr("BOOK_CONTENTS")}
	_draw_entry(font, title, area.position, area.size.x)
	var y := area.position.y + _entry_height(title) + 6.0
	var line := font.get_height(BODY_SIZE)
	for chapter in GuideBook.CHAPTERS.size():
		var rect := Rect2(area.position.x - 2.0, y - 1.0, area.size.x + 4.0, line + 2.0)
		if _hit(rect, "chapter", chapter):
			draw_rect(rect, Color(UiTheme.BUTTON, 0.6))
		var baseline := y + font.get_ascent(BODY_SIZE)
		var chapter_name := tr(GuideBook.CHAPTERS[chapter])
		var number := str(_starts[chapter] + 1) if chapter < _starts.size() else ""
		draw_string(
			font,
			Vector2(area.position.x, baseline),
			chapter_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			BODY_SIZE,
			UiTheme.INK
		)
		draw_string(
			font,
			Vector2(area.position.x, baseline),
			number,
			HORIZONTAL_ALIGNMENT_RIGHT,
			area.size.x,
			BODY_SIZE,
			UiTheme.WOOD
		)
		# Dots from the name to its page.
		var from := area.position.x + _string_width(font, chapter_name, BODY_SIZE) + 3.0
		var to := area.end.x - _string_width(font, number, BODY_SIZE) - 3.0
		var x := ceilf(from)
		while x < to:
			draw_rect(Rect2(x, baseline - 1.0, 1.0, 1.0), UiTheme.WOOD)
			x += 3.0
		y += line + 5.0


## An entry's height, the space after it included.
func _entry_height(entry: Dictionary) -> float:
	var font := get_theme_default_font()
	var width := PAGE_SIZE.x - MARGIN.x * 2.0
	var text: String = entry["text"]
	match entry["kind"]:
		GuideBook.Kind.TITLE:
			return font.get_height(TITLE_SIZE) + 6.0
		GuideBook.Kind.HEADING:
			return _text_height(font, text, width, HEADING_SIZE) + 2.0 + GAP
		GuideBook.Kind.TEXT:
			return _text_height(font, text, width, BODY_SIZE) + GAP
		GuideBook.Kind.TIP:
			return _text_height(font, text, width - 6.0, BODY_SIZE) + GAP
		GuideBook.Kind.KEYS:
			var keys_width := _keys_width(font, entry["keys"])
			var label := _text_height(font, text, width - keys_width - 4.0, BODY_SIZE)
			return maxf(label, _key_height(font)) + GAP
		GuideBook.Kind.COMBO:
			var how := _text_height(font, entry["how"], width - 6.0, SMALL_SIZE)
			return _text_height(font, text, width, BODY_SIZE) + how + GAP
		GuideBook.Kind.ICON:
			return maxf(ICON, _text_height(font, text, width - ICON - 4.0, BODY_SIZE)) + GAP
		GuideBook.Kind.RECIPE:
			var grid := _recipe_size(entry["recipes"][0])
			var text_width := width - _recipe_width(grid) - 4.0
			var rows := maxf(grid.y, 1.0) * RECIPE_CELL
			return maxf(rows, _text_height(font, text, text_width, BODY_SIZE)) + GAP + 2.0
	return 0.0


func _draw_entry(font: Font, entry: Dictionary, at: Vector2, width: float) -> void:
	var text: String = entry["text"]
	match entry["kind"]:
		GuideBook.Kind.TITLE:
			var baseline := at.y + font.get_ascent(TITLE_SIZE)
			draw_string(
				font,
				Vector2(at.x, baseline),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				width,
				TITLE_SIZE,
				UiTheme.INK
			)
			draw_rect(
				Rect2(at.x, at.y + font.get_height(TITLE_SIZE) + 1.0, width, 1.0), UiTheme.WOOD
			)
		GuideBook.Kind.HEADING:
			_paragraph(font, text, at + Vector2(0.0, 2.0), width, HEADING_SIZE, UiTheme.WOOD)
		GuideBook.Kind.TEXT:
			_paragraph(font, text, at, width, BODY_SIZE, UiTheme.INK)
		GuideBook.Kind.TIP:
			var dot := Vector2(at.x + 1.0, at.y + floorf(font.get_ascent(BODY_SIZE) * 0.6))
			draw_rect(Rect2(dot, Vector2(2.0, 2.0)), UiTheme.WOOD)
			_paragraph(font, text, at + Vector2(6.0, 0.0), width - 6.0, BODY_SIZE, UiTheme.INK)
		GuideBook.Kind.KEYS:
			var keys: PackedStringArray = entry["keys"]
			var keys_width := _keys_width(font, keys)
			var label_height := font.get_height(BODY_SIZE)
			_paragraph(font, text, at, width - keys_width - 4.0, BODY_SIZE, UiTheme.INK)
			var key_top := at.y + floorf((label_height - _key_height(font)) * 0.5)
			_draw_keys(font, keys, Vector2(at.x + width - keys_width, key_top))
		GuideBook.Kind.COMBO:
			_paragraph(font, text, at, width, BODY_SIZE, UiTheme.INK)
			var below := Vector2(6.0, _text_height(font, text, width, BODY_SIZE))
			_paragraph(font, entry["how"], at + below, width - 6.0, SMALL_SIZE, UiTheme.WOOD)
		GuideBook.Kind.ICON:
			var icon := library.icon(entry["item"]) if library != null else null
			if icon != null:
				draw_texture_rect(icon, Rect2(at, Vector2.ONE * ICON), false)
				_named.append([Rect2(at, Vector2.ONE * ICON), entry["item"]])
			var text_width := width - ICON - 4.0
			var text_height := _text_height(font, text, text_width, BODY_SIZE)
			var beside := Vector2(ICON + 4.0, maxf(0.0, floorf((ICON - text_height) * 0.5)))
			_paragraph(font, text, at + beside, text_width, BODY_SIZE, UiTheme.INK)
		GuideBook.Kind.RECIPE:
			_draw_recipe(font, entry, at, width)


## A recipe: its grid of ingredients, an arrow, what it makes and its
## name. Groups (and entries of several recipes) go through their items.
func _draw_recipe(font: Font, entry: Dictionary, at: Vector2, width: float) -> void:
	var recipes: Array = entry["recipes"]
	var tick := Time.get_ticks_msec() / CYCLE_MSEC
	var recipe: Dictionary = recipes[tick % recipes.size()]
	var grid := _recipe_size(recipe)
	for y in grid.y:
		for x in grid.x:
			var ingredient: Variant = _recipe_ingredient(recipe, Vector2i(x, y))
			var cell := Rect2(at + Vector2(x, y) * RECIPE_CELL, Vector2.ONE * (RECIPE_CELL - 1.0))
			_draw_cell(cell, _item_of(ingredient, tick))
	var middle := at.y + floorf(grid.y * RECIPE_CELL * 0.5)
	var arrow_x := at.x + grid.x * RECIPE_CELL + 2.0
	draw_rect(Rect2(arrow_x, middle - 1.0, 4.0, 2.0), UiTheme.WOOD)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(arrow_x + 4.0, middle - 3.0),
				Vector2(arrow_x + 7.0, middle),
				Vector2(arrow_x + 4.0, middle + 3.0)
			]
		),
		UiTheme.WOOD
	)
	var result: Array = recipe["result"]
	var result_at := Vector2(arrow_x + 9.0, middle - floorf(RECIPE_CELL * 0.5))
	_draw_cell(Rect2(result_at, Vector2.ONE * (RECIPE_CELL - 1.0)), result[0])
	var text_x := at.x + _recipe_width(grid) + 4.0
	var text: String = entry["text"]
	var text_width := at.x + width - text_x
	var text_top := middle - floorf(_text_height(font, text, text_width, BODY_SIZE) * 0.5)
	_paragraph(font, text, Vector2(text_x, text_top), text_width, BODY_SIZE, UiTheme.INK)


## A cell of a recipe: a frame and the item's icon.
func _draw_cell(cell: Rect2, item: int) -> void:
	draw_rect(cell, KEY_FILL)
	draw_rect(cell, PAPER_SHADE.darkened(0.25), false, 1.0)
	var icon := library.icon(item) if library != null and item != Items.Id.NONE else null
	if icon != null:
		draw_texture_rect(icon, cell.grow(-0.5), false)
		_named.append([cell, item])


## The cells of a recipe's grid: its pattern, or a row of its ingredients.
static func _recipe_size(recipe: Dictionary) -> Vector2i:
	if recipe.has("pattern"):
		var pattern: Array = recipe["pattern"]
		return Vector2i(String(pattern[0]).length(), pattern.size())
	return Vector2i(recipe["ingredients"].size(), 1)


static func _recipe_ingredient(recipe: Dictionary, cell: Vector2i) -> Variant:
	if recipe.has("pattern"):
		return Recipes.ingredient_at(recipe, cell)
	return recipe["ingredients"][cell.x]


## The width of a recipe drawn: its grid, the arrow and what it makes.
static func _recipe_width(grid: Vector2i) -> float:
	return grid.x * RECIPE_CELL + 9.0 + RECIPE_CELL


## The item an ingredient shows now (a group goes through its items).
static func _item_of(ingredient: Variant, tick: int) -> int:
	if ingredient == null:
		return Items.Id.NONE
	if ingredient is Array:
		return ingredient[tick % ingredient.size()]
	return int(ingredient)


func _paragraph(
	font: Font, text: String, at: Vector2, width: float, font_size: int, color: Color
) -> void:
	var baseline := Vector2(at.x, at.y + font.get_ascent(font_size))
	draw_multiline_string(
		font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color
	)


func _text_height(font: Font, text: String, width: float, font_size: int) -> float:
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y


func _string_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _key_height(font: Font) -> float:
	return font.get_height(SMALL_SIZE) + 3.0


func _key_width(font: Font, key: String) -> float:
	return ceilf(_string_width(font, key, SMALL_SIZE)) + KEY_PADDING * 2.0


func _keys_width(font: Font, keys: PackedStringArray) -> float:
	var width := 0.0
	for key in keys:
		width += _key_width(font, key) + 2.0
	return maxf(width - 2.0, 0.0)


## Keys drawn as keyboard caps, from `at` (top left) rightwards.
func _draw_keys(font: Font, keys: PackedStringArray, at: Vector2) -> void:
	var x := at.x
	var height := _key_height(font)
	for key in keys:
		var rect := Rect2(x, at.y, _key_width(font, key), height)
		draw_rect(rect, KEY_FILL)
		draw_rect(
			Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), PAPER_SHADE.darkened(0.2)
		)
		draw_rect(rect, UiTheme.WOOD_DARK, false, 1.0)
		var baseline := at.y + 1.5 + font.get_ascent(SMALL_SIZE)
		draw_string(
			font,
			Vector2(x + KEY_PADDING, baseline),
			key,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			SMALL_SIZE,
			UiTheme.INK
		)
		x += rect.size.x + 2.0


## The arrows turning the pages, at the bottom outer corners.
func _draw_arrows() -> void:
	for side in 2:
		var step := -1 if side == 0 else 1
		if _spread + step < 0 or _spread + step > _last_spread():
			continue
		var page := _page_rect(side)
		var x := page.position.x + 11.0 if side == 0 else page.end.x - 11.0
		var center := Vector2(x, page.end.y - 8.0)
		var color := UiTheme.WOOD
		if _hit(Rect2(center - Vector2(7.0, 6.0), Vector2(14.0, 12.0)), "turn", step):
			color = UiTheme.WOOD_DARK
		var tip := Vector2(4.0 * step, 0.0)
		var back := Vector2(-3.0 * step, 0.0)
		draw_colored_polygon(
			PackedVector2Array(
				[center + tip, center + back + Vector2(0, -4.0), center + back + Vector2(0, 4.0)]
			),
			color
		)


## A cross at the cover's top right corner closes the book.
func _draw_close(book: Rect2) -> void:
	var center := Vector2(book.end.x - 1.0, book.position.y + 1.0)
	var color := GOLD
	if _hit(Rect2(center - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), "close", 0):
		color = PAPER
	draw_circle(center, 5.0, LEATHER_DARK)
	draw_line(center + Vector2(-2.5, -2.5), center + Vector2(2.5, 2.5), color, 1.0)
	draw_line(center + Vector2(-2.5, 2.5), center + Vector2(2.5, -2.5), color, 1.0)
