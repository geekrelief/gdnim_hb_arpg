import gdnim

gdnim Stats of Node:

  var
    max_health {.gdExport.}:int = 1
    health:int

  signal:
    no_health()
    health_changed(val:int)
    max_health_changed(val:int)

  method ready() =
    self.set_max_health(self.max_health)
    self.set_health(self.max_health)

  proc decHealth(val:int) {.gdExport.} =
    self.health = self.health - val
    self.emitSignal("health_changed", self.health.toVariant)
    if self.health <= 0:
      self.emitSignal("no_health")

  proc get_health():int {.gdExport.} =
    self.health

  proc set_health(val:int) {.gdExport.} =
    self.health = clamp(val, 0, self.max_health)
    self.emitSignal("health_changed", self.health.toVariant)

  proc get_max_health():int {.gdExport.} =
    self.max_health

  proc set_max_health(val:int) {.gdExport.} =
    self.max_health = max(1, val)
    self.emitSignal("max_health_changed", self.max_health.toVariant)

  proc get_trauma():float {.gdExport.} =
    1.0 - float(self.health)/float(self.max_health)