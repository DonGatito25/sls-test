class_name SLSManagerRegistry
extends RefCounted


static var _managers: Dictionary = {}


static func register_manager(
	id: String,
	manager: Object
) -> void:

	if id.is_empty():
		push_error(
			"Cannot register an SLS manager with an empty ID."
		)
		return

	if manager == null:
		push_error(
			"Cannot register null SLS manager: " + id
		)
		return

	_managers[id] = manager


static func unregister_manager(
	id: String
) -> void:

	_managers.erase(id)


static func has_manager(
	id: String
) -> bool:

	return _managers.has(id)


static func get_manager(
	id: String
) -> Object:

	if not _managers.has(id):
		return null

	return _managers[id]


static func clear() -> void:
	_managers.clear()
