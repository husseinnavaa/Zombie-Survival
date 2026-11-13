## Interface du jeu (scène hud.tscn, un CanvasLayer).
##
## Affiche : barres de vie et d'endurance, munitions, clé, objectif, messages, titre du niveau,
## effet de dégâts, et les menus pause, mort et victoire.
## Ce script ne contient aucune logique de jeu : main.gd appelle ses fonctions (set_health,
## toast...)
## quand les signaux du joueur arrivent.
class_name Hud
extends CanvasLayer

## Émis par les boutons de redémarrage. 'from_checkpoint' vaut vrai pour reprendre au dernier point
## de sauvegarde,
## faux pour recommencer le niveau depuis le début.
signal restart_requested(from_checkpoint: bool)

# Références aux nodes de hud.tscn. Le préfixe % désigne un « nom unique » :
# on retrouve le node par son nom, peu importe sa position dans l'arbre.
@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var key_label: Label = %KeyLabel
@onready var crouch_label: Label = %CrouchLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var hint_label: Label = %HintLabel
@onready var toast_label: Label = %ToastLabel
@onready var title_box: Control = %TitleBox
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var hurt_overlay: ColorRect = %HurtOverlay
@onready var pause_menu: Control = %PauseMenu
@onready var game_over_menu: Control = %GameOverMenu
@onready var win_menu: Control = %WinMenu
@onready var win_stats: Label = %WinStats

# Vrai quand un écran de fin (mort ou victoire) est affiché : la pause n'est alors plus possible
var over := false
# Animation du message temporaire en cours (pour l'interrompre si un autre message arrive)
var toast_tween: Tween


## Cache les menus et connecte chaque bouton à son action.
func _ready() -> void:
	pause_menu.hide()
	game_over_menu.hide()
	win_menu.hide()
	toast_label.text = ""
	title_box.modulate.a = 0.0
	# Boutons : Reprendre et Quitter (pause), Recommencer (mort), Rejouer et Quitter (victoire)
	%ResumeButton.pressed.connect(_resume)
	%QuitButton.pressed.connect(_quit)
	%RestartCheckpointButton.pressed.connect(func() -> void: restart_requested.emit(true))
	%RestartLevelButton.pressed.connect(func() -> void: restart_requested.emit(false))
	%QuitButtonOver.pressed.connect(_quit)
	%ReplayButton.pressed.connect(func() -> void: restart_requested.emit(false))
	%QuitButtonWin.pressed.connect(_quit)


## La touche Échap (action ui_cancel) ouvre ou ferme le menu pause, sauf quand un écran de fin est
## affiché.
func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


## Met le jeu en pause et affiche le menu.
func _pause() -> void:
	get_tree().paused = true
	pause_menu.show()
	%ResumeButton.grab_focus()


## Cache le menu et relance le jeu.
func _resume() -> void:
	pause_menu.hide()
	get_tree().paused = false


## Ferme le jeu.
func _quit() -> void:
	get_tree().quit()


# ---------- fonctions appelées par main.gd (via les signaux du joueur et du niveau) ----------

## Met à jour la barre de vie.
func set_health(hp: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp


## Met à jour la barre d'endurance ; elle devient plus terne quand le joueur est épuisé.
func set_stamina(value: float, exhausted: bool) -> void:
	stamina_bar.value = value
	stamina_bar.modulate = Color(0.6, 0.55, 0.3) if exhausted else Color.WHITE


## Affiche « chargeur / réserve », ou « RECHARGE… » pendant un rechargement.
func set_ammo(mag: int, reserve: int, reloading: bool) -> void:
	if reloading:
		ammo_label.text = "RECHARGE…"
	else:
		ammo_label.text = "%d / %d" % [mag, reserve]


## Affiche ou cache l'indicateur « CLÉ ».
func set_key(has_key: bool) -> void:
	key_label.visible = has_key


## Affiche ou cache l'indicateur « ACCROUPI ».
func set_crouch(crouching: bool) -> void:
	crouch_label.visible = crouching


## Texte d'aide d'interaction en bas de l'écran (vide quand rien n'est proche).
func set_hint(text: String) -> void:
	hint_label.text = text


## Texte de l'objectif en haut de l'écran.
func set_objective(text: String) -> void:
	objective_label.text = text


## Affiche un message temporaire au centre : visible 1,8 s puis disparaît en fondu (0,7 s).
func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	# Si un message précédent est encore en train de disparaître, on arrête son animation
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.7)


## Éclair rouge sur tout l'écran quand le joueur est blessé : l'opacité passe de 0,3 à 0 en 0,3 s.
func flash_hurt() -> void:
	hurt_overlay.color.a = 0.3
	create_tween().tween_property(hurt_overlay, "color:a", 0.0, 0.3)


## Affiche le titre du niveau, puis le fait disparaître en fondu après 3,5 s.
func show_title(title: String, subtitle: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	title_box.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(title_box, "modulate:a", 0.0, 1.0)


## Affiche l'écran de mort ; 'over' empêche d'ouvrir le menu pause.
func show_game_over() -> void:
	over = true
	game_over_menu.show()
	%RestartCheckpointButton.grab_focus()


## Affiche l'écran de victoire avec le nombre de zombies tués et le temps (minutes:secondes).
func show_win(kills: int, seconds: float) -> void:
	over = true
	# Conversion en minutes (s / 60) et secondes (s % 60)
	var s := int(seconds)
	win_stats.text = "Zombies éliminés : %d   |   Temps : %d:%02d" % [kills, s / 60, s % 60]
	win_menu.show()
	%ReplayButton.grab_focus()
