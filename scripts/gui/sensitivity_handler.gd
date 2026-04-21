extends HSlider

@onready var textHolder = $Value
var old_text := ""

func _ready():
	self.value = GameManager.data.sensitivity
	old_text = str(self.value)
	_on_value_text_changed(old_text)
	pass

func _on_value_text_changed(new_text: String) -> void:
	var old_column = textHolder.caret_column
	if new_text.is_valid_float():
		old_text = new_text
		value = old_text.to_float()
	else:
		textHolder.caret_column = old_column
		textHolder.text = old_text

func _on_value_changed(n: float) -> void:
	old_text = str(n)
	var old_column = textHolder.caret_column
	if textHolder.text != old_text:
		textHolder.text = old_text
		textHolder.caret_column = old_column
	GameManager.data.sensitivity = n
