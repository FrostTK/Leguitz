class_name ClientMessages
extends RefCounted
## What the client does with each message from the server (GameClient
## polls its transport every frame and hands them here, in order).


static func handle(client: GameClient, message: Dictionary) -> void:
	match message.get("t"):
		Msg.WELCOME:
			client.player_id = message["player_id"]
			client.dropped_items.player_id = client.player_id
			client.creatures.player_id = client.player_id
			client.world_info = message["world"]
			client.local_player.spawn_at(message["spawn"], message["h"])
			client.joined = true
			client.snap_camera()
		Msg.CHUNK_DATA:
			var chunk := ChunkData.from_dict(message["chunk"])
			client.world.store(chunk)
			client.world_view.show_chunk(chunk)
			client.weather_effects.terrain_changed()
		Msg.CHUNK_UNLOAD:
			client.world.remove(message["coord"])
			client.world_view.remove_chunk(message["coord"])
		Msg.TIME_STATE:
			client.clock.load_dict(message["clock"])
			if client.pause_menu.visible:
				client.pause_menu.refresh_from_state()
		Msg.PLAYER_CORRECTION:
			client.local_player.apply_correction(message["pos"], message["h"])
		Msg.PLAYER_TELEPORT:
			client.local_player.apply_correction(message["pos"], message["h"])
			client.snap_camera()
		Msg.MAP_DATA:
			client.debug_map.show_map(message["png"], message["scale"])
		Msg.WEATHER_STATE:
			client.weather_effects.apply_state(message["weather"])
		Msg.WORLD_SAVED:
			client.save_notice.flash()
		Msg.BLOCK_CHANGED:
			client.interaction.on_block_changed(message["cell"], message["voxel"])
			client.weather_effects.terrain_changed()
			client.actions.close_if_gone(message["cell"])
		Msg.VITALS:
			client.vitals.on_vitals(
				message["health"], message["food"], message["hurt"], message["air"]
			)
			client.vitals.on_effects(message.get("effects", {}))
		Msg.DIED:
			client.vitals.on_passed_out(message["cause"])
		Msg.GAME_MODE:
			client.modes.on_game_mode(message["mode"], message["spectator"])
		Msg.INVENTORY:
			var inventory := client.inventory
			var selected := inventory.selected
			inventory.load_dict(message["inventory"])
			# The hand follows the player's own choice (the server may lag).
			inventory.selected = selected
		Msg.CHEST:
			var actions := client.actions
			if actions.chest != null and message["cell"] == actions.chest_cell:
				actions.chest.load_dict(message["chest"])
		Msg.FURNACE:
			var actions := client.actions
			if actions.furnace != null and message["cell"] == actions.furnace_cell:
				actions.furnace.load_dict(message["furnace"])
		_:
			_handle_world(client, message)


## Messages about what lives and moves in the world, and the chat.
static func _handle_world(client: GameClient, message: Dictionary) -> void:
	match message.get("t"):
		Msg.ITEM_SPAWN:
			client.dropped_items.spawn(
				message["id"], message["item"], message["count"], message["pos"]
			)
		Msg.ITEM_MOVE:
			client.dropped_items.move(message["id"], message["pos"])
		Msg.ITEM_REMOVE:
			client.dropped_items.remove(message["id"], message["by"])
		Msg.ENTITY_SPAWN:
			client.creatures.spawn(message)
		Msg.ENTITY_MOVE:
			client.creatures.move(message)
		Msg.ANIMAL_NOTICE:
			client.hotbar.announce(client.creatures.notice_text(message))
		Msg.ENTITY_HURT:
			client.creatures.hurt(message["id"])
		Msg.ENTITY_REMOVE:
			client.creatures.remove(message["id"], message["died"])
		Msg.PUSH:
			client.local_player.push(message["speed"], message["hop"])
		Msg.ARROW_SPAWN:
			client.arrows.spawn(message["id"], message["from"], message["velocity"])
		Msg.ARROW_REMOVE:
			client.arrows.remove(message["id"])
		Msg.BOBBER:
			client.angler.on_bobber(message)
		Msg.CAUGHT:
			client.angler.on_caught(message)
		Msg.LANTERN_OUT:
			client.lighting.lantern_out(message["seconds"])
		Msg.CHAT_LINE:
			client.chat.show_line(message)
		var unknown:
			push_warning("Client: unknown message type %s" % unknown)
