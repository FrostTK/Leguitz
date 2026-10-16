class_name NetServer
extends RefCounted
## A dedicated server's listening end (ENet, UDP): `listen` on an address
## ("*": every address of the machine) and a port; `service` (every frame)
## makes a NetTransport for each player connecting (to hand to
## GameServer.connect_client), gives each what it received and marks those
## that went; `flush` sends what was sent.

var _host: ENetConnection
var _peers: Dictionary[ENetPacketPeer, NetTransport] = {}


## Listens for players (`most`: connections at once). An error: it could
## not (the port taken...).
func listen(address: String, port: int, most: int) -> Error:
	_host = ENetConnection.new()
	var error := _host.create_host_bound(address, port, most, 1)
	if error != OK:
		_host = null
		return error
	_host.compress(ENetConnection.COMPRESS_ZSTD)
	return OK


## The connections made since the last call; what came goes to theirs.
func service() -> Array[NetTransport]:
	var joined: Array[NetTransport] = []
	if _host == null:
		return joined
	while true:
		var event := _host.service()
		var kind: int = event[0]
		if kind == ENetConnection.EVENT_NONE or kind == ENetConnection.EVENT_ERROR:
			break
		var peer := event[1] as ENetPacketPeer
		match kind:
			ENetConnection.EVENT_CONNECT:
				var transport := NetTransport.new()
				transport.peer = peer
				transport.watch()
				_peers[peer] = transport
				joined.append(transport)
			ENetConnection.EVENT_DISCONNECT:
				if _peers.has(peer):
					_peers[peer].lost()
					_peers.erase(peer)
			ENetConnection.EVENT_RECEIVE:
				var transport: NetTransport = _peers.get(peer)
				while peer.get_available_packet_count() > 0:
					var packet := peer.get_packet()
					if transport != null:
						transport.receive(packet)
	return joined


func flush() -> void:
	if _host != null:
		_host.flush()


## Lets every player go and stops listening.
func close() -> void:
	if _host == null:
		return
	for peer: ENetPacketPeer in _peers:
		peer.peer_disconnect_later()
	_host.flush()
	_host.destroy()
	_host = null
	_peers.clear()
