import gdnim

gdnim Effect of AnimatedSprite:

  method enter_tree() =
    self.play("Animate")
    discard self.connect("animation_finished", self, "on_animation_finished")

  proc onAnimationFinished() {.gdExport.} =
    self.queueFree()