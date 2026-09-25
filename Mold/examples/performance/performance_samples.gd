extends RefCounted
# Same columns as the C# performance samples. Preallocated while collecting.
var count := 0
var _cursor := 0
var _capacity: int
var _column_0 := PackedFloat64Array()
var _column_1 := PackedFloat64Array()
var _column_2 := PackedFloat64Array()
var _column_3 := PackedFloat64Array()
var _column_4 := PackedFloat64Array()
var _column_5 := PackedFloat64Array()
var _column_6 := PackedFloat64Array()
var _column_7 := PackedFloat64Array()
var _column_8 := PackedFloat64Array()
var _column_9 := PackedFloat64Array()
var _scratch := PackedFloat64Array()


func _init(capacity: int) -> void:
	_capacity = capacity
	_column_0.resize(capacity)
	_column_1.resize(capacity)
	_column_2.resize(capacity)
	_column_3.resize(capacity)
	_column_4.resize(capacity)
	_column_5.resize(capacity)
	_column_6.resize(capacity)
	_column_7.resize(capacity)
	_column_8.resize(capacity)
	_column_9.resize(capacity)
	_scratch.resize(capacity)


func clear() -> void:
	count = 0
	_cursor = 0


func add(frame: float, simulation: float, update: float, render: MoldPerformanceMetrics, updated: int) -> void:
	_column_0[_cursor] = frame
	_column_1[_cursor] = simulation
	_column_2[_cursor] = update
	_column_3[_cursor] = render.render_cpu_milliseconds
	_column_4[_cursor] = render.lod_cpu_milliseconds
	_column_5[_cursor] = render.upload_cpu_milliseconds
	_column_6[_cursor] = render.upload_bytes
	_column_7[_cursor] = render.upload_calls
	_column_8[_cursor] = updated
	_column_9[_cursor] = simulation + update
	_cursor = (_cursor + 1) % _capacity
	count = mini(count + 1, _capacity)


func mean(column: int) -> float:
	var total := 0.0
	var values := _get_column(column)
	for index in count: total += values[index]
	return total / count if count > 0 else 0.0


func percentile(column: int, fraction: float) -> float:
	if count == 0: return 0.0
	_scratch.resize(count)
	var values := _get_column(column)
	for index in count: _scratch[index] = values[index]
	_scratch.sort()
	var position := (count - 1) * fraction
	var lower := floori(position)
	var upper := mini(lower + 1, count - 1)
	return lerpf(_scratch[lower], _scratch[upper], position - lower)


func _get_column(column: int) -> PackedFloat64Array:
	match column:
		0: return _column_0
		1: return _column_1
		2: return _column_2
		3: return _column_3
		4: return _column_4
		5: return _column_5
		6: return _column_6
		7: return _column_7
		8: return _column_8
		9: return _column_9
	return PackedFloat64Array()
