extends KinematicBody2D


#player dir enum
enum enum_player_dir {
	right = 1
	left = -1,
}

#-------------------------------------------------------#

#player information variable
export(float) var player_max_speed #player final speed
export(float) var player_first_speed #phase 1 speed
export(float) var air_speed
export(float) var change_speed_delay
export(float) var jump_f
export(float) var wall_jump_f
export(float) var wall_slide_speed
export(float) var reg_grav
export(float) var up_grav
export(float) var super_grav
export(float) var wall_grav
var gravity : float = reg_grav

export(float) var slide_dur
export(float) var slide_speed
export(float) var slide_cooldown

export(float) var attack_cd
export(float) var attack_onair_time

export(enum_player_dir) var facing_dir

#-------------------------------------------------------#

#move and slide slope variable
var floor_normal = Vector2.UP
var snap_dir = Vector2.DOWN
var def_snaplength = 20
var snap_length = def_snaplength
var snap_vec : Vector2
var slope_thes = deg2rad(47)

#-------------------------------------------------------#

#script variable
var player_speed
var motion = Vector2()
var x_input : float

##jump
var is_jump_press = false

var is_grounded = false
var active_super_grav = false

##wall slide , jump
var is_wall = false # For base wall sliding ref
var sliding_wall = false # For prevent super gravity bug
var wall_side
var is_wall_jumping = false

##ground slide
var can_slide = false
var is_sliding = false
var is_press_slide = false

var pressdelay_slide := 0.2

##attack
var can_attack = true
var is_attacking = false

##animation
onready var animtree = $fliper/Sprite/AnimationTree.get("parameters/playback")
onready var player_anim = $fliper/Sprite/AnimationPlayer

#-------------------------------------------------------#

signal press_super_grav

#-------------------------------------------------------#

func _ready():
	connect("press_super_grav",self,"on_press_super_grav")
	
	animtree.start('spr_player_anim_idle')
	pass

func _process(delta):
	snap_vec = snap_dir * snap_length
	
	_area_attack_hitbox()
	pass

func _physics_process(delta):
	
	#debuging
#	print(is_sliding)
	
	
	#horizontal thing
	get_xinput()
	set_player_speed()
	ground_check()
	_jump()
	_slide()
	
	#vertical thing
	wall_check(delta)
	set_grav()
	use_super_grav()
	
	
	#combat thing
	_attack()
	
	#common thing
	set_fliper_dir()
	animation_logic()
	
	
	#set motion
	if !is_sliding:
		motion.x = x_input * player_speed
	motion.y += gravity * delta
	
	
	motion = move_and_slide_with_snap(motion,snap_vec,floor_normal,true,4,slope_thes)
	

#set x_input
func get_xinput():
	x_input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

#set acceleration speed
func set_player_speed():
	if not is_grounded:
		player_speed = air_speed
	elif x_input == 0 and is_grounded:
#		print("stop") #debug
		$change_speed_timer.stop()
		player_speed = player_first_speed
	elif x_input != 0 and player_speed < player_max_speed and $change_speed_timer.is_stopped() and is_grounded:
#		print("start") #debug
		$change_speed_timer.start(change_speed_delay)
		yield($change_speed_timer,"timeout")
		player_speed = player_max_speed

#jump function
func _jump():
	#standard jump
	if Input.is_action_just_pressed("ui_jump") and is_grounded and is_wall == false:
		$jumpdelay.stop()
		$jumpdelay.emit_signal("timeout")
		snap_length = 0
		motion.y = -jump_f
		
	if Input.is_action_just_pressed("ui_jump") and is_wall and is_grounded == false:
		$jumpdelay.stop()
		$jumpdelay.emit_signal("timeout")
		is_wall_jumping = true
		snap_length = 0
		motion.y = -wall_jump_f
		is_wall_jumping = false
	
	if Input.is_action_just_pressed("ui_jump"):
		is_jump_press = true
		$jumpdelay.start(0.1)
		
	

#ground check funtion
func ground_check():
	if !$ground_check.get_overlapping_bodies().empty():
		is_grounded = true
	else:
		is_grounded = false

func wall_check(delta):
	#set standard wall ref
	if is_on_wall() and !is_grounded and motion.y >= 0:
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
			is_wall = true
		else:
			is_wall = false
	else:
		is_wall = false
	
	
	#set wall ref for super grav condition
	if is_on_wall() and !is_grounded:
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
			sliding_wall = true
		else:
			sliding_wall = false
	else:
		sliding_wall = false
	
	#set wall sliding
	if is_wall and active_super_grav == false and motion.y >= 0:
		motion.y = wall_slide_speed

#set where player should facing
func set_fliper_dir():
	if motion.x > 0:
		facing_dir = 1
	elif motion.x < 0:
		facing_dir = -1
	
	$fliper.scale.x = facing_dir

#set gravity value
func set_grav():
	if is_wall and motion.y >= 0:
		gravity = 0
	elif motion.y < 0 and is_wall == false:
		gravity = up_grav
	elif motion.y >= 0 and !active_super_grav and is_wall == false:
		gravity = reg_grav
	

#use super grav when press slide on air
func use_super_grav():
	if Input.is_action_just_pressed("ui_slide") and !is_grounded and sliding_wall == false and active_super_grav == false:
		emit_signal("press_super_grav")
		motion.y = 0
		active_super_grav = true
		gravity = super_grav
		yield($ground_check,"body_entered")
		active_super_grav = false
		#gravity = reg_grav
		

#set snap length to normal
func _on_ground_check_body_entered(body):
	snap_length = def_snaplength

#getter of facing dir
func get_facing_dir():
	return facing_dir

#slide function
func _slide():
	#set can slide bool
	if is_grounded and $slide_cd.is_stopped() and !is_sliding:
		can_slide = true
	else:
		can_slide = false
	
	#slide method
	if is_press_slide and can_slide and motion.x != 0:
		
		var slide_dir = get_facing_dir()
		
		$slidedelay.stop()
		$slidedelay.emit_signal("timeout")
		is_sliding = true
		can_slide = false
		motion.x = slide_dir * slide_speed
		$dur_slide.start(slide_dur)
		yield($dur_slide,"timeout")
		is_sliding = false
		$slide_cd.start(slide_cooldown)
	
	#slide press delay
	if Input.is_action_just_pressed("ui_slide") and is_sliding == false:
		$slidedelay.start(pressdelay_slide)
		is_press_slide = true
	
	
	#cancel slide when change direction
	if motion.x > 0 and is_sliding and x_input < 0:
		$dur_slide.emit_signal("timeout")
		$dur_slide.stop()
	elif motion.x < 0 and is_sliding and x_input > 0:
		$dur_slide.emit_signal("timeout")
		$dur_slide.stop()

func _attack():
	if Input.is_action_just_pressed("m1") and can_attack:
		$dur_slide.stop()
		$dur_slide.emit_signal("timeout")
		
		can_attack = false
		
		var enemies_inarea = $attack_hitbox_pivot/attack_area.get_overlapping_bodies()
		for enemy in enemies_inarea:
			if enemy.has_method("_take_damage"):
				enemy._take_damage()
			else:
				continue
		
		
		
		$_attack_timer.start(attack_cd)
		yield($_attack_timer,"timeout")
		can_attack = true
		
	

func _area_attack_hitbox():
	$attack_hitbox_pivot.look_at(get_global_mouse_position())

func _on_slidedelay_timeout():
	is_press_slide = false

func _on_jumpdelay_timeout():
	is_jump_press = false


func animation_logic():
	if is_wall:
		animtree.travel("spr_player_anim_wallslide")
	else:
		if is_grounded:
			if motion.x != 0:
				animtree.travel('spr_player_anim_run')
			else:
				animtree.travel('spr_player_anim_idle')
		else:
			if motion.y < 0:
				animtree.travel("spr_player_anim_jump")
			elif motion.y >= 0:
				animtree.travel("spr_player_anim_fall")

func on_press_super_grav():
	pressdelay_slide = false
