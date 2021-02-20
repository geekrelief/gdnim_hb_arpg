import gdnim, godotapi / [
  kinematic_body_2d,
  input, animation_player,
  animation_tree, animation_node_state_machine_playback,
  remote_transform_2d,
  audio_stream_player, resource_loader
  ],
  strformat

var vzero:Vector2

type
  PlayerState = enum
    MOVE,
    ROLL,
    ATTACK

gdobj Player of KinematicBody2D:
  var max_speed {.gdExport.}:float = 150.0
  var roll_max_speed {.gdExport.}:float = 150 * 1.5
  var acceleration {.gdExport.}:float = 1000.0
  var friction {.gdExport.}:float = 1100.0

  var roll_invincibility_duration:float = 0.2

  var gameData:Node
  var state:PlayerState = MOVE
  var velocity:Vector2
  var inputVector:Vector2
  var animationPlayer:AnimationPlayer
  var animationTree:AnimationTree
  var animationState:AnimationNodeStateMachinePlayback

  var remoteTransform:RemoteTransform2D
  var blinkAnimationPlayer:AnimationPlayer

  var hurtArea:Area2D
  var stats:Node

  proc hot_unload():seq[byte] {.gdExport.} =
    self.queue_free()
    var remotePath = $self.remoteTransform.remotePath
    save(self.position, self.inputVector, remotePath)

  method enter_tree() =
    self.remoteTransform = self.get_node("PlayerRemoteTransform") as RemoteTransform2D
    var remotePath:string = $self.remoteTransform.remotePath
    register(player)?.load(self.position, self.inputVector, remotePath)
    register_dependencies(player, stats)
    self.hot_depreload("stats", false)
    self.hurtArea = self.get_node("HurtArea2D") as Area2D
    discard self.hurtArea.connect("area_entered", self, "on_hurt_area_entered")

    self.gameData = self.getTree().root.getNode("GameData")
    self.gameData.setImpl("input_vector", vzero.toVariant)
    self.animationPlayer = self.get_node("AnimationPlayer") as AnimationPlayer
    self.animationTree = self.get_node("AnimationTree") as AnimationTree
    self.animationTree.active = true
    self.animationState = asObject[AnimationNodeStateMachinePlayback](self.animationTree.getImpl("parameters/playback"))

    self.remoteTransform.remotePath = NodePath(remotePath)

    self.blinkAnimationPlayer = self.get_node("BlinkAnimationPlayer") as AnimationPlayer

  proc hot_depreload(compName:string, isUnloading:bool) {.gdExport.} =
    case compName:
      of "stats":
        if isUnloading:
          self.stats = nil
        else:
          self.stats = self.get_node("Stats") as Node

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
    deathSound.stream = resource_loader.load("res://resources/Music and Sounds/Hurt.wav") as AudioStream
    deathSound.autoplay = true
    discard deathSound.connect("finished", deathSound, "queue_free")
    self.getTree().root.addChild(deathSound)

  proc onInvincibilityStarted() {.gdExport.} =
    self.blinkAnimationPlayer.play("Start")

  proc onInvincibilityEnded() {.gdExport.} =
    self.blinkAnimationPlayer.play("Stop")