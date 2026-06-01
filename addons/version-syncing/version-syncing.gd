@tool
extends EditorPlugin

var exporter

func _enter_tree():
	exporter = load("res://addons/version-syncing/plugin.gd").new()
	add_export_plugin(exporter)

func _exit_tree():
	remove_export_plugin(exporter)
	exporter = null
