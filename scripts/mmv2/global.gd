extends Control

@onready var version = $Version
var whitespace_remover = RegEx.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.version_latest == "": await GameManager.VersionLoaded
	whitespace_remover.compile("\\s+")
	
	var curr_version = whitespace_remover.sub(GameManager.version,"",true)
	var latest_version = whitespace_remover.sub(GameManager.version_latest,"",true)
	
	if latest_version == "":
		version.text = "v%s (failed to fetch)" % curr_version
		return
	
	if curr_version != latest_version:
		version.text = "v%s is outdated! Latest: v%s" % [curr_version, latest_version]
	else:
		version.text = "v" + curr_version + " (latest)"
	version.text = '[url=https://github.com/GameabillityOnYt/obbying-revival-project/releases][u]%s[/u][/url]' % version.text
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
