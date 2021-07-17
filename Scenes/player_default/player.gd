extends KinematicBody2D

var id=self
var vectorVelocity=Vector2()
var vector_gravity = Vector2()
export var last_horizontal_direction = 1
var active=true
var anim=''

enum {State_normal, State_dive}
var state = State_normal

export var flag_constant_spritetrail = false
export var color_spritetrail = Color()
var flag_can_create_spritetrail = true

const lerp_constant = 0.5
const vector_gravity_up = Vector2(0, 10)
const vector_gravity_down = Vector2(0, 12.5)

const vector_normal=Vector2(0, -1)
const maximum_speed=95#120
const jump_force=175

var airTime=0
const maxAirTime=5
var jumpBuffer=0
const maxJumpBuffer=2.5
var diveBuffer=0
const maxDiveBuffer=0.51
var target_rotation=0
const twn_duration=0.25
const spritetrail=preload('res://Scenes/spritetrail/sprite_trail.tscn')
const spherizeShader=preload("res://Scenes/spherizeShader.tscn")
const drop=preload("res://Scenes/drop.tscn")

onready var dive_aim=$dive_aim/dive_aim
func _ready():
	add_to_group('Player')
	global.player=self
	$dive_aim.rotation=0 if self.last_horizontal_direction==1 else -PI

func _physics_process(delta):
	$sprite.flip_h=false if(last_horizontal_direction==1) else true
	if state==State_dive:
		anim="idle"
	else:
		if self.is_on_floor():
			anim="idle" if abs(vectorVelocity.x)<=10 else "walk"
		else:
			anim="going_up" if vectorVelocity.y<0 else "goind_down"
	if($animation_player.current_animation!=anim): $animation_player.play(anim)

	if flag_constant_spritetrail: _create_spritetrail()
	if Input.is_action_just_pressed('ui_reset'): get_tree().reload_current_scene()
	
	var vector_direction_input=Vector2(1 if Input.is_action_pressed('ui_right') else -1 if Input.is_action_pressed('ui_left') else 0, 1 if Input.is_action_pressed('ui_down') else -1 if Input.is_action_pressed('ui_up') else 0)
	last_horizontal_direction=vector_direction_input.x if vector_direction_input.x != 0 else last_horizontal_direction
#	if vector_direction_input!=Vector2(): $dive_aim.rotation=vector_direction_input.angle()
	
	if self.active:
		if state==State_normal: _state_normal(delta,vector_direction_input)
		elif state==State_dive: _state_dive(delta,vector_direction_input)
	if vector_direction_input!=Vector2(): $dive_aim.rotation=vector_direction_input.angle()

func _state_normal(delta,vector_direction_input):
	set_collision_layer_bit(0, true)
	set_collision_mask_bit(0, true)
	vector_gravity=vector_gravity_up if (vectorVelocity.y<0 and Input.is_action_pressed('ui_jump')) else vector_gravity_down
	
	if Input.is_action_just_pressed('ui_jump'):jumpBuffer=maxJumpBuffer
	if Input.is_action_just_pressed('ui_dive'):diveBuffer=maxDiveBuffer
	if self.is_on_floor():airTime=maxAirTime
	else:airTime-=0.5
	jumpBuffer-=0.5
	diveBuffer-=0.5
	
	if jumpBuffer>0 and airTime>0:
		airTime=0
		jumpBuffer=0
		_twn_squishy()
		$sounds/snd_jump.play()
		vectorVelocity.y=-jump_force
		
	if diveBuffer>0 and dive_aim.get_overlapping_bodies().size()>0:
		var phaseable=true
		#Check if the tileset is unphaseable
		for body in dive_aim.get_overlapping_bodies():
			if body.is_in_group('Unphaseable'): phaseable=false
		if phaseable:
			global.changeToLowPassMusic()
			if randf()<=0.5: $sounds/snd_dive.play()
			else: $sounds/snd_dive1.play()
			self.state=State_dive
			var cursor_position=dive_aim.get_node('position_2d').global_position#-Vector2(0,1)
			var vector_target_position=Vector2(floor(cursor_position.x/global.tile_size.x)*global.tile_size.x,floor(cursor_position.y/global.tile_size.y)*global.tile_size.y)+global.tile_size/2
			$twn_dive.interpolate_property(self, 'global_position', self.global_position,vector_target_position, twn_duration, Tween.TRANS_QUART, Tween.EASE_OUT)
			$twn_dive.start()
			$animation_player.play("idle")
			create_splash(20,30,-(self.global_position-vector_target_position),(self.global_position-vector_target_position)/2)
			createSpherize()
	else:
		var initialVelocity=vectorVelocity
		vectorVelocity.x=lerp(vectorVelocity.x, maximum_speed*vector_direction_input.x, lerp_constant)
		vectorVelocity.y+=vector_gravity.y
		vectorVelocity=move_and_slide(vectorVelocity, vector_normal)
		if initialVelocity.y!=vectorVelocity.y and self.is_on_floor():
			$sounds/snd_land.play()

func _state_dive(delta,vector_direction_input):
	if Input.is_action_just_pressed('ui_dive'):diveBuffer=maxDiveBuffer
	diveBuffer-=0.5
	if diveBuffer>0 and dive_aim.get_overlapping_bodies().size()==0:
		global.changeFromLowPassMusic()
		$sounds/snd_dive_away.play()
		self.state=State_normal
		var vector_target_position=Vector2(floor(dive_aim.global_position.x/global.tile_size.x)*global.tile_size.x,floor(dive_aim.global_position.y/global.tile_size.y)*global.tile_size.y)+global.tile_size/2
		$twn_dive.interpolate_property(self, 'global_position', self.global_position,vector_target_position, twn_duration*0.8, Tween.TRANS_QUART, Tween.EASE_OUT)
		$twn_dive.start() 
		create_splash(10,15,(self.global_position-vector_target_position),(self.global_position-vector_target_position)/2)
		createSpherize()
		vectorVelocity=Vector2()#(self.global_position-vector_target_position).normalized()*maximum_speed #Add conservation of momentum maybe
		#@Maybe allow for diving without the position "fixing" //@Add a dive buffer as well

func create_splash(minimum=5,maximum=10,direction=Vector2(0,-1),offset=Vector2()):
	for a in range(rand_range(minimum,maximum)):
		var i=drop.instance()
		i.global_position=self.global_position+offset*Vector2(rand_range(-0.5,0.5),rand_range(-0.5,0.5))
		i.direction=direction.normalized()
		get_tree().current_scene.add_child(i)
func createSpherize():
	var i=spherizeShader.instance()
	i.global_position=self.global_position
#	get_tree().root.add_child(i)
	get_parent().add_child(i)
func _create_spritetrail():
	if flag_can_create_spritetrail == true:
		flag_can_create_spritetrail = false; $timers/tmr_spritetrail.start()
		var i = spritetrail.instance()
		i.texture = $sprite.texture
		i.hframes = $sprite.hframes
		i.vframes = $sprite.vframes
		i.flip_h=$sprite.flip_h
		i.frame   = $sprite.frame
		i.scale = $sprite.scale
		i.rotation = $sprite.global_rotation
		i.global_position = $sprite.global_position
		i.modulate = color_spritetrail
		i.fade_increment = 0.05
		get_parent().add_child(i)

func _twn_squishy( scale_vector = Vector2(0.50, 1.50) ):
	$twn_squishy.interpolate_property($sprite, 'scale', $sprite.scale * scale_vector, Vector2(1,1), 0.5, Tween.TRANS_QUINT, Tween.EASE_OUT)
	$twn_squishy.start()

func _on_tmr_spritetrail_timeout(): flag_can_create_spritetrail = true

func _on_twn_dive_tween_started(object, key):
	self.active=false
	$sprite.modulate.a=0 if $sprite.modulate.a==1 else 1
	$eyes.visible=!$eyes.visible
	self.flag_constant_spritetrail=true
	set_collision_layer_bit(0, false)
	set_collision_mask_bit(0, false)
func _on_twn_dive_tween_completed(object, key):
	self.active=true
	self.flag_constant_spritetrail=false
	if self.state==State_normal:
		set_collision_layer_bit(1, false)
		set_collision_mask_bit(1, false)
	else:
		pass

func footstepSfx():
	var footsteps=["res://Resources/SFX/footsteps/footstep_grass_000.ogg","res://Resources/SFX/footsteps/footstep_grass_001.ogg","res://Resources/SFX/footsteps/footstep_grass_002.ogg","res://Resources/SFX/footsteps/footstep_grass_003.ogg","res://Resources/SFX/footsteps/footstep_grass_004.ogg"]
	$sounds.get_node("sndFootsteps").stream=load(footsteps[randi()%footsteps.size()])
	$sounds.get_node("sndFootsteps").play()
