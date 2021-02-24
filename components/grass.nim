import gdnim

gdnim Grass of Node2D:
  godotapi Area2D

  var grassEffectRes:PackedScene

  unload:
    save(self.position)

  reload:
    load(self.position)

  method enter_tree() =
    self.grassEffectRes = loadScene("grass_effect")
    discard self.get_node("Area2D").connect("area_entered", self, "cut_grass")

  proc cut_grass(area:Area2D) {.gdExport.} =
    self.queueFree()
    var grassEffect = self.grassEffectRes.instance() as Node2D
    grassEffect.position = self.position
    self.getParent().addChild(grassEffect)