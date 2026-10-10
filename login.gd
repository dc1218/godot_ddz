extends Control

@onready var status_label: Label = $CenterPanel/Content/Status


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://game.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()