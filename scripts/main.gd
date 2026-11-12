class_name Main
extends Node2D
# Scène principale. Le niveau 1 est construit directement dans main.tscn avec des nodes :
# CanvasModulate, Sol, Murs, Porte, Caisses, Barils, Points de sauvegarde, Sortie, Zombies, Joueur, HUD.
# Ce script relie ces nodes entre eux (signaux), gère le chemin des zombies et la sauvegarde.

const TILE := 32
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Données du dernier point de sauvegarde (gardées quand on recharge la scène)
static var saved: Dictionary = {}

@export var title := "CHAPITRE 1 — LA BANLIEUE"
@export var subtitle := "Niveau 1 : trouver la clé et rejoindre la zone d'évacuation"
@export var grid_size := Vector2i(40, 20)

var time_played := 0.0
var killed: Array = []
var destroyed: Array = []
var finished := false
var door: Door
var static_blocked := {}
var dist := {}
var dist_timer := 0.0

@onready var player: Player = $Joueur
@onready var hud: Hud = $HUD


func _ready() -> void:
	add_to_group("level")
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	player.set_camera_limits(grid_size * TILE)

	for w in get_tree().get_nodes_in_group("wall"):
		static_blocked[cell_of((w as Node2D).global_position)] = true

	door = get_tree().get_first_node_in_group("doors") as Door
	if door != null:
		door.opened.connect(refresh_objective)
	for z in get_tree().get_nodes_in_group("zombies"):
		(z as Zombie).died.connect(_on_zombie_died)
	for b in get_tree().get_nodes_in_group("barrels"):
		(b as Barrel).destroyed.connect(_on_barrel_destroyed)
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		(cp as Checkpoint).activated.connect(_on_checkpoint)
	for ex in get_tree().get_nodes_in_group("exit"):
		(ex as ExitZone).reached.connect(_on_exit)

	if not saved.is_empty():
		_apply_checkpoint()

	# Le joueur parle au HUD par signaux
	player.health_changed.connect(hud.set_health)
	player.stamina_changed.connect(hud.set_stamina)
	player.ammo_changed.connect(hud.set_ammo)
	player.key_changed.connect(hud.set_key)
	player.key_changed.connect(func(_has_key: bool) -> void: refresh_objective())
	player.crouch_changed.connect(hud.set_crouch)
	player.hint_changed.connect(hud.set_hint)
	player.message.connect(hud.toast)
	player.hurt.connect(hud.flash_hurt)
	player.died.connect(_on_player_died)
	hud.restart_requested.connect(_on_restart_requested)

	hud.show_title(title, subtitle)
	player.emit_state()
	refresh_objective()
	_update_dist()


func _process(delta: float) -> void:
	time_played += delta


func _physics_process(delta: float) -> void:
	dist_timer -= delta
	if dist_timer <= 0.0:
		dist_timer = 0.3
		_update_dist()


func refresh_objective() -> void:
	var text := "Objectif : atteindre la zone d'évacuation"
	if door != null and not door.used:
		if player.has_key:
			text = "Objectif : ouvrir la porte verrouillée"
		else:
			text = "Objectif : trouver la clé de la porte verrouillée"
	hud.set_objective(text)


# ---------- chemin des zombies (champ de distance vers le joueur) ----------

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE), int(pos.y / TILE))


func _update_dist() -> void:
	dist.clear()
	var blocked := static_blocked.duplicate()
	for n in get_tree().get_nodes_in_group("dynamic_obstacle"):
		blocked[cell_of((n as Node2D).global_position)] = true
	var start := cell_of(player.global_position)
	var queue: Array[Vector2i] = [start]
	dist[start] = 0
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for off in DIRS:
			var n2: Vector2i = c + off
			if n2.x < 0 or n2.y < 0 or n2.x >= grid_size.x or n2.y >= grid_size.y:
				continue
			if dist.has(n2) or blocked.has(n2):
				continue
			dist[n2] = int(dist[c]) + 1
			queue.append(n2)


# Prochain point à viser pour contourner les obstacles
func flow_target(pos: Vector2, fallback: Vector2) -> Vector2:
	var c := cell_of(pos)
	if not dist.has(c):
		return fallback
	var best := c
	var best_d: int = dist[c]
	for off in DIRS:
		var n: Vector2i = c + off
		if dist.has(n) and int(dist[n]) < best_d:
			best_d = dist[n]
			best = n
	if best == c:
		return fallback
	return Vector2(best.x * TILE + TILE * 0.5, best.y * TILE + TILE * 0.5)


# ---------- événements ----------

func _on_zombie_died(z: Zombie) -> void:
	killed.append(str(z.name))


func _on_barrel_destroyed(b: Barrel) -> void:
	destroyed.append(str(b.name))


func _on_player_died() -> void:
	hud.show_game_over()
	get_tree().paused = true


func _on_exit() -> void:
	if finished:
		return
	finished = true
	saved.clear()
	hud.show_win(killed.size(), time_played)
	get_tree().paused = true


func _on_restart_requested(from_checkpoint: bool) -> void:
	if not from_checkpoint:
		saved.clear()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------- points de sauvegarde ----------

func _on_checkpoint(cp: Checkpoint) -> void:
	var used_names: Array = []
	for n in get_tree().get_nodes_in_group("stateful"):
		if n.used:
			used_names.append(str(n.name))
	saved = {
		"pos": cp.global_position,
		"hp": player.hp,
		"mag": player.mag,
		"reserve": player.reserve,
		"key": player.has_key,
		"killed": killed.duplicate(),
		"destroyed": destroyed.duplicate(),
		"used": used_names,
		"time": time_played,
	}
	hud.toast("Point de sauvegarde")


func _apply_checkpoint() -> void:
	player.global_position = saved["pos"]
	player.restore(saved["hp"], saved["mag"], saved["reserve"], saved["key"])
	killed = saved["killed"].duplicate()
	destroyed = saved["destroyed"].duplicate()
	time_played = saved["time"]
	for z in get_tree().get_nodes_in_group("zombies"):
		if str(z.name) in killed:
			z.queue_free()
	for b in get_tree().get_nodes_in_group("barrels"):
		if str(b.name) in destroyed:
			b.queue_free()
	for n in get_tree().get_nodes_in_group("stateful"):
		if str(n.name) in saved["used"]:
			n.restore_used()
