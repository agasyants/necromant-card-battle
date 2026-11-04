class_name FloatingText
extends Label

func setup(text_val: String, color: Color, start_pos: Vector2) -> void:
	text = text_val
	modulate = color
	z_index = 100
	global_position = start_pos - Vector2(size.x / 2.0, size.y / 2.0)
	
	# Анимация взлета и растворения
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", start_pos.y - 45.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.95).set_delay(0.35)
	tween.chain().tween_callback(queue_free)
