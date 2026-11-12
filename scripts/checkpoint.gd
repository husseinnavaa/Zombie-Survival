class_name Checkpoint
extends Area2D

signal activated(checkpoint: Checkpoint)

var used := false

@onready var pad: Polygon2D = $Pad
@onready var core: Polygon2D = $Core


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tw := create_tween().set_loops()
	tw.tween_property(core, "modulate:a", 0.4, 0.8)
	tw.tween_property(core, "modulate:a", 1.0, 0.8)


func _on_body_entered(body: Node2D) -> void:
	if used or not body.is_in_group("player"):
		return
	_mark_used()
	activated.emit(self)


func restore_used() -> void:
	_mark_used()


func _mark_used() -> void:
	used = true
	pad.color = Color("4fd16a")
