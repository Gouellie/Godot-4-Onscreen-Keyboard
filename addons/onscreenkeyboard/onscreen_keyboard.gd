@tool
extends PanelContainer


###########################
## SETTINGS
###########################

@export var autoShow :bool= true
@export_file("*.json") var customLayoutFile = null
@export var styleBackground :StyleBoxFlat= null
@export var styleHover :StyleBoxFlat= null
@export var stylePressed :StyleBoxFlat= null
@export var styleNormal :StyleBoxFlat= null
@export var styleSpecialKeys :StyleBoxFlat= null
@export var font :FontFile= null
@export var fontColor :Color= Color(1,1,1)
@export var fontColorHover :Color= Color(1,1,1)
@export var fontColorPressed :Color= Color(1,1,1)


###########################
## SIGNALS
###########################

signal visibilityChanged
signal layoutChanged

###########################
## PANEL 
###########################

func _enter_tree():
	get_tree().get_root().size_changed.connect(size_changed)
	_initKeyboard()

#func _exit_tree():
#	pass

#func _process(delta):
#	pass

func _input(event):
	_updateAutoDisplayOnInput(event)

func size_changed():
	if autoShow:
		_hideKeyboard()


###########################
## INIT
###########################
var KeyboardButton
var KeyListHandler

var layouts = []
var keys = []
var capslockKeys = []
var uppercase = false

#var tweenPosition : Tween
var tweenSpeed = .2

func _initKeyboard():

	if customLayoutFile == null:
		var defaultLayout = preload("default_layout.gd").new()
		_createKeyboard(defaultLayout.data)
	else:
		_createKeyboard(_loadJSON(customLayoutFile))
	
	if autoShow:
		_hideKeyboard()



###########################
## HIDE/SHOW
###########################

var focusObject = null

func show():
	_showKeyboard()
	
func hide():
	_hideKeyboard()

var released = true
func _updateAutoDisplayOnInput(event):
	if autoShow == false:
		return
	
	if event is InputEventMouseButton:
		released = !released
		if released == false:
			return
		
		var focusObject = get_viewport().gui_get_focus_owner()
		if focusObject != null:
			var clickOnInput = Rect2(focusObject.global_position,focusObject.size).has_point(get_global_mouse_position())
			var clickOnKeyboard = Rect2(global_position,size).has_point(get_global_mouse_position())
			
			if clickOnInput:
				if isKeyboardFocusObject(focusObject):
					_showKeyboard()
			elif clickOnKeyboard:
				_showKeyboard()
			else:
				_hideKeyboard()

	if event is InputEventKey:
		var focusObject = get_viewport().gui_get_focus_owner()
		if focusObject != null:
			if event.keycode == KEY_ENTER:
				if isKeyboardFocusObjectCompleteOnEnter(focusObject):
					_hideKeyboard()


func _hideKeyboard(keyData=null):
	var tweenPosition = get_tree().create_tween()
	tweenPosition.tween_property(self, "position", Vector2(position.x,get_viewport().get_visible_rect().size.y + 10), tweenSpeed).from(position).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_setCapsLock(false)
	emit_signal("visibilityChanged",false)


func _showKeyboard(keyData=null):
	var tweenPosition = get_tree().create_tween()	
	tweenPosition.tween_property(self, "position", Vector2(position.x,get_viewport().get_visible_rect().size.y-size.y - 10), tweenSpeed).from(position).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emit_signal("visibilityChanged",true)


###########################
##  KEY LAYOUT
###########################

var prevPrevLayout = null
var previousLayout = null
var currentLayout = null

func setActiveLayoutByName(name):
	for layout in layouts:
		if layout.tooltip_text == str(name):
			_showLayout(layout)
		else:
			_hideLayout(layout)


func _showLayout(layout):
	layout.show()
	currentLayout = layout


func _hideLayout(layout):
	layout.hide()


func _switchLayout(keyData):	
	prevPrevLayout = previousLayout
	previousLayout = currentLayout
	emit_signal("layoutChanged", keyData.get("layout-name"))
	
	for layout in layouts:
		_hideLayout(layout)
	
	if keyData.get("layout-name") == "PREVIOUS-LAYOUT":
		if prevPrevLayout != null:
			_showLayout(prevPrevLayout)
			return
	
	for layout in layouts:
		if layout.tooltip_text == keyData.get("layout-name"):
			_showLayout(layout)
			return
	
	_setCapsLock(false)
	

###########################
## KEY EVENTS
###########################

func _setCapsLock(value):
	uppercase = value
	for key in capslockKeys:
		if value:
			if key.get_draw_mode() != BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
		else:
			if key.get_draw_mode() == BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
				
	for key in keys:
		key.changeUppercase(value)


func _triggerUppercase(keyData):
	uppercase = !uppercase
	_setCapsLock(uppercase)


func _keyReleased(keyData):
	
	if keyData.has("output"):
		var keyValue = keyData.get("output")
		
		###########################
		## DISPATCH InputEvent 
		###########################
		
		var inputEventKey = InputEventKey.new()
		inputEventKey.shift_pressed = uppercase
		inputEventKey.alt_pressed = false
		inputEventKey.meta_pressed = false
		inputEventKey.command_or_control_autoremap = false
		inputEventKey.pressed = true
		
		var keyUnicode = KeyListHandler.getUnicodeFromString(keyValue)
		if uppercase==false and KeyListHandler.hasLowercase(keyValue):
			keyUnicode +=32
		inputEventKey.unicode = keyUnicode
		inputEventKey.keycode = KeyListHandler.getScancodeFromString(keyValue)

		Input.parse_input_event(inputEventKey)
		
		###########################
		## DISABLE CAPSLOCK AFTER 
		###########################
		_setCapsLock(false)


###########################
## CONSTRUCT KEYBOARD
###########################

func _setKeyStyle(styleName, key, style):
	if style != null:
		key.set('custom_styles/'+styleName, style)

func _createKeyboard(layoutData):
	if layoutData == null:
		print("ERROR. No layout file found")
		return
	
	KeyListHandler = preload("keylist.gd").new()
	KeyboardButton = preload("keyboard_button.gd")
	
	var ICON_DELETE = preload("icons/delete.png")
	var ICON_SHIFT = preload("icons/shift.png")
	var ICON_LEFT = preload("icons/left.png")
	var ICON_RIGHT = preload("icons/right.png")
	var ICON_HIDE = preload("icons/hide.png")
	var ICON_ENTER = preload("icons/enter.png")
	
	var data = layoutData
	
	if styleBackground != null:
		set('custom_styles/panel', styleBackground)
	
	var index = 0
	for layout in data.get("layouts"):

		var layoutContainer := PanelContainer.new()
		
		if styleBackground != null:
			layoutContainer.set('custom_styles/panel', styleBackground)
		
		# SHOW FIRST LAYOUT ON DEFAULT
		if index > 0:
			layoutContainer.hide()
		else:
			currentLayout = layoutContainer
		
		layoutContainer.tooltip_text = layout.get("name")
		layouts.push_back(layoutContainer)
		add_child(layoutContainer)
		
		var baseVbox = VBoxContainer.new()
		baseVbox.size_flags_horizontal = SIZE_EXPAND_FILL
		baseVbox.size_flags_vertical = SIZE_EXPAND_FILL
		
		for row in layout.get("rows"):

			var keyRow = HBoxContainer.new()
			keyRow.size_flags_horizontal = SIZE_EXPAND_FILL
			keyRow.size_flags_vertical = SIZE_EXPAND_FILL
			
			for key in row.get("keys"):
				var newKey = KeyboardButton.new(key)
				
				_setKeyStyle("normal",newKey, styleNormal)
				_setKeyStyle("hover",newKey, styleHover)
				_setKeyStyle("pressed",newKey, stylePressed)
					
				if font != null:
					newKey.set('custom_fonts/font', font)
				if fontColor != null:
					newKey.set('custom_colors/font_color', fontColor)
					newKey.set('custom_colors/font_color_hover', fontColorHover)
					newKey.set('custom_colors/font_color_pressed', fontColorPressed)
					newKey.set('custom_colors/font_color_disabled', fontColor)
					
				newKey.connect("released", _keyReleased)
				
				if key.has("type"):
					if key.get("type") == "switch-layout":
						newKey.connect("released", _switchLayout)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special":
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special-shift":
						newKey.connect("released", _triggerUppercase)
						newKey.toggle_mode = true
						capslockKeys.push_back(newKey)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special-hide-keyboard":
						newKey.connect("released", _hideKeyboard)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
				
				# SET ICONS
				if key.has("display-icon"):
					var iconData = str(key.get("display-icon")).split(":")
					# PREDEFINED
					if str(iconData[0])=="PREDEFINED":
						if str(iconData[1])=="DELETE":
							newKey.setIcon(ICON_DELETE)
						elif str(iconData[1])=="SHIFT":
							newKey.setIcon(ICON_SHIFT)
						elif str(iconData[1])=="LEFT":
							newKey.setIcon(ICON_LEFT)
						elif str(iconData[1])=="RIGHT":
							newKey.setIcon(ICON_RIGHT)
						elif str(iconData[1])=="HIDE":
							newKey.setIcon(ICON_HIDE)
						elif str(iconData[1])=="ENTER":
							newKey.setIcon(ICON_ENTER)
					# CUSTOM
					if str(iconData[0])=="res":
						print(key.get("display-icon"))
						var texture = load(key.get("display-icon"))
						newKey.setIcon(texture)
						
					if fontColor != null:
						newKey.setIconColor(fontColor)
				
				keyRow.add_child(newKey)
				keys.push_back(newKey)
				
			baseVbox.add_child(keyRow)
		
		layoutContainer.add_child(baseVbox)
		index+=1


###########################
## LOAD SETTINGS
###########################

func _loadJSON(filePath):
	var content = JSON.parse_string(_loadFile(filePath))
	
	if content.error == OK:
		return content.result
	else:
		print("!JSON PARSE ERROR!")
		return null


func _loadFile(filePath) -> String:
	var file = FileAccess.open(filePath, FileAccess.READ)
	var error = FileAccess.get_open_error()
	
	if error != 0:
		print("Error loading File. Error: "+str(error))
	
	var content = file.get_as_text()
	file.close()
	return content


###########################
## HELPER
###########################

func isKeyboardFocusObjectCompleteOnEnter(focusObject):
	if focusObject.get_class() == "LineEdit":
		return true
	return false

func isKeyboardFocusObject(focusObject):
	if focusObject.get_class() == "LineEdit" or focusObject.get_class() == "TextEdit":
		return true
	return false




