extends Control

@onready var pages = {
	"Main": $Pages/MainPage,
	"Performance": $Pages/PerformancePage,
	"Display": $Pages/DisplayPage,
	"Controls": $Pages/ControlsPage,
	"Extras": $Pages/ExtrasPage
}

@onready var tabs = {
	"Main": $Tabs/Main,
	"Performance": $Tabs/Performance,
	"Display": $Tabs/Display,
	"Controls": $Tabs/Controls,
	"Extras": $Tabs/Extras
}

func _ready():
	show_page("Main")
	
	for tab in tabs.values():
		tab.pivot_offset = tab.size / 2
	
func show_page(name: String):
	# hide all pages
	for page in pages.values():
		page.visible = false
		
	# show selected page
	pages[name].visible = true
	
	# reset tab visuals
	for tab in tabs.values():
		tab.modulate = Color(1, 1, 1, 0.5)
		tab.scale = Vector2(0.95, 0.95)
		
	# highlight activated tab
	tabs[name].modulate = Color(1, 1, 1, 1)
	tabs[name].scale = Vector2(1.05, 1.05)

func _on_main_pressed():
	show_page("Main")


func _on_performance_pressed():
	show_page("Performance")


func _on_display_pressed():
	show_page("Display")


func _on_controls_pressed():
	show_page("Controls")


func _on_extras_pressed():
	show_page("Extras")
