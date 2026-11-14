## 跨场景的临时游戏状态（不落盘）
extends Node

var current_level_id: int = 1
var difficulty: String = LevelData.DEFAULT_DIFFICULTY
var last_result: Dictionary = {}


func start_level(level_id: int, diff: String = "") -> void:
	current_level_id = maxi(1, level_id)
	if diff != "" and LevelData.is_difficulty(diff):
		difficulty = diff
	elif not LevelData.is_difficulty(difficulty):
		difficulty = LevelData.DEFAULT_DIFFICULTY
