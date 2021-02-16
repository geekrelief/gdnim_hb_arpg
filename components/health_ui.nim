import gdnim, godotapi / [control]
import math, strformat

const HeartWidth:float = 15
const HeartHeight:float = 11

gdobj HealthUi of Control:
  var playerStatsPath {.gdExport.}:NodePath
  var max_hearts {.gdExport.}:int = 4
  var hearts {.gdExport.}:int

  var uiEmpty:Control
  var uiFull:Control

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    #save()

  method enter_tree() =
    discard register(health_ui)#?.load()

  method ready() =
    self.uiEmpty = self.get_node("HeartsEmpty") as Control
    self.uiFull = self.get_node("HeartsFull") as Control
    self.set_hearts(self.max_hearts)
    var playerStats = self.get_node(self.playerStatsPath)
    discard playerStats.connect("health_changed", self, "set_hearts")
    discard playerStats.connect("max_health_changed", self, "set_max_hearts")

  proc set_max_hearts(val:int) {.gdExport.} =
    self.max_hearts = max(1, val)
    self.uiEmpty.rect_size = vec2(HeartWidth * float(self.max_hearts), HeartHeight)
    self.set_hearts(min(self.hearts, self.max_hearts))

  proc set_hearts(val:int) {.gdExport.} =
    self.hearts = clamp(val, 0, self.max_hearts)
    self.uiFull.rect_size = vec2(HeartWidth * float(self.hearts), HeartHeight)