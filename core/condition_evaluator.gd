class_name ConditionEvaluator
extends RefCounted


static func evaluate(
	condition: Dictionary
) -> bool:

	var condition_type: String = (
		condition.get("type", "")
	)

	var result := false

	match condition_type:

		"HAS_ITEM":
			var item_id: String = (
				condition.get("id", "")
			)

			result = RunState.has_item(
				item_id
			)


		"HAS_MEMORY":
			var memory_id: String = (
				condition.get("id", "")
			)

			result = RunState.remembers(
				memory_id
			)


		_:
			push_warning(
				"Unknown condition type: "
				+ condition_type
			)

			return false


	if condition.get("negated", false):
		result = not result


	return result


static func evaluate_all(
	conditions: Array
) -> bool:

	for condition in conditions:

		if not evaluate(condition):
			return false


	return true
