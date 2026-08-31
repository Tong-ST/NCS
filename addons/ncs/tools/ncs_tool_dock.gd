@tool
extends Control

var txt_scan_dir: LineEdit
var txt_csv_dir: LineEdit
var txt_target_class: LineEdit
var file_dialog: FileDialog
var current_picking_target: LineEdit


func _ready() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var tabs = TabContainer.new()
	margin.add_child(tabs)
	var tab_balancer = VBoxContainer.new()
	tab_balancer.name = "CSV Helper"
	tabs.add_child(tab_balancer)
	var settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 8)
	tab_balancer.add_child(settings_box)

	settings_box.add_child(_create_label("Target Resource Class (Default: NCSEntityDataSet):"))
	txt_target_class = LineEdit.new()
	txt_target_class.text = "NCSEntityDataSet"
	settings_box.add_child(txt_target_class)

	settings_box.add_child(_create_label("Select folder containing .tres:"))
	var row1 = HBoxContainer.new()
	txt_scan_dir = LineEdit.new()
	txt_scan_dir.text = "res://ncs_datasets/"
	txt_scan_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_browse1 = Button.new()
	btn_browse1.text = "Browse"
	btn_browse1.pressed.connect(_on_browse.bind(txt_scan_dir))
	row1.add_child(txt_scan_dir)
	row1.add_child(btn_browse1)
	settings_box.add_child(row1)

	settings_box.add_child(_create_label("Select folder to sync data from CSV:"))
	var row2 = HBoxContainer.new()
	txt_csv_dir = LineEdit.new()
	txt_csv_dir.text = "res://ncs_csv_exports/"
	txt_csv_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_browse2 = Button.new()
	btn_browse2.text = "Browse"
	btn_browse2.pressed.connect(_on_browse.bind(txt_csv_dir))
	row2.add_child(txt_csv_dir)
	row2.add_child(btn_browse2)
	settings_box.add_child(row2)

	settings_box.add_child(_create_label("After export, Open CSV with other apps e.g. excel"))
	settings_box.add_child(_create_label("Exported folder hidden from Godot by Default"))

	var sep = HSeparator.new()
	tab_balancer.add_child(sep)

	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 20)

	var btn_export = Button.new()
	btn_export.text = "  Export to CSV  "
	btn_export.pressed.connect(_on_export_pressed)

	var btn_import = Button.new()
	btn_import.text = "  Import from CSV  "
	btn_import.pressed.connect(_on_import_pressed)

	action_box.add_child(btn_export)
	action_box.add_child(btn_import)
	tab_balancer.add_child(action_box)

	var tab_future = Label.new()
	tab_future.name = "Entity Setup"
	tab_future.text = "(Coming soon...)"
	tab_future.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_future.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(tab_future)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.dir_selected.connect(_on_dir_selected)
	add_child(file_dialog)


func _create_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	return l


func _on_browse(target_input: LineEdit) -> void:
	current_picking_target = target_input
	file_dialog.current_dir = target_input.text
	file_dialog.popup_centered_ratio(0.5)


func _on_dir_selected(dir: String) -> void:
	if current_picking_target:
		current_picking_target.text = dir


func _on_export_pressed() -> void:
	var exporter = NCSDataExporter.new()
	var target = txt_target_class.text.strip_edges()
	if target.is_empty(): target = "NCSEntityDataSet"
	exporter.run_export(txt_scan_dir.text, txt_csv_dir.text, target)


func _on_import_pressed() -> void:
	var importer = NCSDataImporter.new()
	var target = txt_target_class.text.strip_edges()
	if target.is_empty(): target = "NCSEntityDataSet"
	importer.run_import(txt_csv_dir.text, target)

	var editor = EditorInterface.get_resource_filesystem()
	if editor: editor.scan()
