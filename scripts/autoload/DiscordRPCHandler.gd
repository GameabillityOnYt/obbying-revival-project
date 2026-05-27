extends Node

const APP_ID = 1508206038304686291

var enabled:bool = true
var start_time:int
var last_sync_time:float = 0.0
var sync_interval:float = 1.5

func _ready():
	start_time = int(Time.get_unix_time_from_system())
	enabled = GameManager.data.rpc_enabled

	await get_tree().create_timer(0.2).timeout # bad but works

	if enabled:
		init()
		menu()

func init():

	if !enabled:
		return

	DiscordRPC.app_id = APP_ID
	DiscordRPC.large_image = "orp_logo"
	DiscordRPC.large_image_text = "Obby Revival Project"
	DiscordRPC.start_timestamp = start_time
	DiscordRPC.refresh()

func enable():

	enabled = true
	GameManager.data.rpc_enabled = true

	await get_tree().process_frame

	init()
	menu()

func disable():

	enabled = false
	GameManager.data.rpc_enabled = false

	DiscordRPC.clear()

# i don't really like how much it overwrites but ok

func apply(details:String, state:String = ""):

	if !enabled:
		return

	DiscordRPC.details = details
	DiscordRPC.state = state
	DiscordRPC.refresh()
	
# preset functions

func menu():
	apply("In Menu", "")

func settings():
	apply("In Settings", "")

func playing(level_path:String):

	var file = FileAccess.open(level_path, FileAccess.READ)
	if file == null:
		apply("Playing", "Unknown level")
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		apply("Playing", "Invalid level file")
		return

	var data = json.data

	var name = data.get("ObbyName", "Unknown")
	var diff = data.get("Difficulty", "Unknown")
	var creator = data.get("Creator", "Unknown")

	var details = ("All Jumping " + name) if GameManager.alljump else ("Playing " + name)
	# i hate that state is a gray text right ot timer and not actualy rpc state
	var state = "Tier " + str(diff) + " by " + creator

	apply(details, state)

func clear():
	if enabled:
		DiscordRPC.clear()

func _process(_delta):
	# this function originally meant to fix time jumping in rpc
	# but i feel like i broke something with it instead
	if GameManager.data.rpc_enabled != enabled:
		if GameManager.data.rpc_enabled:
			enable()
		else:
			disable()
		return

	if not enabled:
		return

	DiscordRPC.run_callbacks()
	
	# remove these two lines if you want timer to reset when player enters/leaves an obby
	if DiscordRPC.start_timestamp != start_time:
		DiscordRPC.start_timestamp = start_time

	last_sync_time += _delta
	if last_sync_time >= sync_interval:
		last_sync_time = 0
		DiscordRPC.refresh()
