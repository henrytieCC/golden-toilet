extends Node3D

signal finished
var active := false
var elapsed := 0.0
var streams: Node3D
var mist: CPUParticles3D
var spill: CPUParticles3D
var liquid: MeshInstance3D
var cold_light: OmniLight3D
var ripples: Array[MeshInstance3D] = []

func _ready() -> void:
	visible = false
	var fluid := StandardMaterial3D.new()
	fluid.albedo_color = Color(0.60, 0.85, 1.0, 0.65)
	fluid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fluid.metallic = 0.12
	fluid.roughness = 0.12
	fluid.emission_enabled = true
	fluid.emission = Color(0.05, 0.15, 0.21)
	streams = Node3D.new()
	add_child(streams)
	for i in range(16):
		var angle := TAU * i / 16.0
		var origin := Vector3(0.145*cos(angle), 0.423, 0.13+0.203*sin(angle))
		var end := Vector3(0.097*cos(angle), 0.322, 0.13+0.144*sin(angle))
		var direction := end - origin
		var jet := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.0028
		tube.bottom_radius = 0.0042
		tube.height = direction.length()
		tube.radial_segments = 12
		jet.mesh = tube
		jet.material_override = fluid
		jet.position = (origin + end) / 2
		jet.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
		streams.add_child(jet)
	liquid = MeshInstance3D.new()
	var pool := CylinderMesh.new()
	pool.top_radius = 1
	pool.bottom_radius = 1
	pool.height = 0.005
	pool.radial_segments = 96
	liquid.mesh = pool
	liquid.material_override = fluid
	liquid.position = Vector3(0, 0.326, 0.13)
	liquid.scale = Vector3(0.100, 1, 0.143)
	add_child(liquid)
	for i in range(3):
		var ripple := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.94
		ring.outer_radius = 1.0
		ring.rings = 48
		ring.ring_segments = 8
		ripple.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.82, 0.95, 1.0, 0.5)
		ripple.material_override = mat
		ripple.position = Vector3(0, 0.335, 0.13)
		add_child(ripple)
		ripples.append(ripple)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(0.94,0.98,1,0.70), Color(0.94,0.98,1,0.40), Color(0.94,0.98,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 64
	texture.height = 64
	var cloud := StandardMaterial3D.new()
	cloud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud.albedo_texture = texture
	cloud.albedo_color = Color(1,1,1,0.62)
	mist = vapor(cloud, 74, Vector3(0,0.390,0.13), Vector3(0.100,0.006,0.14))
	mist.direction = Vector3.UP
	mist.initial_velocity_min = 0.05
	mist.initial_velocity_max = 0.15
	mist.gravity = Vector3(0,-0.04,0)
	spill = vapor(cloud, 54, Vector3(0,0.420,0.16), Vector3(0.16,0.01,0.20))
	spill.direction = Vector3(0,0,1)
	spill.initial_velocity_min = 0.07
	spill.initial_velocity_max = 0.12
	spill.gravity = Vector3(0,-0.11,0)
	cold_light = OmniLight3D.new()
	cold_light.position = Vector3(0,0.39,0.13)
	cold_light.light_color = Color(0.50,0.79,1)
	cold_light.omni_range = 0.5
	cold_light.light_energy = 0
	add_child(cold_light)

func vapor(material: Material, amount: int, origin: Vector3, box: Vector3) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 1.5
	particles.randomness = 0.45
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = box
	particles.spread = 75
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.8
	var growth := Curve.new()
	growth.add_point(Vector2(0,0.25))
	growth.add_point(Vector2(0.5,1.0))
	growth.add_point(Vector2(1,1.5))
	particles.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.15,0.6,1.0])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,1),Color(1,1,1,0.85),Color(1,1,1,0)])
	particles.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11,0.11)
	quad.material = material
	particles.mesh = quad
	particles.position = origin
	add_child(particles)
	return particles

func start() -> bool:
	if active:
		return false
	active = true
	elapsed = 0
	visible = true
	streams.visible = false
	liquid.visible = false
	mist.emitting = false
	spill.emitting = false
	return true

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var pouring := elapsed > 0.6 and elapsed < 3.0
	streams.visible = pouring
	liquid.visible = elapsed > 0.65 and elapsed < 4.4
	mist.emitting = pouring
	spill.emitting = elapsed > 0.85 and elapsed < 3.2
	var fill := clampf((elapsed - 0.6) / 1.6, 0, 1)
	liquid.position.y = 0.310 + fill * 0.025
	liquid.scale = Vector3(0.073+fill*0.030,1,0.108+fill*0.041)
	cold_light.light_energy = minf(clampf((elapsed-0.6)*2,0,1),clampf((4.8-elapsed)/1.8,0,1))*0.65
	for i in range(ripples.size()):
		var ring_phase := fposmod(elapsed*0.8 + i/3.0, 1.0)
		var ripple := ripples[i]
		ripple.visible = liquid.visible
		ripple.position.y = liquid.position.y + 0.004
		ripple.scale = Vector3(liquid.scale.x*ring_phase,0.025,liquid.scale.z*ring_phase)
		ripple.material_override.albedo_color.a = (1-ring_phase)*0.45
	if elapsed >= 4.8:
		active = false
		visible = false
		cold_light.light_energy = 0
		finished.emit()
