## Interface du jeu (scène hud.tscn, un CanvasLayer).
##
## Affiche : barres de vie et d'endurance, munitions, clé, objectif, messages, titre du niveau,
## effet de dégâts, barre de vie du boss, et les menus pause (avec inventaire et options), mort et
## victoire.
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
@onready var win_title: Label = %WinTitle
@onready var boss_box: Control = %BossBox
@onready var boss_name: Label = %BossName
@onready var boss_bar: ProgressBar = %BossBar
@onready var inventory_panel: Control = %InventoryPanel
@onready var inventory_text: Label = %InventoryText
@onready var options_panel: OptionsPanel = %OptionsPanel

# Vrai quand un écran de fin (mort ou victoire) est affiché : la pause n'est alors plus possible
var over := false
# Animation du message temporaire en cours (pour l'interrompre si un autre message arrive)
var toast_tween: Tween
# Le joueur, lu par l'inventaire du menu pause (voir bind_player)
var player_ref: Player
# Vrai quand l'écran de victoire est celui de la fin de la campagne
var final_win := false


## Cache les menus et connecte chaque bouton à son action.
func _ready() -> void:
	pause_menu.hide()
	game_over_menu.hide()
	win_menu.hide()
	boss_box.hide()
	inventory_panel.hide()
	toast_label.text = ""
	title_box.modulate.a = 0.0
	# Boutons : Reprendre, Inventaire, Options et Quitter (pause), Recommencer (mort), Rejouer et Quitter
	# (victoire)
	%ResumeButton.pressed.connect(_resume)
	%InventoryButton.pressed.connect(_open_inventory)
	%OptionsButton.pressed.connect(_open_options)
	%InventoryBackButton.pressed.connect(_close_inventory)
	options_panel.closed.connect(func() -> void: %OptionsButton.grab_focus())
	%QuitButton.pressed.connect(_quit)
	%RestartCheckpointButton.pressed.connect(func() -> void: restart_requested.emit(true))
	%RestartLevelButton.pressed.connect(func() -> void: restart_requested.emit(false))
	%QuitButtonOver.pressed.connect(_quit)
	%ReplayButton.pressed.connect(_on_replay)
	%QuitButtonWin.pressed.connect(_quit)


## La touche Échap (action ui_cancel) ouvre ou ferme le menu pause, sauf quand un écran de fin est
## affiché.
func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event.is_action_pressed("ui_cancel"):
		# Échap ferme d'abord l'inventaire ou les options s'ils sont ouverts
		if inventory_panel.visible:
			_close_inventory()
		elif options_panel.visible:
			options_panel.close()
		elif get_tree().paused:
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


## Retourne au menu principal (le singleton Game fait le changement de scène avec un fondu).
func _quit() -> void:
	Game.go_to_menu()


## Bouton « Rejouer » de l'écran de victoire : recommence le niveau, ou toute la campagne si c'était la
## fin du jeu.
func _on_replay() -> void:
	if final_win:
		Game.new_game()
	else:
		restart_requested.emit(false)


## Mémorise le joueur pour pouvoir afficher son inventaire dans le menu pause.
func bind_player(p: Player) -> void:
	player_ref = p


## Affiche l'inventaire : vie, munitions, clé et endurance du joueur.
func _open_inventory() -> void:
	if player_ref != null:
		inventory_text.text = "Vie : %d / %d\nChargeur : %d   |   Réserve : %d\nClé de la porte : %s" % [
			int(player_ref.hp), int(player_ref.max_hp), player_ref.mag, player_ref.reserve,
			"oui" if player_ref.has_key else "non"]
	inventory_panel.show()
	%InventoryBackButton.grab_focus()


## Cache l'inventaire.
func _close_inventory() -> void:
	inventory_panel.hide()
	%InventoryButton.grab_focus()


## Ouvre le panneau des options (le même que dans le menu principal).
func _open_options() -> void:
	options_panel.open()


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


## Affiche la barre de vie du boss en haut de l'écran.
func show_boss(boss_title: String, hp: float, max_hp: float) -> void:
	boss_name.text = boss_title
	boss_bar.max_value = max_hp
	boss_bar.value = hp
	boss_box.show()


## Met à jour la barre de vie du boss.
func set_boss_health(hp: float, max_hp: float) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = hp


## Cache la barre de vie du boss (il est mort).
func hide_boss() -> void:
	boss_box.hide()


## Affiche l'écran de victoire avec le nombre de zombies tués et le temps (minutes:secondes).
## Si 'final' est vrai, c'est la fin de la campagne : le titre et le bouton changent.
func show_win(kills: int, seconds: float, final := false) -> void:
	over = true
	final_win = final
	if final:
		win_title.text = "VOUS AVEZ SURVÉCU !"
		%ReplayButton.text = "Rejouer la campagne"
	# Conversion en minutes (s / 60) et secondes (s % 60)
	var s := int(seconds)
	win_stats.text = "Zombies éliminés : %d   |   Temps : %d:%02d" % [kills, s / 60, s % 60]
	win_menu.show()
	%ReplayButton.grab_focus()
