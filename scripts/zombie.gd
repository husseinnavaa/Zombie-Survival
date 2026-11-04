class_name Zombie
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, DEAD }

var kind := "walker"       # "walker" ou "runner"
var state: State = State.IDLE
var hp := 60.0
var speed := 52.0
var damage := 12.0
var attack_rate := 1.1     # secondes entre deux attaques
var detect := 170.0        # distance de détection
var attack_cd := 0.0
var alert_t := 0.0         # temps restant avant d'abandonner la poursuite
var wander_t := 0.0
var wander_dir := Vector2.ZERO
var knock := Vector2.ZERO
var hit_flash := 0.0
var face := Vector2.RIGHT
var shamble := 0.0
var player: Player


func _ready() -> void:
	add_to_group("zombies")
	if kind == "runner":
		hp = 25.0
		speed = 135.0
		damage = 8.0
		attack_rate = 0.7
		detect = 300.0
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 9.0 if kind == "walker" else 8.0
	cs.shape = sh
	add_child(cs)
	wander_t = randf_range(0.0, 3.0)
	face = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return

	attack_cd = maxf(0.0, attack_cd - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

	var to_p := player.global_position - global_position
	var d := to_p.length()

	# Perception (pour l'instant : seulement la distance)
	var sees := player.alive and d < detect
	if sees:
		alert_t = 5.0
	else:
		alert_t = maxf(0.0, alert_t - delta)

	# Machine à états : IDLE -> CHASE -> ATTACK (-> DEAD)
	var move_vel := Vector2.ZERO
	match state:
		State.IDLE:
			if alert_t > 0.0:
				state = State.CHASE
			else:
				move_vel = _wander(delta)
		State.CHASE:
			if alert_t <= 0.0 or not player.alive:
				state = State.IDLE
			elif d < 24.0:
				state = State.ATTACK
			else:
				var dir := to_p.normalized()
				face = face.lerp(dir, 0.25).normalized()
				move_vel = dir * speed
		State.ATTACK:
			if not player.alive:
				state = State.IDLE
			elif d > 32.0:
				state = State.CHASE
			else:
				face = to_p.normalized()
				if attack_cd <= 0.0:
					attack_cd = attack_rate
					player.take_damage(damage)

	# Évite que les zombies se superposent
	var sep := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("zombies"):
		var z := other as Zombie
		if z == null or z == self or z.state == State.DEAD:
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


func _wander(delta: float) -> Vector2:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 4.0)
		if randf() < 0.5:
			wander_dir = Vector2.ZERO
		else:
			wander_dir = Vector2.from_angle(randf() * TAU)
	if wander_dir != Vector2.ZERO:
		face = face.lerp(wander_dir, 0.1).normalized()
	return wander_dir * speed * 0.3


func take_damage(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	hit_flash = 0.12
	knock = dir.normalized() * 140.0
	alert_t = 6.0                      # être touché alerte le zombie
	if state == State.IDLE:
		state = State.CHASE
	if hp <= 0.0:
		die()


func die() -> void:
	state = State.DEAD
	remove_from_group("zombies")
	set_deferred("collision_layer", 0)
	get_parent().move_child(self, 0)   # le cadavre passe sous les autres
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, face.angle())
	var walker := kind == "walker"
	var skin := Color("7f9a6b") if walker else Color("a9b28c")
	var cloth := Color("4b4036") if walker else Color("6a2f2f")
	if state == State.DEAD:
		draw_rect(Rect2(-13, -9, 26, 18), Color(0.3, 0.04, 0.05, 0.75))   # flaque de sang
		draw_rect(Rect2(-9, -4, 18, 8), cloth.darkened(0.3))
		draw_rect(Rect2(8, -3, 6, 6), skin.darkened(0.3))
		return
	var sway := sin(shamble) * 1.6
	draw_rect(Rect2(-5, -8, 10, 16), cloth)
	draw_rect(Rect2(2, -9 + sway, 10, 3), skin)
	draw_rect(Rect2(2, 6 - sway, 10, 3), skin)
	draw_rect(Rect2(-4, -4, 8, 8), skin)
	draw_rect(Rect2(2, -3, 2, 2), Color("ff3030"))
	draw_rect(Rect2(2, 1, 2, 2), Color("ff3030"))
	if hit_flash > 0.0:
		draw_rect(Rect2(-6, -9, 12, 18), Color(1, 1, 1, 0.55))
