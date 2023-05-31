extends Node2D

@onready var stack_size_input = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/GridContainer/HBoxContainer/StackSizeInput")
@onready var display = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/Output")
@onready var menu = get_tree().get_nodes_in_group("Menu")
@onready var menu_button = get_node("Control/Menu/VBoxContainer/MenuButton")
@onready var bars_a = get_node("BarsA")
@onready var bars_b = get_node("BarsB")
@onready var window_size = get_window().get_size_with_decorations()
@onready var bar_height = window_size.y / stack_size
@onready var speed_timer = $Speed

var stack_size = 3
var values = [42, -1, 69]
var stack_a = []
var stack_b = []
var values_as_string = "42 -1 69"
var max_bar_length
var bar_scene = load("res://Bar.tscn")
var commands = []
var speed = 1.0
var reversing: bool = false
var is_visualising: bool = false
var cmd_index = 0
var steps_per_second_input = 1
var colour_index = 0


func _ready():
	fit_window_to_screen()

func fit_window_to_screen():
	var screen_size = DisplayServer.screen_get_size()
	
	if window_size.x > screen_size.x or window_size.y > screen_size.y:
		get_window().set_size(screen_size)
	
	menu_button.modulate.a = 0.4


func generate_values():
	var new_value
	
	values.clear()
	values_as_string = ""
	randomize()
	while values.size() < stack_size:
		new_value = randi() % (2147483647 * 2 + 1) - 2147483648
		if not values.has(new_value):
			values.append(new_value)
		
		if values_as_string == "":
			values_as_string = str(new_value)
		else:
			values_as_string += " " + str(new_value)


func generate_bars():
	for i in range(stack_a.size()):
		var new_bar = bar_scene.instantiate()
		bars_a.add_child(new_bar)
		new_bar.index = stack_a[i]
	update_bars_size()
	update_bars_position()
	update_colour()

func update_bars_size():
	var bars = bars_a.get_children() + bars_b.get_children()
	var min_bar_length: float
	var increment
	
	window_size = get_window().get_size()
	bar_height = window_size.y / float(stack_size)
	max_bar_length = 0.48 * window_size.x
	if stack_size > 10:
		min_bar_length = max_bar_length * 0.01
	else:
		min_bar_length = 50.0
	increment = (max_bar_length - min_bar_length) / stack_size
	for bar in bars:
		bar.scale.x = bar.index * increment
		bar.scale.y = bar_height


func update_bars_position():
	var a_bars = bars_a.get_children()
	var b_bars = bars_b.get_children()
	for i in range(stack_a.size()):
		if a_bars[i]:
			a_bars[i].position.y = a_bars[i].scale.y * (i)
			a_bars[i].position.x = 0
	for i in range(stack_b.size()):
		if b_bars[i]:
			b_bars[i].position.y = b_bars[i].scale.y * (i)
			b_bars[i].position.x = window_size.x / 2


func _on_Compute_pressed():
	var push_swap = "./compute.sh"
	var ps_out: FileAccess
	var args = [values_as_string]
	
	if stack_a.is_empty():
		display.update_display("No values generated")
		return
	
	var file_check = FileAccess.file_exists(push_swap)
	if !file_check:
		display.update_display("Missing push_swap executable")
		return
	
	OS.execute(push_swap, args)
#	await get_tree().create_timer(stack_size * 0.0001).timeout
	ps_out = FileAccess.open("ps_out", FileAccess.READ)
	if !ps_out:
		display.update_display("Failed to open: ps_out")
		return
	else:
		var count = cmd_count(ps_out)
		var counter = " steps"
		if count == 1:
			counter = " step"
		display.update_display(str(count) + counter)
	save_commands(ps_out)
	DirAccess.remove_absolute(ps_out.get_path_absolute())
	ps_out.close()
	
	update_commands()
	cmd_index = 0


func cmd_count(file):
	var count = 0
	while file.get_line():
		count += 1
	file.seek(0)
	return count


func save_commands(file):
	var command = file.get_line()
	
	commands.clear()
	while not file.eof_reached():
		commands.append(command)
		command = file.get_line()


func _on_Visualise_pressed():
	menu_button.button_pressed = false
	is_visualising = true
	visualise(is_visualising)


func visualise(visualising):
#	var steps_per_second_input = speed_input.text
#	if not steps_per_second_input.is_valid_float():
#		display.update_display("Invalid steps per second")
#		return
#	speed = 1 / float(steps_per_second_input)
#	if speed > 1000:
#		display.update_display("Invalid steps per second (max 1000)")
#		return
#	if speed < -1000:
#		display.update_display("Invalid steps per second (max 500)")
#		return
#	if speed < 0:
#		is_reverse = true
#		speed = abs(speed)
#	else:
#		is_reverse = false
#	speed_timer.wait_time = speed
	if not visualising:
		speed_timer.stop()
	else:
		speed_timer.start()


func _on_generate_pressed():
	for n in bars_a.get_children():
		bars_a.remove_child(n)
		n.queue_free()
	for n in bars_b.get_children():
		bars_b.remove_child(n)
		n.queue_free()
	if stack_size_input.text.is_valid_int():
		stack_size = stack_size_input.text.to_int()
		generate_values()
	else:
		display.update_display("Invalid stack size")
	stack_a = values.duplicate()
	simplify()
	generate_bars()
	

func _on_quit_pressed():
	get_tree().quit()


func _on_menu_button_toggled(button_pressed):
	for child in menu:
		child.visible = button_pressed


func simplify():
	var stack_min = stack_a.min()
	if stack_min < 1:
		for i in range(stack_a.size()):
			stack_a[i] += 1 - stack_min
	elif stack_min > 1:
		for i in range(stack_a.size()):
			stack_a[i] -= stack_min - 1
	var next = 2
	while stack_a.max() != stack_size: #this is ugly :(
		stack_min = lowest_number_great_than(stack_a, next)
		if not stack_a.has(next):
			for i in range(stack_a.size()):
				if stack_a[i] > next:
					stack_a[i] -= stack_min - next
		next += 1
		

func lowest_number_great_than(arr, n):
	var ret: int = 10000000000
	for i in arr:
		if n < i and i < ret:
			ret = i
	return ret


func _on_play_pause_pressed():
	is_visualising = true if is_visualising == false else false
	visualise(is_visualising)


func _on_reset_pressed():
	cmd_index = 0
	is_visualising = false
	visualise(is_visualising)
	stack_a = []
	stack_b = []
	_on_generate_pressed()
	_on_Compute_pressed()
	

func _on_speed_timeout():
	if commands.size() == 0:
		speed_timer.stop()
		is_visualising == false
		return
	step(reversing)


func step(is_reverse):
	var command = commands[cmd_index]
	
	if (cmd_index == 0 and is_reverse) or (cmd_index == commands.size() - 1 and not is_reverse):
		speed_timer.stop()
		is_visualising = false
	
	match command:
		"sa":
			swap_a()
		"sb":
			swap_b()
		"ss":
			swap_a()
			swap_b()
		"pa":
			if not is_reverse:
				push_a()
			else:
				push_b()
		"pb":
			if not is_reverse:
				push_b()
			else:
				push_a()
		"ra":
			if not is_reverse:
				rotate_a()
			else:
				rev_rotate_a()
		"rb":
			if not is_reverse:
				rotate_b()
			else:
				rev_rotate_b()
		"rr":
			if not is_reverse:
				rotate_a()
				rotate_b()
			else:
				rev_rotate_a()
				rev_rotate_b()
		"rra":
			if not is_reverse:
				rev_rotate_a()
			else:
				rotate_a()
		"rrb":
			if not is_reverse:
				rev_rotate_b()
			else:
				rotate_b()
		"rrr":
			if not is_reverse:
				rev_rotate_a()
				rev_rotate_b()
			else:
				rotate_a()
				rotate_b()
		_:
			display.update_display("Invalid command: ", command)
	
	update_bars_position()
	if not is_reverse and is_visualising:
		cmd_index += 1
	update_commands()
	if is_reverse and is_visualising:
		cmd_index -= 1
	


func update_commands():
	var queue = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/Queue")
	var display_text = ""
	for n in range(9):
		if cmd_index + n >= commands.size():
			break
		if commands[cmd_index + n]:
			if n == 0:
				display_text = commands[cmd_index]
			else:
				display_text += "\n" + commands[cmd_index + n]
	queue.text = display_text
	


func swap_a():
	if stack_a.size() < 2:
		display.update_display("Not enough items in stack a to swap")
		return
	
	var temp
	temp = stack_a[0]
	stack_a[0] = stack_a[1]
	stack_a[1] = temp
	
	bars_a.move_child(bars_a.get_child(1), 0)


func swap_b():
	if stack_b.size() < 2:
		display.update_display("Not enough items in stack b to swap")
		return
	
	var temp
	temp = stack_b[0]
	stack_b[0] = stack_b[1]
	stack_b[1] = temp
	
	bars_b.move_child(bars_b.get_child(1), 0)


func push_a():
	if stack_b.size() == 0:
		display.update_display("No item to push from stack a")
		return
	
	stack_a.push_front(stack_b.pop_front())
	
	var pushed = bars_b.get_child(0)
	bars_b.remove_child(pushed)
	bars_a.add_child(pushed)
	bars_a.move_child(pushed, 0)


func push_b():
	if stack_a.size() == 0:
		display.update_display("No item to push from stack b")
		return
	
	stack_b.push_front(stack_a.pop_front())
	
	var pushed = bars_a.get_child(0)
	bars_a.remove_child(pushed)
	bars_b.add_child(pushed)
	bars_b.move_child(pushed, 0)


func rotate_a():
	if stack_a.size() < 2:
		display.update_display("No item to rotate in stack a")
		return
	
	stack_a.push_back(stack_a.pop_front())
	
	var moved = bars_a.get_child(0)
	bars_a.move_child(moved, bars_a.get_child_count() - 1)


func rotate_b():
	if stack_b.size() < 2:
		display.update_display("No item to rotate in stack b")
		return
	
	stack_b.push_back(stack_b.pop_front())
	
	var moved = bars_b.get_child(0)
	bars_b.move_child(moved, bars_b.get_child_count() - 1)


func rev_rotate_a():
	if stack_a.size() < 2:
		display.update_display("No item to rotate in stack a")
		return
	
	stack_a.push_front(stack_a.pop_back())
	
	var moved = bars_a.get_child(bars_a.get_child_count() - 1)
	bars_a.move_child(moved, 0)


func rev_rotate_b():
	if stack_b.size() < 2:
		display.update_display("No item to rotate in stack b")
		return
	
	stack_b.push_front(stack_b.pop_back())
	
	var moved = bars_b.get_child(bars_b.get_child_count() - 1)
	bars_b.move_child(moved, 0)


func _on_speed_slider_value_changed(value):
	var slider = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/GridContainer/SpeedSlider")
	if abs(value) > 1.0:
		steps_per_second_input = value
	elif value > 0.0:
		steps_per_second_input = 1.0
	else:
		steps_per_second_input = -1.0
	speed = 1.0 / float(steps_per_second_input)
	if speed < 0.0:
		reversing = true
		speed = abs(speed)
	else:
		reversing = false
	speed_timer.wait_time = speed


func _on_option_button_item_selected(index):
	colour_index = index
	update_colour()


func update_colour():
	var white = Color(1, 1, 1, 1)
	var bars = bars_a.get_children() + bars_b.get_children()
	match colour_index:
		0:
			for bar in bars:
				bar.color = white
		1:
			for bar in bars:
				bar.color.s = 0.75
				bar.color.h = lerp(0.0, 0.8, float(bar.index) / float(stack_size))
				bar.color.v = 0.9
		2:
			for bar in bars:
				bar.color.s = 0.3
				bar.color.h = lerp(0.5, 0.9, float(bar.index) / float(stack_size))
				bar.color.v = 1.0
		3:
			for bar in bars:
				bar.color.s = 0.6
				bar.color.h = lerp(-0.01, 0.15, float(bar.index) / float(stack_size))
				if bar.color.h < 0:
					bar.color.h += 1.0
				bar.color.v = lerp(1.0, 0.8, float(bar.index) / float(stack_size))
		4:
			for bar in bars:
				bar.color.s = 0.6
				bar.color.h = lerp(0.45, 0.68, float(bar.index) / float(stack_size))
				bar.color.v = lerp(1.0, 0.5, float(bar.index) / float(stack_size))
		5:
			for bar in bars:
				bar.color.s = 0.7
				bar.color.h = lerp(0.22, 0.45, float(bar.index) / float(stack_size))
				bar.color.v = lerp(1.0, 0.5, float(bar.index) / float(stack_size))
		6:
			for bar in bars:
				bar.color.s = lerp(0.1, 1.0, float(bar.index) / float(stack_size))
				bar.color.h = 0.1
				bar.color.v = lerp(1.0, 0.1, float(bar.index) / float(stack_size))
		7:
			for bar in bars:
				bar.color.s = lerp(0.0, 0.3, float(bar.index) / float(stack_size))
				bar.color.h = 0.98
				bar.color.v = 1.0
		8:
			for bar in bars:
				bar.color.s = lerp(0.1, 0.3, float(bar.index) / float(stack_size))
				bar.color.h = lerp(0.64, 0.7, float(bar.index) / float(stack_size))
				bar.color.v = lerp(1.0, 0.95, float(bar.index) / float(stack_size))
		9:
			for bar in bars:
				bar.color.s = lerp(0.8, 0.5, float(bar.index) / float(stack_size))
				bar.color.h = lerp(0.6, 0.7, float(bar.index) / float(stack_size))
				bar.color.v = lerp(0.5, 0.1, float(bar.index) / float(stack_size))
		10:
			for bar in bars:
				bar.color.s = 0.0
				bar.color.h = 0.0
				bar.color.v = lerp(1.0, 0.0, float(bar.index) / float(stack_size))
		11:
			randomize()
			for bar in bars:
				bar.color.s = randf()
				bar.color.h = randf()
				bar.color.v = randf()


func _on_step_forward_pressed():
	if not is_visualising:
		step(false)


func _on_step_backward_pressed():
	if not is_visualising:
		step(true)