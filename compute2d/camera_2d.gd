extends Camera2D

@export var speed = 500  # Adjust the speed to your liking


func _process(delta):
	
	# Movement inputs
	if Input.is_action_pressed("ui_left"):
		position.x -= speed * delta
	if Input.is_action_pressed("ui_right"):
		position.x += speed * delta
	if Input.is_action_pressed("ui_down"):
		position.y += speed * delta
	if Input.is_action_pressed("ui_up"):
		position.y -= speed * delta

#	$CanvasLayer/Label.text = str(Engine.get_frames_per_second())


func _on_timer_timeout() -> void:
	#$"../CanvasLayer/Label".text = str(Engine.get_frames_per_second())
	pass # Replace with function body.
