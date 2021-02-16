import gdnim, godotapi / [area_2d]
import strformat

gdobj DetectionZone of Area2D:

  signal playerFound(player:Node)
  signal playerLost()

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()

  method enter_tree() =
    discard register(detection_zone)
    discard self.connect("body_entered", self,  "on_body_entered")
    discard self.connect("body_exited", self, "on_body_exited")

  proc onBodyEntered(body:Node) {.gdExport.} =
    self.emitSignal("player_found", body.toVariant)

  proc onBodyExited(body:Node) {.gdExport.} =
    self.emitSignal("player_lost")