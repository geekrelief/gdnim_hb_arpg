import gdnim
import strformat

gdnim DetectionZone of Area2D:

  signal:
    playerFound(player:Node)
    playerLost()

  method ready() =
    discard self.connect("body_entered", self,  "on_body_entered")
    discard self.connect("body_exited", self, "on_body_exited")

  proc onBodyEntered(body:Node) {.gdExport.} =
    self.emitSignal("player_found", body.toVariant)

  proc onBodyExited(body:Node) {.gdExport.} =
    self.emitSignal("player_lost")