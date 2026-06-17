@tool
extends EditorExportPlugin

func _get_name():
	return "VersionSync"

func _export_begin(features, is_debug, path, flags):
	var file = FileAccess.open("res://version.txt", FileAccess.READ)
	if file:
		var version = file.get_as_text().strip_edges()
		ProjectSettings.set_setting("application/config/version", version)
		ProjectSettings.save()
		print("VersionSync: set version to ", version)
