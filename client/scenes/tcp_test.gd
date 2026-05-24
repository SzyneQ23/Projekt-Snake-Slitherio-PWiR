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

func _ready() -> void:
	for player_node in player_nodes:
		player_node.hide()
	
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
	if packet.player_count == 0:
		return
	for i in range(len(packet.players)):
		if not player_nodes[i].visible:
			player_nodes[i].show()
		player_nodes[i].position = packet.players[i].position * 32

func _on_connected():
	connect_button.hide()

func _on_disconnected():
	test_player.queue_free()
