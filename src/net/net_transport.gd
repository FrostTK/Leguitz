class_name NetTransport
extends Transport
## One end of a connection over the network (ENet, UDP): the server's end
## of a player's connection (NetServer feeds it what comes), or as NetClient
## the player's. Messages go whole and in order on one reliable channel,
## as bytes (var_to_bytes: plain values, never objects); ENet compresses
## them (zstd). What comes larger than `most_bytes`, or is no message,
## closes the connection.

const CHANNEL := 0
## A player's messages are small; a server's (chunks) larger.
const CLIENT_MOST_BYTES := 64 * 1024
const SERVER_MOST_BYTES := 32 * 1024 * 1024

var peer: ENetPacketPeer
## The largest message taken (bytes, as it came).
var most_bytes := CLIENT_MOST_BYTES

var _inbox: Array[Dictionary] = []
var _open := true


func send(message: Dictionary) -> void:
	if _open and peer != null:
		peer.send(CHANNEL, var_to_bytes(message), ENetPacketPeer.FLAG_RELIABLE)


func poll() -> Array[Dictionary]:
	var messages := _inbox
	_inbox = []
	return messages


func is_open() -> bool:
	return _open


func close() -> void:
	if _open:
		_open = false
		if peer != null:
			peer.peer_disconnect_later()


## A packet came from the other end.
func receive(packet: PackedByteArray) -> void:
	if not _open:
		return
	if packet.size() > most_bytes:
		close()
		return
	var message: Variant = bytes_to_var(packet)
	if message is Dictionary and (message as Dictionary).has("t"):
		_inbox.append(message)
	else:
		close()


## The other end went (or could not be reached).
func lost() -> void:
	_open = false


## Where the other end is ("address:port").
func address() -> String:
	if peer == null:
		return ""
	return "%s:%d" % [peer.get_remote_address(), peer.get_remote_port()]
