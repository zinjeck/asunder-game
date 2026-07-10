extends Node

const SLOW_TICK_WARNING_USEC: int = 16_000

var last_tick_index: int = 0
var last_tick_duration_usec: int = 0
var maximum_tick_duration_usec: int = 0

var processed_tick_count: int = 0
var slow_tick_count: int = 0


func _ready() -> void:
	var tick_callable := Callable(self, "on_simulation_tick")

	if not SimulationClock.simulation_tick.is_connected(tick_callable):
		SimulationClock.simulation_tick.connect(tick_callable)


func on_simulation_tick(
	tick_index: int,
	minutes_advanced: int
) -> void:
	var tick_start_usec := Time.get_ticks_usec()

	run_simulation_systems(
		tick_index,
		minutes_advanced
	)

	last_tick_duration_usec = (
		Time.get_ticks_usec()
		- tick_start_usec
	)

	last_tick_index = tick_index
	processed_tick_count += 1

	if last_tick_duration_usec > maximum_tick_duration_usec:
		maximum_tick_duration_usec = last_tick_duration_usec

	if last_tick_duration_usec >= SLOW_TICK_WARNING_USEC:
		slow_tick_count += 1


func run_simulation_systems(
	tick_index: int,
	minutes_advanced: int
) -> void:
	WorldData.run_simulation_tick(
		tick_index,
		minutes_advanced
	)


func reset_performance_statistics() -> void:
	last_tick_index = 0
	last_tick_duration_usec = 0
	maximum_tick_duration_usec = 0
	processed_tick_count = 0
	slow_tick_count = 0


func get_last_tick_duration_msec() -> float:
	return float(last_tick_duration_usec) / 1000.0


func get_maximum_tick_duration_msec() -> float:
	return float(maximum_tick_duration_usec) / 1000.0


func get_debug_text() -> String:
	return (
		"Simulation Tick Cost: "
		+ "%.3f ms" % get_last_tick_duration_msec()
		+ "\n"
		+ "Maximum Tick Cost: "
		+ "%.3f ms" % get_maximum_tick_duration_msec()
		+ "\n"
		+ "Processed Ticks: " + str(processed_tick_count)
		+ "\n"
		+ "Slow Ticks: " + str(slow_tick_count)
	)
