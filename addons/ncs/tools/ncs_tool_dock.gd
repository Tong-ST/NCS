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

	settings_box.add_child(_create_label(
			"Target Resource Class
			(Default: NCSEntityDataSet):")
	)
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

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	settings_box.add_child(spacer)

	var panel_container = PanelContainer.new()
	settings_box.add_child(panel_container)

	var notes_vbox = VBoxContainer.new()
	notes_vbox.add_theme_constant_override("separation", 4)
	panel_container.add_child(notes_vbox)

	var lbl_flow_hdr = _create_label(" NOTE:")
	lbl_flow_hdr.add_theme_color_override("font_color", Color.YELLOW)
	notes_vbox.add_child(lbl_flow_hdr)
	notes_vbox.add_child(_create_label("• Exported folders are hidden from Godot"))
	notes_vbox.add_child(_create_label("• Open .CSV with others apps e.g. Excel"))
	notes_vbox.add_child(_create_label(
			"• Support only spreadsheet friendly
			for complex data better edit in Godot")
	)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 2
	notes_vbox.add_child(spacer2)

	var lbl_data_hdr = _create_label(" DATA-Types:")
	lbl_data_hdr.add_theme_color_override("font_color", Color.YELLOW)

	var lbl_safe = _create_label(
		"Support (Synced): Int, Float, Bool, String, Enums, Vector2/3/4, Rect2, Color and Array/Dict with simple type above"
	)
	lbl_safe.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_safe.add_theme_color_override("font_color", Color.GREEN)
	notes_vbox.add_child(lbl_safe)

	var lbl_unsafe = _create_label(
		"Unsupport (Ignored): Objects, Textures, PackedScenes, Sub-Resources"
	)
	lbl_unsafe.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_unsafe.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	notes_vbox.add_child(lbl_unsafe)

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
