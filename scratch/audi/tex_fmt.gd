extends SceneTree
func _initialize() -> void:
	for path: String in ["res://assets/cars/audi_r8/textures/base_color.png", "res://assets/cars/audi_r8/textures/normal.png", "res://assets/cars/porsche_911/textures/base_color.jpg", "res://assets/cars/porsche_911/textures/normal.png"]:
		var img: Image = (load(path) as Texture2D).get_image()
		print("TFMT ", path.get_file(), " format ", img.get_format(), " mipmaps ", img.has_mipmaps(), " bytes ", img.get_data().size())
	quit(0)
