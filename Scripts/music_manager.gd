extends Node # AUTOLOAD: MusicManager

# use AudioStreamSynchronized
enum Music {MENU, HOME, RUN}

const STREAMS = {
	Music.MENU: preload("res://Assets/audio/music/menu_theme.wav"),
	Music.HOME: preload("res://Assets/audio/music/main_theme.wav"),
	Music.RUN: preload("res://Assets/audio/music/jimbattleloop.ogg")
}

var current_playing := -1
var active_stream: AudioStreamPlayer
var idle_stream: AudioStreamPlayer
var tween: Tween


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active_stream = make_stream_player()
	idle_stream = make_stream_player()

func make_stream_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Music"
	player.volume_db = -80
	add_child(player)
	return player


# Called every frame. 'delta' is the elapsed time since the previous frame.
func play(track: Music, fade_time := 1.0) -> void:
	if track == current_playing: return
	current_playing = track
	
	var tmp = active_stream
	active_stream = idle_stream
	idle_stream = tmp
	
	active_stream.stream = STREAMS[track]
	active_stream.volume_db = -80
	active_stream.play()
	
	if tween: tween.kill()
	tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(active_stream, "volume_db", 0.0, fade_time)
	
	if idle_stream.playing:
		tween.tween_property(idle_stream, "volume_db", -80, fade_time)
		tween.chain().tween_callback(idle_stream.stop)

func stop(fade_time := 1.0) -> void:
	current_playing = -1
	if tween: tween.kill()
	tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	if active_stream.playing:
		tween.tween_property(active_stream, "volume_db", -80, fade_time)
	if idle_stream.playing:
		tween.tween_property(idle_stream, "volume_db", -80, fade_time)
	tween.chain().tween_callback(func(): active_stream.stop(); idle_stream.stop())
