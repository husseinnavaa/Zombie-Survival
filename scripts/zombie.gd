class_name Zombie
extends CharacterBody2D
# Machine à états : IDLE -> CHASE -> ATTACK (-> DEAD).
# Les stats sont des @export : zombie_runner.tscn hérite de zombie.tscn et change juste ces valeurs.

signal died(zombie: Zombie)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var max_hp := 60.0
@export var speed := 52.0
@export var damage := 12.0
@export var attack_rate := 1.1
@export var detect_range := 170.0
@export var blood_hit_scene: PackedScene
@export var blood_stain_scene: PackedScene

var hp := 60.0
var state: State = State.IDLE
var alert_time := 0.0
var wander_time := 0.0
var wander_dir := Vector2.ZERO
var knock := Vector2.ZERO
var face := Vector2.RIGHT
var shamble := 0.0
var player: Player
var level: Main

@onready var visual: Node2D = $Visual
@onready var alive_visual: Node2D = $Visual/Alive
@onready var dead_visual: Node2D = $Visual/Dead
@onready var arm_left: Polygon2D = $Visual/Alive/ArmLeft
@onready var arm_right: Polygon2D = $Visual/Alive/ArmRight
@onready var sight: RayCast2D = $SightRay
@onready var attack_timer: Timer = $AttackTimer


func _ready() -> void:
	hp = max_hp
	wander_time = randf_range(0.0, 3.0)
	face = Vector2.from_angle(randf() * TAU)
	attack_timer.wait_time = attack_rate


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		level = get_tree().get_first_node_in_group("level") as Main
		if player == null:
			return

	var to_p := player.global_position - global_position
	var d := to_p.length()

	# Perception : distance modulée par l'état du joueur + ligne de vue (RayCast2D)
	var sees := false
	if player.alive:
		var mult := 1.0
		if player.crouching:
			mult *= 0.55
		if not player.flashlight_on:
			mult *= 0.75
		if player.running:
			mult *= 1.35
		if d < 40.0 or (d < detect_range * mult and _can_see(player.global_position)):
			sees = true
	if sees:
		alert_time = 5.0
	else:
		alert_time = maxf(0.0, alert_time - delta)

	var move_vel := Vector2.ZERO
	match state:
		State.IDLE:
			if alert_time > 0.0:
				state = State.CHASE
			else:
				move_vel = _wander(delta)
		State.CHASE:
			if alert_time <= 0.0 or not player.alive:
				state = State.IDLE
			elif d < 24.0:
				state = State.ATTACK
			else:
				var target := player.global_position
				if not sees and level != null:
					target = level.flow_target(global_position, target)
				var dir := (target - global_position).normalized()
				face = face.lerp(dir, 0.25).normalized()
				move_vel = dir * speed
		State.ATTACK:
			if not player.alive:
				state = State.IDLE
			elif d > 32.0:
				state = State.CHASE
			else:
				face = to_p.normalized()
				if attack_timer.is_stopped():
					attack_timer.start()
					player.take_damage(damage)

	# Évite que les zombies se superposent
	var sep := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("zombies"):
		var z := other as Zombie
		if z == null or z == self:
			continue
		var off := global_position - z.global_position
		var l := off.length()
		if l > 0.1 and l < 16.0:
			sep += off / l * (16.0 - l) * 4.0

	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity = move_vel + sep + knock
	move_and_slide()
	if move_vel.length() > 1.0:
		shamble += delta * speed / 12.0


func _process(_delta: float) -> void:
	visual.rotation = face.angle()
	var sway := sin(shamble) * 1.6
	arm_left.position.y = sway
	arm_right.position.y = -sway


func _can_see(target: Vector2) -> bool:
	sight.target_position = sight.to_local(target)
	sight.force_raycast_update()
	return not sight.is_colliding()


func _wander(delta: float) -> Vector2:
	wander_time -= delta
	if wander_time <= 0.0:
		wander_time = randf_range(1.5, 4.0)
		if randf() < 0.5:
			wander_dir = Vector2.ZERO
		else:
			wander_dir = Vector2.from_angle(randf() * TAU)
	if wander_dir != Vector2.ZERO:
		face = face.lerp(wander_dir, 0.1).normalized()
	return wander_dir * speed * 0.3


# Appelé par le groupe "zombies" quand un bruit est émis (tir, explosion...)
func hear_noise(pos: Vector2, radius: float) -> void:
	if state != State.DEAD and global_position.distance_to(pos) < radius:
		alert_time = maxf(alert_time, 4.0)


func take_damage(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	knock = dir.normalized() * 140.0
	alert_time = 6.0
	if state == State.IDLE:
		state = State.CHASE
	visual.modulate = Color(2, 2, 2)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.12)
	_spawn(blood_hit_scene, global_position, dir)
	_spawn(blood_stain_scene, global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2.RIGHT.rotated(randf() * TAU))
	if hp <= 0.0:
		die()


func die() -> void:
	state = State.DEAD
	remove_from_group("zombies")
	set_deferred("collision_layer", 0)
	alive_visual.hide()
	dead_visual.show()
	z_index = -5   # le cadavre passe sous les vivants
	_spawn(blood_stain_scene, global_position, Vector2.RIGHT.rotated(randf() * TAU))
	died.emit(self)


func _spawn(scene: PackedScene, pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	if scene == null:
		return
	var fx := scene.instantiate() as Node2D
	fx.position = pos
	fx.rotation = dir.angle()
	get_parent().add_child(fx)
