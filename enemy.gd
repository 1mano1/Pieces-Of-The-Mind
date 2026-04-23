extends CharacterBody3D

@export var player_path: NodePath
@export_range(0.5, 20.0, 0.1) var chase_speed: float = 4.0
@export_range(0.5, 40.0, 0.1) var acceleration: float = 12.0
@export_range(0.5, 6.0, 0.1) var attack_range: float = 3.0
@export_range(0.1, 5.0, 0.1) var attack_cooldown: float = 1.0
@export_range(1.0, 100.0, 1.0) var damage_per_hit: float = 30.0
@export_range(2.0, 120.0, 1.0) var detection_range: float = 45.0
@export_range(1.0, 20.0, 0.5) var turn_speed: float = 10.0
@export_range(2.0, 40.0, 0.5) var flashlight_scare_range: float = 16.0
@export_range(1.0, 24.0, 0.5) var flee_speed: float = 6.0
@export_range(-1.0, 1.0, 0.05) var flashlight_required_dot: float = 0.15

var _player: CharacterBody3D = null
var _time_since_last_attack: float = 0.0
var _gravity: float = 9.8

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_resolve_player()

func _physics_process(delta: float) -> void:
	_time_since_last_attack += delta

	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		return

	if _is_player_dead():
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()

	if _is_scared_by_flashlight(distance, to_player):
		_flee_from_player(delta, to_player, distance)
		_apply_gravity(delta)
		move_and_slide()
		return

	if distance > detection_range:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var move_dir: Vector3 = Vector3.ZERO
	if distance > attack_range and distance > 0.001:
		move_dir = to_player / distance
		var target_vx: float = move_dir.x * chase_speed
		var target_vz: float = move_dir.z * chase_speed
		velocity.x = move_toward(velocity.x, target_vx, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vz, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_try_attack()

	if distance > 0.001:
		var target_y: float = atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, target_y, clampf(turn_speed * delta, 0.0, 1.0))

	_apply_gravity(delta)
	move_and_slide()

func _is_scared_by_flashlight(distance: float, to_player: Vector3) -> bool:
	if _player == null:
		return false
	if distance > flashlight_scare_range:
		return false

	if _player.has_method("is_enemy_in_flashlight"):
		return bool(_player.call("is_enemy_in_flashlight", global_position))

	if not _player.has_method("is_flashlight_on"):
		return false
	if not bool(_player.call("is_flashlight_on")):
		return false

	if distance <= 0.001:
		return true

	if not (_player is Node3D):
		return true

	var p3d := _player as Node3D
	var player_forward: Vector3 = -p3d.global_transform.basis.z.normalized()
	var from_player_to_enemy: Vector3 = (-to_player).normalized()
	return player_forward.dot(from_player_to_enemy) >= flashlight_required_dot

func _flee_from_player(delta: float, to_player: Vector3, distance: float) -> void:
	if distance > 0.001:
		var away_dir: Vector3 = -to_player / distance
		var target_vx: float = away_dir.x * flee_speed
		var target_vz: float = away_dir.z * flee_speed
		velocity.x = move_toward(velocity.x, target_vx, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vz, acceleration * delta)

		var target_y: float = atan2(away_dir.x, away_dir.z)
		rotation.y = lerp_angle(rotation.y, target_y, clampf(turn_speed * delta, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

func _resolve_player() -> void:
	_player = null

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody3D:
		_player = players[0] as CharacterBody3D
		return

	if player_path != NodePath(""):
		_player = get_node_or_null(player_path) as CharacterBody3D
		if _player != null:
			return

	var current_scene := get_tree().current_scene
	if current_scene != null:
		_player = current_scene.find_child("Jugador", true, false) as CharacterBody3D
		if _player == null:
			_player = current_scene.find_child("Player", true, false) as CharacterBody3D

func _is_player_dead() -> bool:
	if _player == null:
		return true
	if _player.has_method("is_player_dead"):
		return bool(_player.call("is_player_dead"))
	var dead_prop = _player.get("is_dead")
	if dead_prop != null:
		return bool(dead_prop)
	return false

func _try_attack() -> void:
	if _time_since_last_attack < attack_cooldown:
		return
	if _player == null or not _player.has_method("take_damage"):
		return

	_player.call("take_damage", damage_per_hit)
	_time_since_last_attack = 0.0
