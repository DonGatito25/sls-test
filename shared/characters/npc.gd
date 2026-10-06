extends Area2D

@export_category("Character")
@export var character_id: String = ""

@export_category("Dialogue")
@export_file("*.txt") var dialogue_file: String = ""
@export var starting_section: String = ""

var _detector_in_range: Area2D = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.name == "InteractionDetector":
		_detector_in_range = area


func _on_area_exited(area: Area2D) -> void:
	if area == _detector_in_range:
		_detector_in_range = null


func _unhandled_input(event: InputEvent) -> void:
	if _detector_in_range and event.is_action_pressed("interact"):
		if DialogueManager.dialogue_active:
			return

		interact()
		get_viewport().set_input_as_handled()


func interact() -> void:
	if DialogueManager.dialogue_active:
		return

	if dialogue_file.is_empty():
		push_warning(
			"NPC " + character_id + " has no dialogue file."
		)
		return

	DialogueManager.start_dialogue(
		dialogue_file,
		starting_section
	)
