extends Node # AUTOLOAD: SFXManagerNonspatial

const MAX_POLYPHONY: int = 32
const BUS: StringName = &'Nonspatial SFX'

var playback: AudioStreamPlaybackPolyphonic;

var _player := AudioStreamPlayer.new()
var _stream := AudioStreamPolyphonic.new()

func _ready() -> void:
	_player.bus = BUS
	
	_stream.polyphony = MAX_POLYPHONY
	_player.stream = _stream
	
	add_child(_player)
	
	_player.play()
	playback = _player.get_stream_playback()

## returns an ID for `playback`, a AudioStreamPlaybackPolyphonic instance
## use this ID for changing the volume/pitch of the stream after playing
func play(stream: AudioStream, from_offset: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0) -> int:
	return playback.play_stream(stream, from_offset, volume_db, pitch)
