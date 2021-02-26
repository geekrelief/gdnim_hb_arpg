import gdnim

const HeartWidth:float = 15
const HeartHeight:float = 11

gdnim HealthUi of Control:
  var
    max_hearts {.gdExport, set:"set_max_hearts".}:int = 4
    hearts {.gdExport, set:"set_hearts".}:int
    uiEmpty:Control
    uiFull:Control

  unload:
    save()

  reload:
    load()

  dependencies:
    player:
      var playerStats = self.getTree().root.get_node("World/YSort/Player/Stats")
      discard playerStats.connect("health_changed", self, "set_hearts")
      discard playerStats.connect("max_health_changed", self, "set_max_hearts")

  method enter_tree() =
    self.uiEmpty = self.get_node("HeartsEmpty") as Control
    self.uiFull = self.get_node("HeartsFull") as Control

  proc set_max_hearts(val:int) {.gdExport.} =
    print "set max hearts " & $val
    self.max_hearts = max(1, val)
    if not self.uiEmpty.isNil:
      self.uiEmpty.rect_size = vec2(HeartWidth * float(self.max_hearts), HeartHeight)
    self.set_hearts(min(self.hearts, self.max_hearts))

  proc set_hearts(val:int) {.gdExport.} =
    self.hearts = clamp(val, 0, self.max_hearts)
    if not self.uiFull.isNil:
      self.uiFull.rect_size = vec2(HeartWidth * float(self.hearts), HeartHeight)