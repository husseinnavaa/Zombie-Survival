## Fondu au noir entre deux scènes (scène fade.tscn, un CanvasLayer au-dessus de tout).
## Le singleton Game l'utilise lors des changements de niveau et de menu.
class_name Fade
extends CanvasLayer

# Rectangle noir qui couvre tout l'écran (transparent par défaut)
@onready var rect: ColorRect = $Rect


## Assombrit l'écran. Pendant le fondu, le rectangle bloque la souris pour éviter les clics par erreur.
func fade_out(duration := 0.4) -> void:
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, duration)
	await tw.finished


## Éclaircit l'écran, puis laisse de nouveau passer la souris.
func fade_in(duration := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	await tw.finished
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
