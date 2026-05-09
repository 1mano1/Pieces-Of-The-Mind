extends CharacterBody3D

signal cinematic_skip_requested
signal health_changed(current_health: float, max_health: float)
signal player_died
signal hotbar_slot_selected(active_index: int, slot_data: Dictionary)
signal flashlight_toggled(is_on: bool)
signal lupa_mode_toggled(is_on: bool)

const SPEED = 5.0
const MOUSE_SENSITIVITY = 0.002
const DEFAULT_DIALOGUE_CHARS_PER_SECOND = 45.0

@export_range(20.0, 300.0, 1.0) var max_health: float = 100.0
@export_range(0.5, 12.0, 0.1) var regen_delay_seconds: float = 4.0
@export_range(1.0, 120.0, 0.5) var regen_per_second: float = 24.0
@export_range(0.2, 1.0, 0.01) var max_damage_overlay_alpha: float = 0.8
@export_range(0.5, 12.0, 0.1) var flashlight_energy: float = 4.5
@export_range(3.0, 35.0, 0.5) var flashlight_range: float = 18.0
@export_range(8.0, 60.0, 1.0) var flashlight_half_angle_deg: float = 24.0
@export_range(8.0, 60.0, 1.0) var flashlight_effect_half_angle_deg: float = 26.0
