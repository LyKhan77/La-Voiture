class_name GtCar
extends RefCounted

## Live state of one car in the GT sim (reference `CarState`). Plain data; every
## rule lives in GtRace. `s` is meters along the lap (negative on the grid, grows
## across laps), `lateral` meters right of the centre line.

# Identity
var id: int = 0 # index in the field, also the 3D actor index
var number: int = 0
var code: String = ""
var team_id: int = 0 # 0..9, also the garage
var team_name: String = ""
var driver_name: String = ""
var color: Color = Color.WHITE
var skill: float = 1.0
var consistency: float = 0.9
var wet_skill: float = 0.9
var top_speed: float = 85.0
var grip: float = 1.0
var tyre_wear_rate: float = 1.0
var fuel_use: float = 3.0 # kg per lap

# Position on track
var s: float = 0.0
var prev_s: float = 0.0
var v: float = 0.0
var lateral: float = 0.0
var prev_lateral: float = 0.0
var v_lat: float = 0.0
var target_lateral: float = 0.0
var lane_offset: float = 0.0 # post-collision lateral hold
var lap: int = -1
var stops: int = 0
var position: int = 0

# Tyres, fuel, pace
var compound: int = GtTypes.Compound.SOFT
var tyre_age_laps: int = 0
var wear: float = 0.0
var tyre_temp: float = 90.0
var brake_temp: float = 350.0
var fuel: float = 0.0
var fuel_stage: int = GtTypes.FuelStage.OPTIMAL
var fuel_burn_rate: float = 0.0
var pace_mode: int = GtTypes.PaceMode.STANDARD
var fuel_mode: int = GtTypes.FuelMode.STANDARD
var ers_mode: int = GtTypes.ErsMode.NEUTRAL
var ers_battery: float = 100.0
var gear: int = 1
var rpm: float = 4500.0

# Timing
var lap_start_time: float = 0.0
var best_lap: float = -1.0 # < 0 = none
var last_lap: float = -1.0
var current_sector: int = 0
var sector_entry_time: float = 0.0
var sector_times: Array[float] = [-1.0, -1.0, -1.0]
var current_lap_sectors: Array[float] = [-1.0, -1.0, -1.0]
var last_lap_sectors: Array[float] = [-1.0, -1.0, -1.0]
var personal_best_sectors: Array[float] = [-1.0, -1.0, -1.0]
var sector_colors: Array[int] = [GtTypes.SectorColor.NONE, GtTypes.SectorColor.NONE, GtTypes.SectorColor.NONE]
var speed_trap_speed: float = -1.0
var finished_at: float = -1.0 # < 0 = still racing

# Pit
var pit_request: int = -1 # compound, -1 = none
var pit: GtPit = null

# Incidents and damage
var error_timer: float = 0.0
var pass_timer: float = 0.0
var is_dnf: bool = false
var dnf_reason: String = ""
var dnf_timer: float = 0.0
var is_cleared: bool = false
var damage: float = 0.0
var spin_timer: float = 0.0
var spin_angle: float = 0.0
var incident_cooldown: float = 0.0
## The driver has already complained about this set of tyres being past the wear cliff.
var tyre_cliff_called: bool = false
## Decided when the attack began (same random draw as always): the engineer praises the pass once it is made.
var praise_pending: bool = false
var impact_jolt: float = 0.0
var impact_side: float = 1.0
var collision_hold_timer: float = 0.0
var is_punctured: bool = false
var punctured_wheel: int = -1
var puncture_distance_driven: float = 0.0

# Racecraft
var overtake_phase: int = GtTypes.Overtake.NONE
var side_by_side_timer: float = 0.0
var defend_timer: float = 0.0
var defend_target_lateral: float = 0.0

# 3D chassis dynamics
var yaw_offset: float = 0.0
var chassis_roll: float = 0.0
var chassis_pitch: float = 0.0
var steer_angle: float = 0.0

# Active aero
var drs_eligible: bool = false
var drs_active: bool = false
var slipstream_factor: float = 0.0

# Telemetry
var throttle: float = 1.0
var brake: float = 0.0
var lateral_g: float = 0.0
var longitudinal_g: float = 0.0
var driver_stress: float = 20.0
var driver_confidence: float = 85.0
var driver_heart_rate: float = 125.0
var wheel_temp: PackedFloat64Array = PackedFloat64Array([90.0, 90.0, 88.0, 88.0])
var wheel_pressure_psi: PackedFloat64Array = PackedFloat64Array([28.5, 28.5, 27.8, 27.8])
var wheel_blister_pct: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_brake_temp: PackedFloat64Array = PackedFloat64Array([350.0, 350.0, 320.0, 320.0])


func is_racing() -> bool:
	return pit == null and finished_at < 0.0 and not is_dnf


func has_finished() -> bool:
	return finished_at >= 0.0


func speed_kmh() -> float:
	return v * 3.6


func compound_label() -> String:
	return GtTypes.COMPOUND_LABEL[compound]
