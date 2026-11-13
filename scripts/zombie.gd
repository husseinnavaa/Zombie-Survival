## Zombie (scène zombie.tscn). Sert de base au marcheur ET au coureur.
##
## Comportement : machine à états finis (FSM) avec 4 états :
##   IDLE   : se promène au hasard
##   CHASE  : poursuit le joueur
##   ATTACK : frappe le joueur quand il est à portée
##   DEAD   : mort, laisse un cadavre
##
## Le zombie coureur (zombie_runner.tscn) hérite de cette scène : seules les valeurs @export
## changent.
class_name Zombie
extends CharacterBody2D

## Émis à la mort du zombie (main.gd s'en sert pour compter les zombies tués et pour la sauvegarde).
signal died(zombie: Zombie)

## Les 4 états de la machine à états.
enum State { IDLE, CHASE, ATTACK, DEAD }

## Points de vie maximum (60 pour le marcheur, 25 pour le coureur).
@export var max_hp := 60.0
## Vitesse de déplacement, en pixels par seconde.
@export var speed := 52.0
## Dégâts infligés à chaque attaque.
@export var damage := 12.0
## Nombre de secondes entre deux attaques.
@export var attack_rate := 1.1
## Distance de détection du joueur, en pixels (avant les modificateurs de furtivité).
@export var detect_range := 170.0
## Effet de sang quand le zombie est touché.
@export var blood_hit_scene: PackedScene
## Tache de sang laissée au sol.
@export var blood_stain_scene: PackedScene

# --- État actuel du zombie ---
var hp := 60.0
# État courant de la machine à états
var state: State = State.IDLE
# Temps restant (en s) pendant lequel le zombie reste « alerté » après avoir perçu le joueur
var alert_time := 0.0
# Temps restant avant de changer de direction de promenade
var wander_time := 0.0
# Direction de promenade actuelle (ZERO = immobile)
var wander_dir := Vector2.ZERO
# Recul reçu quand le zombie est touché (diminue vite)
var knock := Vector2.ZERO
# Direction vers laquelle le zombie regarde
var face := Vector2.RIGHT
# Phase de l'oscillation des bras (animation de marche)
var shamble := 0.0
# Références au joueur et au niveau (main.gd), trouvées au premier appel de _physics_process
var player: Player
var level: Main

# Références aux nodes enfants de zombie.tscn
@onready var visual: Node2D = $Visual
@onready var alive_visual: Node2D = $Visual/Alive
@onready var dead_visual: Node2D = $Visual/Dead
@onready var arm_left: Polygon2D = $Visual/Alive/ArmLeft
@onready var arm_right: Polygon2D = $Visual/Alive/ArmRight
# RayCast2D : rayon invisible qui sert à savoir si un obstacle bloque la vue
@onready var sight: RayCast2D = $SightRay
# Timer qui impose un délai entre deux attaques
@onready var attack_timer: Timer = $AttackTimer


## Initialise la vie, une promenade au hasard et le délai d'attaque.
func _ready() -> void:
	hp = max_hp
	wander_time = randf_range(0.0, 3.0)
	# Regarde dans une direction aléatoire pour que les zombies ne soient pas tous alignés
	face = Vector2.from_angle(randf() * TAU)
	attack_timer.wait_time = attack_rate


## Cerveau du zombie, appelé à chaque image physique :
## perception du joueur, machine à états, séparation entre zombies, puis déplacement.
func _physics_process(delta: float) -> void:
	# Un zombie mort ne fait plus rien
	if state == State.DEAD:
		return
	# Premier appel : on cherche le joueur et le niveau grâce à leurs groupes
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		level = get_tree().get_first_node_in_group("level") as Main
		if player == null:
			return

	# Vecteur du zombie vers le joueur, et distance (d)
	var to_p := player.global_position - global_position
	var d := to_p.length()

	# Perception : distance modulée par l'état du joueur + ligne de vue (RayCast2D)
	var sees := false
	if player.alive:
		# La distance de détection est multipliée : accroupi ×0,55, lampe éteinte ×0,75, joueur qui court
		# ×1,35
		var mult := 1.0
		if player.crouching:
			mult *= 0.55
		if not player.flashlight_on:
			mult *= 0.75
		if player.running:
			mult *= 1.35
		# Il te voit s'il est très proche (< 40 px), ou s'il est à portée ET qu'aucun obstacle ne bloque
		# la vue
		if d < 40.0 or (d < detect_range * mult and _can_see(player.global_position)):
			sees = true
	# S'il te voit, l'alerte est remise à 5 s ; sinon elle diminue peu à peu
	if sees:
		alert_time = 5.0
	else:
		alert_time = maxf(0.0, alert_time - delta)

	# --- Machine à états : chaque état décide de la vitesse voulue (move_vel) et des changements
	# d'état ---
	var move_vel := Vector2.ZERO
	match state:
		# IDLE : se promène ; passe en CHASE dès qu'il est alerté
		State.IDLE:
			if alert_time > 0.0:
				state = State.CHASE
			else:
				move_vel = _wander(delta)
		# CHASE : court vers le joueur ; passe en ATTACK à moins de 24 px, retourne en IDLE quand l'alerte
		# est finie
		State.CHASE:
			if alert_time <= 0.0 or not player.alive:
				state = State.IDLE
			elif d < 24.0:
				state = State.ATTACK
			else:
				var target := player.global_position
				# Sans vue directe sur le joueur, il suit le chemin calculé par main.gd pour contourner les murs
				if not sees and level != null:
					target = level.flow_target(global_position, target)
				var dir := (target - global_position).normalized()
				face = face.lerp(dir, 0.25).normalized()
				move_vel = dir * speed
		# ATTACK : s'arrête et frappe quand l'attaque est prête ; repasse en CHASE si le joueur s'éloigne
		# (> 32 px)
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
			# Plus deux zombies sont proches, plus ils se repoussent fort
			sep += off / l * (16.0 - l) * 4.0

	# Le recul diminue progressivement ; la vitesse finale combine déplacement voulu, séparation et
	# recul
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity = move_vel + sep + knock
	move_and_slide()
	# L'animation des bras avance seulement quand le zombie marche
	if move_vel.length() > 1.0:
		shamble += delta * speed / 12.0


## Oriente le corps vers la direction du regard et fait osciller les bras (animation simple faite
## par code).
func _process(_delta: float) -> void:
	visual.rotation = face.angle()
	var sway := sin(shamble) * 1.6
	arm_left.position.y = sway
	arm_right.position.y = -sway


## Retourne vrai si aucun obstacle n'est entre le zombie et la cible.
## On pointe le RayCast2D vers la cible puis on force sa mise à jour immédiate.
func _can_see(target: Vector2) -> bool:
	sight.target_position = sight.to_local(target)
	sight.force_raycast_update()
	return not sight.is_colliding()


## Promenade au hasard : toutes les 1,5 à 4 s, le zombie choisit de rester immobile ou de partir
## dans une direction aléatoire.
## Retourne la vitesse voulue (30 % de la vitesse normale).
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


## Appelé avec call_group("zombies", "hear_noise", ...) quand un bruit est émis (tir, coup,
## explosion).
## Un zombie vivant dans le rayon du bruit est alerté, même sans voir le joueur.
func hear_noise(pos: Vector2, radius: float) -> void:
	if state != State.DEAD and global_position.distance_to(pos) < radius:
		alert_time = maxf(alert_time, 4.0)


## Le zombie reçoit des dégâts : recul, alerte, flash blanc et sang. Il meurt à 0 point de vie.
func take_damage(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	# Repoussé dans la direction du coup
	knock = dir.normalized() * 140.0
	# Être touché alerte le zombie, même s'il ne voyait pas le joueur
	alert_time = 6.0
	if state == State.IDLE:
		state = State.CHASE
	# Flash blanc pendant 0,12 s
	visual.modulate = Color(2, 2, 2)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.12)
	_spawn(blood_hit_scene, global_position, dir)
	_spawn(blood_stain_scene, global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2.RIGHT.rotated(randf() * TAU))
	if hp <= 0.0:
		die()


## Mort du zombie : change d'état, quitte le groupe 'zombies', n'a plus de collision, affiche le
## cadavre et prévient main.gd.
func die() -> void:
	state = State.DEAD
	remove_from_group("zombies")
	# set_deferred : la modification se fait à la fin de l'image (on ne change pas la physique en plein
	# calcul de collision)
	set_deferred("collision_layer", 0)
	alive_visual.hide()
	dead_visual.show()
	z_index = -5   # le cadavre passe sous les vivants
	_spawn(blood_stain_scene, global_position, Vector2.RIGHT.rotated(randf() * TAU))
	died.emit(self)


## Crée un effet visuel (sang) dans la scène du niveau, à la position et avec l'orientation données.
func _spawn(scene: PackedScene, pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	if scene == null:
		return
	var fx := scene.instantiate() as Node2D
	fx.position = pos
	fx.rotation = dir.angle()
	get_parent().add_child(fx)
