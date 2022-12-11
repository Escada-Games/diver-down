extends AnimatedSprite

func _ready() -> void:
	self.scale.x = rand_range(0.6, 1.4)
	self.play("default")
	yield(self,"animation_finished")
	self.visible = false
	#yield(get_tree().create_timer(1.0), "timeout")
	self.queue_free()
	
