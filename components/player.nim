import gdnim,
  godotapi / [ kinematic_body_2d, input, audio_stream_player ]

var vzero:Vector2

type
  PlayerState = enum
    MOVE,
    ROLL,
    ATTACK

gdnim Player of KinematicBody2D:
  var
    max_speed {.gdExport.}:float = 150.0
    roll_max_speed {.gdExport.}:float = 150 * 1.5
    acceleration {.gdExport.}:float = 1000.0
    friction {.gdExport.}:float = 1100.0

    roll_invincibility_duration:float = 0.2
    gameData:Node
    state:PlayerState = MOVE
    velocity:Vector2
    inputVector:Vector2

    animationTree:AnimationTree
    animationState:AnimationNodeStateMachinePlayback

    remoteTransform:RemoteTransform2D
    blinkAnimationPlayer:AnimationPlayer

    hurtArea:Area2D
    stats:Node

  unload:
    var health = self.stats.call("get_health").asInt
    save(self.position, self.inputVector, $self.remoteTransform.remotePath, health)

  reload:
    self.remoteTransform = self.get_node("PlayerRemoteTransform") as RemoteTransform2D
    var remotePath:string = $self.remoteTransform.remotePath
    var health = self.stats.call("get_health").asInt
    load(self.position, self.inputVector, remotePath, health)
    self.remoteTransform.remotePath = remotePath
    discard self.stats.call("set_health", health.toVariant)

  dependencies:
    stats:
      self.stats = self.get_node("Stats") as Node

  method ready() =
    self.hurtArea = self.get_node("HurtArea2D") as Area2D
    discard self.hurtArea.connect("area_entered", self, "on_hurt_area_entered")

    self.gameData = self.getTree().root.getNode("GameData")
    self.gameData.setImpl("input_vector", vzero.toVariant)
    self.animationTree = self.get_node("AnimationTree") as AnimationTree
    self.animationTree.active = true
    self.animationState = asObject[AnimationNodeStateMachinePlayback](self.animationTree.getImpl("parameters/playback"))

    self.blinkAnimationPlayer = self.get_node("BlinkAnimationPlayer") as AnimationPlayer

  method physics_process(delta: float64) =
    self.update_input()

    case self.state:
    of MOVE: self.move_state(delta)
    of ATTACK: self.attack_state(delta)
    of ROLL: self.roll_state(delta)

    self.update_motion()

  proc update_input() =
    self.inputVector = vec2(input.get_action_strength("ui_right") - input.get_action_strength("ui_left"),
      input.get_action_strength("ui_down") - input.get_action_strength("ui_up"))
    self.inputVector.normalize

  proc update_motion() =
    self.velocity = self.move_and_slide(self.velocity)

  proc move_state(delta: float64) =
    if self.inputVector != vzero:
      self.gameData.set_meta("input_vector", self.inputVector.toVariant)

      self.velocity = self.velocity.move_toward(self.inputVector * self.max_speed, self.acceleration * delta)
      var vIV = self.inputVector.toVariant
      self.animationTree.setImpl("parameters/Idle/blend_position", vIV)
      self.animationTree.setImpl("parameters/Run/blend_position", vIV)
      self.animationTree.setImpl("parameters/Attack/blend_position", vIV)
      self.animationTree.setImpl("parameters/Roll/blend_position", vIV)
      self.animationState.travel("Run")

      if input.isActionJustPressed("roll"):
        self.velocity = self.inputVector * self.roll_max_speed
        self.state = ROLL
        self.animationState.travel("Roll")
        discard self.hurtArea.call("start_invincibility", self.roll_invincibility_duration.toVariant)
    else:
      self.velocity = self.velocity.move_toward(vzero, self.friction * delta)
      self.animationState.travel("Idle")

    if input.isActionJustPressed("attack"):
      self.state = ATTACK
      self.animationState.travel("Attack")

  proc attack_state(delta:float64) =
    self.velocity = self.velocity.move_toward(vzero, self.friction * delta * 0.50)

  proc attack_animation_finished() {.gdExport.} =
    self.state = MOVE

  proc roll_state(delta:float64) {.gdExport.} =
    self.velocity = self.velocity.move_toward(vzero, self.friction * delta * 0.30)

  proc roll_animation_finished() {.gdExport.} =
    self.state = MOVE

  proc on_hurt_area_entered(area:Area2D) {.gdExport.} =
    var damage = area.get_node("Damage").getImpl("amount")
    discard self.stats.call("dec_health", damage)
    discard self.remoteTransform.call("shake", self.stats.call("get_trauma"))

  proc on_no_health() {.gdExport.} =
    self.queueFree()
    var deathSound = gdnew[AudioStreamPlayer]()
    deathSound.stream = load("res://resources/Music and Sounds/Hurt.wav") as AudioStream
    deathSound.autoplay = true
    discard deathSound.connect("finished", deathSound, "queue_free")
    self.getTree().root.addChild(deathSound)

  proc onInvincibilityStarted() {.gdExport.} =
    self.blinkAnimationPlayer.play("Start")

  proc onInvincibilityEnded() {.gdExport.} =
    self.blinkAnimationPlayer.play("Stop")