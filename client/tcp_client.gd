class_name ClientTCP extends Node
## Main class for TCP communication with the server
## Other classes can read incoming data by adding event handlers to the signals below
## Or send data with the send function 

signal packet_received(packet:NetworkPacket.BaseNetworkPacket)
signal disconnected
signal connected


# TODO: Ideally these would be pulled from something like a .env file and not hard-coded
const HOST_ADDRESS = "127.0.0.1"
const HOST_PORT = 5000


var stream_peer:StreamPeerTCP = StreamPeerTCP.new()
var peer_status: StreamPeerSocket.Status = StreamPeerSocket.Status.STATUS_NONE

func is_connected_to_server() -> bool:
	return peer_status == StreamPeerSocket.Status.STATUS_CONNECTED

func connect_to_host() -> bool:
	if peer_status == stream_peer.STATUS_CONNECTED:
		print_debug("Server connection already established")
		return true
	
	print_debug("Connecting to host %s at port %d" % [HOST_ADDRESS, HOST_PORT])
	var connection_result = stream_peer.connect_to_host(HOST_ADDRESS, HOST_PORT)
	if connection_result != OK:
		push_error("Couldn't resolve host")
		return false
	
	
	# Actively wait while client is trying to establish a connection
	while stream_peer.get_status() == stream_peer.STATUS_CONNECTING:
		stream_peer.poll()
	
	peer_status = stream_peer.get_status()
	
	if peer_status == stream_peer.STATUS_ERROR or peer_status == stream_peer.STATUS_NONE:
		push_error("Failed to establish a connection")
		return false
	print_debug("Successfully connected to host")
	connected.emit()
	return true

func _process(delta: float) -> void:
	stream_peer.poll()
	var new_status = stream_peer.get_status()
	
	# Handle connection status changes
	if new_status != peer_status:
		if new_status == StreamPeerSocket.Status.STATUS_ERROR:
			push_error("ERROR: Connection error")
			disconnected.emit()
			queue_free()
		if new_status == StreamPeerSocket.Status.STATUS_NONE:
			disconnected.emit()
			queue_free()
		peer_status = new_status
	
	
	if new_status != stream_peer.STATUS_CONNECTED:
		return
	
	var received_bytes: int = stream_peer.get_available_bytes()
	if received_bytes > NetworkPacket.BaseNetworkPacket.byte_size:
		# Has to match structure of the data sent from the server
		var packet:NetworkPacket.BaseNetworkPacket = read_packet()
		if packet != null:
			packet_received.emit(packet)



func read_packet() -> NetworkPacket.BaseNetworkPacket:
	var packet_type: NetworkPacket.PacketType = stream_peer.get_32()
	if packet_type == NetworkPacket.PacketType.BoardData:
		# print_debug("Received board data")
		var packet := NetworkPacket.BoardDataPacket.new()
		packet.read_from_network(stream_peer)
		return packet
	elif packet_type == NetworkPacket.PacketType.PlayerInput:
		print_debug("received player inpu")
	
	return null
