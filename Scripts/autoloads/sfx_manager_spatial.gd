extends Node # AUTOLOAD: SFXManagerSpatial

## Proxy class for an underlying AudioStreamPlayer2D
## Disallows modifying the underlying player once the SFX is finished.
	## Call .done() to check if the SFX is still valid.
class SpatialSFX extends RefCounted:
	var _player: AudioStreamPlayer2D
	var _id: int
	
	func _init(player: AudioStreamPlayer2D = null):
		_player = player
		
		if _player != null:
			_id = _player.get_meta(&'sfx_id')
		
	func done() -> bool:
		return _player == null \
			or !_player.playing \
			or _player.get_meta(&'sfx_id') != _id
		
	# wrappers for AudioStreamPlayer2D properties (& global_position)
		# NO: autoplay; playing; playback_type
	
	var global_position: Vector2:
		get: return _player.global_position if !done() else Vector2.ZERO
		set(value): if !done(): _player.global_position = value
		
	var area_mask: int:
		get: return _player.area_mask if !done() else 0
		set(value): if !done(): _player.area_mask = value
	
	var attenuation: float:
		get: return _player.attenuation if !done() else 0.0
		set(value): if !done(): _player.attenuation = value

	var bus: StringName:
		get: return _player.bus if !done() else &''
		set(value): if !done(): _player.bus = value
		
	var max_distance: float:
		get: return _player.max_distance if !done() else 0.0
		set(value): if !done(): _player.max_distance = value

	var max_polyphony: int:
		get: return _player.max_polyphony if !done() else 0
		set(value): if !done(): _player.max_polyphony = value

	var panning_strength: float:
		get: return _player.panning_strength if !done() else 0.0
		set(value): if !done(): _player.panning_strength = value
		
	var pitch_scale: float:
		get: return _player.pitch_scale if !done() else 0.0
		set(value): if !done(): _player.pitch_scale = value

	var stream: AudioStream:
		get: return _player.stream if !done() else null
		set(value): if !done(): _player.stream = value
		
	var stream_paused: bool:
		get: return _player.stream_paused if !done() else false
		set(value): if !done(): _player.stream_paused = value
		
	var volume_db: float:
		get: return _player.volume_db if !done() else 0.0
		set(value): if !done(): _player.volume_db = value

	var volume_linear: float:
		get: return _player.volume_linear if !done() else 0.0
		set(value): if !done(): _player.volume_linear = value
	
	# wrappers for AudioStreamPlayer2D methods
		# NO: play(), use seek(0); 
		
	func get_playback_position() -> float: 
		return _player.get_playback_position() if !done() else 0.0

	func get_stream_playback() -> AudioStreamPlayback:
		return _player.get_stream_playback() if !done() else null

	func has_stream_playback() -> bool:
		return _player.has_stream_playback() if !done() else false

	func seek(to_position: float) -> void:
		if !done(): _player.seek(to_position)

	func stop() -> void:
		if !done(): _player.stop()

const PLAYER_DEFAULTS = {
	'area_mask': 0,
	'attenuation': 1.0,
	'bus': &'Spatial SFX',
	'max_distance': 2000.0,
	'max_polyphony': 1,
	'panning_strength': 1.0,
	'pitch_scale': 1.0,
	'volume_db': 0.0
}

const PLAYERS_POOL_SIZE: int = 32

var _players: Array[AudioStreamPlayer2D] = []
var _sfx_id: int = 0

func _ready() -> void:
	for i in PLAYERS_POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.set_meta(&'attached_node', null)
		
		add_child(p)
		_players.append(p)

func _physics_process(delta: float) -> void:
	# for players which are tracking a node: move to track the node
	for p in _players:
		if !p.playing: continue
		
		var attached_node: Node = p.get_meta(&'attached_node')
		
		if is_instance_valid(attached_node) and attached_node.is_inside_tree():
			p.global_position = attached_node.global_position

func _play(stream: AudioStream, attached_node: Node = null) -> SpatialSFX:
	var player: AudioStreamPlayer2D = null
	
	for p in _players:
		if !p.playing:
			player = p
			break
	
	if player != null:
		player.set_meta(&'attached_node', attached_node)
		
		player.set_meta(&'sfx_id', _sfx_id)
		_sfx_id += 1
		
		for property in PLAYER_DEFAULTS:
			player.set(property, PLAYER_DEFAULTS[property])
		
		player.stream = stream
		player.play()
	
	return SpatialSFX.new(player)

## Play a SFX at a node. The SFX will track the node's position.
func play_at_node(stream: AudioStream, node: Node) -> SpatialSFX:
	var spatial_sfx := _play(stream, node)
	
	assert(is_instance_valid(node) and node.is_inside_tree()) # ensure node has a global_position
	spatial_sfx.global_position = node.global_position
	
	return spatial_sfx

## Play a SFX at a node. The SFX will stay in the same position by default.
func play_at(stream: AudioStream, position: Vector2) -> SpatialSFX:
	var spatial_sfx := _play(stream)
	spatial_sfx.global_position = position
	return spatial_sfx
