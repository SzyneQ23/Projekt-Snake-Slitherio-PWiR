extends Node2D

@onready var test_player: Sprite2D = $TestPlayer
@onready var connect_button: Button = $UI/ConnectButton
@onready var tcp_client: ClientTCP = $TCP_Client

func _ready() -> void:
	test_player.visible = false
	
	connect_button.pressed.connect(_on_button_pressed)
	
	tcp_client.packet_received.connect(_on_packet_received)
	tcp_client.connected.connect(_on_connected)
	tcp_client.disconnected.connect(_on_disconnected)

func _on_button_pressed():
	tcp_client.connect_to_host()


func _process(delta: float) -> void:
	pass

func _on_packet_received(packet: NetworkPacket.BoardDataPacket):
	if packet.player_count == 0:
		return
	test_player.position = packet.players[0].position * 32
	# print_debug("New position: ", $TestPlayer.position)

func _on_connected():
	test_player.visible = true

func _on_disconnected():
	test_player.queue_free()
