class_name InventoryManager
extends RefCounted


func has_state(id: String) -> bool:
	return RunState.inventory.has(id)


func mark_state(id: String) -> void:
	if not RunState.inventory.has(id):
		RunState.set_item_count(id, 1)


func clear_state(id: String) -> void:
	RunState.clear_item(id)


func set_state(id: String, value) -> void:
	if not (
		value is int
		or value is float
	):
		push_error(
			"Inventory state '" + id +
			"' requires a numeric value."
		)
		return

	RunState.set_item_count(id, int(value))


func modify_state(id: String, amount) -> void:
	if not (
		amount is int
		or amount is float
	):
		push_error(
			"Inventory state '" + id +
			"' requires a numeric modifier."
		)
		return

	RunState.modify_item_count(
		id,
		int(amount)
	)


func get_state(id: String):
	return RunState.get_item_count(id)


func get_display_value(id: String) -> String:
	return str(RunState.get_item_count(id))
