extends Node

# UI

var dialogue_ui: CanvasLayer = null

# CURRENT DIALOGUE

var current_dialogue: Dictionary = {}
var current_scene: String = ""

var dialogue_active: bool = false

var waiting_for_input: bool = false
var waiting_for_choice: bool = false
var waiting_for_cue: bool = false


# EXECUTION STACK

var execution_stack: Array = []


# CHOICES

var current_choices: Array = []


# UI REGISTRATION

func register_ui(ui: CanvasLayer) -> void:
	dialogue_ui = ui


# STARTING DIALOGUE

func start_dialogue(
	path: String,
	starting_scene: String = ""
) -> void:

	if dialogue_active:
		push_warning("Dialogue is already active.")
		return


	var data := DialogueParser.parse_file(path)

	if data.is_empty():
		push_error(
			"DialogueManager could not load: " + path
		)
		return


	# SLS no longer has an implicit entry Scene.

	if starting_scene.is_empty():
		push_error(
			"Dialogue requires an explicit starting Scene: "
			+ path
		)

		return


	var scenes: Dictionary = data.get(
		"scenes",
		{}
	)

	if not scenes.has(starting_scene):
		push_error(
			"Dialogue starting Scene does not exist: "
			+ starting_scene
		)

		return


	current_dialogue = data
	current_scene = starting_scene

	dialogue_active = true

	waiting_for_input = false
	waiting_for_choice = false
	waiting_for_cue = false

	execution_stack.clear()
	current_choices.clear()


	var scene: Dictionary = scenes[starting_scene]

	_push_instruction_list(
		scene.get("nodes", [])
	)

	_continue_execution()


# EXECUTION

func _continue_execution() -> void:

	if not dialogue_active:
		return

	if waiting_for_input:
		return

	if waiting_for_choice:
		return

	if waiting_for_cue:
		return


	while not execution_stack.is_empty():

		var frame: Dictionary = execution_stack.back()

		var instructions: Array = frame.get(
			"instructions",
			[]
		)

		var index: int = frame.get(
			"index",
			0
		)


		# Finished this block.

		if index >= instructions.size():
			execution_stack.pop_back()
			continue


		# Fetch instruction.

		var instruction: Dictionary = instructions[index]

		frame["index"] = index + 1


		var instruction_type: String = instruction.get(
			"type",
			""
		)


		match instruction_type:

			"LINE":
				_run_line(instruction)
				return


			"CHECK":
				_run_check(instruction)


			"CHOICE":
				if _run_choice_group(
					instructions,
					index
				):
					return


			"MARK", "CLEAR":
				_run_state_instruction(instruction)


			"CUE":
				if _run_cue(instruction):
					return


			"ACTION_CALL":
				_run_action(instruction)


			"CUT":
				_run_cut(instruction)
				return


			_:
				push_warning(
					"Unknown SLS instruction type: "
					+ instruction_type
				)


	end_dialogue()


# LINES

func _run_line(
	instruction: Dictionary
) -> void:

	var speaker_id: String = instruction.get(
		"speaker",
		""
	)

	var raw_text: String = instruction.get(
		"text",
		""
	)

	var aliases: Array = instruction.get(
		"aliases",
		[]
	)


	var speaker_name := CharacterDatabase.get_display_name(
		speaker_id
	)

	var display_text := _resolve_display_text(
		raw_text,
		aliases
	)


	waiting_for_input = true


	if dialogue_ui:
		dialogue_ui.show_line(
			speaker_name,
			display_text
		)


# CHECKS

func _run_check(
	instruction: Dictionary
) -> void:

	var expression: Dictionary = instruction.get(
		"expression",
		{}
	)

	if expression.is_empty():
		return


	if not _evaluate_check_expression(expression):
		return


	var children: Array = instruction.get(
		"children",
		[]
	)

	if children.is_empty():
		return


	_push_instruction_list(children)


func _evaluate_check_expression(
	expression: Dictionary
) -> bool:

	var terms: Array = expression.get(
		"terms",
		[]
	)

	var operators: Array = expression.get(
		"operators",
		[]
	)


	if terms.is_empty():
		return false

	var current_group := _evaluate_check_term(
		terms[0]
	)

	for index in range(operators.size()):

		var operator: String = operators[index]

		if index + 1 >= terms.size():
			break


		var next_value := _evaluate_check_term(
			terms[index + 1]
		)


		match operator:

			"AND":
				current_group = (
					current_group
					and next_value
				)


			"OR":
				if current_group:
					return true

				current_group = next_value


	return current_group


func _evaluate_check_term(
	term: Dictionary
) -> bool:

	var manager_id: String = term.get(
		"manager",
		""
	)

	var state_id: String = term.get(
		"id",
		""
	)

	var countercheck: bool = term.get(
		"countercheck",
		false
	)

	var comparison: String = term.get(
		"comparison",
		""
	)

	var manager: Object = _get_state_manager(
		manager_id
	)

	if manager == null:
		return false


	var result := false


	# EXISTENCE CHECK

	if comparison.is_empty():

		if not _manager_supports(
			manager,
			"has_state",
			manager_id
		):
			return false


		result = bool(
			manager.call(
				"has_state",
				state_id
			)
		)


	# VALUE COMPARISON

	else:

		if not _manager_supports(
			manager,
			"has_state",
			manager_id
		):
			return false


		var exists := bool(
			manager.call(
				"has_state",
				state_id
			)
		)


		if not exists:
			result = false

		else:

			if not _manager_supports(
				manager,
				"get_state",
				manager_id
			):
				return false


			var actual = manager.call(
				"get_state",
				state_id
			)

			var expected = term.get(
				"value",
				null
			)


			result = _compare_values(
				actual,
				expected,
				comparison,
				manager_id + "." + state_id
			)


	# COUNTERCHECK

	if countercheck:
		result = not result


	return result


func _compare_values(
	actual,
	expected,
	operator: String,
	state_name: String
) -> bool:

	match operator:

		"=":
			return actual == expected


		"!=":
			return actual != expected


		">", ">=", "<", "<=":

			var actual_type := typeof(actual)
			var expected_type := typeof(expected)


			var actual_numeric := (
				actual_type == TYPE_INT
				or actual_type == TYPE_FLOAT
			)

			var expected_numeric := (
				expected_type == TYPE_INT
				or expected_type == TYPE_FLOAT
			)


			var both_strings := (
				actual_type == TYPE_STRING
				and expected_type == TYPE_STRING
			)


			if not (
				(actual_numeric and expected_numeric)
				or both_strings
			):
				push_error(
					"Cannot compare incompatible values for "
					+ state_name
					+ " using "
					+ operator
				)

				return false


			match operator:

				">":
					return actual > expected

				">=":
					return actual >= expected

				"<":
					return actual < expected

				"<=":
					return actual <= expected


	push_error(
		"Unknown SLS comparison operator: "
		+ operator
	)

	return false


# CHOICES

func _run_choice_group(
	instructions: Array,
	first_choice_index: int
) -> bool:

	var available_choices: Array = []

	var index := first_choice_index


	# Consecutive CHOICE nodes form one choice group.

	while index < instructions.size():

		var instruction: Dictionary = instructions[index]

		if instruction.get(
			"type",
			""
		) != "CHOICE":
			break


		if _choice_is_available(instruction):

			var display_choice := instruction.duplicate(
				true
			)

			display_choice["_source_choice"] = instruction

			display_choice["text"] = _resolve_display_text(
				instruction.get("text", ""),
				instruction.get("aliases", [])
			)

			available_choices.append(
				display_choice
			)


		index += 1


	if not execution_stack.is_empty():
		execution_stack.back()["index"] = index


	# No options available.
	# Keep executing.

	if available_choices.is_empty():
		return false


	current_choices = available_choices
	waiting_for_choice = true


	if dialogue_ui:
		dialogue_ui.show_choices(
			available_choices
		)


	return true


func _choice_is_available(
	choice: Dictionary
) -> bool:
	var availability: Array = choice.get(
		"availability",
		[]
	)


	for check in availability:

		var expression: Dictionary = check.get(
			"expression",
			{}
		)

		if expression.is_empty():
			return false


		if not _evaluate_check_expression(expression):
			return false


	return true


func select_choice(
	choice: Dictionary
) -> void:

	if not dialogue_active:
		return

	if not waiting_for_choice:
		return


	waiting_for_choice = false
	current_choices.clear()


	if dialogue_ui:
		dialogue_ui.hide_choices()

	var source_choice: Dictionary = choice.get(
		"_source_choice",
		choice
	)


	var children: Array = source_choice.get(
		"children",
		[]
	)


	if not children.is_empty():
		_push_instruction_list(children)


	_continue_execution()


# MARK / CLEAR

func _run_state_instruction(
	instruction: Dictionary
) -> void:

	var instruction_type: String = instruction.get(
		"type",
		""
	)

	var manager_id: String = instruction.get(
		"manager",
		""
	)

	var state_id: String = instruction.get(
		"id",
		""
	)


	var manager: Object = _get_state_manager(
		manager_id
	)

	if manager == null:
		return


	match instruction_type:

		# MARK

		"MARK":

			var operation: String = instruction.get(
				"operation",
				"MARK"
			)


			match operation:

				"MARK":

					if not _manager_supports(
						manager,
						"mark_state",
						manager_id
					):
						return


					manager.call(
						"mark_state",
						state_id
					)


				"SET":

					if not _manager_supports(
						manager,
						"set_state",
						manager_id
					):
						return


					manager.call(
						"set_state",
						state_id,
						instruction.get(
							"value",
							null
						)
					)


				"MODIFY":

					if not _manager_supports(
						manager,
						"modify_state",
						manager_id
					):
						return


					manager.call(
						"modify_state",
						state_id,
						instruction.get(
							"value",
							0
						)
					)


				_:
					push_error(
						"Unknown Mark operation: "
						+ operation
					)


		# CLEAR

		"CLEAR":

			if not _manager_supports(
				manager,
				"clear_state",
				manager_id
			):
				return


			manager.call(
				"clear_state",
				state_id
			)


# STATE MANAGER REGISTRY

func _get_state_manager(
	manager_id: String
) -> Object:

	var lookup_id: String = manager_id

	if lookup_id.is_empty():
		lookup_id = "default"


	var manager: Object = SLSManagerRegistry.get_manager(
		lookup_id
	)


	if manager == null:
		push_error(
			"Unknown SLS state manager: "
			+ lookup_id
		)

		return null


	return manager


func _manager_supports(
	manager: Object,
	method_name: String,
	manager_id: String
) -> bool:

	if manager.has_method(method_name):
		return true

	push_error(
		"SLS manager '"
		+ manager_id
		+ "' does not implement "
		+ method_name
		+ "()."
	)

	return false


# ACTIONS

func _run_action(
	instruction: Dictionary
) -> void:

	var action_name: String = instruction.get(
		"name",
		""
	)

	if action_name.is_empty():
		push_error("SLS Action call has no name.")
		return


	var action_definition: Dictionary = {}


	# Local Actions override file-global Actions.

	var scenes: Dictionary = current_dialogue.get(
		"scenes",
		{}
	)


	if scenes.has(current_scene):

		var scene: Dictionary = scenes[current_scene]

		var local_actions: Dictionary = scene.get(
			"actions",
			{}
		)

		if local_actions.has(action_name):
			action_definition = local_actions[action_name]


	if action_definition.is_empty():

		var global_actions: Dictionary = current_dialogue.get(
			"global_actions",
			{}
		)

		if global_actions.has(action_name):
			action_definition = global_actions[action_name]


	if action_definition.is_empty():
		push_error(
			"Unknown SLS Action: $"
			+ action_name
		)

		return


	var children: Array = action_definition.get(
		"children",
		[]
	)


	if children.is_empty():
		return


	_push_instruction_list(children)


# CUES

func _run_cue(
	instruction: Dictionary
) -> bool:

	var cue_name: String = instruction.get(
		"name",
		""
	)

	if cue_name.is_empty():
		push_error("SLS Cue has no name.")
		return false


	var sync: bool = instruction.get(
		"sync",
		false
	)


	var command := {
		"name": cue_name,

		# Typed arguments generated by the new parser.
		"arguments": instruction.get(
			"arguments",
			[]
		),

		# Useful for debugging / legacy adapters.
		"raw_arguments": instruction.get(
			"raw_arguments",
			""
		),

		"sync": sync
	}

	var completion = CommandRegistry.execute(
		command,
		get_tree().current_scene
	)


	if not sync:
		return false


	if typeof(completion) != TYPE_SIGNAL:
		return false


	var completion_signal: Signal = completion


	waiting_for_cue = true


	completion_signal.connect(
		_on_synced_cue_finished,
		CONNECT_ONE_SHOT
	)


	return true


func _on_synced_cue_finished() -> void:

	if not dialogue_active:
		return


	waiting_for_cue = false

	_continue_execution()


# CUTS

func _run_cut(
	instruction: Dictionary
) -> void:

	var target: String = instruction.get(
		"target",
		""
	)


	if target.is_empty():
		push_error("SLS Cut has no target.")
		end_dialogue()
		return


	cut_to_scene(target)


func cut_to_scene(
	scene_name: String
) -> void:

	var scenes: Dictionary = current_dialogue.get(
		"scenes",
		{}
	)


	if not scenes.has(scene_name):
		push_error(
			"Cannot Cut to missing SLS Scene: "
			+ scene_name
		)

		end_dialogue()
		return


	current_scene = scene_name


	# Cut does NOT return.

	execution_stack.clear()


	waiting_for_input = false
	waiting_for_choice = false
	waiting_for_cue = false

	current_choices.clear()


	if dialogue_ui:
		dialogue_ui.hide_choices()


	var scene: Dictionary = scenes[scene_name]


	_push_instruction_list(
		scene.get(
			"nodes",
			[]
		)
	)


	_continue_execution()


# TEMPORARY OLD-NAME COMPATIBILITY

func jump_to_section(
	section: String
) -> void:

	push_warning(
		"jump_to_section() is deprecated. "
		+ "Use cut_to_scene()."
	)

	cut_to_scene(section)


# ALIASES

func _resolve_display_text(
	text: String,
	aliases: Array
) -> String:

	if aliases.is_empty():
		return text


	var result := text

	for index in range(
		aliases.size() - 1,
		-1,
		-1
	):

		var alias: Dictionary = aliases[index]

		var start: int = alias.get(
			"start",
			-1
		)

		var end: int = alias.get(
			"end",
			-1
		)


		if start < 0 or end <= start:
			continue


		var replacement := _resolve_alias(
			alias,
			result.substr(
				start,
				end - start
			)
		)


		result = (
			result.substr(0, start)
			+ replacement
			+ result.substr(end)
		)


	return result


func _resolve_alias(
	alias: Dictionary,
	original_text: String
) -> String:

	var alias_type: String = alias.get(
		"type",
		""
	)

	if alias_type == "PING":

		var ping_name: String = alias.get(
			"name",
			""
		)


		var character_id := CharacterDatabase.resolve_dialogue_alias(
			ping_name
		)


		if character_id.is_empty():
			push_error(
				"Could not resolve SLS Ping Alias: "
				+ original_text
			)

			return original_text


		var display_name := CharacterDatabase.get_display_name(
			character_id
		)


		if display_name.is_empty():
			push_error(
				"SLS Ping Alias has no display name: "
				+ original_text
			)

			return original_text


		return display_name


	# VALUE ALIAS

	if alias_type == "VALUE":

		var manager_id: String = alias.get(
			"manager",
			""
		)

		var state_id: String = alias.get(
			"id",
			""
		)


		var manager: Object = _get_state_manager(
			manager_id
		)

		if manager == null:
			return original_text


		if not _manager_supports(
			manager,
			"has_state",
			manager_id
		):
			return original_text


		if not manager.call(
			"has_state",
			state_id
		):
			push_error(
				"SLS Value Alias references missing state: "
				+ manager_id
				+ "."
				+ state_id
			)

			return original_text


		if not _manager_supports(
			manager,
			"get_display_value",
			manager_id
		):
			return original_text


		return str(
			manager.call(
				"get_display_value",
				state_id
			)
		)


	push_error(
		"Unknown SLS Alias type: "
		+ alias_type
	)


	return original_text


# EXECUTION STACK

func _push_instruction_list(
	instructions: Array
) -> void:

	execution_stack.append({
		"instructions": instructions,
		"index": 0
	})


# PLAYER ADVANCE

func advance_dialogue() -> void:

	if not dialogue_active:
		return

	if waiting_for_choice:
		return

	if waiting_for_cue:
		return

	if not waiting_for_input:
		return


	waiting_for_input = false

	_continue_execution()


# ENDING / RESETTING

func end_dialogue() -> void:

	if dialogue_ui:
		dialogue_ui.hide_dialogue()
		dialogue_ui.hide_choices()


	_reset_dialogue()


func _reset_dialogue() -> void:

	dialogue_active = false

	waiting_for_input = false
	waiting_for_choice = false
	waiting_for_cue = false


	current_dialogue = {}
	current_scene = ""


	execution_stack.clear()
	current_choices.clear()


# INPUT

func _unhandled_input(
	event: InputEvent
) -> void:

	if not dialogue_active:
		return


	# CHOICE INPUT

	if waiting_for_choice:

		if event.is_action_pressed("move_up"):

			if dialogue_ui:
				dialogue_ui.move_choice_up()

			get_viewport().set_input_as_handled()
			return


		if event.is_action_pressed("move_down"):

			if dialogue_ui:
				dialogue_ui.move_choice_down()

			get_viewport().set_input_as_handled()
			return


		if event.is_action_pressed("select"):

			if dialogue_ui:
				dialogue_ui.confirm_choice()

			get_viewport().set_input_as_handled()
			return


		return


	# NORMAL DIALOGUE ADVANCE

	if waiting_for_input:

		if event.is_action_pressed("interact"):

			advance_dialogue()

			get_viewport().set_input_as_handled()
			return
