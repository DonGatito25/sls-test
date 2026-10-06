class_name RelationshipManager
extends RefCounted


const MIN_RELATIONSHIP := -20
const MAX_RELATIONSHIP := 20


func has_state(id: String) -> bool:
	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return false

	return RunState.relationships.has(character_id)


func mark_state(id: String) -> void:
	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return

	if not RunState.relationships.has(character_id):
		RunState.relationships[character_id] = 0


func clear_state(id: String) -> void:
	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return

	RunState.relationships.erase(character_id)


func set_state(
	id: String,
	value
) -> void:

	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return

	if not _is_numeric(value):
		push_error(
			"Relationship value for @"
			+ id
			+ " must be numeric."
		)
		return

	RunState.relationships[character_id] = clampi(
		int(value),
		MIN_RELATIONSHIP,
		MAX_RELATIONSHIP
	)

	print(
		"Relationship set: ",
		id,
		" = ",
		RunState.relationships[character_id]
	)


func modify_state(
	id: String,
	amount
) -> void:

	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return

	if not _is_numeric(amount):
		push_error(
			"Relationship modifier for @"
			+ id
			+ " must be numeric."
		)
		return

	var current: int = RunState.relationships.get(
		character_id,
		0
	)

	var updated := clampi(
		current + int(amount),
		MIN_RELATIONSHIP,
		MAX_RELATIONSHIP
	)

	RunState.relationships[character_id] = updated

	print(
		"Relationship modified: ",
		id,
		" by ",
		int(amount),
		" -> ",
		updated
	)


func get_state(id: String):
	var character_id := _resolve_character(id)

	if character_id.is_empty():
		return 0

	return RunState.relationships.get(
		character_id,
		0
	)


func get_display_value(id: String) -> String:
	return str(
		get_state(id)
	)


func _resolve_character(alias: String) -> String:
	return CharacterDatabase.resolve_dialogue_alias(
		alias
	)


func _is_numeric(value) -> bool:
	return (
		typeof(value) == TYPE_INT
		or typeof(value) == TYPE_FLOAT
	)
