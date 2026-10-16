class_name Online
extends Node
## What the client shows of a game with others (multiplayer, step 2): the
## other players (PeersView, in the world root), their names (PeerNames),
## who plays (PlayerList, the roster), the join screen (JoinScreen, from
## the pause menu or the connection screen) and the ways to another
## server, back to solo or to the same server again (ConnectionScreen's
## buttons). Game answers its signals.

## Join a server; the same one again; back to the solo world; the server
## welcomed the player (Msg.WELCOME).
signal join_requested(address: String, port: int, player_name: String, password: String)
signal retry_requested
signal solo_requested
signal welcomed

var client: GameClient
var peers := PeersView.new()
var names := PeerNames.new()
var players := PlayerList.new()
var join_screen := JoinScreen.new()
## The server played on ("address:port"; "": solo).
var server := ""


## Builds its views in the client's world and UI (once these are built).
func setup(ui_root: Control) -> void:
	peers.library = client.items
	peers.client_world = client.world
	peers.world_view = client.world_view
	peers.lighting = client.lighting
	client.world_root.add_child(peers)
	names.peers = peers
	names.viewport = client.world_viewport
	names.player_feet = _player_feet
	# Under the HUD and every screen.
	ui_root.add_child(names)
	ui_root.move_child(names, 0)
	players.can_show = _list_shows
	ui_root.add_child(players)
	ui_root.add_child(join_screen)
	join_screen.join_requested.connect(join_requested.emit)
	client.connection.retry_requested.connect(retry_requested.emit)
	client.connection.solo_requested.connect(solo_requested.emit)
	client.connection.other_requested.connect(join_screen.open)
	client.pause_menu.join_screen_requested.connect(join_screen.open)
	client.pause_menu.leave_server_requested.connect(solo_requested.emit)


## Playing on `address` ("address:port"; "": solo).
func play_on(address: String) -> void:
	server = address
	players.server = address
	client.pause_menu.online = address != ""


## Who plays (Msg.PLAYERS): on a server, only its admins see the world's
## settings in the pause menu.
func set_roster(roster: Array) -> void:
	players.player_id = client.player_id
	players.set_roster(roster)
	var editable := server == "" or players.is_admin()
	if editable != client.pause_menu.world_editable:
		client.pause_menu.world_editable = editable
		client.pause_menu.refresh_from_state()


func _player_feet() -> Vector3:
	return Render3D.world_px_to_local(client.local_player.position, client.local_player.height)


func _list_shows() -> bool:
	return client.joined and not client.screen_open() and not client.get_tree().paused
