class_name Player
extends CharacterBody2D
# Le joueur est une scène (player.tscn) : les formes, lumières, caméra, minuteurs
# et zones de détection sont des nodes. Ce script ne contient que la logique.

signal died
signal hurt
signal health_changed(hp: float, max_hp: float)
signal stamina_changed(value: float, exhausted: bool)
signal ammo_changed(mag: int, reserve: int, reloading: bool)
signal key_changed(has_key: bool)
signal crouch_changed(crouching: bool)
signal hint_changed(text: String)
signal message(text: String)

@export var walk_speed := 105.0
@export var run_speed := 175.0
@export var crouch_speed := 55.0
@export var max_hp := 100.0
@export var mag_size := 12
@export var start_reserve := 24
@export var bullet_scene: PackedScene
@export var muzzle_flash_scene: PackedScene
@export var blood_hit_scene: PackedScene

var hp := 100.0
var stamina := 100.0
var exhausted := false
var stamina_delay := 0.0
var mag := 12
var reserve := 24
var has_key := false
var crouching := false
var running := false
var flashlight_on := true
var alive := true
var aim := Vector2.RIGHT
var shake := 0.0
var hint := ""

@onready var visual: Node2D = $Visual
@onready var muzzle: Marker2D = $Visual/Muzzle
@onready var flashlight: PointLight2D = $Visual/Flashlight
@onready var swing_fx: Polygon2D = $Visual/SwingFx
@onready var melee_area: Area2D = $Visual/MeleeArea
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D
@onready var reload_timer: Timer = $ReloadTimer
@onready var fire_timer: Timer = $FireTimer
@onready var melee_timer: Timer = $MeleeTimer


func _ready() -> void:
	hp = max_hp
	mag = mag_size
	reserve = start_reserve
	reload_timer.timeout.connect(_finish_reload)


# Envoie l'état actuel aux écouteurs (HUD) une fois les connexions faites
func emit_state() -> void:
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, exhausted)
	ammo_changed.emit(mag, reserve, not reload_timer.is_stopped())
	key_changed.emit(has_key)
	crouch_changed.emit(crouching)
	hint_changed.emit(hint)


func set_camera_limits(size: Vector2i) -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size.x
	camera.limit_bottom = size.y


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()
	visual.rotation = aim.angle()

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var now_crouching := Input.is_action_pressed("crouch")
	if now_crouching != crouching:
		crouching = now_crouching
		crouch_changed.emit(crouching)
		visual.scale = Vector2(0.9, 0.9) if crouching else Vector2.ONE

	var wants_run := Input.is_action_pressed("sprint") and dir != Vector2.ZERO and not crouching
	running = wants_run and not exhausted and stamina > 0.0

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed
	if not reload_timer.is_stopped():
		speed *= 0.85

	_update_stamina(delta)
	velocity = dir * speed
	move_and_slide()
	_update_hint()


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - 30.0 * delta)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake


func _update_stamina(delta: float) -> void:
	var old := stamina
	if running:
		stamina = maxf(0.0, stamina - 28.0 * delta)
		stamina_delay = 1.0
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina_delay = maxf(0.0, stamina_delay - delta)
		if stamina_delay <= 0.0:
			stamina = minf(100.0, stamina + 18.0 * delta)
		if exhausted and stamina >= 30.0:
			exhausted = false
	if stamina != old:
		stamina_changed.emit(stamina, exhausted)


# ---------- interaction ----------

func _find_interactable() -> Node:
	var best: Node = null
	var best_d := 50.0
	for body in interact_area.get_overlapping_bodies():
		if not body.is_in_group("interactable") or body.used:
			continue
		var d := global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


func _update_hint() -> void:
	var target := _find_interactable()
	var text := ""
	if target != null:
		text = target.get_hint(self)
	if text != hint:
		hint = text
		hint_changed.emit(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event.is_action_pressed("shoot"):
		_attack_primary()
	elif event.is_action_pressed("melee"):
		melee()
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		flashlight.enabled = flashlight_on
	elif event.is_action_pressed("interact"):
		var target := _find_interactable()
		if target != null:
			target.interact(self)


# ---------- combat ----------

func _attack_primary() -> void:
	if not reload_timer.is_stopped() or not fire_timer.is_stopped():
		return
	if mag > 0:
		_shoot()
	elif reserve > 0:
		start_reload()
	else:
		melee()   # plus de munitions : coup au corps à corps


func _shoot() -> void:
	mag -= 1
	fire_timer.start()
	var d := aim.rotated(randf_range(-0.04, 0.04))
	var b := bullet_scene.instantiate() as Bullet
	b.direction = d
	b.rotation = d.angle()
	b.position = muzzle.global_position
	get_parent().add_child(b)
	_spawn_fx(muzzle_flash_scene, muzzle.global_position, d)
	add_shake(1.5)
	get_tree().call_group("zombies", "hear_noise", global_position, 350.0)
	ammo_changed.emit(mag, reserve, false)


func melee() -> void:
	if not alive or not melee_timer.is_stopped():
		return
	melee_timer.start()
	get_tree().call_group("zombies", "hear_noise", global_position, 120.0)
	swing_fx.visible = true
	for body in melee_area.get_overlapping_bodies():
		if body.is_in_group("zombies"):
			body.take_damage(35.0, aim)
	await get_tree().create_timer(0.15).timeout
	swing_fx.visible = false


func start_reload() -> void:
	if not reload_timer.is_stopped() or mag >= mag_size or reserve <= 0:
		return
	reload_timer.start()
	ammo_changed.emit(mag, reserve, true)


func _finish_reload() -> void:
	var take := mini(mag_size - mag, reserve)
	mag += take
	reserve -= take
	ammo_changed.emit(mag, reserve, false)


func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	add_shake(4.0)
	_spawn_fx(blood_hit_scene, global_position)
	visual.modulate = Color(1.7, 0.6, 0.6)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.25)
	hurt.emit()
	if hp <= 0.0:
		hp = 0.0
		alive = false
		health_changed.emit(hp, max_hp)
		died.emit()
		return
	health_changed.emit(hp, max_hp)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


# ---------- objets ramassés ----------

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	message.emit("Trousse de soins : +%d PV" % int(amount))


func add_ammo(count: int) -> void:
	reserve += count
	ammo_changed.emit(mag, reserve, not reload_timer.is_stopped())
	message.emit("+%d munitions" % count)


func give_key() -> void:
	has_key = true
	key_changed.emit(true)
	message.emit("Clé trouvée !")


# Utilisé par le niveau pour reprendre au dernier point de sauvegarde
func restore(new_hp: float, new_mag: int, new_reserve: int, new_key: bool) -> void:
	hp = maxf(new_hp, 40.0)   # filet de sécurité contre les boucles de mort
	mag = new_mag
	reserve = maxi(new_reserve, 12)
	has_key = new_key
	camera.reset_smoothing()
	emit_state()


func _spawn_fx(scene: PackedScene, pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	if scene == null:
		return
	var fx := scene.instantiate() as Node2D
	fx.position = pos
	fx.rotation = dir.angle()
	get_parent().add_child(fx)
