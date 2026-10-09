extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var viewer = load("res://viewer.gd").new()
	root.add_child(viewer)
	await process_frame
	for pose in ["raised", "lowered", "in motion"]:
		viewer.set_seat(pose != "lowered")
		viewer.set_lid(pose != "lowered")
		await create_timer(0.18 if pose == "in motion" else 0.85).timeout
		var original_angle: float = viewer.seat.rotation.x
		var original_state: bool = viewer.seat_open
		var original_lid_angle: float = viewer.lid.rotation.x
		var original_lid_state: bool = viewer.lid_open
		var original_yaw: float = viewer.yaw
		viewer.auto_rotate = true
		if not viewer.trigger_flush():
			printerr("FAIL: flush did not start")
			quit(1)
			return
		# Clicking the 3D seat must also leave it still throughout the effect.
		viewer.set_seat(not original_state)
		viewer.set_lid(not original_lid_state)
		while viewer.is_flushing:
			if abs(viewer.seat.rotation.x - original_angle) > 0.0001 or viewer.seat_open != original_state:
				printerr("FAIL: nitrogen flush moves seat from ", pose, " pose")
				quit(1)
				return
			if abs(viewer.lid.rotation.x - original_lid_angle) > 0.0001 or viewer.lid_open != original_lid_state:
				printerr("FAIL: nitrogen flush moves lid from ", pose, " pose")
				quit(1)
				return
			if abs(viewer.yaw - original_yaw) > 0.0001:
				printerr("FAIL: automatic rotation continues during nitrogen flush")
				quit(1)
				return
			await process_frame
		if abs(viewer.seat.rotation.x - original_angle) > 0.0001 or abs(viewer.lid.rotation.x - original_lid_angle) > 0.0001:
			printerr("FAIL: hinged parts moved at flush completion")
			quit(1)
			return
	viewer.queue_free()
	await process_frame
	print("PASS: nitrogen flush preserves both hinge angles and pauses automatic rotation")
	quit(0)
