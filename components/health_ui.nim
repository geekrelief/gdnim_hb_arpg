import gdnim, godotapi / [control]
import strformat

const HeartWidth:float = 15
const HeartHeight:float = 11

gdobj HealthUi of Control:
  var playerStatsPath {.gdExport.}:NodePath
  var max_hearts {.gdExport, set:"set_max_hearts".}:int = 4
  var hearts {.gdExport, set:"set_hearts".}:int

  var uiEmpty:Control
  var uiFull:Control

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    var path = $self.playerStatsPath
    save(path)

  method enter_tree() =
    var path:string
    register(health_ui)?.load(path)
    if path != "":
      self.playerStatsPath = NodePath(path)

    self.uiEmpty = self.get_node("HeartsEmpty") as Control
    self.uiFull = self.get_node("HeartsFull") as Control
    self.set_hearts(self.max_hearts)
    self.set_hearts(self.hearts)
    var playerStats = self.get_node(self.playerStatsPath)
    .= playerStats.connect("health_changed", self, "set_hearts")
    .= playerStats.connect("max_health_changed", self, "set_max_hearts")

  proc set_max_hearts(val:int) {.gdExport.} =
    self.max_hearts = max(1, val)
    if not self.uiEmpty.isNil:
      self.uiEmpty.rect_size = vec2(HeartWidth * float(self.max_hearts), HeartHeight)
    self.set_hearts(min(self.hearts, self.max_hearts))

  proc set_hearts(val:int) {.gdExport.} =
    self.hearts = clamp(val, 0, self.max_hearts)
    if not self.uiFull.isNil:
      self.uiFull.rect_size = vec2(HeartWidth * float(self.hearts), HeartHeight)