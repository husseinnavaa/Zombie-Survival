## Singleton « Game » (Autoload déclaré dans project.godot).
##
## Il reste en mémoire pendant tout le jeu, même quand on change de scène. Il contient :
##   - la liste des niveaux et le niveau actuel ;
##   - les statistiques reportées d'un niveau à l'autre (vie, munitions) ;
##   - le dernier point de sauvegarde ('saved') ;
##   - la sauvegarde dans un fichier JSON (Nouvelle partie / Charger partie) ;
##   - les options (volume, plein écran) ;
##   - le changement de scène avec un fondu au noir.
extends Node

## Les scènes des niveaux, dans l'ordre de la campagne.
const LEVELS := [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]
## Scène du menu principal.
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
## Fichier de sauvegarde de la partie (dossier de données de l'utilisateur).
const SAVE_PATH := "user://save.json"
## Fichier des options.
const OPTIONS_PATH := "user://options.cfg"
## Scène du fondu au noir.
const FADE_SCENE := preload("res://scenes/ui/fade.tscn")

## Indice du niveau en cours dans LEVELS (0 = niveau 1).
var current_level := 0
## Dernier point de sauvegarde atteint dans le niveau en cours (vide s'il n'y en a pas).
var saved: Dictionary = {}
## Statistiques du joueur au début du niveau en cours (hp, mag, reserve). Vide au niveau 1.
var carry: Dictionary = {}
## Total de zombies éliminés dans les niveaux déjà terminés.
var total_kills := 0
## Temps de jeu total (en secondes) des niveaux déjà terminés.
var total_time := 0.0
## Volume général, entre 0.0 et 1.0.
var volume := 0.8
## Vrai si le jeu est en plein écran.
var fullscreen := false

# Le fondu au noir (créé au démarrage) et un verrou pour éviter deux changements de scène en même temps
var fade: Fade
var changing := false


## Au démarrage : crée le fondu, charge les options et les applique.
func _ready() -> void:
	# Le singleton continue de fonctionner même quand le jeu est en pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade = FADE_SCENE.instantiate() as Fade
	add_child(fade)
	_load_options()
	_apply_options()


# ---------- progression dans la campagne ----------

## Démarre une nouvelle partie au niveau 1 (l'ancienne sauvegarde reste dans le fichier tant
## qu'on n'atteint pas un nouveau point de sauvegarde).
func new_game() -> void:
	current_level = 0
	saved = {}
	carry = {}
	total_kills = 0
	total_time = 0.0
	change_scene(LEVELS[0])


## Recommence le niveau en cours (le dernier point de sauvegarde est conservé dans 'saved').
func restart_level() -> void:
	change_scene(LEVELS[current_level])


## Retourne vrai si le niveau en cours est le dernier de la campagne.
func is_last_level() -> bool:
	return current_level >= LEVELS.size() - 1


## Appelé à la fin d'un niveau : ajoute ses statistiques aux totaux et efface le point de sauvegarde.
func finish_level(kills: int, seconds: float) -> void:
	total_kills += kills
	total_time += seconds
	saved = {}


## Passe au niveau suivant en reportant la vie et les munitions du joueur.
## 'stats' est un dictionnaire avec les clés hp, mag et reserve.
func next_level(stats: Dictionary) -> void:
	current_level += 1
	carry = stats
	saved = {}
	# On sauvegarde tout de suite : « Charger partie » reprendra au début de ce niveau
	write_save()
	change_scene(LEVELS[current_level])


## Retourne au menu principal.
func go_to_menu() -> void:
	change_scene(MENU_SCENE)


# ---------- sauvegarde dans un fichier JSON ----------

## Retourne vrai s'il existe un fichier de sauvegarde.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Écrit la partie dans le fichier JSON : niveau, statistiques reportées, totaux et point de sauvegarde.
## Le JSON ne connaît pas Vector2 : la position est enregistrée sous forme de liste [x, y].
func write_save() -> void:
	var data := {
		"level": current_level,
		"carry": carry,
		"total_kills": total_kills,
		"total_time": total_time,
		"checkpoint": {},
	}
	if not saved.is_empty():
		var cp := saved.duplicate()
		var pos: Vector2 = cp["pos"]
		cp["pos"] = [pos.x, pos.y]
		data["checkpoint"] = cp
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Impossible d'écrire la sauvegarde.")
		return
	file.store_string(JSON.stringify(data, "\t"))


## Lit le fichier JSON et reprend la partie. Retourne faux si la sauvegarde est absente ou illisible.
func continue_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	# Un fichier abîmé donne null : on refuse de charger plutôt que de planter
	if typeof(data) != TYPE_DICTIONARY or not data.has("level"):
		return false
	current_level = clampi(int(data["level"]), 0, LEVELS.size() - 1)
	carry = data.get("carry", {})
	total_kills = int(data.get("total_kills", 0))
	total_time = float(data.get("total_time", 0.0))
	saved = {}
	var cp: Dictionary = data.get("checkpoint", {})
	if not cp.is_empty():
		# Le JSON rend des nombres décimaux : on remet les bons types
		var p: Array = cp["pos"]
		cp["pos"] = Vector2(float(p[0]), float(p[1]))
		cp["hp"] = float(cp["hp"])
		cp["mag"] = int(cp["mag"])
		cp["reserve"] = int(cp["reserve"])
		cp["time"] = float(cp["time"])
		saved = cp
	change_scene(LEVELS[current_level])
	return true


# ---------- options ----------

## Règle le volume général (0.0 à 1.0) et l'enregistre.
func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_options()
	_save_options()


## Active ou désactive le plein écran et l'enregistre.
func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_options()
	_save_options()


## Applique le volume (bus audio principal) et le mode de fenêtre.
func _apply_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Enregistre les options dans le fichier de configuration.
func _save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "volume", volume)
	cfg.set_value("options", "fullscreen", fullscreen)
	cfg.save(OPTIONS_PATH)


## Charge les options si le fichier existe (sinon les valeurs par défaut restent).
func _load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS_PATH) == OK:
		volume = float(cfg.get_value("options", "volume", 0.8))
		fullscreen = bool(cfg.get_value("options", "fullscreen", false))


# ---------- changement de scène ----------

## Change de scène avec un fondu au noir : l'écran s'assombrit, la scène change, puis l'écran s'éclaircit.
func change_scene(path: String) -> void:
	# Évite de lancer deux changements de scène en même temps (double-clic sur un bouton)
	if changing:
		return
	changing = true
	await fade.fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# Le changement de scène se fait à la fin de l'image : on attend deux images avant d'éclaircir
	await get_tree().process_frame
	await get_tree().process_frame
	await fade.fade_in()
	changing = false
