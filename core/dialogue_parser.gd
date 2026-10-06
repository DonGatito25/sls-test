class_name DialogueParser
extends RefCounted


# ============================================================
# PUBLIC
# ============================================================

static func parse_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("DialogueParser could not open: " + path)
		return {}

	return parse(file.get_as_text())


static func parse(source: String) -> Dictionary:
	var result := {
		"notes": [],
		"global_actions": {},
		"scenes": {},
		"scene_order": [],
		"diagnostics": [],

		# Temporary backwards compatibility.
		# Deliberately empty: SLS has no implicit entry Scene.
		"first_section": "",
		"sections": {}
	}

	var global_nodes: Array = []
	var stack: Array = []

	var current_scene := ""
	var pending_ping: Dictionary = {}

	var lines := source.split("\n")


	for line_index in range(lines.size()):
		var raw := String(lines[line_index])
		var line_number := line_index + 1
		var trimmed := raw.strip_edges()


		# ----------------------------------------------------
		# BLANK / COMMENT
		# ----------------------------------------------------

		if trimmed.is_empty():
			continue

		if trimmed.begins_with("--"):
			continue


		# Inline comments are illegal.
		if _find_inline_comment(raw) != -1:
			_diag(
				result,
				line_number,
				"Inline comments are not allowed."
			)
			continue


		var indent := _get_indent(raw)


		# ----------------------------------------------------
		# PENDING PING
		#
		# A Ping owns exactly ONE Dialogue line.
		# Blank lines/comments do not count.
		# ----------------------------------------------------

		if not pending_ping.is_empty():
			if not _looks_like_operation(trimmed):
				if current_scene.is_empty():
					_diag(
						result,
						line_number,
						"Dialogue cannot exist outside a Scene."
					)
				else:
					var character_id := CharacterDatabase.resolve_dialogue_alias(
						pending_ping["speaker"]
					)

					if character_id.is_empty():
						_diag(
							result,
							pending_ping["line"],
							"Unknown Ping @" + pending_ping["speaker"] + "."
						)
						character_id = pending_ping["speaker"]

					var line_node := {
						"type": "LINE",
						"speaker": character_id,
						"speaker_alias": pending_ping["speaker"],
						"text": trimmed,
						"aliases": _parse_aliases(
							trimmed,
							line_number,
							result
						),
						"children": [],
						"line": pending_ping["line"]
					}

					_append_node(
						result["scenes"][current_scene]["nodes"],
						stack,
						line_node,
						pending_ping["indent"]
					)

				pending_ping = {}
				continue

			_diag(
				result,
				pending_ping["line"],
				"Ping @" + pending_ping["speaker"] +
				" must be followed by Dialogue."
			)

			pending_ping = {}


		# ----------------------------------------------------
		# SCENE
		# ----------------------------------------------------

		if trimmed.begins_with("::"):
			var scene_name := trimmed.trim_prefix("::").strip_edges()

			if not _is_identifier(scene_name, true):
				_diag(
					result,
					line_number,
					"Invalid Scene name: " + scene_name
				)

				current_scene = ""
				stack.clear()
				continue

			if result["scenes"].has(scene_name):
				_diag(
					result,
					line_number,
					"Duplicate Scene ::" + scene_name + "."
				)

				current_scene = ""
				stack.clear()
				continue

			var scene := {
				"name": scene_name,
				"nodes": [],
				"notes": [],
				"actions": {}
			}

			result["scenes"][scene_name] = scene
			result["sections"][scene_name] = scene["nodes"]
			result["scene_order"].append(scene_name)

			current_scene = scene_name
			stack.clear()

			continue


		# ----------------------------------------------------
		# PING
		# ----------------------------------------------------

		if trimmed.begins_with("@"):
			var speaker := trimmed.trim_prefix("@").strip_edges()

			if current_scene.is_empty():
				_diag(
					result,
					line_number,
					"Ping exists outside a Scene."
				)
				continue

			if not _is_identifier(speaker, true):
				_diag(
					result,
					line_number,
					"Invalid Ping @" + speaker + "."
				)
				continue

			pending_ping = {
				"speaker": speaker,
				"indent": indent,
				"line": line_number
			}

			continue


		# ----------------------------------------------------
		# LOOSE TEXT
		# ----------------------------------------------------

		if not _looks_like_operation(trimmed):
			_diag(
				result,
				line_number,
				"Loose text is not allowed. Dialogue must follow a Ping."
			)
			continue


		# ----------------------------------------------------
		# NORMAL OPERATION
		# ----------------------------------------------------

		var node := _parse_operation(
			trimmed,
			line_number,
			result
		)

		if node.is_empty():
			continue


		if current_scene.is_empty():
			_append_node(
				global_nodes,
				stack,
				node,
				indent
			)
		else:
			_append_node(
				result["scenes"][current_scene]["nodes"],
				stack,
				node,
				indent
			)


	# --------------------------------------------------------
	# UNCLOSED PING AT EOF
	# --------------------------------------------------------

	if not pending_ping.is_empty():
		_diag(
			result,
			pending_ping["line"],
			"Ping @" + pending_ping["speaker"] +
			" must be followed by Dialogue."
		)


	# ========================================================
	# POST-PARSE STRUCTURE
	# ========================================================

	_classify_actions(global_nodes)

	for scene_name in result["scene_order"]:
		_classify_actions(
			result["scenes"][scene_name]["nodes"]
		)


	# Validate parenting before extracting static structures.
	_validate_parenting(global_nodes, result)

	for scene_name in result["scene_order"]:
		_validate_parenting(
			result["scenes"][scene_name]["nodes"],
			result
		)


	# Validate Action bodies.
	_validate_action_bodies(global_nodes, result)

	for scene_name in result["scene_order"]:
		_validate_action_bodies(
			result["scenes"][scene_name]["nodes"],
			result
		)


	# --------------------------------------------------------
	# GLOBAL ACTIONS
	# --------------------------------------------------------

	_extract_action_definitions(
		global_nodes,
		result["global_actions"],
		result,
		"global"
	)

	_extract_notes(
		global_nodes,
		result["notes"]
	)


	# Anything executable remaining globally is illegal.
	for node in global_nodes:
		_diag(
			result,
			node["line"],
			"Executable operation exists outside a Scene."
		)


	# --------------------------------------------------------
	# SCENE-LOCAL ACTIONS / NOTES
	# --------------------------------------------------------

	for scene_name in result["scene_order"]:
		var scene: Dictionary = result["scenes"][scene_name]

		_extract_action_definitions(
			scene["nodes"],
			scene["actions"],
			result,
			scene_name
		)

		_extract_notes(
			scene["nodes"],
			scene["notes"]
		)

		_prepare_choices(scene["nodes"])

		_resolve_action_calls(
			scene["nodes"],
			scene["actions"],
			result["global_actions"],
			result
		)


	return result


# ============================================================
# OPERATION PARSING
# ============================================================

static func _parse_operation(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	# --------------------------------------------------------
	# CUT
	# --------------------------------------------------------

	if line.begins_with("->"):
		var target := line.trim_prefix("->").strip_edges()

		if not _is_identifier(target, true):
			_diag(result, line_number, "Invalid Cut target: " + target)
			return {}

		return {
			"type": "CUT",
			"target": target,
			"children": [],
			"line": line_number
		}


	# --------------------------------------------------------
	# CHOICE
	# --------------------------------------------------------

	if line.begins_with(">"):
		var text := line.trim_prefix(">").strip_edges()

		if text.is_empty():
			_diag(result, line_number, "Choice text cannot be empty.")
			return {}

		return {
			"type": "CHOICE",
			"text": text,
			"aliases": _parse_aliases(
				text,
				line_number,
				result
			),
			"availability": [],
			"children": [],
			"line": line_number
		}


	# --------------------------------------------------------
	# CHECK / COUNTERCHECK
	# --------------------------------------------------------

	if line.begins_with("?"):
		var expression := _parse_check_expression(
			line,
			line_number,
			result
		)

		if expression.is_empty():
			return {}

		return {
			"type": "CHECK",
			"expression": expression,
			"children": [],
			"line": line_number
		}


	# --------------------------------------------------------
	# MARK
	# --------------------------------------------------------

	if line.begins_with("+"):
		return _parse_mark(
			line,
			line_number,
			result
		)


	# --------------------------------------------------------
	# CLEAR
	# --------------------------------------------------------

	if line.begins_with("-"):
		return _parse_clear(
			line,
			line_number,
			result
		)


	# --------------------------------------------------------
	# CUE
	# --------------------------------------------------------

	if line.begins_with(";"):
		return _parse_cue(
			line,
			line_number,
			result
		)


	# --------------------------------------------------------
	# ACTION
	#
	# Definition vs invocation is determined after indentation
	# has built the tree.
	# --------------------------------------------------------

	if line.begins_with("$"):
		var action_name := line.trim_prefix("$").strip_edges()

		if not _is_identifier(action_name, true):
			_diag(
				result,
				line_number,
				"Invalid Action name: " + action_name
			)
			return {}

		return {
			"type": "ACTION",
			"name": action_name,
			"children": [],
			"line": line_number
		}


	# --------------------------------------------------------
	# NOTE
	# --------------------------------------------------------

	if line.begins_with("#"):
		return _parse_note(
			line,
			line_number,
			result
		)


	_diag(
		result,
		line_number,
		"Unknown SLS operation: " + line
	)

	return {}


# ============================================================
# MARK / CLEAR
# ============================================================

static func _parse_mark(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var body := line.trim_prefix("+").strip_edges()

	var modifier_index := _find_state_modifier(body)

	var state_text := body
	var modifier := ""

	if modifier_index != -1:
		state_text = body.substr(0, modifier_index).strip_edges()
		modifier = body.substr(modifier_index).strip_edges()

	var state := _parse_state_reference(state_text)

	if state.is_empty() or state["manager"].is_empty():
		_diag(
			result,
			line_number,
			"Mark requires manager-qualified state: +" + state_text
		)
		return {}


	var node := {
		"type": "MARK",
		"manager": state["manager"],
		"id": state["id"],
		"operation": "MARK",
		"value": null,
		"children": [],
		"line": line_number
	}


	# +manager.state
	if modifier.is_empty():
		return node


	# +manager.state=N
	if modifier.begins_with("="):
		var value_text := modifier.trim_prefix("=").strip_edges()

		var literal := _parse_literal(value_text, false)

		if literal.is_empty():
			_diag(
				result,
				line_number,
				"Invalid Mark setter value: " + value_text
			)
			return {}

		# State truth is structural.
		# yes / no / void are therefore illegal setters.
		if literal["type"] in ["YES", "NO", "VOID"]:
			_diag(
				result,
				line_number,
				"yes, no, and void cannot be used as state setters."
			)
			return {}

		node["operation"] = "SET"
		node["value"] = literal["value"]

		return node


	# +manager.state+N / +manager.state-N
	if modifier.begins_with("+") or modifier.begins_with("-"):
		if not modifier.is_valid_float():
			_diag(
				result,
				line_number,
				"Relative Mark requires a number: " + modifier
			)
			return {}

		node["operation"] = "MODIFY"

		if modifier.is_valid_int():
			node["value"] = int(modifier)
		else:
			node["value"] = float(modifier)

		return node


	_diag(
		result,
		line_number,
		"Malformed Mark: " + line
	)

	return {}


static func _parse_clear(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var body := line.trim_prefix("-").strip_edges()
	var state := _parse_state_reference(body)

	if state.is_empty() or state["manager"].is_empty():
		_diag(
			result,
			line_number,
			"Clear requires manager-qualified state: -" + body
		)
		return {}

	return {
		"type": "CLEAR",
		"manager": state["manager"],
		"id": state["id"],
		"children": [],
		"line": line_number
	}


# ============================================================
# CHECKS
# ============================================================

static func _parse_check_expression(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var split := _split_logic(line)

	if split["terms"].is_empty():
		_diag(result, line_number, "Empty Check.")
		return {}

	var terms: Array = []

	for term_text in split["terms"]:
		var term := _parse_check_term(
			String(term_text).strip_edges(),
			line_number,
			result
		)

		if term.is_empty():
			return {}

		terms.append(term)

	return {
		"terms": terms,
		"operators": split["operators"]
	}


static func _parse_check_term(
	text: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var countercheck := false

	if text.begins_with("?!"):
		countercheck = true
		text = text.trim_prefix("?!").strip_edges()
	elif text.begins_with("?"):
		text = text.trim_prefix("?").strip_edges()
	else:
		_diag(
			result,
			line_number,
			"Every Check term must begin with ? or ?!."
		)
		return {}


	var comparison := _find_comparison(text)

	var state_text := text
	var operator := ""
	var value = null
	var value_type := ""


	if not comparison.is_empty():
		var index: int = comparison["index"]
		operator = comparison["operator"]

		state_text = text.substr(0, index).strip_edges()

		var value_text := text.substr(
			index + operator.length()
		).strip_edges()

		var literal := _parse_literal(value_text, false)

		if literal.is_empty():
			_diag(
				result,
				line_number,
				"Invalid comparison value: " + value_text
			)
			return {}

		value = literal["value"]
		value_type = literal["type"]


	var state := _parse_state_reference(state_text)

	if state.is_empty():
		_diag(
			result,
			line_number,
			"Invalid state reference in Check: " + state_text
		)
		return {}


	return {
		"manager": state["manager"],
		"id": state["id"],
		"countercheck": countercheck,
		"comparison": operator,
		"value": value,
		"value_type": value_type
	}


# ============================================================
# CUES
# ============================================================

static func _parse_cue(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var body := line.trim_prefix(";").strip_edges()

	if body.is_empty():
		_diag(result, line_number, "Cue name cannot be empty.")
		return {}

	var first_space := body.find(" ")

	var cue_name := body
	var argument_text := ""

	if first_space != -1:
		cue_name = body.substr(0, first_space)
		argument_text = body.substr(first_space + 1).strip_edges()

	if not _is_identifier(cue_name, true):
		_diag(
			result,
			line_number,
			"Invalid Cue name: " + cue_name
		)
		return {}


	var tokens := _tokenize_arguments(
		argument_text,
		line_number,
		result
	)

	var sync := false
	var arguments: Array = []


	for index in range(tokens.size()):
		var token: Dictionary = tokens[index]

		if token["quoted"]:
			arguments.append({
				"type": "STRING",
				"value": token["value"]
			})
			continue


		var raw: String = token["value"]


		if raw == "..." or raw == "…":
			if index != 0 or sync:
				_diag(
					result,
					line_number,
					"Sync must be the first Cue argument and may appear only once."
				)
				continue

			sync = true
			continue


		if _is_sync_like(raw):
			_diag(
				result,
				line_number,
				"Malformed Sync token: " + raw
			)
			continue


		var literal := _parse_literal(raw, true)

		arguments.append({
			"type": literal["type"],
			"value": literal["value"]
		})


	return {
		"type": "CUE",
		"name": cue_name,
		"sync": sync,
		"arguments": arguments,
		"raw_arguments": argument_text,
		"children": [],
		"line": line_number
	}


# ============================================================
# NOTES
# ============================================================

static func _parse_note(
	line: String,
	line_number: int,
	result: Dictionary
) -> Dictionary:

	var body := line.trim_prefix("#").strip_edges()

	if body.is_empty():
		_diag(result, line_number, "Note name cannot be empty.")
		return {}

	var first_space := body.find(" ")

	var note_name := body
	var value_text := ""

	if first_space != -1:
		note_name = body.substr(0, first_space)
		value_text = body.substr(first_space + 1).strip_edges()


	if not _is_identifier(note_name, true):
		_diag(
			result,
			line_number,
			"Invalid Note name: " + note_name
		)
		return {}


	var value = null
	var value_type := "VOID"
	var has_value := not value_text.is_empty()


	if has_value:
		var literal := _parse_literal(value_text, true)

		value = literal["value"]
		value_type = literal["type"]


	return {
		"type": "NOTE",
		"name": note_name,
		"value": value,
		"value_type": value_type,
		"has_value": has_value,
		"raw_value": value_text,
		"children": [],
		"line": line_number
	}


# ============================================================
# ALIASES
# ============================================================

static func _parse_aliases(
	text: String,
	line_number: int,
	result: Dictionary
) -> Array:

	var aliases: Array = []
	var cursor := 0


	while true:
		var start := text.find("^{", cursor)

		if start == -1:
			break

		var end := text.find("}", start + 2)

		if end == -1:
			_diag(
				result,
				line_number,
				"Unclosed Alias."
			)
			break


		var content := text.substr(
			start + 2,
			end - start - 2
		)


		# ^{@nate}
		if content.begins_with("@"):
			var ping := content.trim_prefix("@")

			if _is_identifier(ping, true):
				aliases.append({
					"type": "PING",
					"name": ping,
					"start": start,
					"end": end + 1
				})
			else:
				_diag(
					result,
					line_number,
					"Malformed Ping Alias: ^{" + content + "}"
				)


		# ^{%item.cookie}
		elif content.begins_with("%"):
			var state := _parse_state_reference(
				content.trim_prefix("%")
			)

			if not state.is_empty() and not state["manager"].is_empty():
				aliases.append({
					"type": "VALUE",
					"manager": state["manager"],
					"id": state["id"],
					"start": start,
					"end": end + 1
				})
			else:
				_diag(
					result,
					line_number,
					"Malformed Value Alias: ^{" + content + "}"
				)

		else:
			_diag(
				result,
				line_number,
				"Malformed Alias: ^{" + content + "}"
			)


		cursor = end + 1


	return aliases


# ============================================================
# ACTIONS
# ============================================================

static func _classify_actions(nodes: Array) -> void:
	for node in nodes:
		if node["type"] == "ACTION":
			if node["children"].is_empty():
				node["type"] = "ACTION_CALL"
			else:
				node["type"] = "ACTION_DEF"

		_classify_actions(node["children"])


static func _extract_action_definitions(
	nodes: Array,
	table: Dictionary,
	result: Dictionary,
	scope_name: String
) -> void:

	var index := nodes.size() - 1

	while index >= 0:
		var node: Dictionary = nodes[index]

		if node["type"] == "ACTION_DEF":
			var name: String = node["name"]

			if table.has(name):
				_diag(
					result,
					node["line"],
					"Duplicate Action $" + name +
					" in scope " + scope_name + "."
				)
			else:
				table[name] = node

			nodes.remove_at(index)

		else:
			_extract_action_definitions(
				node["children"],
				table,
				result,
				scope_name
			)

		index -= 1


static func _validate_action_bodies(
	nodes: Array,
	result: Dictionary
) -> void:

	for node in nodes:
		if node["type"] == "ACTION_DEF":
			_validate_action_children(
				node["children"],
				result,
				node["name"]
			)
		else:
			_validate_action_bodies(
				node["children"],
				result
			)


static func _validate_action_children(
	nodes: Array,
	result: Dictionary,
	action_name: String
) -> void:

	var allowed := [
		"MARK",
		"CLEAR",
		"CHECK",
		"CUE"
	]

	for node in nodes:
		if not node["type"] in allowed:
			_diag(
				result,
				node["line"],
				"Action $" + action_name +
				" cannot contain " + node["type"] + "."
			)

		_validate_action_children(
			node["children"],
			result,
			action_name
		)


static func _resolve_action_calls(
	nodes: Array,
	local_actions: Dictionary,
	global_actions: Dictionary,
	result: Dictionary
) -> void:

	for node in nodes:
		if node["type"] == "ACTION_CALL":
			var name: String = node["name"]

			if local_actions.has(name):
				node["scope"] = "LOCAL"
			elif global_actions.has(name):
				node["scope"] = "GLOBAL"
			else:
				node["scope"] = "UNKNOWN"

				_diag(
					result,
					node["line"],
					"Unknown Action $" + name + "."
				)

		_resolve_action_calls(
			node["children"],
			local_actions,
			global_actions,
			result
		)


# ============================================================
# CHOICE PRECONDITIONS
# ============================================================

static func _prepare_choices(nodes: Array) -> void:
	for node in nodes:
		if node["type"] == "CHOICE":
			while (
				not node["children"].is_empty()
				and node["children"][0]["type"] == "CHECK"
			):
				node["availability"].append(
					node["children"].pop_front()
				)

		_prepare_choices(node["children"])


# ============================================================
# NOTES
# ============================================================

static func _extract_notes(
	nodes: Array,
	destination: Array
) -> void:

	var index := nodes.size() - 1

	while index >= 0:
		var node: Dictionary = nodes[index]

		if node["type"] == "NOTE":
			destination.push_front(node)
			nodes.remove_at(index)
		else:
			_extract_notes(
				node["children"],
				destination
			)

		index -= 1


# ============================================================
# TREE / INDENTATION
# ============================================================

static func _append_node(
	root: Array,
	stack: Array,
	node: Dictionary,
	indent: int
) -> void:

	_trim_stack(stack, indent)

	if stack.is_empty():
		root.append(node)
	else:
		stack.back()["node"]["children"].append(node)

	stack.append({
		"indent": indent,
		"node": node
	})


static func _trim_stack(
	stack: Array,
	indent: int
) -> void:

	while not stack.is_empty():
		if indent > stack.back()["indent"]:
			break

		stack.pop_back()


static func _get_indent(line: String) -> int:
	var indent := 0

	for character in line:
		if character == "\t":
			indent += 4
		elif character == " ":
			indent += 1
		else:
			break

	return indent


static func _validate_parenting(
	nodes: Array,
	result: Dictionary
) -> void:

	var parent_types := [
		"CHOICE",
		"CHECK",
		"ACTION_DEF"
	]

	for node in nodes:
		if (
			not node["children"].is_empty()
			and not node["type"] in parent_types
		):
			_diag(
				result,
				node["line"],
				node["type"] +
				" cannot own an indented block."
			)

		_validate_parenting(
			node["children"],
			result
		)


# ============================================================
# STATE REFERENCES
# ============================================================

static func _parse_state_reference(text: String) -> Dictionary:
	var cleaned := text.strip_edges()

	if cleaned.is_empty():
		return {}

	var dot := cleaned.find(".")

	# Bare state reference: ?foo
	if dot == -1:
		if not _is_identifier(cleaned, false):
			return {}

		return {
			"manager": "",
			"id": cleaned
		}


	var manager := cleaned.substr(0, dot)
	var state_id := cleaned.substr(dot + 1)

	if (
		not _is_identifier(manager, false)
		or not _is_identifier(state_id, false)
	):
		return {}

	return {
		"manager": manager,
		"id": state_id
	}


static func _find_state_modifier(text: String) -> int:
	for index in range(text.length()):
		var character := text.substr(index, 1)

		if character == "=" or character == "+" or character == "-":
			return index

	return -1


# ============================================================
# LOGICAL EXPRESSIONS
# ============================================================

static func _split_logic(text: String) -> Dictionary:
	var terms: Array = []
	var operators: Array = []

	var start := 0
	var in_string := false
	var escaped := false


	for index in range(text.length()):
		var character := text.substr(index, 1)

		if escaped:
			escaped = false
			continue

		if character == "\\" and in_string:
			escaped = true
			continue

		if character == "\"":
			in_string = not in_string
			continue

		if not in_string and (character == "&" or character == "~"):
			terms.append(
				text.substr(start, index - start).strip_edges()
			)

			operators.append(
				"AND" if character == "&" else "OR"
			)

			start = index + 1


	terms.append(
		text.substr(start).strip_edges()
	)

	return {
		"terms": terms,
		"operators": operators
	}


static func _find_comparison(text: String) -> Dictionary:
	var operators := [
		">=",
		"<=",
		"!=",
		"=",
		">",
		"<"
	]

	var in_string := false
	var escaped := false


	for index in range(text.length()):
		var character := text.substr(index, 1)

		if escaped:
			escaped = false
			continue

		if character == "\\" and in_string:
			escaped = true
			continue

		if character == "\"":
			in_string = not in_string
			continue

		if in_string:
			continue

		for operator in operators:
			if text.substr(index).begins_with(operator):
				return {
					"index": index,
					"operator": operator
				}

	return {}


# ============================================================
# LITERALS
# ============================================================

static func _parse_literal(
	text: String,
	allow_bare: bool
) -> Dictionary:

	var value := text.strip_edges()

	if value.is_empty():
		return {}


	# String
	if (
		value.length() >= 2
		and value.begins_with("\"")
		and value.ends_with("\"")
	):
		return {
			"type": "STRING",
			"value": _unescape_string(
				value.substr(1, value.length() - 2)
			)
		}


	# Anlits
	if value == "yes":
		return {
			"type": "YES",
			"value": true
		}

	if value == "no":
		return {
			"type": "NO",
			"value": false
		}

	if value == "void":
		return {
			"type": "VOID",
			"value": null
		}


	# Number
	if value.is_valid_int():
		return {
			"type": "NUMBER",
			"value": int(value)
		}

	if value.is_valid_float():
		return {
			"type": "NUMBER",
			"value": float(value)
		}


	if allow_bare:
		return {
			"type": "BARE",
			"value": value
		}


	return {}


static func _unescape_string(text: String) -> String:
	var output := ""
	var escaped := false

	for character in text:
		if escaped:
			if character == "\"":
				output += "\""
			elif character == "\\":
				output += "\\"
			else:
				output += "\\" + character

			escaped = false
			continue

		if character == "\\":
			escaped = true
			continue

		output += character

	if escaped:
		output += "\\"

	return output


# ============================================================
# CUE TOKENIZATION
# ============================================================

static func _tokenize_arguments(
	text: String,
	line_number: int,
	result: Dictionary
) -> Array:

	var tokens: Array = []
	var index := 0


	while index < text.length():
		var character := text.substr(index, 1)

		if character == " " or character == "\t":
			index += 1
			continue


		# Quoted string
		if character == "\"":
			index += 1

			var value := ""
			var escaped := false
			var closed := false

			while index < text.length():
				character = text.substr(index, 1)

				if escaped:
					if character == "\"":
						value += "\""
					elif character == "\\":
						value += "\\"
					else:
						value += "\\" + character

					escaped = false
					index += 1
					continue

				if character == "\\":
					escaped = true
					index += 1
					continue

				if character == "\"":
					closed = true
					index += 1
					break

				value += character
				index += 1

			if not closed:
				_diag(
					result,
					line_number,
					"Unclosed Cue string."
				)

			tokens.append({
				"quoted": true,
				"value": value
			})

			continue


		# Bare token
		var start := index

		while index < text.length():
			character = text.substr(index, 1)

			if character == " " or character == "\t":
				break

			index += 1

		tokens.append({
			"quoted": false,
			"value": text.substr(start, index - start)
		})


	return tokens


static func _is_sync_like(text: String) -> bool:
	if text.is_empty():
		return false

	for character in text:
		if character != "." and character != "…":
			return false

	return true


# ============================================================
# ALLOWED SHAPES
# ============================================================

static func _looks_like_operation(line: String) -> bool:
	return (
		line.begins_with("::")
		or line.begins_with("->")
		or line.begins_with("@")
		or line.begins_with(">")
		or line.begins_with("?")
		or line.begins_with("+")
		or line.begins_with("-")
		or line.begins_with(";")
		or line.begins_with("$")
		or line.begins_with("#")
	)


static func _is_identifier(
	text: String,
	allow_hyphen: bool
) -> bool:

	if text.is_empty():
		return false

	var regex := RegEx.new()

	if allow_hyphen:
		regex.compile("^[A-Za-z_][A-Za-z0-9_-]*$")
	else:
		regex.compile("^[A-Za-z_][A-Za-z0-9_]*$")

	return regex.search(text) != null


# ============================================================
# INLINE COMMENTS
# ============================================================

static func _find_inline_comment(text: String) -> int:
	var in_string := false
	var escaped := false

	for index in range(text.length() - 1):
		var character := text.substr(index, 1)

		if escaped:
			escaped = false
			continue

		if character == "\\" and in_string:
			escaped = true
			continue

		if character == "\"":
			in_string = not in_string
			continue

		if (
			not in_string
			and character == "-"
			and text.substr(index + 1, 1) == "-"
		):
			return index

	return -1


# ============================================================
# DIAGNOSTICS
# ============================================================

static func _diag(
	result: Dictionary,
	line_number: int,
	message: String
) -> void:

	result["diagnostics"].append({
		"line": line_number,
		"message": message
	})

	push_warning(
		"SLS line " +
		str(line_number) +
		": " +
		message
	)
