class_name TcpClient extends Node
## Main class for TCP communication with the server
## Other classes can read incoming data by adding event handlers to the signals defined below
## Or send data with the send_packet 

signal packet_received(packet:NetworkPacket.BaseNetworkPacket)
signal disconnected
signal connected

var HOST_ADDRESS = "127.0.0.1"
const HOST_PORT = 5000

const MAX_PLAYER_COUNT = 8

var stream_peer:StreamPeerTCP = null
var peer_status: StreamPeerSocket.Status = StreamPeerSocket.Status.STATUS_NONE

func is_connected_to_server() -> bool:
	return peer_status == StreamPeerSocket.Status.STATUS_CONNECTED

func connect_to_host(ip:String) -> bool:
	HOST_ADDRESS = ip
	
	if stream_peer != null and peer_status == StreamPeerSocket.Status.STATUS_CONNECTED:
		print_debug("Server connection already established")
		return true
	
	print_debug("Connecting to host %s at port %d" % [HOST_ADDRESS, HOST_PORT])
	stream_peer = StreamPeerTCP.new()
	var connection_result = stream_peer.connect_to_host(HOST_ADDRESS, HOST_PORT)
	if connection_result != OK:
		push_error("Couldn't resolve host")
		return false
	
	while stream_peer.get_status() == stream_peer.STATUS_CONNECTING:
		stream_peer.poll()
	
	peer_status = stream_peer.get_status()
	
	if peer_status == stream_peer.STATUS_ERROR or peer_status == stream_peer.STATUS_NONE:
		push_error("Failed to establish a connection")
		return false
	print_debug("Successfully connected to host")
	connected.emit()
	return true

func disconnect_from_host() -> void:
	if stream_peer != null:
		stream_peer.disconnect_from_host()
		peer_status = StreamPeerSocket.Status.STATUS_NONE
		print_debug("Manually disconnected from host.")

func send_packet(packet: NetworkPacket.BaseNetworkPacket):
	if stream_peer == null or stream_peer.get_status() != StreamPeerSocket.Status.STATUS_CONNECTED:
		print(peer_status)
		push_error("Tried to send a packet but connection is not established")
		return
	
	var result = stream_peer.put_data(packet.into_bytes())
	if result != OK:
		push_error("Failed to send packet")

func _process(delta: float) -> void:
	if stream_peer == null:
		return
	
	stream_peer.poll()
	var new_status = stream_peer.get_status()
	
	if new_status != peer_status:
		if new_status == StreamPeerSocket.Status.STATUS_ERROR:
			push_error("ERROR: Connection error")
			disconnected.emit()
			queue_free()
		if new_status == StreamPeerSocket.Status.STATUS_NONE:
			push_error("ERROR: Connection error")
			disconnected.emit()
			queue_free()
		peer_status = new_status
	
	if new_status != stream_peer.STATUS_CONNECTED:
		return
	
	var received_bytes: int = stream_peer.get_available_bytes()
	if received_bytes == 0: return
	
	var packet_size: int = stream_peer.get_32()
	received_bytes = stream_peer.get_available_bytes()
	
	while received_bytes < packet_size - 4:
		stream_peer.poll()
		received_bytes = stream_peer.get_available_bytes()
	
	var packet_bytes = stream_peer.get_data(packet_size-4)
	if packet_bytes[0] != OK:
		push_error("Error occurred while reading data from TCP stream")
		return
	var bytes: PackedByteArray = packet_bytes[1]
		
	var packet:NetworkPacket.BaseNetworkPacket = NetworkPacket.read_packet(bytes)
	
	if packet == null:
		push_error("Couldn't parse received packet")
		return
	
	packet_received.emit(packet)
