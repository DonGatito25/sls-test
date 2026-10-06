extends CharacterBody2D

@export var speed: float = 500.0

func _physics_process(_delta: float) -> void:
	if DialogueManager.dialogue_active:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()
