extends Node3D

var lid: Node3D
var seat: Node3D
var camera: Camera3D
var lid_open := true
var seat_open := false
var distance := 1.65
var yaw := 0.68
var pitch := 0.24
var auto_rotate := false
var dragging := false
var drag_length := 0.0
var pose_tween: Tween
var lid_button: Button
var seat_button: Button
var rotate_button: Button
var status: Label
var font: SystemFont
var nitrogen: Node3D
var is_flushing := false
var nitrogen_button: Button
const TARGET := Vector3(0, 0.47, 0)

func _ready() -> void:
	var model = load("res://assets/golden_toilet.glb").instantiate()
	add_child(model)
	lid = model.find_child("LidPivot", true, false)
	seat = model.find_child("SeatPivot", true, false)
	assert(lid != null and seat != null, "GLB must include the two hinge pivots")
	lid.rotation.x = deg_to_rad(-98)
	seat.rotation.x = 0
	add_pick_colliders(model)
	nitrogen = load("res://nitrogen_effect.gd").new()
	add_child(nitrogen)
	nitrogen.finished.connect(func(): is_flushing = false; refresh_buttons())
	build_studio()
	build_interface()
	update_camera()

func add_pick_colliders(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D:
			add_pick_colliders(child)

func build_studio() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bdbfb7")
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/studio.exr")
	sky.sky_material = panorama
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = 2 # Sky reflections in Godot 4.3.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.position.y = -0.003
	var ground_material := ShaderMaterial.new()
	ground_material.shader = load("res://studio_floor.gdshader")
	ground.material_override = ground_material
	add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -35, 0)
	light.light_color = Color(1, 0.97, 0.90)
	light.light_energy = 0.65
	light.shadow_enabled = false
	light.directional_shadow_max_distance = 6
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.1, 1.3, 1.0)
	fill.light_energy = 0.3
	fill.omni_range = 4
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 42
	camera.near = 0.02
	camera.far = 50
	camera.h_offset = -0.20
	add_child(camera)
	camera.make_current()

func panel_style(color: Color, border: Color, radius := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func text_label(copy: String, size: int, color: Color = Color("ede8db")) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func button(copy: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = copy
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_stylebox_override("normal", panel_style(Color("30352e"), Color("4a4f42"), 10))
	b.add_theme_stylebox_override("hover", panel_style(Color("4a4832"), Color("c6a85f"), 10))
	b.add_theme_stylebox_override("pressed", panel_style(Color("615336"), Color("e1bc67"), 10))
	b.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, Color("dab46b"), 10))
	b.pressed.connect(action)
	return b

func build_interface() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	ui.theme = theme
	layer.add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(32, 40)
	panel.custom_minimum_size = Vector2(276, 0)
	panel.add_theme_stylebox_override("panel", panel_style(Color("1d221fe8"), Color("4a4d3d")))
	ui.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	panel.add_child(column)
	column.add_child(text_label("G O L D  /  0 1", 13, Color("dab46b")))
	column.add_child(text_label("金色坐便器", 29))
	column.add_child(text_label("360° 交互展示", 15, Color("a6aa9d")))
	var divider := HSeparator.new()
	column.add_child(divider)
	column.add_child(text_label("部件操作", 13, Color("a6aa9d")))
	lid_button = button("合上盖子    L", func(): set_lid(not lid_open))
	seat_button = button("抬起座圈    S", func(): set_seat(not seat_open))
	column.add_child(lid_button)
	column.add_child(seat_button)
	nitrogen_button = button("液氮冲洗    N", trigger_flush)
	column.add_child(nitrogen_button)
	column.add_child(text_label("观察角度", 13, Color("a6aa9d")))
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 7)
	column.add_child(views)
	for entry in [["正面", 0.0], ["侧面", PI/2], ["背面", PI]]:
		var angle: float = entry[1]
		var view_button := button(entry[0], func(): yaw = angle; auto_rotate = false; update_camera(); refresh_buttons())
		view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view_button.add_theme_font_size_override("font_size", 14)
		views.add_child(view_button)
	rotate_button = button("自动旋转    A", func(): auto_rotate = not auto_rotate; refresh_buttons())
	column.add_child(rotate_button)
	column.add_child(button("复位视角    R", reset_view))
	column.add_child(HSeparator.new())
	column.add_child(text_label("拖动  ·  旋转视角\n滚轮  ·  放大 / 缩小\n点击盖子或座圈  ·  开合", 14, Color("b0b3a5")))
	status = text_label("盖子已打开 · 座圈已放下", 12, Color("dab46b"))
	column.add_child(status)
	var footer := text_label("依据八视角参考图制作  /  金属光泽", 13, Color("586052"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.position = Vector2(-365, -43)
	footer.size = Vector2(333, 25)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)

func set_lid(open: bool) -> void:
	if is_flushing:
		return
	lid_open = open
	if not open:
		seat_open = false
	animate_pose()

func set_seat(open: bool) -> void:
	if is_flushing:
		return
	seat_open = open
	if open:
		lid_open = true
	animate_pose()

func animate_pose() -> void:
	if pose_tween:
		pose_tween.kill()
	pose_tween = create_tween().set_parallel(true)
	pose_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var lid_target := deg_to_rad(-98) if lid_open else 0.0
	var seat_target := deg_to_rad(-86) if seat_open else 0.0
	var lid_delay := 0.18 if not lid_open and abs(seat.rotation.x) > 0.01 else 0.0
	var seat_delay := 0.16 if seat_open and abs(lid.rotation.x) < 1.5 else 0.0
	pose_tween.tween_property(lid, "rotation:x", lid_target, 0.60).set_delay(lid_delay)
	pose_tween.tween_property(seat, "rotation:x", seat_target, 0.48).set_delay(seat_delay)
	refresh_buttons()

func refresh_buttons() -> void:
	lid_button.text = "合上盖子    L" if lid_open else "打开盖子    L"
	seat_button.text = "放下座圈    S" if seat_open else "抬起座圈    S"
	rotate_button.text = "停止旋转    A" if auto_rotate else "自动旋转    A"
	status.text = ("盖子已打开" if lid_open else "盖子已合上") + " · " + ("座圈已抬起" if seat_open else "座圈已放下")
	lid_button.disabled = is_flushing
	seat_button.disabled = is_flushing
	nitrogen_button.disabled = is_flushing
	nitrogen_button.text = "液氮冲洗中…" if is_flushing else "液氮冲洗    N"
	if is_flushing:
		status.text = "液氮流动 · 冷雾扩散"

func trigger_flush() -> bool:
	if is_flushing:
		return false
	# Freeze any ongoing hinge animation at its current position before the effect starts.
	if pose_tween:
		pose_tween.kill()
	is_flushing = nitrogen.start()
	refresh_buttons()
	return is_flushing

func zoom_by(amount: float) -> void:
	distance = clampf(distance + amount, 0.9, 3.5)
	update_camera()

func update_camera() -> void:
	pitch = clampf(pitch, -0.10, 1.18)
	camera.position = TARGET + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * distance
	camera.look_at(TARGET)

func reset_view() -> void:
	yaw = 0.68
	pitch = 0.24
	distance = 1.65
	auto_rotate = false
	update_camera()
	refresh_buttons()

func _process(delta: float) -> void:
	if auto_rotate and not dragging and not is_flushing:
		yaw += delta * 0.32
		update_camera()

func _input(event: InputEvent) -> void:
	# A release over the control panel must also end a drag started in the model area.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		if drag_length < 5 and get_viewport().gui_get_hovered_control() == null:
			pick_part(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(-0.10)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(0.10)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_length = 0
	elif event is InputEventMouseMotion and dragging:
		drag_length += event.relative.length()
		yaw -= event.relative.x * 0.007
		pitch += event.relative.y * 0.005
		update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L: set_lid(not lid_open)
			KEY_S: set_seat(not seat_open)
			KEY_N: trigger_flush()
			KEY_A: auto_rotate = not auto_rotate; refresh_buttons()
			KEY_R: reset_view()

func pick_part(screen_position: Vector2) -> void:
	var start := camera.project_ray_origin(screen_position)
	var end := start + camera.project_ray_normal(screen_position) * 10
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
	if hit.is_empty():
		return
	var part: Node = hit.collider
	while part:
		if part.name.to_lower().contains("flush"):
			trigger_flush()
			return
		if part == lid:
			set_lid(not lid_open)
			return
		if part == seat:
			set_seat(not seat_open)
			return
		part = part.get_parent()
