extends CanvasLayer

@onready var item_label: Label = $Panel/MarginContainer/VBoxContainer/ItemLabel


func _process(_delta: float) -> void:
	update_inventory()


func update_inventory() -> void:
	if RunState.inventory.is_empty():
		item_label.text = "Empty"
		return

	var lines: Array[String] = []

	for item_id in RunState.inventory:
		var amount: int = RunState.inventory[item_id]

		lines.append(
			item_id + " x" + str(amount)
		)

	item_label.text = "\n".join(lines)
