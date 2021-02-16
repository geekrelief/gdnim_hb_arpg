import gdnim, godotapi / [area_2d, animated_sprite, timer]

gdobj HurtArea of Area2D:
  var timer:Timer
  var hasInvincibility {.gdExport.}:bool = false
  var invincibilityDuration {.gdExport.}:float64 = 1

  method ready() =
    discard self.connect("area_entered", self, "on_area_entered")
    self.timer = self.get_node("Timer") as Timer
    discard self.timer.connect("timeout", self, "on_timeout")

  proc onAreaEntered(area:Area2D) {.gdExport.} =
    var effect = (loadScene("hit_effect").instance()) as Node2D
    effect.global_position = self.global_position
    self.getTree().root.getNode("World/YSort").addChild(effect)
    self.startInvincibility()

  proc startInvincibility(duration:float64 = 0.0) {.gdExport.} =
    if self.hasInvincibility:
      var iduration:float64
      if duration == 0.0:
        iduration = self.invincibilityDuration

      if not self.timer.isStopped():
        iduration = max(self.timer.timeLeft, iduration)

      self.timer.start(iduration)
      self.setDeferred("monitoring", false.toVariant)

  proc onTimeout() {.gdExport.} =
    self.monitoring = true