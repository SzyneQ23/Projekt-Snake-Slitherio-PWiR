extends Node

enum PacketType {
	BoardData,
	PlayerInput
}

class BaseNetworkPacket extends RefCounted:
	## Main class for incoming network data packets



	## Methods for reading/writing packets to the TCP server
	## Meant to be overriden in derived classes

	# For incoming packets
	func read_from_network(peer: StreamPeerTCP):
		pass

	# For outgoing packets
	func write_to_network(peer: StreamPeerTCP):
		pass

	var packet_type: PacketType

	# Workaround:
	# Godot doesn't have a sizeof() like in C but we need the size of this class to properly deserialize it from network data
	# Has to be updated if the underlying structure changes
	static var byte_size = 8

# ----- Derived packet classes -----

class BoardPlayerData extends RefCounted:
	var position: Vector2i
	func _init(pos_x: int, pos_y: int) -> void:
		self.position = Vector2i(pos_x, pos_y)

class BoardDataPacket extends BaseNetworkPacket:
	var player_count: int
	var players: Array[BoardPlayerData] = []
	
	func _init() -> void:
		self.packet_type = PacketType.BoardData
	
	func read_from_network(peer: StreamPeerTCP):
		self.player_count = peer.get_u32()
		while(peer.get_available_bytes() < self.player_count * 4 * 2): # TODO: make this clearer
			peer.poll()
		for i in range(player_count):
			var pos_x = peer.get_32()
			var pos_y = peer.get_32()
			self.players.append(BoardPlayerData.new(pos_x, pos_y))
		
