extends Node

## 全局音频设置：SFX 音量 + Music 音量（0~100 线性，映射到 dB）

var sfx_volume: int = 80
var music_volume: int = 80

const _SAVE_PATH := "user://audio_settings.json"
const _BUS_SFX := &"SFX"
const _BUS_MUSIC := &"Music"

func _ready() -> void:
	_ensure_buses()
	_load()
	apply()

func _ensure_buses() -> void:
	if AudioServer.get_bus_index(_BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, _BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(_BUS_MUSIC) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, _BUS_MUSIC)
		AudioServer.set_bus_send(idx, "Master")

func apply() -> void:
	_set_bus_volume(_BUS_SFX, sfx_volume)
	_set_bus_volume(_BUS_MUSIC, music_volume)

func _set_bus_volume(bus_name: StringName, linear_pct: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear_pct / 100.0))
	AudioServer.set_bus_mute(idx, linear_pct <= 0)

func save() -> void:
	var file := FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"sfx": sfx_volume, "music": music_volume}))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(_SAVE_PATH):
		return
	var file := FileAccess.open(_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data := json.data as Dictionary
		if data.has("sfx"):
			sfx_volume = clampi(int(data["sfx"]), 0, 100)
		if data.has("music"):
			music_volume = clampi(int(data["music"]), 0, 100)
	file.close()
