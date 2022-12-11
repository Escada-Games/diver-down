extends Line2D

func _ready() -> void:
	self.points = get_node("../line_2d").points
