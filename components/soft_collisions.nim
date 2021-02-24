import gdnim

gdnim SoftCollisions of Area2D:

  proc is_colliding():bool {.gdExport.} =
    var areas = self.getOverlappingAreas()
    return areas.len > 0

  proc get_push_vector():Vector2 {.gdExport.} =
    var areas = self.getOverlappingAreas()
    if areas.len > 0:
      var area = areas[0].asObject(Area2D)
      result = area.globalPosition.directionTo(self.globalPosition)