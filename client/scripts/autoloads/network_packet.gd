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
	var positions: Array[Vector2i] = []
	var direction: Vector2i
	var length: int
	var is_alive: bool
	func _init() -> void:
		pass

## Information about current board state, sent periodically by the server
class GameDataPacket extends BaseNetworkPacket:
	var player_count: int
	var current_player_id: int
	
	var board_width : int
	var board_height : int
	
	var players: Array[PlayerData] = []
	var foods: Array[Dictionary] = [] 
	var bonuses: Array[Vector2i] = [] 
	
	func _init() -> void:
		self.packet_type = PacketType.BoardData
	
	func from_bytes(bytes: PackedByteArray):
		self.current_player_id = bytes.decode_s32(0)
		self.player_count = bytes.decode_s32(4)
		self.board_width = bytes.decode_s32(8)
		self.board_height = bytes.decode_s32(12)
		bytes = bytes.slice(16)
				
		for i in range(player_count):
			var dir_x = bytes.decode_s32(0)
			var dir_y = bytes.decode_s32(4)
			var p_length = bytes.decode_s32(808)
			var p_alive = bytes.decode_s8(812) == 1
			
			var p_data = PlayerData.new()
			p_data.direction = Vector2i(dir_x, dir_y)
			p_data.length = p_length
			p_data.is_alive = p_alive
			
			for j in range(p_length):
				var px = bytes.decode_s32(8 + (j * 8))
				var py = bytes.decode_s32(12 + (j * 8))
				p_data.positions.append(Vector2i(px, py))
			
			self.players.append(p_data)
			bytes = bytes.slice(816) 
		
		var empty_slots = 8 - player_count
		bytes = bytes.slice(empty_slots * 816)
		
		self.foods.clear()
		for i in range(2):
			var food_x = bytes.decode_s32(0)
			var food_y = bytes.decode_s32(4)
			var is_active = bytes.decode_s8(8) 
			var item_type = bytes.decode_s8(9)
			
			bytes = bytes.slice(12)
			if is_active == 1:
				self.foods.append({"pos": Vector2i(food_x, food_y), "type": item_type})
				
		self.bonuses.clear()
		for i in range(5):
			var b_x = bytes.decode_s32(0)
			var b_y = bytes.decode_s32(4)
			var b_active = bytes.decode_s8(8)
			
			bytes = bytes.slice(12) 
			if b_active == 1:
				self.bonuses.append(Vector2i(b_x, b_y))
	
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
