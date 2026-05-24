extends Node

## Module for code related to network packets
## Added to ProjectSettings->Globals so it's available from all Nodes


enum PacketType {
	BoardData,
	PlayerInput
}

## Base class for custom data packets transfered over the network
@abstract
class BaseNetworkPacket extends RefCounted:
	# should be set by each derived class
	var packet_type: PacketType
	
	@abstract
	func from_bytes(bytes: PackedByteArray)
	
	@abstract
	func into_bytes() -> PackedByteArray

# ----- Derived packet classes -----

class BoardPlayerData extends RefCounted:
	var position: Vector2i
	func _init(pos_x: int, pos_y: int) -> void:
		self.position = Vector2i(pos_x, pos_y)

# 
class BoardDataPacket extends BaseNetworkPacket:
	var player_count: int
	var players: Array[BoardPlayerData] = []
	
	func _init() -> void:
		self.packet_type = PacketType.BoardData
	
	func from_bytes(bytes: PackedByteArray):
		self.player_count = bytes.decode_s32(0)
		bytes = bytes.slice(4)
				
		for i in range(player_count):
			var pos_x = bytes.decode_s32(0)
			var pos_y = bytes.decode_s32(4)
			bytes = bytes.slice(8)
			
			self.players.append(BoardPlayerData.new(pos_x, pos_y))
	
	func into_bytes() -> PackedByteArray:
		return []

## Reads data from the TCP stream and parses it into a NetworkPacket
func read_packet(bytes: PackedByteArray) -> BaseNetworkPacket:
	var packet_type: PacketType = bytes.decode_s32(0)
	bytes = bytes.slice(4)
	
	if packet_type == NetworkPacket.PacketType.BoardData:
		# print_debug("Received board data")
		var packet := NetworkPacket.BoardDataPacket.new()
		packet.from_bytes(bytes)
		return packet
	elif packet_type == NetworkPacket.PacketType.PlayerInput:
		print_debug("received player input")
	
	return null
