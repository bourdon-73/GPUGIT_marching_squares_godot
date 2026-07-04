extends RigidBody2D


@export var fly_mode : bool = true
@export var speed : float = 3000

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity = state.get_linear_velocity()
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed*2

	state.set_linear_velocity(velocity)
