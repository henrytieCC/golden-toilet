extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not ResourceLoader.exists("res://viewer.gd") or not ResourceLoader.exists("res://assets/golden_toilet.glb"):
		printerr("FAIL: interactive viewer and hinged model are missing")
		quit(1)
		return
	assert(ResourceLoader.exists("res://assets/studio.exr"), "Studio HDR failed to import")
	var viewer = load("res://viewer.gd").new()
	root.add_child(viewer)
	await process_frame
	assert(viewer.lid != null and viewer.seat != null, "Missing hinged parts")
	viewer.set_lid(false)
	await create_timer(0.85).timeout
	assert(abs(viewer.lid.rotation.x) < 0.01, "Lid does not close")
	viewer.set_seat(true)
	await create_timer(0.85).timeout
	assert(viewer.lid.rotation.x < -1.6, "Opening seat must first open lid")
	assert(viewer.seat.rotation.x < -1.4, "Seat does not open")
	viewer.set_lid(false)
	await create_timer(0.85).timeout
	assert(abs(viewer.seat.rotation.x) < 0.01, "Closing lid must lower seat")
	assert(abs(viewer.lid.rotation.x) < 0.01, "Lid close failed after seat open")
	viewer.set_lid(true)
	viewer.set_lid(false)
	viewer.set_lid(true)
	await create_timer(0.85).timeout
	assert(viewer.lid.rotation.x < -1.6, "Rapid clicks leave wrong lid state")
	viewer.zoom_by(-1000)
	assert(viewer.distance >= 0.9, "Zoom clips inside model")
	viewer.zoom_by(1000)
	assert(viewer.distance <= 3.5, "Zoom exceeds useful range")
	if not viewer.has_method("trigger_flush"):
		printerr("FAIL: liquid nitrogen interaction is missing")
		quit(1)
		return
	viewer.set_lid(false)
	await create_timer(0.85).timeout
	var flush_lid_angle: float = viewer.lid.rotation.x
	var flush_seat_angle: float = viewer.seat.rotation.x
	assert(viewer.trigger_flush(), "Nitrogen flush must start")
	assert(viewer.is_flushing, "Flush state must become active")
	assert(not viewer.trigger_flush(), "Repeated flush clicks must not stack effects")
	await create_timer(0.95).timeout
	assert(abs(viewer.lid.rotation.x - flush_lid_angle) < 0.01 and abs(viewer.seat.rotation.x - flush_seat_angle) < 0.01, "Flush must preserve the lid and seat positions")
	assert(viewer.nitrogen.streams.visible and viewer.nitrogen.mist.emitting, "Liquid and vapor must appear")
	await create_timer(4.2).timeout
	assert(not viewer.is_flushing and not viewer.nitrogen.visible, "Nitrogen effect must finish and clear")
	viewer.queue_free()
	await process_frame
	await process_frame
	print("PASS: import, lid/seat interlock, rapid clicks, zoom, nitrogen flow/vapor and effect cleanup")
	quit(0)
