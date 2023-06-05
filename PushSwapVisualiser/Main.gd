extends Node2D

@onready var stack_size_input = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/GridContainer/HBoxContainer/StackSizeInput")
@onready var display = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/Output")
@onready var menu = get_tree().get_nodes_in_group("Menu")
@onready var menu_button = get_node("Control/Menu/VBoxContainer/MenuButton")
@onready var bars_a = get_node("BarsA")
@onready var bars_b = get_node("BarsB")
@onready var window_size = get_window().get_size_with_decorations()
@onready var bar_height = window_size.y / stack_size

var stack_size = 3
var values = [42, -1, 69]
var stack_a = []
var stack_b = []
var max_bar_length
var bar_scene = load("res://Bar.tscn")
var commands = []
var reversing: bool = false
var is_program_stopped: bool = true
var command_i = 0
var colour_index = 0
var step_interval = 1 / 2.0
var push_swap = null
var time_since_stepped = 0.0


func _ready():
	fit_window_to_screen()
	menu_button.modulate.a = 0.4
	get_viewport().files_dropped.connect(on_files_dropped)


func _process(delta):
	if is_program_stopped:
		return
	time_since_stepped += delta
	if time_since_stepped >= step_interval:
		var step_count = floor(time_since_stepped / step_interval)
		if step_count > 200.0:
			step_count = 200
			time_since_stepped = 0.0
		time_since_stepped -= step_count * step_interval
		for _step in range(step_count):
			if is_program_stopped:
				return
			step(reversing)


func fit_window_to_screen():
	var screen_size = DisplayServer.screen_get_size()
	
	if window_size.x > screen_size.x or window_size.y > screen_size.y:
		get_window().set_size(screen_size)
	


func generate_values():
	var new_value
	
	values.clear()
	randomize()
	while values.size() < stack_size:
		new_value = randi() % (2147483647 * 2 + 1) - 2147483648
		if not values.has(new_value):
			values.append(new_value)



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
	
	window_size = Vector2i(1920, 1080)
	bar_height = window_size.y / float(stack_size)
	max_bar_length = 0.49 * window_size.x
	if stack_size > 10:
		min_bar_length = max_bar_length * 0.015
	else:
		min_bar_length = 50.0
	for bar in bars:
		bar.scale.x = lerp(min_bar_length, max_bar_length, bar.index / stack_size)
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



func on_files_dropped(files):
	print(files[0])
	if files.size() < 1:
		display.update_display("No file detected, please try again")
	if not (files[0].ends_with("push_swap") or files[0].ends_with("push_swap.exe")):
		display.update_display("Invalid file: please drag your push_swap into this window")
		return
	push_swap = files[0]
	clear_display()


func clear_display():
	display.update_display("")



func _on_Compute_pressed():
	if stack_a.is_empty():
		display.update_display("No values generated: please click 'Generate'")
		return

	if push_swap == null:
		display.update_display("Missing push_swap: please drag your push_swap into this window")
		return
	
	var out = []
	OS.execute(push_swap, values, out)
	
	var delimiter: String
	if OS.get_name() == "Windows":
		delimiter = "\r\n"
	else:
		delimiter = "\n"
	out = out[0].split(delimiter)
	var count = out.size()
	var counter = " steps"
	if count == 1:
		counter = " step"
	display.update_display(str(count) + counter)
	
	commands = out
	update_commands()
	command_i = 0


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


func _on_generate_pressed():
	stack_a.clear()
	stack_b.clear()
	values.clear()
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
	while stack_a.max() != stack_size:
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
	if is_program_stopped:
		is_program_stopped = false
		menu_button.button_pressed = false
	else:
		is_program_stopped = true


func _on_reset_pressed():
	command_i = 0
	is_program_stopped = true
	_on_generate_pressed()
	_on_Compute_pressed()
	


func step(is_reverse):
	if command_i >= commands.size() and not is_reverse:
		command_i = commands.size() - 1
		is_program_stopped = true
		return
	if command_i <= 0 and is_reverse:
		command_i = 0
		is_program_stopped = true
		return
	
	
	var command = ""
	if not is_reverse:
		command = commands[command_i]
		command_i += 1
		cmd_state_machine(command, is_reverse)
	else:
		command_i -= 1
		command = commands[command_i]
		cmd_state_machine(command, is_reverse)
	
	update_bars_position()
	update_commands()
	

func cmd_state_machine(command, is_reverse):
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
			if command != "":
				display.update_display("Invalid command: ", command)

func update_commands():
	var queue = get_node("Control/Menu/HBoxContainer2/HBoxContainer/MenuItems/VBoxContainer/Queue")
	var display_text = ""
	for n in range(9):
		if command_i + n >= commands.size():
			break
		if commands[command_i + n]:
			if n == 0:
				display_text = commands[command_i]
			else:
				display_text += "\n" + commands[command_i + n]
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
	if is_program_stopped:
		step(false)


func _on_step_backward_pressed():
	if is_program_stopped:
		step(true)


func _on_reverse_toggled(button_pressed):
	reversing = button_pressed


func _on_speed_item_selected(index):
	match index:
		0:
			step_interval = 1 / 2.0
		1:
			step_interval = 1 / 4.0
		2:
			step_interval = 1 / 10.0
		3:
			step_interval = 1 / 50.0
		4:
			step_interval = 1 / 200.0
		5:
			step_interval = 1 / 1000.0
		6:
			step_interval = 1 / 2000.0
			

