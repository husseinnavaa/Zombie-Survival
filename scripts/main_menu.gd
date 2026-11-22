## Menu principal (scène main_menu.tscn) : première scène lancée par le jeu.
## Options : Nouvelle partie, Charger partie, Options, Crédits, Quitter.
extends Control

# Panneaux secondaires, affichés par-dessus le menu
@onready var options_panel: OptionsPanel = %OptionsPanel
@onready var credits_panel: Control = %CreditsPanel
@onready var menu_box: Control = %MenuBox
@onready var continue_button: Button = %ContinueButton


## Branche les boutons. « Charger partie » est grisé s'il n'y a pas de sauvegarde.
func _ready() -> void:
	# Le niveau met le curseur en croix : dans le menu on remet la flèche normale
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().paused = false
	credits_panel.hide()
	continue_button.disabled = not Game.has_save()
	%NewGameButton.pressed.connect(func() -> void: Game.new_game())
	continue_button.pressed.connect(_on_continue)
	%OptionsButton.pressed.connect(_on_options)
	%CreditsButton.pressed.connect(_on_credits)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	%CreditsBackButton.pressed.connect(_close_credits)
	options_panel.closed.connect(_on_options_closed)
	%NewGameButton.grab_focus()
	_pulse_title()


## Reprend la partie enregistrée. Si le fichier est illisible, on grise le bouton.
func _on_continue() -> void:
	if not Game.continue_game():
		continue_button.disabled = true


## Ouvre le panneau des options.
func _on_options() -> void:
	menu_box.hide()
	options_panel.open()


## Retour des options : on réaffiche le menu.
func _on_options_closed() -> void:
	menu_box.show()
	%OptionsButton.grab_focus()


## Ouvre les crédits.
func _on_credits() -> void:
	menu_box.hide()
	credits_panel.show()
	%CreditsBackButton.grab_focus()


## Ferme les crédits.
func _close_credits() -> void:
	credits_panel.hide()
	menu_box.show()
	%CreditsButton.grab_focus()


## Effet visuel : le titre pulse doucement (animation en boucle faite avec un Tween).
func _pulse_title() -> void:
	var title: Label = %TitleLabel
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1.0, 0.55, 0.55), 1.4)
	tw.tween_property(title, "modulate", Color.WHITE, 1.4)
