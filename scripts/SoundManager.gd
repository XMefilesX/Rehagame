class_name SoundManagerClass
extends Node

var _player_hit: AudioStreamPlayer
var _player_result: AudioStreamPlayer
var _player_miss: AudioStreamPlayer

func _ready() -> void:
	_player_hit    = _make_player()
	_player_result = _make_player()
	_player_miss   = _make_player()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p

func play_hit() -> void:
	_play_tone(_player_hit, 880.0, 0.09)

func play_win() -> void:
	_play_chord(_player_result, [523.25, 659.25, 783.99], 0.5)

func play_lose() -> void:
	_play_tone(_player_result, 196.0, 0.35)

func play_miss() -> void:
	_play_tone(_player_miss, 330.0, 0.12)

func _play_tone(player: AudioStreamPlayer, freq: float, duration: float) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var frames := int(gen.mix_rate * duration)
	for i in frames:
		var t := float(i) / gen.mix_rate
		var env := 1.0 - t / duration
		var sample := sin(TAU * freq * t) * 0.3 * env
		pb.push_frame(Vector2(sample, sample))

func _play_chord(player: AudioStreamPlayer, freqs: Array, duration: float) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var frames := int(gen.mix_rate * duration)
	var vol := 0.2 / float(freqs.size())
	for i in frames:
		var t := float(i) / gen.mix_rate
		var env := 1.0 - t / duration
		var sample := 0.0
		for f in freqs:
			sample += sin(TAU * float(f) * t) * vol * env
		pb.push_frame(Vector2(sample, sample))
