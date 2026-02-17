extends Node2D

const PlayerScript := preload("res://scripts/Player.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const BulletScript := preload("res://scripts/Bullet.gd")
const XPBitScript := preload("res://scripts/XPBit.gd")

const STARTING_XP_TO_LEVEL: int = 8
const SPAWN_MARGIN: float = 120.0
const AUTO_AIM_RANGE: float = 360.0

enum RunState {
	START_MENU,
	PLAYING,
	LEVEL_UP,
	GAME_OVER,
}

var _run_state: int = RunState.START_MENU
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: Player
var _enemies: Array[Enemy] = []
var _xp_bits: Array[XPBit] = []
var _bullets: Array[Bullet] = []

var _game_time_seconds: float = 0.0
var _spawn_accumulator: float = 0.0
var _fire_accumulator: float = 0.0

var _player_level: int = 1
var _current_xp: int = 0
var _xp_to_next_level: int = STARTING_XP_TO_LEVEL
var _kills: int = 0

var _base_move_speed: float = 260.0
var _base_fire_interval: float = 0.48
var _base_bullet_damage: float = 3.0
var _base_projectiles: int = 1
var _base_pickup_radius: float = 120.0

var _upgrades_pool: Array[Dictionary] = [
	{"id": "fire_rate", "name": "+Fire Rate", "desc": "Shoot 15% faster.", "weight": 1.0},
	{"id": "move_speed", "name": "+Move Speed", "desc": "Move 12% faster.", "weight": 1.0},
	{"id": "bullet_damage", "name": "+Bullet Damage", "desc": "Neon Bolts hit harder.", "weight": 1.0},
	{"id": "projectiles", "name": "+Projectiles", "desc": "Fire one extra bolt.", "weight": 0.8},
	{"id": "magnet", "name": "XP Magnet", "desc": "XP pickup radius +30%.", "weight": 0.9},
	{"id": "vitality", "name": "Vitality", "desc": "Heal and increase max HP.", "weight": 0.7},
]

var _ui_layer: CanvasLayer
var _top_hud: VBoxContainer
var _level_label: Label
var _timer_label: Label
var _kills_label: Label
var _xp_bar: ProgressBar
var _hint_label: Label

var _start_panel: PanelContainer
var _start_button: Button

var _levelup_panel: PanelContainer
var _upgrade_buttons: Array[Button] = []

var _gameover_panel: PanelContainer
var _gameover_label: Label
var _restart_button: Button


func _ready() -> void:
	_rng.randomize()
	_build_ui()
	_show_start_menu()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _run_state != RunState.PLAYING:
		return

	_game_time_seconds += delta
	_spawn_accumulator += delta
	_fire_accumulator += delta

	var spawn_interval: float = maxf(0.2, 1.1 - (_game_time_seconds * 0.012))
	while _spawn_accumulator >= spawn_interval:
		_spawn_accumulator -= spawn_interval
		_spawn_enemy()

	while _fire_accumulator >= _base_fire_interval:
		_fire_accumulator -= _base_fire_interval
		_auto_fire()

	_cleanup_dead_references()
	_resolve_bullet_hits()
	_update_ui()


func collect_xp(amount: int) -> void:
	if _run_state != RunState.PLAYING:
		return
	_current_xp += max(0, amount)
	while _current_xp >= _xp_to_next_level:
		_current_xp -= _xp_to_next_level
		_player_level += 1
		_xp_to_next_level = int(roundi(float(_xp_to_next_level) * 1.25 + 2.0))
		_open_level_up()
		break
	_update_ui()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	_top_hud = VBoxContainer.new()
	_top_hud.position = Vector2(16, 12)
	_ui_layer.add_child(_top_hud)

	_level_label = Label.new()
	_timer_label = Label.new()
	_kills_label = Label.new()
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(360, 20)
	_xp_bar.max_value = STARTING_XP_TO_LEVEL
	_hint_label = Label.new()
	_hint_label.text = "Survive, collect XP Bits, and evolve your Neon Bolts."
	_hint_label.modulate = Color(0.85, 0.95, 1.0)
	_top_hud.add_child(_level_label)
	_top_hud.add_child(_timer_label)
	_top_hud.add_child(_kills_label)
	_top_hud.add_child(_xp_bar)
	_top_hud.add_child(_hint_label)

	_start_panel = _build_center_panel("Neon Tide Survivors", "A tiny bullet-heaven vertical slice.\nMove with WASD / Arrow Keys.")
	_start_button = Button.new()
	_start_button.text = "Start Run"
	_start_button.pressed.connect(_start_run)
	_start_panel.get_child(0).add_child(_start_button)

	_levelup_panel = _build_center_panel("Level Up!", "Choose one upgrade")
	for i: int in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(360, 48)
		button.pressed.connect(_on_upgrade_button_pressed.bind(i))
		_upgrade_buttons.append(button)
		_levelup_panel.get_child(0).add_child(button)

	_gameover_panel = _build_center_panel("Run Over", "")
	_gameover_label = Label.new()
	_gameover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_panel.get_child(0).add_child(_gameover_label)
	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.pressed.connect(_start_run)
	_gameover_panel.get_child(0).add_child(_restart_button)


func _build_center_panel(title: String, subtitle: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.size = Vector2(500, 360)
	panel.position = Vector2(390, 180)
	_ui_layer.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	vb.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(subtitle_label)

	return panel


func _show_start_menu() -> void:
	_run_state = RunState.START_MENU
	_clear_run_entities()
	_top_hud.visible = false
	_start_panel.visible = true
	_levelup_panel.visible = false
	_gameover_panel.visible = false


func _start_run() -> void:
	_clear_run_entities()
	_reset_run_stats()
	_spawn_player()
	_run_state = RunState.PLAYING
	_top_hud.visible = true
	_start_panel.visible = false
	_levelup_panel.visible = false
	_gameover_panel.visible = false
	_update_ui()


func _reset_run_stats() -> void:
	_game_time_seconds = 0.0
	_spawn_accumulator = 0.0
	_fire_accumulator = 0.0
	_player_level = 1
	_current_xp = 0
	_xp_to_next_level = STARTING_XP_TO_LEVEL
	_kills = 0
	_base_move_speed = 260.0
	_base_fire_interval = 0.48
	_base_bullet_damage = 3.0
	_base_projectiles = 1
	_base_pickup_radius = 120.0


func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.global_position = get_viewport_rect().size * 0.5
	_player.move_speed = _base_move_speed
	_player.max_health = 100.0
	_player.heal_full()
	_player.died.connect(_on_player_died)
	add_child(_player)


func _spawn_enemy() -> void:
	if _player == null:
		return
	var enemy := EnemyScript.new()
	enemy.global_position = _get_spawn_position_offscreen()
	enemy.target = _player
	enemy.speed = 85.0 + _game_time_seconds * 3.2
	enemy.health = 6.0 + _game_time_seconds * 0.35
	enemy.xp_drop = 1 + int(_game_time_seconds / 45.0)
	enemy.killed.connect(_on_enemy_killed)
	_enemies.append(enemy)
	add_child(enemy)


func _get_spawn_position_offscreen() -> Vector2:
	var view := get_viewport_rect()
	var side: int = _rng.randi_range(0, 3)
	match side:
		0:
			return Vector2(view.size.x + SPAWN_MARGIN, _rng.randf_range(-SPAWN_MARGIN, view.size.y + SPAWN_MARGIN))
		1:
			return Vector2(-SPAWN_MARGIN, _rng.randf_range(-SPAWN_MARGIN, view.size.y + SPAWN_MARGIN))
		2:
			return Vector2(_rng.randf_range(-SPAWN_MARGIN, view.size.x + SPAWN_MARGIN), -SPAWN_MARGIN)
		_:
			return Vector2(_rng.randf_range(-SPAWN_MARGIN, view.size.x + SPAWN_MARGIN), view.size.y + SPAWN_MARGIN)


func _auto_fire() -> void:
	if _player == null:
		return
	var target := _get_nearest_enemy_in_range(_player.global_position, AUTO_AIM_RANGE)
	if target == null:
		return

	for i: int in range(max(1, _base_projectiles)):
		var bolt := BulletScript.new()
		var angle_offset: float = 0.0
		if _base_projectiles > 1:
			angle_offset = deg_to_rad(-8.0 + (16.0 * float(i) / float(_base_projectiles - 1)))
		var dir: Vector2 = (_get_target_aim_position(target) - _player.global_position).normalized().rotated(angle_offset)
		bolt.global_position = _player.global_position
		bolt.direction = dir
		bolt.damage = _base_bullet_damage
		_bullets.append(bolt)
		add_child(bolt)


func _get_target_aim_position(target: Enemy) -> Vector2:
	return target.global_position + target.velocity * 0.12


func _get_nearest_enemy_in_range(origin: Vector2, max_range: float) -> Enemy:
	var nearest: Enemy = null
	var nearest_distance: float = max_range
	for enemy: Enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist: float = origin.distance_to(enemy.global_position)
		if dist <= nearest_distance:
			nearest_distance = dist
			nearest = enemy
	return nearest


func _resolve_bullet_hits() -> void:
	for bullet: Bullet in _bullets:
		if bullet == null or not is_instance_valid(bullet):
			continue
		for enemy: Enemy in _enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			if bullet.global_position.distance_to(enemy.global_position) <= 14.0:
				enemy.apply_damage(bullet.damage)
				bullet.queue_free()
				break


func _on_enemy_killed(world_position: Vector2, xp_value: int) -> void:
	_kills += 1
	_spawn_xp_bit(world_position, xp_value)


func _spawn_xp_bit(world_position: Vector2, xp_value: int) -> void:
	var xp := XPBitScript.new()
	xp.global_position = world_position
	xp.xp_value = max(1, xp_value)
	xp.pickup_radius = _base_pickup_radius
	xp.attractor = _player
	xp.collector = self
	_xp_bits.append(xp)
	add_child(xp)


func _open_level_up() -> void:
	_run_state = RunState.LEVEL_UP
	_levelup_panel.visible = true
	var options: Array[Dictionary] = _roll_upgrade_choices(3)
	for i: int in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[i]
		if i < options.size():
			var option: Dictionary = options[i]
			button.visible = true
			button.set_meta("upgrade_id", option.get("id", ""))
			button.text = "%s\n%s" % [String(option.get("name", "Upgrade")), String(option.get("desc", ""))]
		else:
			button.visible = false


func _roll_upgrade_choices(count: int) -> Array[Dictionary]:
	var weighted_pool: Array[Dictionary] = []
	for entry: Dictionary in _upgrades_pool:
		var copies: int = max(1, int(roundf(float(entry.get("weight", 1.0)) * 3.0)))
		for _i: int in range(copies):
			weighted_pool.append(entry)
	weighted_pool.shuffle()

	var selected: Array[Dictionary] = []
	for option: Dictionary in weighted_pool:
		var id: String = String(option.get("id", ""))
		var already: bool = false
		for existing: Dictionary in selected:
			if String(existing.get("id", "")) == id:
				already = true
				break
		if already:
			continue
		selected.append(option)
		if selected.size() >= count:
			break
	return selected


func _on_upgrade_button_pressed(index: int) -> void:
	if index < 0 or index >= _upgrade_buttons.size():
		return
	var chosen_id: String = String(_upgrade_buttons[index].get_meta("upgrade_id", ""))
	_apply_upgrade(chosen_id)
	_levelup_panel.visible = false
	_run_state = RunState.PLAYING


func _apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"fire_rate":
			_base_fire_interval = maxf(0.1, _base_fire_interval * 0.85)
		"move_speed":
			_base_move_speed *= 1.12
			if _player != null:
				_player.move_speed = _base_move_speed
		"bullet_damage":
			_base_bullet_damage += 1.5
		"projectiles":
			_base_projectiles += 1
		"magnet":
			_base_pickup_radius *= 1.3
			for xp: XPBit in _xp_bits:
				if xp != null and is_instance_valid(xp):
					xp.pickup_radius = _base_pickup_radius
		"vitality":
			if _player != null:
				_player.max_health += 12.0
				_player.heal_full()
		_:
			pass


func _on_player_died() -> void:
	_run_state = RunState.GAME_OVER
	_gameover_panel.visible = true
	_gameover_label.text = "You lasted %.1f seconds and defeated %d enemies." % [_game_time_seconds, _kills]


func _update_ui() -> void:
	_level_label.text = "Level %d" % _player_level
	_timer_label.text = "Time: %.1fs" % _game_time_seconds
	_kills_label.text = "Kills: %d" % _kills
	_xp_bar.max_value = _xp_to_next_level
	_xp_bar.value = _current_xp


func _clear_run_entities() -> void:
	for enemy: Enemy in _enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	for xp: XPBit in _xp_bits:
		if xp != null and is_instance_valid(xp):
			xp.queue_free()
	for bullet: Bullet in _bullets:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_enemies.clear()
	_xp_bits.clear()
	_bullets.clear()
	_player = null


func _cleanup_dead_references() -> void:
	_enemies = _enemies.filter(func(e: Enemy) -> bool: return e != null and is_instance_valid(e))
	_xp_bits = _xp_bits.filter(func(x: XPBit) -> bool: return x != null and is_instance_valid(x))
	_bullets = _bullets.filter(func(b: Bullet) -> bool: return b != null and is_instance_valid(b))
