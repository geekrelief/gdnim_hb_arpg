import gdnim, godotapi / [area_2d]

gdobj SoftCollisions of Area2D:

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    #save()

  method enter_tree() =
    .= register(soft_collisions)#?.load()

  proc is_colliding():bool {.gdExport.} =
    var areas = self.getOverlappingAreas()
    return areas.len > 0

  proc get_push_vector():Vector2 {.gdExport.} =
    var areas = self.getOverlappingAreas()
    if areas.len > 0:
      var area = areas[0].asObject(Area2D)
      result = area.globalPosition.directionTo(self.globalPosition)