class_name MemoryManager
extends RefCounted


func has_state(id: String) -> bool:
	return RunState.remembers(id)


func mark_state(id: String) -> void:
	RunState.remember(id)


func clear_state(id: String) -> void:
	RunState.forget(id)


func get_state(id: String):
	return RunState.remembers(id)


func get_display_value(id: String) -> String:
	return "yes" if RunState.remembers(id) else "no"
