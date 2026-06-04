extends Node2D

@onready var test_player: Sprite2D = $TestPlayer1
@onready var test_player2: Sprite2D = $TestPlayer2
@onready var connect_button: Button = $UI/ConnectButton
@onready var tcp_client: TcpClient = TcpClientInstance

@onready var player_nodes = [
	$TestPlayer1,
	$TestPlayer2,
	$TestPlayer3,
	$TestPlayer4
]

var current_board_w = 0
var current_board_h = 0
var normal_apple_scene = preload("res://scenes/apple.tscn")
var wormy_apple_scene = preload("res://scenes/apple_bug.tscn")
var bonus_scene = preload("res://scenes/bonus.tscn")

var food_slots: Array[Dictionary] = []
var active_bonuses: Array[Node2D] = []
var segment_scene = preload("res://scenes/snake_segment.tscn")
var player_segments = [[], [], [], [], [], [], [], []] 

func _ready() -> void:
	for player_node in player_nodes:
		player_node.hide()
		
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
	# Get player input and send an input event packet to the server
	var input_packet: NetworkPacket.InputEventPacket = null
	if Input.is_action_just_pressed("ui_left"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Left)
	elif Input.is_action_just_pressed("ui_right"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Right)
	elif Input.is_action_just_pressed("ui_up"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Up)
	elif Input.is_action_just_pressed("ui_down"):
		input_packet = NetworkPacket.InputEventPacket.new(NetworkPacket.InputType.Down)
	
	if input_packet != null:
		TcpClientInstance.send_packet(input_packet)
	

func _on_packet_received(packet: NetworkPacket.GameDataPacket):
	$UI/PlayerIDLabel.text = "Player %d" % (packet.current_player_id + 1)
	
	if packet.board_width != current_board_w or packet.board_height != current_board_h:
		current_board_w = packet.board_width
		current_board_h = packet.board_height
		rebuild_board(current_board_w, current_board_h)
		
	if packet.player_count == 0:
		return
	for i in range(len(packet.players)):
		var p_data = packet.players[i]
		var segments_array = player_segments[i]
		
		if not p_data.is_alive:
			if i < len(player_nodes): player_nodes[i].hide()
			for seg in segments_array: seg.hide()
			continue
			
		if not player_nodes[i].visible:
			player_nodes[i].show()
		player_nodes[i].position = p_data.positions[0] * 32

		var body_length = p_data.length - 1
		
		while len(segments_array) < body_length:
			var new_seg = segment_scene.instantiate()
			new_seg.z_index = 4 
			add_child(new_seg)
			segments_array.append(new_seg)

		for j in range(len(segments_array)):
			if j < body_length:
				segments_array[j].show()
				segments_array[j].position = p_data.positions[j + 1] * 32
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
	test_player.queue_free()
	
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
