class_name EncounterDef
extends Resource

@export var id: String
@export var title: String
@export var question: String
@export var requirements: PackedStringArray
@export var counterexamples: PackedStringArray
@export var max_rounds: int = 8
