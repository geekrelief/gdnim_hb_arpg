import gdnim
import random

randomize()
var vzero:Vector2

type
  BatState = enum
    IDLE, WANDER, CHASE, FLEE

gdnim Bat of KinematicBody2D:
  godotapi Area2D

  var
    HitSpeed {.gdExport.}:float = 130.0
    Friction {.gdExport.}:float = 800.0
    Acceleration {.gdExport.}:float = 350.0
    MaxSpeed {.gdExport.}:float = 150.0
    PushAmount {.gdExport.}:float = 1000.0
    WanderRadius {.gdExport.}:float = 100.0

    hurtArea:Node
    hurtVector:Vector2
    gameData:Node
    stats:Node
    deathEffectRes:PackedScene

    detectionZone:Node
    state:BatState = IDLE
    velocity:Vector2
    playerTarget:Node2D
    sprite:AnimatedSprite

    idleTimer:Timer

    softCollision:Node
    wanderVector:Vector2
    wanderRadius:float
    startPos:Vector2

    blinkAnimationPlayer:AnimationPlayer

  unload:
    save(self.position, self.startPos)

  reload:
    self.startPos = self.globalPosition
    load(self.position, self.startPos)
    self.globalPosition = self.startPos

  dependencies:
    stats:
      self.stats = self.get_node("Stats")
      discard self.stats.connect("no_health", self, "on_stats_no_health")
    detection_zone:
      self.detectionZone = self.get_node("DetectionZone")
      discard self.detectionZone.connect("player_found", self, "on_player_found")
      discard self.detectionZone.connect("player_lost", self, "on_player_lost")
    soft_collisions:
        self.softCollision = self.get_node("SoftCollisions")

  method enter_tree() =
    self.deathEffectRes = loadScene("bat_death_effect")
    self.gameData = self.getTree().root.get_node("GameData")
    self.hurtArea = self.get_node("HurtArea2D")
    discard self.hurtArea.connect("area_entered", self, "hurt_area_entered")
    discard self.hurtArea.connect("invincibility_started", self, "on_invincibility_started")
    discard self.hurtArea.connect("invincibility_ended", self, "on_invincibility_ended")
    self.sprite = self.get_node("AnimatedSprite") as AnimatedSprite

    self.blinkAnimationPlayer = self.get_node("BlinkAnimationPlayer") as AnimationPlayer

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
      of FLEE:
        if not self.playerTarget.isNil:
          var direction = directionTo(self.playerTarget.globalPosition, self.globalPosition)
          self.velocity = self.velocity.move_toward(direction * self.MaxSpeed, self.Acceleration * 1.1 * delta)

    self.sprite.flip_h = self.velocity.x < 0

    if self.softCollision.call("is_colliding").asBool:
      var push_vector = self.softCollision.call("get_push_vector").asVector2
      self.velocity += push_vector * delta * self.PushAmount

    self.velocity = self.move_and_slide(self.velocity)

  proc hurt_area_entered(area:Area2D) {.gdExport.} =
    self.hurtVector = asVector2(self.gameData.get_meta("input_vector")) * self.HitSpeed
    var damage = area.get_node("Damage").getImpl("amount")
    discard self.stats.call("dec_health", damage)
    discard self.hurtArea.call("start_invincibility")
    self.state = FLEE
    self.modulate = initColor(1.0, 1.0, 0.0)
    asyncCheck self.asyncWander()

  proc onStatsNoHealth() {.gdExport.} =
    self.queueFree()
    var deathEffect = self.deathEffectRes.instance() as Node2D
    deathEffect.position = self.position
    self.getParent().addChild(deathEffect)

  proc onPlayerFound(player:Node) {.gdExport.} =
    self.playerTarget = player as Node2D
    self.state = CHASE
    self.modulate = initColor(1.0, 0.0, 0.0)
    asyncCheck self.asyncWander()

  proc onPlayerLost() {.gdExport.} =
    asyncCheck self.asyncIdle()

  proc asyncIdle() {.async.} =
    self.playerTarget = nil
    await on_signal(self.getTree().createTimer(0.15), "timeout")
    if self.playerTarget.isNil:
      self.state = IDLE
      self.modulate = initColor(0.5, 0.5, 0.5)
      asyncCheck self.asyncWander()

  proc asyncWander() {.async.} =
    while true:
      await on_signal(self.getTree().createTimer(2.0), "timeout")
      if self.state == IDLE or self.state == WANDER:
        self.state = WANDER
        self.modulate = initColor(1.0, 1.0, 1.0)
        self.wanderVector = vec2(rand(self.WanderRadius * 2), rand(self.WanderRadius * 2)) - vec2(self.WanderRadius, self.WanderRadius)

        var toStartPos = self.startPos - self.globalPosition
        if toStartPos.length > self.WanderRadius:
          while self.wanderVector.dot(toStartPos) < 0.0:
            self.wanderVector = vec2(rand(self.WanderRadius * 2), rand(self.WanderRadius * 2)) - vec2(self.WanderRadius, self.WanderRadius)

  proc on_invincibility_started() {.gdExport.} =
    self.blinkAnimationPlayer.play("Start")

  proc on_invincibility_ended() {.gdExport.} =
    self.blinkAnimationPlayer.play("Stop")