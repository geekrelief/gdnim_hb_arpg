import gdnim, godotapi / [node]

gdobj Damage of Node:
  var amount {.gdExport.}:int = 1

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    #save()

  method enter_tree() =
    discard register(damage)#?.load()