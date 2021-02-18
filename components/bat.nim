import gdnim, godotapi / [kinematic_body_2d, area_2d, timer, animated_sprite]
import strformat
import random

var vzero:Vector2

type
  BatState = enum
    IDLE, WANDER, CHASE, FLEE

gdobj Bat of KinematicBody2D:

  var HitSpeed {.gdExport.}:float = 130.0
  var Friction {.gdExport.}:float = 800.0
  var Acceleration {.gdExport.}:float = 350.0
  var MaxSpeed {.gdExport.}:float = 150.0
  var PushAmount {.gdExport.}:float = 1000.0

  var worldSize:Rect2

  var hurtArea:Node
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

  var softCollision:Node
  var wanderVector:Vector2

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
        self.stats = self.get_node("Stats")
        discard self.stats.connect("no_health", self, "on_stats_no_health")
    of "detection_zone":
      if isUnloading:
        self.detectionZone.disconnect("player_found", self, "on_player_found")
        self.detectionZone.disconnect("player_lost", self, "on_player_lost")
        self.detectionZone = nil
      else:
        self.detectionZone = self.get_node("DetectionZone")
        discard self.detectionZone.connect("player_found", self, "on_player_found")
        discard self.detectionZone.connect("player_lost", self, "on_player_lost")
    of "soft_collisions":
      if isUnloading:
        self.soft_collision = nil
      else:
        self.softCollision = self.get_node("SoftCollisions")

  method enter_tree() =
    register(bat)?.load(self.position)
    register_dependencies(bat, stats, detection_zone, soft_collisions)

    self.hot_depreload("stats")
    self.hot_depreload("detection_zone")
    self.hot_depreload("soft_collisions")

    self.deathEffectRes = loadScene("bat_death_effect")
    self.gameData = self.getTree().root.get_node("GameData")
    discard self.get_node("HurtArea2D").connect("area_entered", self, "hurt_area_entered")
    self.sprite = self.get_node("AnimatedSprite") as AnimatedSprite

    randomize()
    self.worldSize = initRect2(0.0, 0.0, 320.0, 180.0)

  method ready() =
    startPolling()
    asyncCheck self.asyncIdle()

  method physics_process(delta:float64) =
    self.hurtVector = self.hurtVector.move_toward(vzero, self.Friction * delta)
    self.hurtVector = self.move_and_slide(self.hurtVector)

    case self.state:
      of IDLE:
        self.velocity = self.velocity.move_toward(vzero, self.Friction * delta)
      of WANDER:
        self.velocity = self.velocity.move_toward(self.wanderVector, self.Acceleration * delta * 0.10)
      of CHASE:
        if not self.playerTarget.isNil:
          var direction = directionTo(self.globalPosition, self.playerTarget.globalPosition)
          self.velocity = self.velocity.move_toward(direction * self.MaxSpeed, self.Acceleration * delta)
        self.sprite.flip_h = self.velocity.x < 0
      of FLEE:
        if not self.playerTarget.isNil:
          var direction = directionTo(self.playerTarget.globalPosition, self.globalPosition)
          self.velocity = self.velocity.move_toward(direction * self.MaxSpeed, self.Acceleration * 1.1 * delta)

    if self.softCollision.call("is_colliding").asBool:
      var push_vector = self.softCollision.call("get_push_vector").asVector2
      self.velocity += push_vector * delta * self.PushAmount

    self.velocity = self.move_and_slide(self.velocity)

  proc hurt_area_entered(area:Area2D) {.gdExport.} =
    self.hurtVector = asVector2(self.gameData.get_meta("input_vector")) * self.HitSpeed
    var damage = area.get_node("Damage").getImpl("amount")
    discard self.stats.call("dec_health", damage)
    self.state = FLEE
    asyncCheck self.asyncWander()

  proc onStatsNoHealth() {.gdExport.} =
    self.queueFree()
    var deathEffect = self.deathEffectRes.instance() as Node2D
    deathEffect.position = self.position
    self.getParent().addChild(deathEffect)

  proc onPlayerFound(player:Node) {.gdExport.} =
    self.playerTarget = player as Node2D
    self.state = CHASE
    asyncCheck self.asyncWander()

  proc onPlayerLost() {.gdExport.} =
    asyncCheck self.asyncIdle()

  proc asyncIdle() {.async.} =
    self.playerTarget = nil
    await on_signal(self.getTree().createTimer(0.15), "timeout")
    if self.playerTarget.isNil:
      self.state = IDLE
      asyncCheck self.asyncWander()

  proc asyncWander() {.async.} =
    while true:
      await on_signal(self.getTree().createTimer(2.0), "timeout")
      if self.state == IDLE or self.state == WANDER:
        self.state = WANDER
        self.wanderVector = vec2(rand(100.0), rand(100.0)) - vec2(50.0, 50.0)

        if not self.worldSize.contains(self.globalPosition):
          var toWorldCenter = self.globalPosition.directionTo(self.worldSize.size * 0.5)
          while self.wanderVector.dot(toWorldCenter) < 0.0:
            self.wanderVector = vec2(rand(100.0), rand(100.0)) - vec2(50.0, 50.0)