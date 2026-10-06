extends Node


const CHARACTER_PATHS := {
	"producer": "res://data/producer.json",
	"seth": "res://data/seth.json"
}


var characters: Dictionary = {}


func _ready() -> void:
	load_characters()


# LOADING

func load_characters() -> void:
	for character_id in CHARACTER_PATHS.keys():
		_load_character(character_id)

	print("Characters loaded.")


func _load_character(character_id: String) -> void:
	var path: String = CHARACTER_PATHS[character_id]

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Could not open character definition: "
			+ path
		)
		return

	var data = JSON.parse_string(
		file.get_as_text()
	)

	if data == null:
		push_error(
			"Could not parse character definition: "
			+ path
		)
		return

	characters[character_id] = data


# LOOKUPS

func get_character(character_id: String) -> Dictionary:
	if not characters.has(character_id):
		push_error(
			"Unknown character ID: "
			+ character_id
		)
		return {}

	return characters[character_id]


func get_display_name(character_id: String) -> String:
	var character := get_character(character_id)

	if character.is_empty():
		return "Unknown"

	return character.get(
		"display_name",
		"Unknown"
	)


func resolve_dialogue_alias(alias: String) -> String:
	if not characters.has(alias):
		push_error(
			"Unknown dialogue alias: @"
			+ alias
		)
		return ""

	return alias
