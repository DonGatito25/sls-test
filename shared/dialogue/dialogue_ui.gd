extends CanvasLayer

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel
@onready var choice_container: VBoxContainer = $DialoguePanel/MarginContainer/VBoxContainer/ChoiceContainer

var current_choices: Array = []
var selected_choice_index: int = 0


func _ready() -> void:
	DialogueManager.register_ui(self)
	hide_dialogue()


func show_line(speaker_name: String, text: String) -> void:
	speaker_label.text = speaker_name
	text_label.text = text

	hide_choices()
	dialogue_panel.show()


func show_choices(choices: Array) -> void:
	current_choices = choices
	selected_choice_index = 0

	dialogue_panel.show()
	_refresh_choices()


func hide_choices() -> void:
	current_choices.clear()
	selected_choice_index = 0

	for child in choice_container.get_children():
		child.queue_free()


func hide_dialogue() -> void:
	hide_choices()
	dialogue_panel.hide()


func _refresh_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

	for i in range(current_choices.size()):
		var choice: Dictionary = current_choices[i]

		var label := Label.new()

		if i == selected_choice_index:
			label.text = "> " + choice.get("text", "")
		else:
			label.text = "  " + choice.get("text", "")

		choice_container.add_child(label)


func move_choice_up() -> void:
	if current_choices.is_empty():
		return

	selected_choice_index -= 1

	if selected_choice_index < 0:
		selected_choice_index = current_choices.size() - 1

	_refresh_choices()


func move_choice_down() -> void:
	if current_choices.is_empty():
		return

	selected_choice_index += 1

	if selected_choice_index >= current_choices.size():
		selected_choice_index = 0

	_refresh_choices()


func confirm_choice() -> void:
	if current_choices.is_empty():
		return

	var choice: Dictionary = current_choices[
		selected_choice_index
	]

	DialogueManager.select_choice(choice)
