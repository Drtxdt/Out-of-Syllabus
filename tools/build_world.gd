extends SceneTree
func _initialize() -> void:
 var palette: Array[Color] = [Color("24363e"),Color("1b2933"),Color("425960"),Color("34494e")]
 var image: Image = Image.create(128,32,false,Image.FORMAT_RGBA8)
 for tile: int in range(4):
  image.fill_rect(Rect2i(tile*32,0,32,32),palette[tile])
  image.fill_rect(Rect2i(tile*32,30,32,2),palette[tile].darkened(0.1))
  image.fill_rect(Rect2i(tile*32+30,0,2,32),palette[tile].darkened(0.1))
  image.fill_rect(Rect2i(tile*32+5,9,3,1),palette[tile].lightened(0.035))
 DirAccess.make_dir_recursive_absolute("res://assets/placeholder")
 image.save_png("res://assets/placeholder/tiles.png")
 var tiles: TileSet = TileSet.new();tiles.tile_size = Vector2i(32,32)
 tiles.add_physics_layer();tiles.set_physics_layer_collision_layer(0,1)
 var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
 atlas.texture = ImageTexture.create_from_image(image);atlas.texture_region_size = Vector2i(32,32)
 tiles.add_source(atlas,0)
 for tile: int in range(4):
  atlas.create_tile(Vector2i(tile,0))
 var wall: TileData = atlas.get_tile_data(Vector2i(2,0),0)
 wall.set_collision_polygons_count(0,1)
 wall.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
 ResourceSaver.save(tiles,"res://world/tileset.tres")
 var data: GameContent = GameContent.new()
 for room: Dictionary in data.chapter.rooms:
  var root: Node2D = Node2D.new();root.name = "Room"
  var floor_layer: TileMapLayer = TileMapLayer.new();floor_layer.name = "Ground";floor_layer.tile_set = tiles
  root.add_child(floor_layer);floor_layer.owner = root
  var walls: TileMapLayer = TileMapLayer.new();walls.name = "Walls";walls.tile_set = tiles
  root.add_child(walls);walls.owner = root
  for y: int in range(11):
   for x: int in range(20):
    floor_layer.set_cell(Vector2i(x,y),0,Vector2i((x+y)%2,0))
    if x==0 or x==19 or y==0 or y==10: walls.set_cell(Vector2i(x,y),0,Vector2i(2,0))
  var props: Node2D = Node2D.new();props.name = "Props";props.y_sort_enabled = true
  root.add_child(props);props.owner = root
  for item: Dictionary in room.objects:
   var prop: WorldProp = WorldProp.new();prop.name = item.id;prop.object_id = item.id;prop.kind = item.kind
   prop.position = Vector2(item.x,item.y);props.add_child(prop);prop.owner = root
  var scene: PackedScene = PackedScene.new();scene.pack(root)
  DirAccess.make_dir_recursive_absolute("res://world/rooms")
  ResourceSaver.save(scene,"res://world/rooms/%s.tscn" % room.id)
  root.free()
 print("WORLD_BUILT: six editable TileMapLayer rooms")
 quit()
