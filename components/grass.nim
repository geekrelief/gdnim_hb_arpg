import gdnim, godotapi / [node_2d, input, packed_scene, resource_loader, area_2d]

gdobj Grass of Node2D:

  var grassEffectRes:PackedScene

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    save(self.position)

  method enter_tree() =
    register(grass)?.load(self.position)
    self.grassEffectRes = loadScene("grass_effect")
    discard self.get_node("Area2D").connect("area_entered", self, "cut_grass")

  proc cut_grass(area:Area2D) {.gdExport.} =
    self.queueFree()
    var grassEffect = self.grassEffectRes.instance() as Node2D
    grassEffect.position = self.position
    self.getParent().addChild(grassEffect)