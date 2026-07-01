class_name UserDataEditor
extends PanelContainer

# These must match the item order set on the OptionButton in Inspector
enum UserDataContainerType { CEL = 0, FRAME = 1, LAYER = 2, ANIMATION_TAG = 3, PROJECT = 4, TILESET = 5 }

class UserDataBox:
	var container: Object
	var container_type: UserDataContainerType
	var dirty: bool = false
	var name: String = ""
	
	func _init(object: Object, type: UserDataContainerType, _name: String = "") -> void:
		container = object
		container_type = type
		name = _name
	
	func equals(other: UserDataBox) -> bool:
		return other != null and container == other.container

class ProjectState:
	var selected_type: UserDataContainerType
	var pinned_box: UserDataBox


var state: Dictionary[Project, ProjectState]
var current_box: UserDataBox


@onready var option_button = %OptionButton as OptionButton
@onready var main_text_edit = %MainTextEdit as TextEdit
@onready var pinned_text_edit = %PinnedTextEdit as TextEdit

@onready var pin_button = %PinButton as Button
@onready var unpin_button = %UnpinButton as Button


func _ready() -> void:
	Global.project_about_to_switch.connect(_before_project_switch)
	Global.project_switched.connect(_after_project_switch)
	Global.pixelorama_about_to_close.connect(save)
	Global.current_project.about_to_serialize.connect(save)
	Global.cel_switched.connect(_cel_switched)
	visibility_changed.connect(refresh_view)

	await Global.pixelorama_opened

	var selected_container_type := option_button.selected as UserDataContainerType
	current_box = find_container(selected_container_type, Global.current_project)
	
	state[Global.current_project] = ProjectState.new()
	state[Global.current_project].selected_type = selected_container_type


func _before_project_switch() -> void:
	if Global.current_project.about_to_serialize.is_connected(save):
		Global.current_project.about_to_serialize.disconnect(save)

	save()

func _after_project_switch() -> void:
	if not Global.current_project.about_to_serialize.is_connected(save):
		Global.current_project.about_to_serialize.connect(save)
		
	if not state.has(Global.current_project):
		state[Global.current_project] = ProjectState.new()
		state[Global.current_project].selected_type = option_button.selected as UserDataContainerType
	
	option_button.select(state[Global.current_project].selected_type as int)
	
	current_box = find_container(state[Global.current_project].selected_type, Global.current_project)
	
	refresh_view()


func _cel_switched() -> void:
	save()
	current_box = find_container(state[Global.current_project].selected_type, Global.current_project)
	refresh_view()


func refresh_view() -> void:
	if not visible:
		return
	
	var st := state[Global.current_project]

	save()

	# Pinned box
	if st.pinned_box != null:
		pinned_text_edit.visible = true
		pin_button.disabled = true
		load_text_from_container(pinned_text_edit, st.pinned_box.container)
		unpin_button.text = "Unpin %s" % st.pinned_box.name
		unpin_button.visible = true
	else:
		pinned_text_edit.visible = false
		pin_button.disabled = false
		pinned_text_edit.text = ""
		unpin_button.visible = false


	# Main box
	main_text_edit.editable = current_box != null
	
	if current_box and not current_box.equals(st.pinned_box):
		load_text_from_container(main_text_edit, current_box.container)
		main_text_edit.visible = true
	else:
		main_text_edit.visible = false


func save() -> void:
	var st := state[Global.current_project]
	
	if st.pinned_box and st.pinned_box.dirty:
		save_text_to_container(pinned_text_edit, st.pinned_box.container)
		st.pinned_box.dirty = false
	
	if current_box and current_box.dirty:
		save_text_to_container(main_text_edit, current_box.container)
		current_box.dirty = false


func save_text_to_container(text_edit: TextEdit, container: Object) -> void:
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		container.user_data = text_edit.text


func load_text_from_container(text_edit: TextEdit, container: Object) -> void:
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		text_edit.editable = true
		text_edit.text = container.user_data
	else:
		text_edit.editable = false
		text_edit.text = &"No user_data to edit"


func find_container(type: UserDataContainerType, project: Project) -> UserDataBox:
	var box: UserDataBox = null
	match type:
		UserDataContainerType.CEL:
			var cell_indeces = project.selected_cels.get(0)  # [ [frame, layer], ... ]
			if cell_indeces is Array and cell_indeces.size() == 2:
				var container = project.frames[cell_indeces[0]].cels[cell_indeces[1]]
				box = UserDataBox.new(container, type, "Cel %d-%d" % [cell_indeces[0], cell_indeces[1]])
		UserDataContainerType.FRAME:
			var container = project.frames[project.current_frame]
			box = UserDataBox.new(container, type, "Frame %d" % [project.current_frame + 1])
		UserDataContainerType.LAYER:
			var container = project.layers[project.current_layer]
			box = UserDataBox.new(container, type, "Layer %d" % [project.current_layer + 1])
		UserDataContainerType.ANIMATION_TAG:
			for tag in project.animation_tags:
				if project.current_frame + 1 >= tag.from and project.current_frame + 1 <= tag.to:
					var container = tag
					box = UserDataBox.new(container, type, tag.name)
			# return null if no animation tag, won't be shown or editable
		UserDataContainerType.PROJECT:
			var container = project
			box = UserDataBox.new(container, type, project.name)
		UserDataContainerType.TILESET:
			pass
	return box



func _on_pinned_text_edit_text_changed() -> void:
	var st := state[Global.current_project]
	if st.pinned_box:
		st.pinned_box.dirty = true 
	if not Global.current_project.has_changed:
		Global.current_project.has_changed = true


func _on_text_edit_text_changed() -> void:
	if current_box:
		current_box.dirty = true
		if not Global.current_project.has_changed:
			Global.current_project.has_changed = true


func _on_option_button_item_selected(index: int) -> void:
	state[Global.current_project].selected_type = index as UserDataContainerType
	save()
	current_box = find_container(state[Global.current_project].selected_type, Global.current_project)
	refresh_view()


func _on_pin_button_pressed() -> void:
	state[Global.current_project].pinned_box = current_box
	refresh_view()


func _on_unpin_button_pressed() -> void:
	save()
	state[Global.current_project].pinned_box = null
	refresh_view()
