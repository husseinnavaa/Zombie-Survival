class_name Player
extends CharacterBody2D

const WALK_SPEED := 105.0

var aim := Vector2.RIGHT   # direction du regard (vers la souris)


func _ready() -> void:
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


func _physics_process(_delta: float) -> void:
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


func _process(_delta: float) -> void:
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
