class_name CommandRegistry
extends RefCounted


static func execute(
	command: Dictionary,
	context: Node
) -> bool:

	if command.is_empty():
		return false

	var command_name: String = command.get("name", "")
	var arguments: String = command.get("arguments", "")

	match command_name:

		"explode-object":
			return _explode_object(arguments, context)

		"hide-object":
			return _hide_object(arguments, context)

		"show-object":
			return _show_object(arguments, context)

		"enable-object":
			return _enable_object(arguments, context)

		"disable-object":
			return _disable_object(arguments, context)

		"move-npc":
			return _move_npc(arguments, context)

		"face":
			return _face(arguments, context)

		"animation":
			return _animation(arguments, context)

		"sfx":
			return _play_sfx(arguments, context)

		"music":
			return _play_music(arguments, context)

		"music-stop":
			return _stop_music(arguments, context)

		"camera-focus":
			return _camera_focus(arguments, context)

		"camera-reset":
			return _camera_reset(arguments, context)

		"camera-shake":
			return _camera_shake(arguments, context)

		"effect":
			return _effect(arguments, context)

		"effect-clear":
			return _effect_clear(arguments, context)
		_:
			push_warning(
                "Unknown dialogue world command: ;"
				+ command_name
			)
			return false


# OBJECT COMMANDS

static func _explode_object(
	arguments: String,
	context: Node
) -> bool:

	var args := _split_arguments(arguments)

	if args.is_empty():
		push_warning(
            ";explode-object requires an object ID."
		)
		return false

	var object_id: String = args[0]

	var strength := 1.0

	if args.size() >= 2:
		strength = float(args[1])

	var target := _find_target(
		context,
		object_id
	)

	if target == null:
		push_warning(
            "Could not find object: "
			+ object_id
		)
		return false


	if target.has_method("explode"):
		target.explode(strength)
	else:
		print(
			"EXPLODE: ",
			object_id,
			" strength=",
			strength
		)

	return true


static func _hide_object(
	arguments: String,
	context: Node
) -> bool:

	var target := _find_target(
		context,
		arguments.strip_edges()
	)

	if target == null:
		return false

	if target is CanvasItem:
		target.visible = false
		return true

	push_warning(
        "Object cannot be hidden: "
		+ arguments
	)

	return false


static func _show_object(
	arguments: String,
	context: Node
) -> bool:

	var target := _find_target(
		context,
		arguments.strip_edges()
	)

	if target == null:
		return false

	if target is CanvasItem:
		target.visible = true
		return true

	push_warning(
        "Object cannot be shown: "
		+ arguments
	)

	return false


static func _enable_object(
	arguments: String,
	context: Node
) -> bool:

	var target := _find_target(
		context,
		arguments.strip_edges()
	)

	if target == null:
		return false

	if target.has_method("set_enabled"):
		target.set_enabled(true)
		return true

	push_warning(
        "Object does not support set_enabled(): "
		+ arguments
	)

	return false


static func _disable_object(
	arguments: String,
	context: Node
) -> bool:

	var target := _find_target(
		context,
		arguments.strip_edges()
	)

	if target == null:
		return false

	if target.has_method("set_enabled"):
		target.set_enabled(false)
		return true

	push_warning(
        "Object does not support set_enabled(): "
		+ arguments
	)

	return false


# CHARACTER / NPC COMMANDS

static func _move_npc(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"MOVE NPC: ",
		arguments
	)

	return true


static func _face(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"FACE: ",
		arguments
	)

	return true


static func _animation(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"ANIMATION: ",
		arguments
	)

	return true


# AUDIO COMMANDS

static func _play_sfx(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"PLAY SFX: ",
		arguments
	)

	return true


static func _play_music(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"PLAY MUSIC: ",
		arguments
	)

	return true


static func _stop_music(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"STOP MUSIC: ",
		arguments
	)

	return true


# CAMERA COMMANDS

static func _camera_focus(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"CAMERA FOCUS: ",
		arguments
	)

	return true


static func _camera_reset(
	_arguments: String,
	_context: Node
) -> bool:

	print("CAMERA RESET")

	return true


static func _camera_shake(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"CAMERA SHAKE: ",
		arguments
	)

	return true


# EFFECT COMMANDS

static func _effect(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"EFFECT: ",
		arguments
	)

	return true


static func _effect_clear(
	arguments: String,
	_context: Node
) -> bool:

	print(
		"CLEAR EFFECT: ",
		arguments
	)

	return true

# HELPERS

static func _split_arguments(
	arguments: String
) -> PackedStringArray:

	return arguments.split(
		" ",
		false
	)


static func _find_target(
	context: Node,
	target_id: String
) -> Node:

	if context == null:
		push_warning(
            "CommandRegistry received no scene context."
		)
		return null

	if target_id.is_empty():
		push_warning(
            "CommandRegistry received an empty target ID."
		)
		return null

	var result := _find_by_world_id(
		context,
		target_id
	)

	if result != null:
		return result

	return context.find_child(
		target_id,
		true,
		false
	)


static func _find_by_world_id(
	node: Node,
	target_id: String
) -> Node:

	if node.has_meta("world_id"):

		if String(
			node.get_meta("world_id")
		) == target_id:

			return node

	for child in node.get_children():

		var result := _find_by_world_id(
			child,
			target_id
		)

		if result != null:
			return result

	return null
