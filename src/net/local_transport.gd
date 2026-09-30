class_name LocalTransport
extends Transport
## In-process transport used for solo play (the "integrated server").
## Messages are delivered by reference, in order, on the receiver's next poll.
## Both ends share one Channel (no reference cycle between the ends).


class Channel:
	extends RefCounted
	var inboxes: Array[Array] = [[], []]


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
	_channel.inboxes[1 - _side].append(message)


func poll() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	messages.assign(_channel.inboxes[_side])
	_channel.inboxes[_side].clear()
	return messages
