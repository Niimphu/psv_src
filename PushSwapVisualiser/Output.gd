extends Label

@onready var display_timer = $DisplayTimer

var valid_input = ["pa", "pb", "sa", "sb", "ss", "ra", "rb", "rr", "rra", "rrb", "rrr"]
var red = Color(1, 0, 0)
var white = Color(1, 1, 1)


func update_display(display_text):
	text = display_text
	if valid_input.has(display_text) or display_text.left(1).is_valid_int():
		set("theme_override_colors/font_color", white)
	else:
		set("theme_override_colors/font_color", red)
	
	display_timer.start()

func _on_display_timer_timeout():
	self.text = ""
