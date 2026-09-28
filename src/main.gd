extends Node2D
## Boot scene. For now it only proves the project starts; the game's real
## entry point replaces this when there is a level to load.


func _ready() -> void:
	print("Slime Train booted (Godot %s)." % Engine.get_version_info().string)
