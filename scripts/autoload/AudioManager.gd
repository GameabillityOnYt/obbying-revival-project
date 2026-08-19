extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	print("hi")

func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	$Click.play()
