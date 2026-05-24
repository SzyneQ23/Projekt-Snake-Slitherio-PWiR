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
	if received_bytes == 0: return
	
	# First value in a transmited packet specifies its size
	var packet_size: int = stream_peer.get_32()
	
	received_bytes = stream_peer.get_available_bytes()
	
	# Handle the case where expected network packet doesn't fit into a single TCP packet - wait for the rest of it
	
	while received_bytes < packet_size - 4: # -4 because we already read 4 bytes from the TCP stream
		stream_peer.poll()
		received_bytes = stream_peer.get_available_bytes()
	
	var packet_bytes = stream_peer.get_data(packet_size-4)
	if packet_bytes[0] != OK:
		push_error("Error occurred while reading data from TCP stream")
		return
	var bytes: PackedByteArray = packet_bytes[1]
		
	var packet:NetworkPacket.BaseNetworkPacket = NetworkPacket.read_packet(bytes) # we already read 4 bytes to get the packet_size
	
	if packet == null:
		push_error("Couldn't parse received packet")
		return
	
	packet_received.emit(packet)
