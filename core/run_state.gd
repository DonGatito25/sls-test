extends Node


const InventoryManagerClass = preload(
	"res://core/inventory_manager.gd"
)

const MemoryManagerClass = preload(
	"res://core/memory_manager.gd"
)

const RelationshipManagerClass = preload(
	"res://core/relationship_manager.gd"
)


var inventory: Dictionary = {}
var memories: Dictionary = {}
var relationships: Dictionary = {}


func _ready() -> void:
	_register_sls_managers()


func _register_sls_managers() -> void:
	SLSManagerRegistry.register_manager(
		"item",
		InventoryManagerClass.new()
	)

	SLSManagerRegistry.register_manager(
		"memory",
		MemoryManagerClass.new()
	)
	
	SLSManagerRegistry.register_manager(
		"relationship",
		RelationshipManagerClass.new()
	)

# INVENTORY

func set_item_count(item_id: String, value: int) -> void:
	inventory[item_id] = value

	print("Set item: ", item_id, " = ", value)


func modify_item_count(item_id: String, delta: int) -> void:
	inventory[item_id] = get_item_count(item_id) + delta

	print(
		"Modified item: ",
		item_id,
		" by ",
		delta,
		" -> ",
		inventory[item_id]
	)


func clear_item(item_id: String) -> void:
	inventory.erase(item_id)

	print("Cleared item: ", item_id)


# Convenience wrappers for non-dialogue callers — same MODIFY
# semantics as above, so these also no longer auto-erase at zero.

func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	modify_item_count(item_id, amount)


func remove_item(item_id: String, amount: int = 1) -> void:
	modify_item_count(item_id, -amount)


func has_item(item_id: String, amount: int = 1) -> bool:
	return inventory.get(item_id, 0) >= amount


func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


# MEMORY

func remember(memory_id: String) -> void:
	memories[memory_id] = true

	print("Remembered: ", memory_id)


func forget(memory_id: String) -> void:
	memories.erase(memory_id)


func remembers(memory_id: String) -> bool:
	return memories.get(memory_id, false)




# RESET

func reset_run() -> void:
	inventory.clear()
	memories.clear()
	relationships.clear()
