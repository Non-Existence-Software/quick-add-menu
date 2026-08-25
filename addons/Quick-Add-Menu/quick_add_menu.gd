'''~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'''
''' Copyright (c) 2025 Varrox                                                      '''
'''                                                                                '''
''' Permission is hereby granted, free of charge, to any person obtaining a copy   '''
''' of this software and associated documentation files (the "Software"), to deal  '''
''' in the Software without restriction, including without limitation the rights   '''
''' to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      '''
''' copies of the Software, and to permit persons to whom the Software is          '''
''' furnished to do so, subject to the following conditions:                       '''
'''                                                                                '''
''' The above copyright notice and this permission notice shall be included in all '''
''' copies or substantial portions of the Software.                                '''
'''                                                                                '''
''' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     '''
''' IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       '''
''' FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    '''
''' AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         '''
''' LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  '''
''' OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  '''
''' SOFTWARE.                                                                      '''
'''~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'''

@tool
class_name QuickAddMenu extends EditorPlugin

var menu_button:MenuButton
var parent_node:Node
var groups:Dictionary[int, PopupMenu]

static var item_instances:Dictionary[int, QuickAddItem]

const TOOLTIP = "Quick Add Child Node... (Ctrl+E)\nQuickly Add/Create a New Node."

const LOGO_PATH:String = "res://addons/Quick-Add-Menu/Icons/QuickAdd.svg"
const PLANE_MESH_ICON_PATH:String = "res://addons/Quick-Add-Menu/Icons/PlaneMesh.svg"
const PRISM_MESH_ICON_PATH:String = "res://addons/Quick-Add-Menu/Icons/PrismMesh.svg"
const TORUS_MESH_ICON_PATH:String = "res://addons/Quick-Add-Menu/Icons/TorusMesh.svg"

## Add custom items
func add_custom_items():
	# Add your own code
	pass

## Reimports icons
func _reimport_icons() -> void:
	# Code from here - https://forum.godotengine.org/t/manually-triggering-a-reimport-via-an-editorscript-results-in-progress-dialog-errors/123523/8
	
	var root = EditorInterface.get_base_control()
	root.get_tree().process_frame.connect(func():
		var file_system = EditorInterface.get_resource_filesystem()
		file_system.reimport_files([LOGO_PATH, PLANE_MESH_ICON_PATH, PRISM_MESH_ICON_PATH, TORUS_MESH_ICON_PATH])
	, CONNECT_ONE_SHOT)

func _enter_tree() -> void:
	add_custom_items()
	
	var top_container:HBoxContainer = _find_container()
	
	if top_container == null:
		print_rich('[color="yellow"]Quick Add button container not found. Unable to add Quick Add button to scene dock.[/color]')
		return
	
	_reimport_icons()
	
	menu_button = MenuButton.new()
	menu_button.theme_type_variation = &"FlatMenuButton"
	menu_button.icon = load(LOGO_PATH)
	menu_button.flat = false
	menu_button.tooltip_text = TOOLTIP
	
	top_container.add_child(menu_button)
	top_container.move_child(menu_button, 1)
	
	# Shortcut.
	
	menu_button.shortcut_context = top_container.get_parent()
	menu_button.shortcut = Shortcut.new()
	menu_button.shortcut_in_tooltip = false
	
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_E
	key_event.ctrl_pressed = true
	key_event.command_or_control_autoremap = true # Swaps Ctrl for Command on Mac.
	
	menu_button.shortcut.events = [key_event]

	# Finalize.
	
	menu_button.about_to_popup.connect(_update_add_list)
	menu_button.get_popup().close_requested.connect(_clear_id_signals)
	
	if EditorInterface.get_selection().get_selected_nodes().size() == 0:
		menu_button.hide()

## Delete [member menu_button].
func _exit_tree() -> void:
	if menu_button != null:
		menu_button.queue_free()
		menu_button = null

## Updates list of items to quick add.
func _update_add_list() -> void:
	menu_button.get_popup().clear()
	
	if parent_node == null:
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		if nodes.size() > 0:
			parent_node = nodes[0]
	
	var items:QuickAddItemList = get_quick_add_item_list(parent_node)
	
	if !items:
		push_error("No quick add item list found.")
		return
	
	groups = {0 : menu_button.get_popup()}
	
	for i in items.list:
		if i.header:
			groups[i.parent_group_id].add_separator(i.name, i.id)
		elif i.group:
			var popup:PopupMenu = PopupMenu.new()
			groups[i.parent_group_id].add_submenu_node_item(i.name, popup, i.group_id)
			groups[i.group_id] = popup
		else:
			groups[i.parent_group_id].add_icon_item(i.icon, i.name, i.id)
	
	for i:PopupMenu in groups.values():
		i.id_pressed.connect(_item_selected)

func _clear_id_signals():
	for i:PopupMenu in groups.values():
		i.id_pressed.disconnect(_item_selected)

## Gets an editor icon.
static func get_icon(icon:String) -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon(icon, "EditorIcons")

class QuickAddItem:
	var name:String
	var icon:Texture2D
	
	var header:bool = false
	
	var group:bool = false
	var group_id:int
	
	var spawn_callable:Callable
	
	var parent_group_id:int
	var id:int
	
	## Get a unique id for an instance.
	static func _get_new_id() -> int:
		var r = randi_range(0, 65536)
		if QuickAddMenu.item_instances.has(r):
			return _get_new_id()
		else:
			return r
	
	## Creates an item.
	func _init(name:String, icon:Texture2D, spawn_callable:Callable, parent_group_id:int = 0) -> void:
		self.name = name
		self.icon = icon
		self.spawn_callable = spawn_callable
		
		self.header = false
		self.group = false
		
		self.parent_group_id = parent_group_id
		self.id = _get_new_id()
		
		QuickAddMenu.item_instances[self.id] = self
	
	## Creates an header item.
	static func new_header(name:String, icon:Texture2D = null, parent_group_id:int = 0) -> QuickAddItem:
		var preset = QuickAddItem.new(name, icon, (func(): return false), parent_group_id)
		preset.header = true
		return preset
	
	## Creates an group item.
	static func new_group(name:String, group_id:int, parent_group_id:int = 0) -> QuickAddItem:
		var preset = QuickAddItem.new(name, null, (func(): return false), parent_group_id)
		preset.group = true
		preset.group_id = group_id
		return preset

class QuickAddItemList:
	var list:Array[QuickAddItem]
	
	func _init(list:Array[QuickAddItem]) -> void:
		self.list = list
	
	func append(quick_add_item:QuickAddItem) -> QuickAddItemList:
		list.append(quick_add_item)
		return self
	
	func append_list(quick_add_item:QuickAddItemList) -> QuickAddItemList:
		list.append_array(quick_add_item.list)
		return self

## Items for [Node3D]s.
static var node_3d_list:QuickAddItemList = QuickAddItemList.new([
	QuickAddItem.new_header("Primitive Shapes"),
	QuickAddItem.new("Plane", load("res://addons/Quick-Add-Menu/Icons/PlaneMesh.svg"), func(): return _create_primitive_3d(0)),
	QuickAddItem.new("Box", get_icon("BoxShape3D"), func(): return _create_primitive_3d(1)),
	QuickAddItem.new("Sphere", get_icon("SphereShape3D"), func(): return _create_primitive_3d(2)),
	QuickAddItem.new("Capsule", get_icon("CapsuleShape3D"), func(): return _create_primitive_3d(3)),
	QuickAddItem.new("Cylinder", get_icon("CylinderShape3D"), func(): return _create_primitive_3d(4)),
	QuickAddItem.new("Prism", load("res://addons/Quick-Add-Menu/Icons/PrismMesh.svg"), func(): return _create_primitive_3d(5)),
	QuickAddItem.new("Torus", load("res://addons/Quick-Add-Menu/Icons/TorusMesh.svg"), func(): return _create_primitive_3d(6)),
	QuickAddItem.new_header("CSGs"),
	QuickAddItem.new("Box CSG", get_icon("CSGBox3D"), func(): return _create_csg_3d(0)),
	QuickAddItem.new("Sphere CSG", get_icon("CSGSphere3D"), func(): return _create_csg_3d(1)),
	QuickAddItem.new("Cylinder CSG", get_icon("CSGCylinder3D"), func(): return _create_csg_3d(2)),
	QuickAddItem.new("Torus CSG", get_icon("CSGTorus3D"), func(): return _create_csg_3d(3)),
	QuickAddItem.new("CSG Combiner", get_icon("CSGCombiner3D"), func(): return _create_csg_3d(4)),
	QuickAddItem.new_header("General"),
	QuickAddItem.new_group("Nodes", 1),
	QuickAddItem.new("Node 2D", get_icon("Node2D"), func(): return _create_node(0), 1),
	QuickAddItem.new("Node 3D", get_icon("Node3D"), func(): return _create_node(1), 1),
	QuickAddItem.new("Control", get_icon("Control"), func(): return _create_node(2), 1)
])

## Items for [Node2D]s.
static var node_2d_list:QuickAddItemList = QuickAddItemList.new([
	QuickAddItem.new_header("Nodes"),
	QuickAddItem.new("Sprite", get_icon("Sprite2D"), func(): return _create_node_2d(0)),
	QuickAddItem.new("Animated Sprite", get_icon("AnimatedSprite2D"), func(): return _create_node_2d(1)),
	QuickAddItem.new("Tile Map", get_icon("TileMapLayer"), func(): return _create_node_2d(2)),
	QuickAddItem.new("Static Body", get_icon("StaticBody2D"), func(): return _create_node_2d(3)),
	QuickAddItem.new("Collision Shape", get_icon("CollisionShape2D"), func(): return _create_node_2d(4)),
	QuickAddItem.new_header("General"),
	QuickAddItem.new_group("Nodes", 1),
	QuickAddItem.new("Node 2D", get_icon("Node2D"), func(): return _create_node(0), 1),
	QuickAddItem.new("Node 3D", get_icon("Node3D"), func(): return _create_node(1), 1),
	QuickAddItem.new("Control", get_icon("Control"), func(): return _create_node(2), 1)
])

## Items for [Control]s.
static var control_list:QuickAddItemList = QuickAddItemList.new([
	QuickAddItem.new_header("UI Elements"),
	QuickAddItem.new("Button", get_icon("Button"), func(): return _create_control(0)),
	QuickAddItem.new("Check Box", get_icon("CheckBox"), func(): return _create_control(1)),
	QuickAddItem.new("Label", get_icon("Label"), func(): return _create_control(2)),
	QuickAddItem.new("Line Edit", get_icon("LineEdit"), func(): return _create_control(3)),
	QuickAddItem.new("VBox Container", get_icon("VBoxContainer"), func(): return _create_control(4)),
	QuickAddItem.new("HBox Container", get_icon("HBoxContainer"), func(): return _create_control(5)),
	QuickAddItem.new_header("General"),
	QuickAddItem.new_group("Nodes", 1),
	QuickAddItem.new("Node 2D", get_icon("Node2D"), func(): return _create_node(0), 1),
	QuickAddItem.new("Node 3D", get_icon("Node3D"), func(): return _create_node(1), 1),
	QuickAddItem.new("Control", get_icon("Control"), func(): return _create_node(2), 1)
])

## Items for [Node].
static var node_list:QuickAddItemList = QuickAddItemList.new([
	QuickAddItem.new_header("Nodes"),
	QuickAddItem.new("Node 2D", get_icon("Node2D"), func(): return _create_node(0)),
	QuickAddItem.new("Node 3D", get_icon("Node3D"), func(): return _create_node(1)),
	QuickAddItem.new("Control", get_icon("Control"), func(): return _create_node(2)),
	QuickAddItem.new("File Dialog", get_icon("FileDialog"), func(): return _create_node(2))
])

## Creates a [StaticBody3D] with a [MeshInstance3D] and a [CollisionShape3D] supposed to be it's children.
static func _create_primitive_3d(type:int) -> Array[Node]:
	var root = StaticBody3D.new()
	var mesh = MeshInstance3D.new()
	var collider = CollisionShape3D.new()
	
	mesh.name = "Mesh"
	collider.name = "Collider"
	
	match type:
		0: # Plane.
			mesh.mesh = PlaneMesh.new()
			collider.shape = mesh.mesh.create_convex_shape()
			root.name = "Plane"
		1: # Box.
			mesh.mesh = BoxMesh.new()
			collider.shape = BoxShape3D.new()
			root.name = "Box"
		2: # Sphere.
			mesh.mesh = SphereMesh.new()
			collider.shape = SphereShape3D.new()
			root.name = "Sphere"
		3: # Capsule.
			mesh.mesh = CapsuleMesh.new()
			collider.shape = CapsuleShape3D.new()
			root.name = "Capsule"
		4: # Cylinder.
			mesh.mesh = CylinderMesh.new()
			collider.shape = CylinderShape3D.new()
			root.name = "Cylinder"
		5: # Prism.
			mesh.mesh = PrismMesh.new()
			collider.shape = mesh.mesh.create_convex_shape()
			root.name = "Prism"
		6: # Torus.
			mesh.mesh = TorusMesh.new()
			collider.shape = mesh.mesh.create_trimesh_shape()
			root.name = "Torus"
	
	return [root, mesh, collider]

## Creates a [CSGShape3D].
static func _create_csg_3d(type:int) -> Array[Node]:
	var csg:Node
	
	match type:
		0: # Box CSG.
			csg = CSGBox3D.new()
			csg.name = "CSG Box"
		1: # Sphere CSG.
			csg = CSGSphere3D.new()
			csg.name = "CSG Sphere"
			csg.rings = 32
			csg.radial_segments = 64
		2: # Cylinder CSG.
			csg = CSGCylinder3D.new()
			csg.name = "CSG Cylinder"
			csg.sides = 64
		3: # Torus CSG.
			csg = CSGTorus3D.new()
			csg.name = "CSG Torus"
			csg.ring_sides = 32
			csg.sides = 64
		4: # CSG Combiner.
			csg = CSGCombiner3D.new()
			csg.name = "CSG Combiner"
	
	return [csg]

## Creates a [Control].
static func _create_control(type:int) -> Array[Node]:
	var control:Control
	
	match type:
		0: # Button.
			control = Button.new()
			control.name = "Button"
		1: # Check Box.
			control = CheckBox.new()
			control.name = "Check Box"
		2: # Label.
			control = Label.new()
			control.name = "Label"
		3: # Line Edit.
			control = LineEdit.new()
			control.name = "Line Edit"
		4: # VBox Container.
			control = VBoxContainer.new()
			control.name = "VBox Container"
		5: # HBox Container.
			control = HBoxContainer.new()
			control.name = "HBox Container"
	
	return [control]

## Creates a [Node].
static func _create_node(type:int) -> Array[Node]:
	var node:Node
	
	match type:
		0: # Node 2D.
			node = Node2D.new()
			node.name = "Node 2D"
		1: # Node 3D.
			node = Node3D.new()
			node.name = "Node 3D"
		2: # Control.
			node = Control.new()
			node.name = "Control"
	
	return [node]

## Creates a [Node2D].
static func _create_node_2d(type:int) -> Array[Node]:
	var node:Node
	
	match type:
		0: # Sprite.
			node = Sprite2D.new()
			node.name = "Sprite 2D"
		1: # Animated Sprite.
			node = AnimatedSprite2D.new()
			node.name = "Animated Sprite 2D"
		2: # Tile Map.
			node = TileMapLayer.new()
			node.name = "Tile Map Layer"
		3: # Static Body.
			node = StaticBody2D.new()
			node.name = "Static Body 2D"
		4: # Collision Shape.
			node = CollisionShape2D.new()
			node.name = "Collision Shape 2D"
	
	return [node]

## A dictionary containing all lists of quick add items. [br]
## The key is name of the node class that the list belongs to, and the value is the list itself.
static var quick_add_item_lists:Dictionary[String, QuickAddItemList] = {
	"Node3D" : node_3d_list,
	"Node2D" : node_2d_list,
	"Control" : control_list,
	"Node" : node_list
}

## Gets the corresponding quick add item list to a node from [member quick_add_item_lists].
static func get_quick_add_item_list(node:Node) -> QuickAddItemList:
	var script:Script = node.get_script()
	var node_class:String = node.get_class()
	
	if script:
		var script_name = script.get_global_name()
		var closest_script = ""
		
		for i in quick_add_item_lists.keys():
			if i == script_name:
				closest_script = i
		return quick_add_item_lists[closest_script]
	
	for i in quick_add_item_lists.keys():
		var closest_class = "Node"
		if i == node_class || node_class in ClassDB.get_inheriters_from_class(i):
			closest_class = i
		return quick_add_item_lists[closest_class]
	
	return quick_add_item_lists["Node"]

## When an item is selected off of the list.
func _item_selected(id:int) -> void:
	if parent_node == null:
		parent_node = get_editor_interface().get_edited_scene_root().get_child(0)
	_clear_id_signals()
	
	# Create Nodes.

	var item:QuickAddItem = item_instances[id]
	
	get_undo_redo().create_action("Quick Add %s" % item.name, UndoRedo.MERGE_ALL, parent_node)
	
	var parent_node_path = String(get_editor_interface().get_edited_scene_root().get_path_to(parent_node))
	
	get_undo_redo().add_do_method(self, "_select_add", parent_node_path, item)
	get_undo_redo().add_undo_method(self, "_quick_remove", parent_node_path + "/" + item.name)
	get_undo_redo().commit_action()

func _quick_remove(item_path:String):
	var node:Node = get_editor_interface().get_edited_scene_root().get_node(NodePath(item_path))
	if node != null:
		var parent = node.get_parent()
		node.queue_free()
		
		var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
		
		if selected_nodes.size() == 1 && selected_nodes[0] == node:
			get_editor_interface().edit_node(parent)
	else:
		print_rich('[color="yellow"]QuickAddItem not found.[/color]')

func _select_add(parent_node_path:String, item:QuickAddItem) -> void:
	if !get_editor_interface().get_edited_scene_root().has_node(NodePath(parent_node_path)):
		print_rich('[color="yellow"]Parent node not found.[/color]')
		return
	
	var _parent_node = get_editor_interface().get_edited_scene_root().get_node(NodePath(parent_node_path))
	
	var nodes_to_spawn:Array[Node] # First node_list is parent, node_list after are children
	nodes_to_spawn = item.spawn_callable.call()
	
	# Rename.
	
	var original_name:String = nodes_to_spawn[0].name
	
	if _parent_node.get_children().any(func(child): return child.name == original_name): # If sibling already has name, find new available name
		var last_index:int
		
		for i in _parent_node.get_children():
			if original_name in i.name:
				last_index += 1
		
		nodes_to_spawn[0].name = str(original_name, " ", last_index)
	
	# Add To Selected Node as Child.
	
	_parent_node.add_child(nodes_to_spawn[0])
	nodes_to_spawn[0].owner = get_editor_interface().get_edited_scene_root()
	
	for i in range(1, nodes_to_spawn.size()):
		nodes_to_spawn[0].add_child(nodes_to_spawn[i])
		nodes_to_spawn[i].owner = get_editor_interface().get_edited_scene_root()
	
	# Select New Node.
	
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(nodes_to_spawn[0])

func _handles(object) -> bool:
	return object is Node && object != null

func _edit(object: Object) -> void:
	if !object:
		return
	
	parent_node = object

func _make_visible(visible: bool) -> void:
	if menu_button != null:
		menu_button.visible = visible

func _is_add_node_button(node:Button) -> bool:
	return node.icon == get_icon("Add") && node.get_parent() is HBoxContainer

## Find the container for the quick add button to be placed in.
func _find_container() -> HBoxContainer:
	var scene_tree_dock = _get_scene_tree_dock()
	
	if scene_tree_dock == null:
		print_rich('[color="yellow"]Scene Tree Dock not found. Unable to get container.[/color]')
		return
	
	var add_node_button:Button = _find_node_custom(scene_tree_dock, "Button", _is_add_node_button)
	
	if add_node_button == null:
		return
	
	return add_node_button.get_parent() as HBoxContainer

## Get the scene dock root node.
func _get_scene_tree_dock() -> Control:
	return _find_node(EditorInterface.get_base_control(), "SceneTreeDock") as Control

## Find a child node by class name.
func _find_node(current_node:Node, node_class:String) -> Node:
	for i in current_node.get_children():
		if i.get_class() == node_class:
			return i
		var c = _find_node(i, node_class)
		if c != null:
			return c
	return null

## Find a child node by class name and a custom check.
func _find_node_custom(current_node:Node, node_class:String, check:Callable) -> Node:
	for i in current_node.get_children():
		if i.get_class() == node_class && check.call(i):
			return i
		var c = _find_node_custom(i, node_class, check)
		if c != null:
			return c
	return null
