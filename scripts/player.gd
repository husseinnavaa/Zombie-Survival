## Joueur (scène player.tscn).
##
## Ce script ne contient que la LOGIQUE du joueur : déplacement, visée, endurance, tir,
## rechargement, corps à corps, interaction (touche E) et points de vie.
## Les éléments visuels (formes, lumières, caméra, minuteurs, zones de détection) sont des
## nodes enfants définis dans la scène.
##
## Le joueur ne connaît pas le HUD : il émet des SIGNAUX (health_changed, ammo_changed...)
## et c'est main.gd qui les relie à l'interface.
class_name Player
extends CharacterBody2D

## Émis quand les points de vie tombent à 0.
signal died
## Émis à chaque dégât reçu (sert à l'éclair rouge à l'écran).
signal hurt
## Émis quand les points de vie changent (barre de vie).
signal health_changed(hp: float, max_hp: float)
## Émis quand l'endurance change. 'exhausted' vaut vrai quand le joueur est épuisé et ne peut plus
## courir.
signal stamina_changed(value: float, exhausted: bool)
## Émis quand le chargeur ou la réserve change, ou quand un rechargement commence.
signal ammo_changed(mag: int, reserve: int, reloading: bool)
## Émis quand le joueur obtient la clé.
signal key_changed(has_key: bool)
## Émis quand le joueur s'accroupit ou se relève.
signal crouch_changed(crouching: bool)
## Texte d'aide d'interaction affiché en bas de l'écran (ex. « E — Fouiller la caisse »).
signal hint_changed(text: String)
## Message temporaire à afficher à l'écran (ex. « Clé trouvée ! »).
signal message(text: String)

# --- Paramètres réglables dans l'inspecteur de Godot ---
## Vitesse de marche, en pixels par seconde.
@export var walk_speed := 105.0
## Vitesse de course (touche Maj) : consomme de l'endurance.
@export var run_speed := 175.0
## Vitesse accroupie (Ctrl ou C) : lente, mais les zombies te repèrent de moins loin.
@export var crouch_speed := 55.0
## Points de vie maximum.
@export var max_hp := 100.0
## Taille du chargeur.
@export var mag_size := 12
## Munitions de réserve au début du niveau.
@export var start_reserve := 24
## Scène de la balle (bullet.tscn).
@export var bullet_scene: PackedScene
## Effet de flammes au bout du canon quand on tire.
@export var muzzle_flash_scene: PackedScene
## Effet de sang quand le joueur est blessé.
@export var blood_hit_scene: PackedScene

# --- État actuel du joueur (change pendant la partie) ---
# Points de vie actuels
var hp := 100.0
# Endurance actuelle (de 0 à 100)
var stamina := 100.0
# Vrai quand l'endurance est tombée à 0 : on ne peut plus courir tant qu'elle n'est pas remontée à
# 30
var exhausted := false
# Délai (en secondes) avant que l'endurance recommence à remonter
var stamina_delay := 0.0
# Balles dans le chargeur
var mag := 12
# Balles de réserve
var reserve := 24
# Vrai si le joueur possède la clé de la porte
var has_key := false
# Vrai quand le joueur est accroupi
var crouching := false
# Vrai quand le joueur court réellement (Maj + endurance disponible)
var running := false
# Lampe torche allumée ou éteinte (touche F)
var flashlight_on := true
# Devient faux à la mort : plus aucune action possible
var alive := true
# Direction de visée (vecteur de longueur 1 vers la souris)
var aim := Vector2.RIGHT
# Intensité de la secousse de caméra (diminue avec le temps)
var shake := 0.0
# Texte d'aide d'interaction actuellement affiché
var hint := ""

# Références aux nodes enfants de player.tscn, récupérées au démarrage grâce à @onready.
# 'Visual' contient tout ce qui tourne avec la visée : corps, lampe torche, zone de coup, point de
# tir.
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


## Initialise la vie et les munitions, et branche la fin du rechargement sur le Timer.
func _ready() -> void:
	hp = max_hp
	mag = mag_size
	reserve = start_reserve
	reload_timer.timeout.connect(_finish_reload)


## Envoie l'état complet du joueur aux écouteurs (HUD).
## Appelé par main.gd une fois les signaux connectés, pour que l'interface affiche les bonnes
## valeurs dès le départ.
func emit_state() -> void:
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, exhausted)
	ammo_changed.emit(mag, reserve, not reload_timer.is_stopped())
	key_changed.emit(has_key)
	crouch_changed.emit(crouching)
	hint_changed.emit(hint)


## Empêche la caméra de sortir du niveau. 'size' est la taille du niveau en pixels.
func set_camera_limits(size: Vector2i) -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size.x
	camera.limit_bottom = size.y


## Appelé à chaque image physique : visée, déplacement, course, accroupi et endurance.
func _physics_process(delta: float) -> void:
	# Mort : le joueur ne bouge plus
	if not alive:
		velocity = Vector2.ZERO
		return

	# --- Visée : direction du joueur vers la souris ---
	var to_mouse := get_global_mouse_position() - global_position
	# On ignore la souris quand elle est presque sur le joueur (évite une direction instable)
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()
	# Tourne le corps, la lampe et la zone de coup vers la souris
	visual.rotation = aim.angle()

	# --- Déplacement : get_vector combine les 4 touches (actions de la Map des entrées) en un seul
	# vecteur ---
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- Accroupi : on n'émet le signal que lorsque l'état change ---
	var now_crouching := Input.is_action_pressed("crouch")
	if now_crouching != crouching:
		crouching = now_crouching
		crouch_changed.emit(crouching)
		visual.scale = Vector2(0.9, 0.9) if crouching else Vector2.ONE

	# --- Course : il faut appuyer sur Maj, bouger, ne pas être accroupi et ne pas être épuisé ---
	var wants_run := Input.is_action_pressed("sprint") and dir != Vector2.ZERO and not crouching
	running = wants_run and not exhausted and stamina > 0.0

	# --- Choix de la vitesse selon l'état ---
	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed
	# Recharger ralentit un peu le joueur (-15 %)
	if not reload_timer.is_stopped():
		speed *= 0.85

	# --- Application du mouvement : move_and_slide gère les collisions avec les murs ---
	_update_stamina(delta)
	velocity = dir * speed
	move_and_slide()
	# Met à jour le texte d'aide si un objet interactif est proche
	_update_hint()


## Appelé à chaque image : applique la secousse de caméra (qui diminue avec le temps).
func _process(delta: float) -> void:
	shake = maxf(0.0, shake - 30.0 * delta)
	# Décale la caméra au hasard, proportionnellement à 'shake'
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake


## Gère l'endurance : elle baisse en courant et remonte après 1 seconde sans courir.
## Si elle tombe à 0, le joueur est épuisé jusqu'à ce qu'elle remonte à 30.
func _update_stamina(delta: float) -> void:
	# On garde l'ancienne valeur pour n'émettre le signal que si elle a changé
	var old := stamina
	if running:
		# En courant : -28 par seconde
		stamina = maxf(0.0, stamina - 28.0 * delta)
		stamina_delay = 1.0
		if stamina <= 0.0:
			# Plus d'endurance : le joueur est épuisé
			exhausted = true
	else:
		stamina_delay = maxf(0.0, stamina_delay - delta)
		if stamina_delay <= 0.0:
			# Récupération : +18 par seconde
			stamina = minf(100.0, stamina + 18.0 * delta)
		# Il faut remonter à 30 pour pouvoir courir de nouveau
		if exhausted and stamina >= 30.0:
			exhausted = false
	if stamina != old:
		stamina_changed.emit(stamina, exhausted)


# ---------- interaction ----------

## Retourne l'objet interactif (caisse, porte...) le plus proche dans la zone d'interaction, ou null
## s'il n'y en a pas.
## Seuls les nodes du groupe 'interactable' qui ne sont pas encore utilisés comptent.
func _find_interactable() -> Node:
	var best: Node = null
	# Distance maximale d'interaction (en pixels)
	var best_d := 50.0
	for body in interact_area.get_overlapping_bodies():
		if not body.is_in_group("interactable") or body.used:
			continue
		var d := global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


## Demande à l'objet le plus proche son texte d'aide et le signale au HUD seulement s'il a changé.
func _update_hint() -> void:
	var target := _find_interactable()
	var text := ""
	if target != null:
		text = target.get_hint(self)
	if text != hint:
		hint = text
		hint_changed.emit(hint)


## Gère les touches ponctuelles : tir, coup, recharge, lampe et interaction.
## _unhandled_input ne reçoit que les événements non consommés par l'interface.
func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	# Les actions (shoot, melee, reload...) sont définies dans la Map des entrées du projet
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
		# Touche E : interagit avec l'objet le plus proche (la caisse ou la porte gère elle-même ce qui se
		# passe)
		var target := _find_interactable()
		if target != null:
			target.interact(self)


# ---------- combat ----------

## Clic gauche : tire s'il reste des balles dans le chargeur, sinon lance un rechargement,
## et sans aucune munition donne un coup au corps à corps.
## Rien ne se passe pendant un rechargement ou entre deux tirs.
func _attack_primary() -> void:
	if not reload_timer.is_stopped() or not fire_timer.is_stopped():
		return
	if mag > 0:
		_shoot()
	elif reserve > 0:
		start_reload()
	else:
		melee()   # plus de munitions : coup au corps à corps


## Tire une balle : retire une balle du chargeur, crée la balle (bullet.tscn), joue l'effet du
## canon,
## secoue la caméra et fait du bruit qui alerte les zombies proches.
func _shoot() -> void:
	mag -= 1
	# Délai entre deux tirs (FireTimer)
	fire_timer.start()
	# Légère imprécision aléatoire de la visée (environ 2 degrés)
	var d := aim.rotated(randf_range(-0.04, 0.04))
	# La balle est ajoutée à la scène du niveau (le parent du joueur), pas à l'intérieur du joueur
	var b := bullet_scene.instantiate() as Bullet
	b.direction = d
	b.rotation = d.angle()
	b.position = muzzle.global_position
	get_parent().add_child(b)
	_spawn_fx(muzzle_flash_scene, muzzle.global_position, d)
	add_shake(1.5)
	# Le tir fait du bruit : les zombies à moins de 350 pixels sont alertés
	get_tree().call_group("zombies", "hear_noise", global_position, 350.0)
	ammo_changed.emit(mag, reserve, false)


## Coup au corps à corps (clic droit) : blesse les zombies dans la zone MeleeArea, devant le joueur.
## Fait moins de bruit qu'un tir.
func melee() -> void:
	# Impossible de frapper si on est mort ou pendant le délai entre deux coups
	if not alive or not melee_timer.is_stopped():
		return
	melee_timer.start()
	get_tree().call_group("zombies", "hear_noise", global_position, 120.0)
	swing_fx.visible = true
	# Chaque zombie dans la zone de coup reçoit 35 dégâts et est repoussé dans la direction de visée
	for body in melee_area.get_overlapping_bodies():
		if body.is_in_group("zombies"):
			body.take_damage(35.0, aim)
	# L'éclair blanc du coup reste visible 0,15 seconde
	await get_tree().create_timer(0.15).timeout
	swing_fx.visible = false


## Lance le rechargement (1,3 s, ReloadTimer) s'il est possible : pas déjà en cours, chargeur non
## plein et réserve non vide.
func start_reload() -> void:
	if not reload_timer.is_stopped() or mag >= mag_size or reserve <= 0:
		return
	reload_timer.start()
	ammo_changed.emit(mag, reserve, true)


## Appelé à la fin du ReloadTimer : transfère les balles de la réserve vers le chargeur.
func _finish_reload() -> void:
	var take := mini(mag_size - mag, reserve)
	mag += take
	reserve -= take
	ammo_changed.emit(mag, reserve, false)


## Le joueur reçoit des dégâts (appelé par les zombies et les explosions).
## Déclenche la secousse, le sang et le flash rouge ; émet 'died' si les points de vie tombent à 0.
func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	add_shake(4.0)
	_spawn_fx(blood_hit_scene, global_position)
	# Flash rouge : le corps devient rouge puis retrouve sa couleur normale en 0,25 s
	visual.modulate = Color(1.7, 0.6, 0.6)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.25)
	hurt.emit()
	# Mort : on bloque les actions (alive = false) et on prévient main.gd avec le signal 'died'
	if hp <= 0.0:
		hp = 0.0
		alive = false
		health_changed.emit(hp, max_hp)
		died.emit()
		return
	health_changed.emit(hp, max_hp)


## Déclenche une secousse de caméra ; on garde la plus forte si plusieurs arrivent en même temps.
func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


# ---------- objets ramassés ----------

## Soigne le joueur (sans dépasser le maximum) et affiche un message.
func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	message.emit("Trousse de soins : +%d PV" % int(amount))


## Ajoute des balles à la réserve et affiche un message.
func add_ammo(count: int) -> void:
	reserve += count
	ammo_changed.emit(mag, reserve, not reload_timer.is_stopped())
	message.emit("+%d munitions" % count)


## Donne la clé de la porte au joueur.
func give_key() -> void:
	has_key = true
	key_changed.emit(true)
	message.emit("Clé trouvée !")


## Rétablit l'état du joueur depuis la sauvegarde du dernier point de contrôle (utilisé par
## main.gd).
## Garantit au moins 40 PV et 12 balles de réserve pour ne pas boucler dans la mort.
func restore(new_hp: float, new_mag: int, new_reserve: int, new_key: bool) -> void:
	hp = maxf(new_hp, 40.0)   # filet de sécurité contre les boucles de mort
	mag = new_mag
	reserve = maxi(new_reserve, 12)
	has_key = new_key
	camera.reset_smoothing()
	emit_state()


## Crée un effet visuel (particules) à la position donnée, dans la scène du niveau. Ne fait rien si
## l'effet n'est pas défini.
func _spawn_fx(scene: PackedScene, pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	if scene == null:
		return
	var fx := scene.instantiate() as Node2D
	fx.position = pos
	fx.rotation = dir.angle()
	get_parent().add_child(fx)
