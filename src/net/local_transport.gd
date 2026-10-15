class_name LocalTransport
extends Transport
## In-process transport used for solo play (the "integrated server").
## Messages are delivered by reference, in order, on the receiver's next poll.
## Both ends share one Channel (no reference cycle between the ends). With
## `serialize` (tests) they cross as bytes, as over the network
## (NetTransport): what does not survive var_to_bytes shows.


class Channel:
	extends RefCounted
	var inboxes: Array[Array] = [[], []]
	var closed := false


## Tests: messages go as bytes (var_to_bytes, then back).
static var serialize := false

var _channel: Channel
var _side := 0


## Returns [client_end, server_end].
static func create_pair() -> Array[LocalTransport]:
	var channel := Channel.new()
	var client_end := LocalTransport.new()
	var server_end := LocalTransport.new()
	client_end._channel = channel
	client_end._side = 0
	server_end._channel = channel
	server_end._side = 1
	return [client_end, server_end]


func send(message: Dictionary) -> void:
	if _channel.closed:
		return
	if serialize:
		_channel.inboxes[1 - _side].append(bytes_to_var(var_to_bytes(message)))
	else:
		_channel.inboxes[1 - _side].append(message)


func poll() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	messages.assign(_channel.inboxes[_side])
	_channel.inboxes[_side].clear()
	return messages


func is_open() -> bool:
	return not _channel.closed


func close() -> void:
	_channel.closed = true
