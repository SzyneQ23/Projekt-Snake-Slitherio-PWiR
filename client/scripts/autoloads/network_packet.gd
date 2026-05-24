extends Node
## Module for code related to network packets
## Added to ProjectSettings->Globals so it's available from all Nodes as a singleton

# NOTE: count and order of enum cases has to match the one declared in the server code
enum PacketType {
	BoardData,
	PlayerInputEvent
}

## Base class for custom data packets transfered over the network
@abstract
class BaseNetworkPacket extends RefCounted:
	# should be set by each derived class
	var packet_type: PacketType
	
	## for deserializing when reading object from the network
	@abstract
	func from_bytes(bytes: PackedByteArray)
	
	## for serializing when sending object over the network
	@abstract
	func into_bytes() -> PackedByteArray


# ----- Derived packet classes -----

class PlayerData extends RefCounted:
	var position: Vector2i
	var direction: Vector2i
	func _init(pos_x: int, pos_y: int, dir_x: int, dir_y: int) -> void:
		self.position = Vector2i(pos_x, pos_y)
		self.direction = Vector2i(dir_x, dir_y)

## Information about current board state, sent periodically by the server
class GameDataPacket extends BaseNetworkPacket:
	var player_count: int
	var current_player_id: int
	
	var players: Array[PlayerData] = []
	
	func _init() -> void:
		self.packet_type = PacketType.BoardData
	
	func from_bytes(bytes: PackedByteArray):
		self.current_player_id = bytes.decode_s32(0)
		self.player_count = bytes.decode_s32(4)
		bytes = bytes.slice(8)
				
		for i in range(player_count):
			var pos_x = bytes.decode_s32(0)
			var pos_y = bytes.decode_s32(4)
			var dir_x = bytes.decode_s32(8)
			var dir_y = bytes.decode_s32(12)
			bytes = bytes.slice(16)
			
			self.players.append(PlayerData.new(pos_x, pos_y, dir_x, dir_y))
	
	func into_bytes() -> PackedByteArray:
		return []

# NOTE: also has to match analogous enum in the server code
enum InputType{
	Left,
	Right,
	Up,
	Down
}

## Sent to the server when player input is detected
class InputEventPacket extends BaseNetworkPacket:
	var input_type: InputType
	
	func _init(input: InputType) -> void:
		self.packet_type = PacketType.PlayerInputEvent
		self.input_type = input
	
	func from_bytes(bytes: PackedByteArray):
		pass
	
	func into_bytes() -> PackedByteArray:
		var bytes: PackedByteArray = []
		bytes.resize(len(bytes) + 4) # reserve space for packet_size
		
		bytes.resize(len(bytes) + 4)
		bytes.encode_s32(len(bytes)-4, self.packet_type)
		
		bytes.resize(len(bytes) + 4)
		bytes.encode_s32(len(bytes)-4, self.input_type)
		
		bytes.encode_s32(0, len(bytes)) # packet_size
		
		return bytes


## Takes bytes read from the network stream and parses them into a NetworkPacket object
func read_packet(bytes: PackedByteArray) -> BaseNetworkPacket:
	var packet_type: PacketType = bytes.decode_s32(0)
	bytes = bytes.slice(4)
	
	match packet_type:
		NetworkPacket.PacketType.BoardData:
			var packet := NetworkPacket.GameDataPacket.new()
			packet.from_bytes(bytes)
			return packet
		# new types of incomint packets should be handled here
		_:
			return null
	
	
	return null
