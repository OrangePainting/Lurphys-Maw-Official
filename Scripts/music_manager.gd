extends Node # AUTOLOAD: MusicManager

const MUSIC_STREAM := preload("res://Assets/audio/music_stream.tres")  # AudioStreamInteractive

const BUS: StringName = &'Music' 

var _player := AudioStreamPlayer.new()
var _playback: AudioStreamPlaybackInteractive

func _ready():
	_player.stream = MUSIC_STREAM
	_player.bus = BUS
	add_child(_player)
	
	_player.play()
	_playback = _player.get_stream_playback()

func switch_to(clip_name: StringName):
	_playback.switch_to_clip_by_name(clip_name)

func set_layer(clip_name: StringName, layer: int, db: float):
	# fetch the synchronized stream for that clip, then:
	# sync.set_sync_stream_volume(layer, db)
	pass
