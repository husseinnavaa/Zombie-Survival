## Panneau des options (scène options_panel.tscn), utilisé dans le menu principal et dans le menu pause.
## Il règle le volume et le plein écran grâce au singleton Game, qui enregistre les choix.
class_name OptionsPanel
extends Control

## Émis quand le joueur ferme le panneau avec le bouton Retour.
signal closed

# Références aux nodes du panneau (noms uniques avec %)
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck


## Cache le panneau et branche les contrôles.
func _ready() -> void:
	hide()
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	%BackButton.pressed.connect(close)


## Affiche le panneau avec les valeurs actuelles des options.
func open() -> void:
	# On règle les contrôles AVANT d'afficher : set_value_no_signal évite de réenregistrer les options
	volume_slider.set_value_no_signal(Game.volume * 100.0)
	fullscreen_check.set_pressed_no_signal(Game.fullscreen)
	show()
	%BackButton.grab_focus()


## Cache le panneau et prévient celui qui l'a ouvert.
func close() -> void:
	hide()
	closed.emit()


## Le curseur va de 0 à 100 ; Game attend une valeur de 0.0 à 1.0.
func _on_volume_changed(value: float) -> void:
	Game.set_volume(value / 100.0)


## Active ou désactive le plein écran.
func _on_fullscreen_toggled(pressed: bool) -> void:
	Game.set_fullscreen(pressed)
