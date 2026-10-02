class_name GameContent
extends RefCounted
var chapter: ChapterManifest
var cards: Dictionary = {}
var knowledge: Dictionary = {}
var encounters: Dictionary = {}
func _init() -> void:
 chapter = load("res://content/chapter.tres") as ChapterManifest
 for id: String in chapter.card_ids:
  cards[id] = load("res://content/cards/%s.tres" % id) as CardDef
 for id: String in chapter.knowledge_ids:
  knowledge[id] = load("res://content/knowledge/%s.tres" % id) as KnowledgeDef
 for id: String in ["mass", "drag"]:
  encounters[id] = load("res://content/encounters/%s.tres" % id) as EncounterDef
func room(id: String) -> Dictionary:
 for entry: Dictionary in chapter.rooms:
  if entry.id == id:
   return entry
 return {}
func object(id: String) -> Dictionary:
 for entry: Dictionary in chapter.rooms:
  for obj: Dictionary in entry.objects:
   if obj.id == id:
    return obj
 return {}
