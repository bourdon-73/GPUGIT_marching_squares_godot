extends Node2D

# Settings, references and constants
@export var noise_scale : float = 2.0
@export var noise_offset : Vector3
@export var iso_level : float = .7
@export var chunk_scale : float = 2500
#@export var player : Node2D
@export var agents : Array[Node2D]
@export var is_DebugDraw : bool

@onready var mesh_path = preload("res://compute2d/chunk.tscn")
@onready var renderDistance : float = 1

const resolution : int = 4
const num_waitframes_gpusync : int = 12
const num_waitframes_meshthread : int = 90

const work_group_size : int = 8
const num_voxels_per_axis : int = work_group_size * resolution

const buffer_set_index : int = 0
const triangle_bind_index : int = 0
const params_bind_index : int = 1
const counter_bind_index : int = 2
const lut_bind_index : int = 3
const matrix_bind_index : int = 4
const surface_bind_index : int = 5
const surface_lut_bind_index : int = 6
const Matcounter_bind_index : int = 7

# Compute stuff
var rendering_device: RenderingDevice
var shader : RID
var pipeline : RID

var buffer_set : RID
var triangle_buffer : RID
var params_buffer : RID
var counter_buffer : RID
var lut_buffer : RID
var matrix_buffer : RID
var mat_counter_buffer : RID
var surface_buffer : RID
var surface_lut_buffer : RID

# Data received from compute shader
var triangle_data_bytes
var counter_data_bytes
var MATcounter_data_bytes
var surface_data_bytes
var num_triangles
var num_vert_lines

#var array_mesh : ArrayMesh
var verts = PackedVector2Array()
var surface_verts = PackedVector2Array()
#var normals = PackedVector2Array()

# State
var time : float
var frame : int
var last_compute_dispatch_frame : int
var last_meshthread_start_frame : int
var waiting_for_compute : bool
var waiting_for_meshthread : bool
var thread
var matrix
var tris
var chunks : Dictionary

func _ready():
	#array_mesh = ArrayMesh.new()
	#mesh = array_mesh
	
	init_compute()
@onready var chunk_queue : Array = [
	#Vector2(2000, 2000),
	#Vector2(5000, 2000),
	#Vector2(2000, 5000),
	#Vector2(10000, 5000),
	#Vector2(5000, 5000)
]

#

#func _process(delta):
func  _physics_process(delta):
	chunk_agent_generator(agents)

	if chunk_queue.size() > 0:
		if (waiting_for_compute ):
			fetch_and_process_compute_data()
		elif (waiting_for_meshthread):
			
			var posi = chunk_queue[0]
			create_mesh(posi)
		#create_mesh_collision(posi)
		elif (!waiting_for_compute && !waiting_for_meshthread):
		#var pos = chunk_queue.pop_front()
			run_compute(chunk_queue.pop_front()*chunk_scale)

	frame += 1
	time += delta



func get_pathing_curvature():
	#if chunks
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse : Vector2 = get_global_mouse_position()
		#print(surface_verts)
		queue_redraw()
		#update_chunk(mouse)


func update_chunk(pos)->void:
	### get position in voxel position
	#get_voxel_coords(pos)
	if chunks.has(pos):
		
		#chunks.erase(pos)
		pass
	pass

func chunk_agent_generator(agents:Array[Node2D]):
### queue chunk for generation\
	for agent in agents:

		var agent_pos : Vector2 = get_chunk_coords(agent.global_position)

		for x in range(agent_pos.x - renderDistance, agent_pos.x + renderDistance + 1):
			for y in range(agent_pos.y - renderDistance, agent_pos.y + renderDistance + 1):
				var chunkPos = Vector2(x, y)
				if !chunks.has(chunkPos):
					#if not processed_chunks.has(chunkPos):
					#if chunk_queue.size() == 0:
						#chunk_queue.append(chunkPos)  # Add chunk to queue
					chunk_queue.append(chunkPos)  # Add chunk to queue
					chunks[chunkPos] = 0

	pass

func init_compute():
	rendering_device= RenderingServer.create_local_rendering_device()
	# Load compute shader
	var shader_file : RDShaderFile = load("res://compute2d/#[compute]2D.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rendering_device.shader_create_from_spirv(shader_spirv)
	
	# Create triangles buffer
	const max_tris_per_voxel : int = 5
	const max_triangles : int = max_tris_per_voxel * int(pow(num_voxels_per_axis, 3))
	const bytes_per_float : int = 4
	const floats_per_triangle : int = 4 * 3
	const bytes_per_triangle : int = floats_per_triangle * bytes_per_float
	const max_bytes : int = bytes_per_triangle * max_triangles
	
	triangle_buffer = rendering_device.storage_buffer_create(max_bytes)
	var triangle_uniform = RDUniform.new()
	triangle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	triangle_uniform.binding = triangle_bind_index
	triangle_uniform.add_id(triangle_buffer)
	
	# Create params buffer
	var params_array = get_params_array(agents[0].global_position + Vector2(200,0))
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rendering_device.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	#var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	params_buffer = rendering_device.storage_buffer_create(params_bytes.size(), params_bytes)
	var params_uniform = RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = params_bind_index
	params_uniform.add_id(params_buffer)
	
	# Create counter buffer
	var counter = [0]
	var counter_bytes = PackedFloat32Array(counter).to_byte_array()
	counter_buffer = rendering_device.storage_buffer_create(counter_bytes.size(), counter_bytes)
	var counter_uniform = RDUniform.new()
	counter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counter_uniform.binding = counter_bind_index
	counter_uniform.add_id(counter_buffer)

	var counter2 = [0]
	var matcounter_bytes = PackedFloat32Array(counter2).to_byte_array()
	mat_counter_buffer = rendering_device.storage_buffer_create(matcounter_bytes.size(), matcounter_bytes)
	var matcounter_uniform = RDUniform.new()
	matcounter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	matcounter_uniform.binding = Matcounter_bind_index
	matcounter_uniform.add_id(mat_counter_buffer)

	# Create lut buffer
	var lut = load_lut("res://compute2d/MarchingCubesLUT2D.txt")
	var lut_bytes = PackedInt32Array(lut).to_byte_array()
	lut_buffer = rendering_device.storage_buffer_create(lut_bytes.size(), lut_bytes)
	var lut_uniform = RDUniform.new()
	lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	lut_uniform.binding = lut_bind_index
	lut_uniform.add_id(lut_buffer)

	var surface_lut = load_lut("res://compute2d/SurfaceLUT.txt")
	var surface_lut_bytes = PackedInt32Array(surface_lut).to_byte_array()
	surface_lut_buffer = rendering_device.storage_buffer_create(surface_lut_bytes.size(), surface_lut_bytes)
	var surface_lut_uniform = RDUniform.new()
	surface_lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	surface_lut_uniform.binding = surface_lut_bind_index
	surface_lut_uniform.add_id(surface_lut_buffer)

	# Create matrix buffer
	#var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	matrix_buffer = rendering_device.storage_buffer_create(195000)
	var matrix_uniform = RDUniform.new()
	matrix_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	matrix_uniform.binding = matrix_bind_index
	matrix_uniform.add_id(matrix_buffer)

	#var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	surface_buffer = rendering_device.storage_buffer_create(5000)
	var surface_uniform = RDUniform.new()
	surface_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	surface_uniform.binding = surface_bind_index
	surface_uniform.add_id(surface_buffer)

	# Create buffer setter and pipeline
	var buffers = [triangle_uniform, params_uniform, counter_uniform, lut_uniform, 
	matrix_uniform, surface_uniform, surface_lut_uniform, matcounter_uniform]
	buffer_set = rendering_device.uniform_set_create(buffers, shader, buffer_set_index)
	pipeline = rendering_device.compute_pipeline_create(shader)
	
func run_compute(pos : Vector2):
	# Update params buffer
	var params_array = get_params_array(pos)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	#rendering_device.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	# ...
	#var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	rendering_device.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	# Reset counter
	var counter = [0]
	var counter_bytes = PackedFloat32Array(counter).to_byte_array()
	rendering_device.buffer_update(counter_buffer,0,counter_bytes.size(), counter_bytes)

	var MATcounter = [0]
	var MATcounter_bytes = PackedFloat32Array(MATcounter).to_byte_array()
	rendering_device.buffer_update(mat_counter_buffer,0,MATcounter_bytes.size(), MATcounter_bytes)


	# Prepare compute list
	var compute_list = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, buffer_set, buffer_set_index)
	rendering_device.compute_list_dispatch(compute_list, resolution, resolution, resolution)
	rendering_device.compute_list_end()
	
	# Run
	rendering_device.submit()
	last_compute_dispatch_frame = frame
	waiting_for_compute = true

func fetch_and_process_compute_data():
	rendering_device.sync()
	waiting_for_compute = false
	# Get output
	triangle_data_bytes = rendering_device.buffer_get_data(triangle_buffer)
	counter_data_bytes = rendering_device.buffer_get_data(counter_buffer)
	MATcounter_data_bytes = rendering_device.buffer_get_data(mat_counter_buffer)
	surface_data_bytes = rendering_device.buffer_get_data(surface_buffer)#.to_float32_array()
	thread = Thread.new()
	thread.start(process_mesh_data)
	waiting_for_meshthread = true
	last_meshthread_start_frame = frame
	
func process_mesh_data():
	var triangle_data = triangle_data_bytes.to_float32_array()
	num_triangles = counter_data_bytes.to_int32_array()[0]
	var num_verts : int = num_triangles * 3
	verts.resize(num_verts)
	
	for tri_index in range(num_triangles):
		var i = tri_index * 6 # Changed from 16 to 6 for 2D
		var posA = Vector2(triangle_data[i + 0], triangle_data[i + 1])
		var posB = Vector2(triangle_data[i + 2], triangle_data[i + 3])
		var posC = Vector2(triangle_data[i + 4], triangle_data[i + 5])
		verts[tri_index * 3 + 0] = posA
		verts[tri_index * 3 + 1] = posB
		verts[tri_index * 3 + 2] = posC
		# No normals needed for 2D, so I removed the normals part
	### now for the surface
	var surface_data = surface_data_bytes.to_float32_array()
	num_vert_lines = MATcounter_data_bytes.to_int32_array()[0]
	#var num_lines : int = num_vert_lines * 2
	#surface_verts.resize(num_Surfverts)
	#print(surface_data)
	for i in range(550):
		#var i = line_index * 2 # Changed from 16 to 6 for 2D
		var posA = Vector2(surface_data[i] , surface_data[i + 1])
		#var posB = Vector2(surface_data[i + 4], surface_data[i + 5])
		surface_verts.append(posA)
		#surface_verts[line_index * 2 + 1] = posB


var processed_chunks = {}  # Dictionary to keep track of processed chunks



func create_mesh(posi : Vector2):
	#thread.wait_to_finish()
	waiting_for_meshthread = false
	matrix = rendering_device.buffer_get_data(matrix_buffer).to_float32_array()
	tris = triangle_data_bytes#rendering_device.buffer_get_data(triangle_buffer).to_float32_array()
	var array_mesh = ArrayMesh.new()
	var m : MeshInstance2D = mesh_path.instantiate()
	add_child(m)
	m.name= str(posi)
	m.mesh = array_mesh
	#mesh = array_mesh

	if len(verts) > 0:
		var mesh_data = []
		mesh_data.resize(Mesh.ARRAY_MAX)
		mesh_data[Mesh.ARRAY_VERTEX] = verts
		mesh_data[Mesh.ARRAY_TEX_UV] = verts
		#mesh_data[Mesh.ARRAY_NORMAL] = normals
		var mat : CanvasItemMaterial = CanvasItemMaterial.new()
		#mat.albedo_texture = 
		array_mesh.clear_surfaces()
		array_mesh.surface_set_material(0, mat)
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)




func get_params_array(pos: Vector2):
	var params = []
	#for agent in agents:
	params.append(time)
	params.append(noise_scale)
	params.append(iso_level)
	params.append(float(num_voxels_per_axis))
	params.append(chunk_scale)
	params.append(pos.x +200)
	params.append(pos.y)
	#params.append(agent.position.z)
	params.append(noise_offset.x)
	params.append(noise_offset.y)
		#params.append(noise_offset.z)
	return params

func load_lut(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var index_strings = text.split(',')
	var indices = []
	for s in index_strings:
		indices.append(int(s))
		
	return indices
	
	
func _notification(type):
	if type == NOTIFICATION_PREDELETE:
		release()

func release():
	rendering_device.free_rid(pipeline)
	rendering_device.free_rid(triangle_buffer)
	rendering_device.free_rid(params_buffer)
	rendering_device.free_rid(counter_buffer);
	rendering_device.free_rid(lut_buffer);
	rendering_device.free_rid(shader)
	
	pipeline = RID()
	triangle_buffer = RID()
	params_buffer = RID()
	counter_buffer = RID()
	lut_buffer = RID()
	shader = RID()
		
	rendering_device.free()
	rendering_device= null



func _draw() -> void:


#// EDGES
#//   0----1----2----
#//   |         |
#//   3         4
#//   |         |
#//   5----6----7----


		#draw_line(Vector2(chunkPos.x * chunkWidth, chunkPos.y * chunkWidth), Vector2(chunkPos.x * chunkWidth, (chunkPos.y + 1) * chunkWidth), Color.BLACK, line_size)

	var zoom = get_viewport().get_camera_2d().zoom  # for 2D cameras

	if surface_verts:
		#print(surface_verts[0]) // prints a vec2
		for i in surface_verts.size():
			draw_circle(surface_verts[i], 32, Color.YELLOW_GREEN)
			#draw_line(surface_verts[i], surface_verts[i-1], Color.AQUA, 32)
			pass
			#draw_line(Vector2(chunk_scale/4, chunk_scale/2), Vector2(chunk_scale, chunk_scale/2), Color.AQUA, line_size)

func get_chunk_coords(pos: Vector2) -> Vector2:
	return Vector2(floor((pos.x + chunk_scale/2) / chunk_scale), 
				   floor((pos.y + chunk_scale/2) / chunk_scale))



func get_normalized_values(pos : Vector2)-> Vector2:
	var value : Vector2
	
	return value

### doesnt work correctlly restart using the ai
func get_voxel_coords(mouse_pos: Vector2) -> Vector2:
	### Get the coord
	var normalized_x = (mouse_pos.x / chunk_scale) - 0.5
	var normalized_y = (mouse_pos.y / chunk_scale) - 0.5
	var voxel_x = round((normalized_x * num_voxels_per_axis))
	var voxel_y = round((normalized_y * num_voxels_per_axis))

	### Get the world position
	var cell_size = chunk_scale / num_voxels_per_axis
	var centre_snapped_x = int((mouse_pos.x / cell_size) + 0.5) * cell_size
	var centre_snapped_y = int(((mouse_pos.y / chunk_scale) - 0.5) * num_voxels_per_axis + 0.5) * cell_size
	var centre_snapped = Vector2(centre_snapped_x, centre_snapped_y)

	var pos_norm = Vector2(voxel_x, voxel_y) / num_voxels_per_axis - Vector2(0.5, 0.5)
	var world_pos = pos_norm * chunk_scale + centre_snapped

	return world_pos
