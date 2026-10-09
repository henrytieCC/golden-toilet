extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var viewer = load("res://viewer.gd").new()
	root.add_child(viewer)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../interactive_preview.png"))
	viewer.trigger_flush()
	await create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../nitrogen_preview.png"))
	print("INTERACTIVE_PREVIEW_SAVED")
	quit()
