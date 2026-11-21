## Global event bus. Modules and screens talk through signals here instead of
## holding references to each other, which keeps every module replaceable.
extends Node

signal language_changed(code: String)
signal settings_changed()
signal navigate(screen: String, params: Dictionary)
signal trial_recorded(trial: Dictionary)
signal game_finished(module_id: String, result: Dictionary)
signal level_changed(module_id: String, old_level: int, new_level: int)
signal safety_requested(context: String)
signal session_completed(summary: Dictionary)
