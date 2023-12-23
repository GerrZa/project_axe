tool
extends Position2D

export(NodePath) var target

func _process(delta):

	if String(target) != "":
		self.position = get_node(target).position
	pass
