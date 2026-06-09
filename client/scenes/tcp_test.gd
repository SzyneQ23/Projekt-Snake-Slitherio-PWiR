extends Node2D

@onready var connect_button: Button = $UI/ConnectButton
@onready var tcp_client: TcpClient = TcpClientInstance

@onready var player_nodes = []

var player_scene = preload("res://scenes/prefab_player.tscn")

var current_board_w = 0
var current_board_h = 0
var normal_apple_scene = preload("res://scenes/apple.tscn")
var wormy_apple_scene = preload("res://scenes/apple_bug.tscn")
var bonus_scene = preload("res://scenes/bonus.tscn")

var food_slots: Array[Dictionary] = []
var active_bonuses: Array[Node2D] = []
var segment_scene = preload("res://scenes/snake_segment.tscn")
var player_segments = [[], [], [], [], [], [], [], []] 

var last_directions: Array[Vector2i] = [Vector2i(1,0), Vector2i(1,0), Vector2i(1,0), Vector2i(1,0), Vector2i(1,0), Vector2i(1,0), Vector2i(1,0), Vector2i(1,0)]
var local_player_index: int = -1


func get_segment_type(index: int) -> int:
	return index % 2
	
func get_turn_name(v_in: Vector2i, v_out: Vector2i) -> String:
	if v_in.x == 1 and v_out.y == -1: return "right_to_up"
	if v_in.x == 1 and v_out.y == 1: return "right_to_down"
	if v_in.x == -1 and v_out.y == -1: return "left_to_up"
	if v_in.x == -1 and v_out.y == 1: return "left_to_down"
	if v_in.y == -1 and v_out.x == 1: return "up_to_right"
	if v_in.y == -1 and v_out.x == -1: return "up_to_left"
	if v_in.y == 1 and v_out.x == 1: return "down_to_right"
	if v_in.y == 1 and v_out.x == -1: return "down_to_left"
	return "straight"

func _ready() -> void:
	player_nodes.resize(TcpClient.MAX_PLAYER_COUNT)
	for i in range(2):
		var normal = normal_apple_scene.instantiate()
		var wormy = wormy_apple_scene.instantiate()
		normal.z_index = 5
		wormy.z_index = 5
		normal.hide()
		wormy.hide()
		add_child(normal)
		add_child(wormy)
		food_slots.append({ "normal": normal, "wormy": wormy })
		
	for i in range(5):
		var bonus = bonus_scene.instantiate()
		bonus.z_index = 5
		bonus.hide()
		add_child(bonus)
		active_bonuses.append(bonus)
	
	connect_button.pressed.connect(_on_button_pressed)
	
	tcp_client.packet_received.connect(_on_packet_received)
	tcp_client.connected.connect(_on_connected)
	tcp_client.disconnected.connect(_on_disconnected)

func _on_button_pressed():
	tcp_client.connect_to_host()


func _process(delta: float) -> void:
	var input_packet: NetworkPacket.InputEventPacket = null
	var next_dir = Vector2i.ZERO
	
	if Input.is_action_just_pressed("ui_left"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Left)
		next_dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Right)
		next_dir = Vector2i(1, 0)
	elif Input.is_action_just_pressed("ui_up"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Up)
		next_dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Down)
		next_dir = Vector2i(0, 1)
	
	if input_packet != null:
		TcpClientInstance.send_packet(input_packet)
		if local_player_index >= 0 and local_player_index < len(player_nodes):
			var current_dir = last_directions[local_player_index] 
			var head = player_nodes[local_player_index] as AnimatedSprite2D 
			
			if head and next_dir != Vector2i.ZERO and next_dir != current_dir:
				var cross = current_dir.x * next_dir.y - current_dir.y * next_dir.x
				if cross == -1: head.play("head_turn_left")
				else: head.play("head_turn_right")
				head.rotation = get_rotation_for_dir(current_dir)
	

func _on_packet_received(packet: NetworkPacket.GameDataPacket):
	$UI/PlayerIDLabel.text = "Player %d" % (packet.current_player_id)
	local_player_index = packet.current_player_id
	
	if not packet.players[local_player_index].is_alive:
		print_debug("Died")
		get_tree().quit()
	
	if packet.board_width != current_board_w or packet.board_height != current_board_h:
		current_board_w = packet.board_width
		current_board_h = packet.board_height
		rebuild_board(current_board_w, current_board_h)
		$Camera2D.zoom = Vector2.ONE * (30.0 / current_board_w) # zoom out when board gets larger
		
	if packet.player_count == 0:
		return
	for i in range(len(packet.players)):
		var p_data = packet.players[i]
		# TODO: get player index
		var player_idx = p_data.index
		var segments_array = player_segments[player_idx]
		
		
		if not p_data.is_alive:
			if player_nodes[player_idx] != null: player_nodes[i].hide()
			for seg in segments_array: seg.hide()
			continue
		
		if player_nodes[player_idx] == null:
			var new_player: AnimatedSprite2D = player_scene.instantiate()
			new_player.show()
			add_child(new_player)
			player_nodes[player_idx] = new_player 
		
		if not player_nodes[player_idx].visible:
			player_nodes[player_idx].show()
		
		player_nodes[player_idx].position = (p_data.positions[0] * 32) + Vector2i(16, 16)
		player_nodes[player_idx].z_index = 5
		
		var head = player_nodes[player_idx] as AnimatedSprite2D
		if head:
			head.play("head_straight")
			head.rotation = get_rotation_for_dir(p_data.direction)
			last_directions[player_idx] = p_data.direction

		var body_length = p_data.length - 1
		while len(segments_array) < body_length:
			var new_seg = segment_scene.instantiate()
			new_seg.z_index = 4 
			add_child(new_seg)
			segments_array.append(new_seg)

		for j in range(len(segments_array)):
			if j < body_length:
				segments_array[j].show()
				segments_array[j].position = (p_data.positions[j + 1] * 32) + Vector2i(16, 16)
				
				var seg_sprite = segments_array[j].get_node("AnimatedSprite2D")
				if seg_sprite:
					var type_suffix = "_A" if j % 2 == 0 else "_B"
					
					var pos_next = p_data.positions[j]    
					var pos_curr = p_data.positions[j + 1] 
					
					if j == body_length - 1:
						seg_sprite.play("tail" + type_suffix)
						var vec_to_head = pos_next - pos_curr
						
						var search_idx = j
						while vec_to_head == Vector2i.ZERO and search_idx > 0:
							search_idx -= 1
							vec_to_head = p_data.positions[search_idx] - p_data.positions[search_idx + 1]
						seg_sprite.rotation = get_rotation_for_dir(vec_to_head)
					else:
						var pos_prev = p_data.positions[j + 2] 
						
						var vec_in = pos_curr - pos_prev 
						var vec_out = pos_next - pos_curr
						
						if vec_in != vec_out:
							seg_sprite.rotation = 0 
							seg_sprite.play("turn" + type_suffix + "_" + get_turn_name(vec_in, vec_out))
						else:
							seg_sprite.rotation = get_rotation_for_dir(vec_out)
							seg_sprite.play("body" + type_suffix)
			else:
				segments_array[j].hide()
	
	for i in range(len(food_slots)):
		if i < len(packet.foods):
			var data = packet.foods[i]
			var target_pos = (data["pos"] * 32) + Vector2i(16, 16)
			
			if data["type"] == 0:
				food_slots[i]["normal"].show()
				food_slots[i]["normal"].position = target_pos
				food_slots[i]["wormy"].hide()
			else:
				food_slots[i]["wormy"].show()
				food_slots[i]["wormy"].position = target_pos
				food_slots[i]["normal"].hide()
		else:
			food_slots[i]["normal"].hide()
			food_slots[i]["wormy"].hide()
			
	for i in range(len(active_bonuses)):
		if i < len(packet.bonuses):
			active_bonuses[i].show()
			active_bonuses[i].position = (packet.bonuses[i] * 32) + Vector2i(16, 16)
		else:
			active_bonuses[i].hide()

func _on_connected():
	connect_button.hide()
	

func _on_disconnected():
	pass
	# test_player.queue_free()
	
func rebuild_board(w: int, h: int):
	if not has_node("TileMapLayer"): 
		return 
		
	var tm = $TileMapLayer
	tm.clear()
	
	if has_node("Camera2D"):
		var srodek_x = (w * 32.0) / 2.0
		var srodek_y = (h * 32.0) / 2.0
		$Camera2D.position = Vector2(srodek_x, srodek_y)
	
	var podloga_a_source = 18; var podloga_a_atlas = Vector2i(0, 0)
	var podloga_b_source = 19; var podloga_b_atlas = Vector2i(0, 0)
	
	var mur_gora_source = 11;  var mur_gora_atlas  = Vector2i(0, 0)
	var mur_dol_source = 10;   var mur_dol_atlas   = Vector2i(0, 0)
	var mur_lewo_source = 12;  var mur_lewo_atlas  = Vector2i(0, 0)
	var mur_prawo_source = 13; var mur_prawo_atlas = Vector2i(0, 0)
	
	var rog_lewy_gora_source = 15;  var rog_lewy_gora_atlas  = Vector2i(0, 0)
	var rog_prawy_gora_source = 17; var rog_prawy_gora_atlas = Vector2i(0, 0)
	var rog_lewy_dol_source = 14;   var rog_lewy_dol_atlas   = Vector2i(0, 0)
	var rog_prawy_dol_source = 16;  var rog_prawy_dol_atlas  = Vector2i(0, 0)
	
	for x in range(-1, w + 1):
		for y in range(-1, h + 1):
			if x == -1 and y == -1:
				tm.set_cell(Vector2i(x, y), rog_lewy_gora_source, rog_lewy_gora_atlas)
			elif x == w and y == -1:
				tm.set_cell(Vector2i(x, y), rog_prawy_gora_source, rog_prawy_gora_atlas)
			elif x == -1 and y == h:
				tm.set_cell(Vector2i(x, y), rog_lewy_dol_source, rog_lewy_dol_atlas)
			elif x == w and y == h:
				tm.set_cell(Vector2i(x, y), rog_prawy_dol_source, rog_prawy_dol_atlas)
			elif y == -1:
				tm.set_cell(Vector2i(x, y), mur_gora_source, mur_gora_atlas)
			elif y == h:
				tm.set_cell(Vector2i(x, y), mur_dol_source, mur_dol_atlas)
			elif x == -1:
				tm.set_cell(Vector2i(x, y), mur_lewo_source, mur_lewo_atlas)
			elif x == w:
				tm.set_cell(Vector2i(x, y), mur_prawo_source, mur_prawo_atlas)
			else:
				if (x + y) % 2 == 0:
					tm.set_cell(Vector2i(x, y), podloga_a_source, podloga_a_atlas)
				else:
					tm.set_cell(Vector2i(x, y), podloga_b_source, podloga_b_atlas)
					
func get_rotation_for_dir(vec: Vector2i) -> float:
	if vec == Vector2i(1, 0): return 0.0          # W prawo (brak obrotu)
	if vec == Vector2i(-1, 0): return PI          # W lewo (obrót o 180 stopni)
	if vec == Vector2i(0, -1): return -PI / 2.0   # W górę (obrót o -90 stopni)
	if vec == Vector2i(0, 1): return PI / 2.0     # W dół (obrót o 90 stopni)
	return 0.0
