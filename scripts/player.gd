class_name Player
extends CharacterBody2D

signal died

const WALK_SPEED := 105.0

var max_hp := 100.0
var hp := 100.0
var alive := true
var aim := Vector2.RIGHT   # direction du regard (vers la souris)
var melee_cd := 0.0
var melee_flash := 0.0
var hurt_flash := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	
	# Collision : un petit cercle
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	cs.shape = shape
	add_child(cs)

	# Caméra qui suit le joueur
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	add_child(cam)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	melee_cd = maxf(0.0, melee_cd - delta)
	melee_flash = maxf(0.0, melee_flash - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	
	# Viser la souris
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()

	# Direction selon les touches (position physique : fonctionne en AZERTY)
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

	velocity = dir.normalized() * WALK_SPEED
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	var me := event as InputEventMouseButton
	if me != null and me.pressed and me.button_index == MOUSE_BUTTON_RIGHT:
		melee()


func melee() -> void:
	if not alive or melee_cd > 0.0:
		return
	melee_cd = 0.55
	melee_flash = 0.15
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.state == Zombie.State.DEAD:
			continue
		var off := z.global_position - global_position
		if off.length() < 40.0 and absf(aim.angle_to(off.normalized())) < 1.05:
			z.take_damage(35.0, aim)


func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	hurt_flash = 0.25
	if hp <= 0.0:
		hp = 0.0
		alive = false
		died.emit()



func _process(_delta: float) -> void:
	if hurt_flash > 0.0:
		modulate = Color(1.7, 0.6, 0.6)
	else:
		modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	# Placeholder en pixel art, dessiné par code (le « devant » est vers +X)
	draw_set_transform(Vector2.ZERO, aim.angle())
	var jacket := Color("3d6a99")
	var skin := Color("d9a679")
	draw_rect(Rect2(-5, -9, 10, 18), jacket)          # torse
	draw_rect(Rect2(3, -8, 8, 3), skin)               # bras gauche
	draw_rect(Rect2(3, 5, 8, 3), skin)                # bras droit
	draw_rect(Rect2(9, -2, 9, 4), Color("23272e"))    # pistolet
	draw_rect(Rect2(-4, -4, 8, 8), skin)              # tête
	draw_rect(Rect2(-5, -5, 5, 10), Color("3a2a1c"))  # cheveux
	if melee_flash > 0.0:
		draw_arc(Vector2.ZERO, 26.0, -0.9, 0.9, 12, Color(1, 1, 1, 0.8), 2.0)
	# Petite barre de vie temporaire
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_rect(Rect2(-12, -22, 24, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-12, -22, 24.0 * hp / max_hp, 3), Color("c42b2b"))
