extends TestCase
## The player's book: what it says, how its pages are laid out, and the
## names of the controls it shows.


func test_every_chapter_is_written_and_every_control_has_its_keys() -> void:
	InputBindings.register_defaults()
	var chapters := GuideBook.chapters()
	assert_eq(chapters.size(), GuideBook.CHAPTERS.size())
	var untranslated := RegEx.create_from_string("^[A-Z0-9_]+$")
	for entries in chapters:
		assert_eq(entries[0]["kind"], GuideBook.Kind.TITLE, "a chapter opens with its title")
		for entry: Dictionary in entries:
			var text: String = entry["text"]
			assert_false(text.is_empty())
			assert_true(untranslated.search(text) == null or text == "Debug", "translated: " + text)
			assert_false("{" in text, "keys named: " + text)
			if entry["kind"] == GuideBook.Kind.KEYS:
				assert_false(entry["keys"].is_empty(), "keys for " + text)
				for key: String in entry["keys"]:
					assert_true(untranslated.search(key) == null or key.length() <= 6, key)
	var tools: Array = chapters[3]
	assert_true(
		tools.any(func(e: Dictionary) -> bool: return e["kind"] == GuideBook.Kind.ICON),
		"the tools are shown"
	)


func test_controls_are_named_as_on_the_keyboard_and_the_gamepad() -> void:
	InputBindings.register_defaults()
	assert_eq(InputNames.movement_keys().length(), 4, "ZQSD, WASD...")
	assert_eq(InputNames.keys(InputBindings.INVENTORY).size(), 1)
	assert_eq(InputNames.pad(InputBindings.JUMP), PackedStringArray(["A"]))
	assert_eq(InputNames.pad(InputBindings.BREAK), PackedStringArray(["RT"]))
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	assert_eq(InputNames.name_of(space), tr("KEY_SPACE"), "a key with a name")
	var f5 := InputEventKey.new()
	f5.physical_keycode = KEY_F5
	assert_eq(InputNames.name_of(f5), "F5")
	assert_eq(InputNames.keys(InputBindings.HOTBAR_BOOK).size(), 1, "the book has its key")


func test_pages_fill_up_and_chapters_start_on_a_new_page() -> void:
	var line := {"kind": GuideBook.Kind.TEXT, "text": "x"}
	var heading := {"kind": GuideBook.Kind.HEADING, "text": "h"}
	var measure := func(_entry: Dictionary) -> float: return 10.0
	var laid_out := BookScreen.paginate(
		[[line, line, line, line], [line, heading, line]], measure, 25.0
	)
	var pages: Array = laid_out[0]
	assert_eq(pages.size(), 4, "2 + 2 pages, then 1 + 2")
	assert_eq(pages[0].size(), 2)
	assert_eq(laid_out[1], [0, 2], "the second chapter on a page of its own")
	assert_eq(pages[2].size(), 1, "the heading goes over with what follows it")
	assert_eq(pages[3][0]["kind"], GuideBook.Kind.HEADING)


func test_the_book_is_an_item_of_its_own() -> void:
	assert_eq(Items.max_stack(Items.Id.GUIDE_BOOK), 1)
	assert_eq(Items.placed_voxel(Items.Id.GUIDE_BOOK), Voxels.AIR)
	assert_eq(Items.tool_of(Items.Id.GUIDE_BOOK), Items.Tool.NONE)
	var settings: Node = load("res://src/core/settings.gd").new()
	assert_true(settings.guide_book, "shown unless the player hides it")
	settings.free()
