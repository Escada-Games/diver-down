extends CanvasLayer
const duration=0.66
const baseDelay=0.1
const delay=0.02
const maximumLightMaskSize=0.55
const lightMaskSpacing=64
var lightMask=preload("res://Scenes/screenTransition/light2DforMasking.tscn")
var deleteNext=false
var nextLevel=PackedScene
func _ready():
	$twnGrow.connect("tween_all_completed",self,"tweenEnded")
	var d=0
	for i in range(0,global.defaultResolution.x+lightMaskSpacing*0.1,lightMaskSpacing):
		for j in range(0,global.defaultResolution.y+lightMaskSpacing*0.3,lightMaskSpacing):
			createLight(i,j)
			d+=1
	print_debug(d)

func createLight(x,y):
	var i=lightMask.instance()
	i.global_position=Vector2(x,y)
	i.texture_scale=0
	$twnGrow.interpolate_property(i,"texture_scale",i.texture_scale,maximumLightMaskSize,duration,Tween.TRANS_QUINT,Tween.EASE_OUT,baseDelay+delay*2*(x+y)/lightMaskSpacing)
	$twnGrow.start()
	$lights.add_child(i)

func tweenEnded():
	if not deleteNext:
		global.change_stage(nextLevel)
		deleteNext=true
		for node in $lights.get_children():
			var x=node.global_position.x
			var y=node.global_position.y
			$twnGrow.interpolate_property(node,"texture_scale",node.texture_scale,0,duration,Tween.TRANS_QUINT,Tween.EASE_OUT,delay*2*(x+y)/lightMaskSpacing)
			$twnGrow.start()
	else:
		self.queue_free()
