## Script commun à tous les niveaux (level_1.tscn, level_2.tscn, level_3.tscn).
##
## Chaque niveau est construit directement avec des nodes : CanvasModulate (obscurité), Sol, Murs,
## Porte, Caisses, Barils, Points de sauvegarde, Sortie, Zombies, Joueur et HUD. Le niveau 3 contient
## aussi le boss Le Boucher.
##
## Ce script :
##   - relie les nodes entre eux grâce aux signaux (joueur -> HUD, zombies, barils, porte...) ;
##   - calcule le chemin des zombies autour des obstacles ;
##   - gère la sauvegarde aux points de contrôle, la mort, le boss et le passage au niveau suivant.
class_name Main
extends Node2D

# Taille d'une case de la grille du niveau, en pixels
const TILE := 32
# Les 4 directions (droite, gauche, bas, haut) utilisées pour explorer la grille
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Dernier point de sauvegarde. Il est stocké dans le singleton Game (qui survit au rechargement de la
# scène) ; cette propriété sert de raccourci pour écrire simplement 'saved' dans ce script.
var saved: Dictionary:
	get:
		return Game.saved
	set(value):
		Game.saved = value

## Titre affiché au début du niveau.
@export var title := "CHAPITRE 1 — LA BANLIEUE"
## Sous-titre affiché sous le titre.
@export var subtitle := "Niveau 1 : trouver la clé et rejoindre la zone d'évacuation"
## Taille du niveau en cases (largeur, hauteur) : sert à limiter la caméra et au calcul du chemin.
@export var grid_size := Vector2i(40, 20)

# Temps de jeu en secondes (affiché à la victoire)
var time_played := 0.0
# Noms des zombies tués (pour la sauvegarde et le score)
var killed: Array = []
# Noms des barils détruits (pour la sauvegarde)
var destroyed: Array = []
# Vrai une fois le niveau terminé (évite de le terminer deux fois)
var finished := false
# La porte verrouillée du niveau
var door: Door
# Le boss du niveau (null s'il n'y en a pas) et vrai tant qu'il est vivant
# (pas de type : le script du boss, boucher.gd, arrive dans une tâche plus tard)
var boss
var boss_alive := false
# Vrai quand la barre de vie du boss est déjà affichée
var boss_intro_done := false
# Cases bloquées par des murs (Vector2i -> true) : calculées une seule fois au démarrage
var static_blocked := {}
# Champ de distance : pour chaque case accessible, nombre de pas jusqu'au joueur
var dist := {}
# Compte à rebours avant le prochain recalcul du champ de distance
var dist_timer := 0.0

# Le joueur et le HUD sont des nodes enfants de Main (leurs noms sont en français dans main.tscn)
@onready var player: Player = $Joueur
@onready var hud: Hud = $HUD


## Initialise le niveau : repère les murs, connecte les signaux, applique la sauvegarde s'il y en a
## une, puis configure le HUD.
func _ready() -> void:
	# Groupe 'level' : les zombies s'en servent pour retrouver ce script
	add_to_group("level")
	# On retrouve le numéro du niveau grâce au chemin de la scène (pratique pour tester avec F6)
	var index: int = Game.LEVELS.find(scene_file_path)
	if index >= 0:
		Game.current_level = index
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	# La caméra ne dépasse pas les bords du niveau
	player.set_camera_limits(grid_size * TILE)

	# Mémorise la case de chaque mur : ces cases seront interdites dans le calcul du chemin
	for w in get_tree().get_nodes_in_group("wall"):
		static_blocked[cell_of((w as Node2D).global_position)] = true

	# --- Connexions par signaux : chaque objet prévient main.gd quand il se passe quelque chose ---
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
		(ex as ExitZone).blocked.connect(_on_exit_blocked)

	# Si le joueur avait atteint un point de sauvegarde de CE niveau avant de mourir, on reprend là.
	# Sinon : on garde la vie et les munitions du niveau précédent (s'il y en a).
	if not saved.is_empty() and int(saved.get("level", -1)) == Game.current_level:
		_apply_checkpoint()
	else:
		saved = {}
		if not Game.carry.is_empty():
			player.restore(float(Game.carry["hp"]), int(Game.carry["mag"]), int(Game.carry["reserve"]), false)

	# Boss : on branche sa barre de vie et on verrouille la sortie tant qu'il est vivant
	boss = get_tree().get_first_node_in_group("boss")
	if boss != null and not (str(boss.name) in killed):
		boss_alive = true
		boss.health_changed.connect(hud.set_boss_health)
		boss.died.connect(_on_boss_died)
		for ex in get_tree().get_nodes_in_group("exit"):
			(ex as ExitZone).locked = true

	# Le joueur parle au HUD par signaux
	player.health_changed.connect(hud.set_health)
	player.stamina_changed.connect(hud.set_stamina)
	player.ammo_changed.connect(hud.set_ammo)
	player.key_changed.connect(hud.set_key)
	# Quand le joueur prend la clé, le texte de l'objectif change
	player.key_changed.connect(func(_has_key: bool) -> void: refresh_objective())
	player.crouch_changed.connect(hud.set_crouch)
	player.hint_changed.connect(hud.set_hint)
	player.message.connect(hud.toast)
	player.hurt.connect(hud.flash_hurt)
	player.died.connect(_on_player_died)
	hud.restart_requested.connect(_on_restart_requested)
	# Le HUD lit le joueur pour afficher l'inventaire du menu pause
	hud.bind_player(player)

	# Dernières étapes : titre du niveau, état initial du HUD, objectif et chemin des zombies
	hud.show_title(title, subtitle)
	player.emit_state()
	refresh_objective()
	_update_dist()


## Fait avancer le chronomètre de la partie.
func _process(delta: float) -> void:
	time_played += delta
	# Le boss présente sa barre de vie quand le joueur s'approche
	if boss_alive and not boss_intro_done and player.global_position.distance_to(boss.global_position) < 420.0:
		boss_intro_done = true
		hud.show_boss("LE BOUCHER", boss.hp, boss.max_hp)
		hud.toast("Le Boucher vous a repéré !")
		player.add_shake(5.0)


## Recalcule le champ de distance toutes les 0,3 s (pas à chaque image, pour économiser du travail).
func _physics_process(delta: float) -> void:
	dist_timer -= delta
	if dist_timer <= 0.0:
		dist_timer = 0.3
		_update_dist()


## Choisit le texte de l'objectif selon la progression : trouver la clé, ouvrir la porte, éliminer le
## boss s'il y en a un, puis atteindre la sortie.
func refresh_objective() -> void:
	var text := "Objectif : atteindre la zone d'évacuation"
	if door != null and not door.used:
		if player.has_key:
			text = "Objectif : ouvrir la porte verrouillée"
		else:
			text = "Objectif : trouver la clé de la porte verrouillée"
	elif boss_alive:
		text = "Objectif : éliminer Le Boucher"
	hud.set_objective(text)


# ---------- chemin des zombies (champ de distance vers le joueur) ----------

## Convertit une position en pixels en coordonnées de case (colonne, ligne) de la grille.
func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE), int(pos.y / TILE))


## Calcule le champ de distance par parcours en largeur (BFS) à partir de la case du joueur :
## chaque case accessible reçoit le nombre de pas qui la sépare du joueur.
## Les murs, caisses, barils et la porte fermée sont des obstacles.
func _update_dist() -> void:
	dist.clear()
	# On part des murs fixes, puis on ajoute les obstacles qui peuvent changer (caisses, barils, porte
	# fermée)
	var blocked := static_blocked.duplicate()
	for n in get_tree().get_nodes_in_group("dynamic_obstacle"):
		blocked[cell_of((n as Node2D).global_position)] = true
	# Le parcours commence sur la case du joueur (distance 0)
	var start := cell_of(player.global_position)
	var queue: Array[Vector2i] = [start]
	dist[start] = 0
	var i := 0
	# BFS : on explore la grille case par case, en s'éloignant du joueur
	while i < queue.size():
		var c := queue[i]
		i += 1
		for off in DIRS:
			var n2: Vector2i = c + off
			# Ignore les cases hors de la grille
			if n2.x < 0 or n2.y < 0 or n2.x >= grid_size.x or n2.y >= grid_size.y:
				continue
			# Ignore les cases déjà visitées ou bloquées
			if dist.has(n2) or blocked.has(n2):
				continue
			# Une case de plus que la voisine dont on vient
			dist[n2] = int(dist[c]) + 1
			queue.append(n2)


## Donne au zombie le prochain point à viser pour contourner les obstacles : parmi les 4 cases
## voisines,
## celle qui est la plus proche du joueur. Retourne le centre de cette case, ou 'fallback' (la
## position du joueur)
## si le zombie n'est pas sur une case connue.
func flow_target(pos: Vector2, fallback: Vector2) -> Vector2:
	var c := cell_of(pos)
	if not dist.has(c):
		return fallback
	# On cherche, parmi les 4 voisines, la case la plus proche du joueur
	var best := c
	var best_d: int = dist[c]
	for off in DIRS:
		var n: Vector2i = c + off
		if dist.has(n) and int(dist[n]) < best_d:
			best_d = dist[n]
			best = n
	if best == c:
		return fallback
	# Centre de la case choisie, en pixels
	return Vector2(best.x * TILE + TILE * 0.5, best.y * TILE + TILE * 0.5)


# ---------- événements ----------

## Un zombie est mort : on retient son nom (pour la sauvegarde et le score).
func _on_zombie_died(z: Zombie) -> void:
	killed.append(str(z.name))


## Un baril a explosé : on retient son nom pour la sauvegarde.
func _on_barrel_destroyed(b: Barrel) -> void:
	destroyed.append(str(b.name))


## Le joueur est mort : affiche l'écran de mort et met le jeu en pause.
func _on_player_died() -> void:
	hud.show_game_over()
	get_tree().paused = true


## Le boss est mort : on déverrouille la sortie et on cache sa barre de vie.
func _on_boss_died(_z: Zombie) -> void:
	boss_alive = false
	hud.hide_boss()
	hud.toast("Le Boucher est mort ! La sortie est ouverte.")
	refresh_objective()
	player.add_shake(6.0)
	for ex in get_tree().get_nodes_in_group("exit"):
		(ex as ExitZone).unlock()


## Le joueur touche la sortie alors qu'elle est verrouillée.
func _on_exit_blocked() -> void:
	hud.toast("Sortie verrouillée : éliminez Le Boucher !")


## Le joueur a atteint la sortie. Dernier niveau : écran de victoire avec les totaux de la campagne.
## Sinon : on passe au niveau suivant en gardant la vie et les munitions du joueur.
func _on_exit() -> void:
	if finished:
		return
	finished = true
	# Les statistiques du niveau s'ajoutent aux totaux ; le point de sauvegarde est effacé
	Game.finish_level(killed.size(), time_played)
	if Game.is_last_level():
		hud.show_win(Game.total_kills, Game.total_time, true)
		get_tree().paused = true
	else:
		hud.toast("Niveau terminé !")
		# Le jeu se fige pendant le fondu au noir (les zombies ne peuvent plus attaquer)
		get_tree().paused = true
		Game.next_level({"hp": player.hp, "mag": player.mag, "reserve": player.reserve})


## Appelé par les boutons du HUD. 'from_checkpoint' vaut vrai pour reprendre au dernier point de
## sauvegarde,
## faux pour recommencer le niveau depuis le début.
func _on_restart_requested(from_checkpoint: bool) -> void:
	if not from_checkpoint:
		saved.clear()
	# Recharge le niveau avec un fondu ; 'saved' est dans Game, donc il survit au rechargement
	Game.restart_level()


# ---------- points de sauvegarde ----------

## Un point de sauvegarde a été touché : enregistre l'état de la partie dans le dictionnaire
## 'saved'.
func _on_checkpoint(cp: Checkpoint) -> void:
	# Liste des objets déjà utilisés (caisses fouillées, porte ouverte, points activés) : tous sont
	# dans le groupe 'stateful'
	var used_names: Array = []
	for n in get_tree().get_nodes_in_group("stateful"):
		if n.used:
			used_names.append(str(n.name))
	# La sauvegarde est un dictionnaire : position, vie, munitions, clé, zombies tués, barils détruits,
	# objets utilisés, temps
	saved = {
		"level": Game.current_level,
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
	# Sauvegarde aussi dans le fichier JSON pour pouvoir « Charger partie » plus tard
	Game.write_save()
	hud.toast("Point de sauvegarde")


## Restaure la partie depuis 'saved' après un rechargement de la scène : replace le joueur, rétablit
## ses stats,
## supprime les zombies tués et les barils détruits, et remet les objets dans leur état.
func _apply_checkpoint() -> void:
	# Replace le joueur au point de sauvegarde et rétablit ses statistiques
	player.global_position = saved["pos"]
	player.restore(saved["hp"], saved["mag"], saved["reserve"], saved["key"])
	killed = saved["killed"].duplicate()
	destroyed = saved["destroyed"].duplicate()
	time_played = saved["time"]
	# Supprime les zombies déjà tués
	for z in get_tree().get_nodes_in_group("zombies"):
		if str(z.name) in killed:
			z.queue_free()
	# Supprime les barils déjà détruits
	for b in get_tree().get_nodes_in_group("barrels"):
		if str(b.name) in destroyed:
			b.queue_free()
	# Remet les caisses, la porte et les points de sauvegarde dans leur état sauvegardé
	for n in get_tree().get_nodes_in_group("stateful"):
		if str(n.name) in saved["used"]:
			n.restore_used()
