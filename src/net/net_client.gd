class_name NetClient
extends NetTransport
## A player's end of a connection to a dedicated server (ENet, UDP):
## `connect_to` an address (a name or an IP) and a port; what is sent before
## the connection is made waits for it; `poll` (every frame) services its
## own host. Closed, `ending` tells why: CONNECTION_UNREACHABLE (it never
## connected: nothing answered within `connect_seconds`), CONNECTION_LOST
## (it went).

enum State { CONNECTING, CONNECTED, CLOSED }

var state := State.CONNECTING
var ending := ""
## How long it waits for the server to answer.
var connect_seconds := 8.0

var _host := ENetConnection.new()
var _waiting: Array[Dictionary] = []
var _started := 0


func _init() -> void:
	most_bytes = SERVER_MOST_BYTES


## Starts connecting. An error: it cannot (no network, a name not found).
func connect_to(address: String, port: int) -> Error:
	var ip := address
	if not address.is_valid_ip_address():
		ip = IP.resolve_hostname(address)
	if ip.is_empty():
		_end("CONNECTION_UNREACHABLE")
		return ERR_CANT_RESOLVE
	var error := _host.create_host(1, 1)
	if error != OK:
		_end("CONNECTION_UNREACHABLE")
		return error
	_host.compress(ENetConnection.COMPRESS_ZSTD)
	peer = _host.connect_to_host(ip, port, 1)
	_started = Time.get_ticks_msec()
	if peer == null:
		_end("CONNECTION_UNREACHABLE")
		return ERR_CANT_CONNECT
	return OK


func send(message: Dictionary) -> void:
	if state == State.CONNECTING:
		_waiting.append(message)
	else:
		super.send(message)


func poll() -> Array[Dictionary]:
	_service()
	return super.poll()


func is_open() -> bool:
	return state != State.CLOSED


## Leaves the server at once (the game quits).
func close() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	lost()
	if peer != null:
		peer.peer_disconnect()
	_host.flush()


func _service() -> void:
	if state == State.CLOSED:
		return
	if state == State.CONNECTING and Time.get_ticks_msec() - _started > connect_seconds * 1000.0:
		peer.reset()
		_end("CONNECTION_UNREACHABLE")
		return
	while true:
		var event := _host.service()
		var kind: int = event[0]
		if kind == ENetConnection.EVENT_NONE:
			break
		if kind == ENetConnection.EVENT_ERROR:
			_end("CONNECTION_LOST")
			return
		match kind:
			ENetConnection.EVENT_CONNECT:
				state = State.CONNECTED
				watch()
				for message in _waiting:
					super.send(message)
				_waiting.clear()
			ENetConnection.EVENT_DISCONNECT:
				_end("CONNECTION_LOST" if state == State.CONNECTED else "CONNECTION_UNREACHABLE")
				return
			ENetConnection.EVENT_RECEIVE:
				while peer.get_available_packet_count() > 0:
					receive(peer.get_packet())
	_host.flush()


func _end(why: String) -> void:
	state = State.CLOSED
	ending = why
	lost()
