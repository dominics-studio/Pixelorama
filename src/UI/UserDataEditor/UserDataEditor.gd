class_name UserDataEditor

extends PanelContainer

enum UserDataContainer { CEL, FRAME, LAYER, ANIMATION_TAG, PROJECT, TILESET }

var dirty: bool = false
var current_container_type: UserDataContainer
var current_container: Object

@onready var option_button = %OptionButton as OptionButton
@onready var text_edit = %TextEdit as TextEdit


func _ready() -> void:
	Global.project_about_to_switch.connect(_before_project_switch)
	Global.project_switched.connect(_after_project_switch)
	Global.pixelorama_about_to_close.connect(save)
	Global.current_project.about_to_serialize.connect(save)
	Global.cel_switched.connect(refresh)

	await Global.pixelorama_opened

	current_container_type = map_container_type(option_button.get_item_id(option_button.selected))
	current_container = find_container(current_container_type)


func _before_project_switch() -> void:
	if Global.current_project.about_to_serialize.is_connected(save):
		Global.current_project.about_to_serialize.disconnect(save)


func _after_project_switch() -> void:
	if not Global.current_project.about_to_serialize.is_connected(save):
		Global.current_project.about_to_serialize.connect(save)
	refresh()


func refresh() -> void:
	if visible or dirty:
		save()
		current_container = find_container(current_container_type)
		load_from_container(current_container)


func save() -> void:
	if dirty:
		sync_to_container(current_container)
		dirty = false


func sync_to_container(container: Object) -> void:
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		container.user_data = text_edit.text


func load_from_container(container: Object) -> void:
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		text_edit.editable = true
		text_edit.text = container.user_data
	else:
		text_edit.editable = false
		text_edit.text = &"No user_data to edit"


func find_container(type: UserDataContainer) -> Object:
	var project = Global.current_project
	var container: Object = null
	match type:
		UserDataContainer.CEL:
			var cell_indeces = project.selected_cels.get(0)  # [ [frame, layer], ... ]
			if cell_indeces is Array and cell_indeces.size() == 2:
				container = project.frames[cell_indeces[0]].cels[cell_indeces[1]]
		UserDataContainer.FRAME:
			container = project.frames[project.current_frame]
		UserDataContainer.LAYER:
			container = project.layers[project.current_layer]
		UserDataContainer.ANIMATION_TAG:
			for tag in project.animation_tags:
				if project.current_frame + 1 >= tag.from and project.current_frame + 1 <= tag.to:
					container = tag
		UserDataContainer.PROJECT:
			container = project
		UserDataContainer.TILESET:
			pass
	return container


func _on_text_edit_text_changed() -> void:
	dirty = true
	Global.current_project.has_changed = true


func _on_text_edit_focus_exited() -> void:
	save()


func _on_option_button_item_selected(index: int) -> void:
	current_container_type = map_container_type(option_button.get_item_id(index))
	refresh()


func map_container_type(option_button_selection: int) -> UserDataContainer:
	match option_button_selection:
		0:
			return UserDataContainer.CEL
		1:
			return UserDataContainer.FRAME
		2:
			return UserDataContainer.LAYER
		3:
			return UserDataContainer.ANIMATION_TAG
		4:
			return UserDataContainer.PROJECT
		_:
			return UserDataContainer.TILESET
