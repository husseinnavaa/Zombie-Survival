class_name Hud
extends CanvasLayer
# Interface : tous les éléments sont des nodes Control dans hud.tscn.

signal restart_requested(from_checkpoint: bool)

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

var over := false
var toast_tween: Tween


func _ready() -> void:
	pause_menu.hide()
	game_over_menu.hide()
	win_menu.hide()
	toast_label.text = ""
	title_box.modulate.a = 0.0
	%ResumeButton.pressed.connect(_resume)
	%QuitButton.pressed.connect(_quit)
	%RestartCheckpointButton.pressed.connect(func() -> void: restart_requested.emit(true))
	%RestartLevelButton.pressed.connect(func() -> void: restart_requested.emit(false))
	%QuitButtonOver.pressed.connect(_quit)
	%ReplayButton.pressed.connect(func() -> void: restart_requested.emit(false))
	%QuitButtonWin.pressed.connect(_quit)


func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	pause_menu.show()
	%ResumeButton.grab_focus()


func _resume() -> void:
	pause_menu.hide()
	get_tree().paused = false


func _quit() -> void:
	get_tree().quit()


# ---------- appelés par game.gd (via les signaux du joueur et du niveau) ----------

func set_health(hp: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp


func set_stamina(value: float, exhausted: bool) -> void:
	stamina_bar.value = value
	stamina_bar.modulate = Color(0.6, 0.55, 0.3) if exhausted else Color.WHITE


func set_ammo(mag: int, reserve: int, reloading: bool) -> void:
	if reloading:
		ammo_label.text = "RECHARGE…"
	else:
		ammo_label.text = "%d / %d" % [mag, reserve]


func set_key(has_key: bool) -> void:
	key_label.visible = has_key


func set_crouch(crouching: bool) -> void:
	crouch_label.visible = crouching


func set_hint(text: String) -> void:
	hint_label.text = text


func set_objective(text: String) -> void:
	objective_label.text = text


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.7)


func flash_hurt() -> void:
	hurt_overlay.color.a = 0.3
	create_tween().tween_property(hurt_overlay, "color:a", 0.0, 0.3)


func show_title(title: String, subtitle: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	title_box.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(title_box, "modulate:a", 0.0, 1.0)


func show_game_over() -> void:
	over = true
	game_over_menu.show()
	%RestartCheckpointButton.grab_focus()


func show_win(kills: int, seconds: float) -> void:
	over = true
	var s := int(seconds)
	win_stats.text = "Zombies éliminés : %d   |   Temps : %d:%02d" % [kills, s / 60, s % 60]
	win_menu.show()
	%ReplayButton.grab_focus()
