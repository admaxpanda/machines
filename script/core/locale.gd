class_name Locale
extends RefCounted

## 简易本地化：静态方法，从 JSON 加载 key → text 映射

static var _data: Dictionary = {}

static func set_lang(lang: String) -> void:
	var path := "res://data/locale/%s.json" % lang
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_data = {}
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		_data = {}
		return
	_data = json.data

static func get_text(key: String) -> String:
	if _data.has(key) and _data[key] != "":
		return _data[key]
	return key
