import gdnim, godotapi / [kinematic_body_2d, area_2d, timer, animated_sprite]
import strformat

var vzero:Vector2

type
  BatState = enum
    IDLE, WANDER, CHASE, FLEE

gdobj Bat of KinematicBody2D:

  var HitSpeed {.gdExport.}:float = 130.0
  var Friction {.gdExport.}:float = 800.0
  var Acceleration {.gdExport.}:float = 350.0
  var MaxSpeed {.gdExport.}:float = 150.0

  var hurtArea:Area2D
  var hurtVector:Vector2
  var gameData:Node
  var stats:Node
  var deathEffectRes:PackedScene

  var detectionZone:Node
  var state:BatState = IDLE
  var velocity:Vector2
  var playerTarget:Node2D
  var sprite:AnimatedSprite

  var idleTimer:Timer

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    save(self.position)

  proc hot_depreload(compName:string, isUnloading:bool = false) {.gdExport.} =
    case compName:
    of "stats":
      if isUnloading:
        self.stats.disconnect("no_health", self, "on_stats_no_health")
        self.stats = nil
      else:
        self.stats = self.get_node("Stats") as Node
        discard self.stats.connect("no_health", self, "on_stats_no_health")
    of "detection_zone":
      if isUnloading:
        self.detectionZone.disconnect("player_found", self, "on_player_found")
        self.detectionZone.disconnect("player_lost", self, "on_player_lost")
        self.detectionZone = nil
      else:
        self.detectionZone = self.get_node("DetectionZone") as Node
        discard self.detectionZone.connect("player_found", self, "on_player_found")
        discard self.detectionZone.connect("player_lost", self, "on_player_lost")

  method enter_tree() =
    register(bat)?.load(self.position)
    register_dependencies(bat, stats, detection_zone)

    self.hot_depreload("stats")
    self.hot_depreload("detection_zone")

    self.deathEffectRes = loadScene("bat_death_effect")

    self.gameData = self.getTree().root.get_node("GameData")
    self.hurtArea = self.get_node("HurtArea2D") as Area2D
    discard self.hurtArea.connect("area_entered", self, "hurt_area_entered")

  method ready() =
    startPolling()
    self.sprite = self.get_node("AnimatedSprite") as AnimatedSprite

  method physics_process(delta:float64) =
    self.hurtVector = self.hurtVector.move_toward(vzero, self.Friction * delta)
    self.hurtVector = self.move_and_slide(self.hurtVector)

    case self.state:
      of IDLE:
        self.velocity = self.velocity.move_toward(vzero, self.Friction * delta)
      of WANDER:
        discard
      of CHASE:
        if not self.playerTarget.isNil:
          var direction = directionTo(self.globalPosition, self.playerTarget.globalPosition)
          self.velocity = self.velocity.move_toward(direction * self.MaxSpeed, self.Acceleration * delta)
        self.sprite.flip_h = self.velocity.x < 0
      of FLEE:
        if not self.playerTarget.isNil:
          var direction = directionTo(self.playerTarget.globalPosition, self.globalPosition)
          self.velocity = self.velocity.move_toward(direction * self.MaxSpeed, self.Acceleration * 1.1 * delta)

    self.velocity = self.move_and_slide(self.velocity)

  proc hurt_area_entered(area:Area2D) {.gdExport.} =
    self.hurtVector = asVector2(self.gameData.get_meta("input_vector")) * self.HitSpeed
    var damage = area.get_node("Damage").getImpl("amount")
    discard self.stats.call("dec_health", damage)
    self.state = FLEE

  proc onStatsNoHealth() {.gdExport.} =
    self.queueFree()
    var deathEffect = self.deathEffectRes.instance() as Node2D
    deathEffect.position = self.position
    self.getParent().addChild(deathEffect)

  proc onPlayerFound(player:Node) {.gdExport.} =
    self.playerTarget = player as Node2D
    self.state = CHASE

  proc onPlayerLost() {.gdExport.} =
    asyncCheck self.asyncIdle()

  proc asyncIdle() {.async.} =
    self.playerTarget = nil
    await on_signal(self.getTree().createTimer(0.15), "timeout")
    if self.playerTarget.isNil:
      self.state = IDLE