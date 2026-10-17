class_name Online
extends Node
## What the client shows of a game with others (multiplayer, step 2): the
## other players (PeersView, in the world root), their names (PeerNames),
## who plays (PlayerList, the roster), the join screen (JoinScreen, from
## the pause menu or the connection screen) and the ways to another
## server, back to solo or to the same server again (ConnectionScreen's
## buttons). Game answers its signals. Step 4: the local player's role
## (from the roster): a visitor's game changes nothing (`keeps_out`); the
## account's password changed from the pause menu (PasswordDialog;
## `on_password_set`, the secret kept updated).

## Join a server; the same one again; back to the solo world; the server
## welcomed the player (Msg.WELCOME).
signal join_requested(
	address: String, port: int, player_name: String, password: String, secret: String, keep: bool
)
signal retry_requested
signal solo_requested
signal welcomed

## A visitor is told again after this long (seconds).
const TELL_AGAIN := 4.0

var client: GameClient
var peers := PeersView.new()
var names := PeerNames.new()
var players := PlayerList.new()
var join_screen := JoinScreen.new()
var password := PasswordDialog.new()
## The server played on ("address:port"; "": solo), and as whom: [address,
## port, name, secret, kept (the secret in ServerList)].
var server := ""
var joined_as := []
## The local player's role there (Access.Role).
var role: int = Access.Role.PLAYER
## When a visitor was last told so (seconds), the secret asked for.
var _told := -INF
var _new_secret := ""


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
	ui_root.add_child(password)
	join_screen.join_requested.connect(join_requested.emit)
	password.change_requested.connect(_change_password)
	client.pause_menu.password_requested.connect(password.open)
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
	for entry: Dictionary in roster:
		if entry.get("id") == client.player_id:
			role = int(entry.get("role", Access.Role.PLAYER))
	var editable := server == "" or players.is_admin()
	if editable != client.pause_menu.world_editable:
		client.pause_menu.world_editable = editable
		client.pause_menu.refresh_from_state()


## A visitor about to change something (`aimed`: VoxelRay's hit, or null):
## told so now and then; true when it is kept from it. Doors, gates,
## seats, beds and workbenches are theirs to use.
func keeps_out(aimed: VoxelRay.Hit) -> bool:
	if role != Access.Role.VISITOR:
		return false
	if aimed != null:
		var block := Voxels.block_of(aimed.voxel)
		var kind := ObjectShapes.base_kind(block)
		if (
			Mining.swings(aimed.voxel)
			or Furniture.is_seat(block)
			or Furniture.is_bed(block)
			or kind == Tiles.Block.WORKBENCH
		):
			return false
	var now := Time.get_ticks_msec() * 0.001
	if now - _told > TELL_AGAIN:
		_told = now
		client.hotbar.announce(tr("HUD_VISITOR"))
	return true


## The server's answer to a new password: the dialog told, the kept
## secret updated.
func on_password_set(done: bool) -> void:
	password.answered(done)
	client.hotbar.announce(tr("PASSWORD_DONE" if done else "PASSWORD_WRONG"))
	if done and joined_as.size() == 5 and joined_as[4]:
		ServerList.new().update_secret(joined_as[0], joined_as[1], _new_secret)
	if done and joined_as.size() == 5:
		joined_as[3] = _new_secret


func _change_password(old: String, new: String) -> void:
	var name: String = joined_as[2] if joined_as.size() == 5 else ""
	_new_secret = Access.secret_of(name, new)
	client.transport.send(Msg.set_password(Access.secret_of(name, old), _new_secret))


func _player_feet() -> Vector3:
	return Render3D.world_px_to_local(client.local_player.position, client.local_player.height)


func _list_shows() -> bool:
	return client.joined and not client.screen_open() and not client.get_tree().paused
