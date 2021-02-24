import gdnim
import random
randomize()

gdnim PlayerRemoteTransform of RemoteTransform2D:
  var canShake {.gdExport.}:bool
  var maxShakeDistance {.gdExport.}:float = 10.0
  var maxShakeDuration {.gdExport.}:float = 1.0
  var noiseOctaves {.gdExport.}:int = 4
  var noisePeriod {.gdExport.}:float = 20.0
  var noisePersistence {.gdExport.}:float = 0.8
  var noisePos:float

  var isShaking:bool
  var trauma:float
  var timer:Timer
  var noise:OpenSimplexNoise

  method enter_tree() =
    self.timer = self.get_node("Timer") as Timer
    discard self.timer.connect("timeout", self, "on_shaking_ended")
    self.noise = gdnew[OpenSimplexNoise]()
    self.noise.seed = rand(1000)
    self.noise.octaves = self.noiseOctaves
    self.noise.period = self.noisePeriod
    self.noise.persistence = self.noisePersistence

  method physics_process(delta:float64) =
    if self.canShake and self.isShaking:
      var nx = self.noise.getNoise1D(self.noisePos) * self.trauma * self.maxShakeDistance
      self.noisePos += 0.1
      var ny = self.noise.getNoise1D(self.noisePos) * self.trauma * self.maxShakeDistance
      self.noisePos += 0.1
      self.position = vec2(nx, ny)
      #print self.position

  proc shake(trauma:float) {.gdExport.} =
    self.isShaking = true
    self.trauma = trauma
    var duration = self.trauma * self.maxShakeDuration
    self.noisePos = 0.0
    self.timer.start(max(0, duration))

  proc on_shaking_ended() {.gdExport.} =
    self.isShaking = false
    self.position = Vector2()