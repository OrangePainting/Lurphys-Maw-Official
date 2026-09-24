# Mold Godot for GDScript

Version 0.8.0 defaults to NativeCompatible transparency. The Performance Test scene switches between Native Compatible and Batched on a 75%-alpha workload. See [Transparency ordering](../../docs/transparent-ordering.md) for behavior, costs, and upgrade notes.

This guide covers creating and updating Mold shapes from GDScript. For installation,
requirements, and the full list of example scenes, start with the
[main README](../../README.md). This directory is also a runnable Godot project,
so you can open it and try the examples directly.

## Create a runtime you own

For most procedural systems, create a `MoldRuntimeInstance` and keep it for as
long as that system needs to draw. You control its settings, mesh cache, and
cleanup. The following script creates a rounded cuboid and places it one unit
above the origin:

```gdscript
extends Node3D

var mold: MoldRuntimeInstance
var handles: Array[MoldHandle] = []


func _ready() -> void:
	mold = MoldRuntime.create_instance(self)
	var shape := mold.create(
		MoldShape.cuboid(Vector3(2.0, 2.0, 2.0), 0.4),
		MoldStyle.dual_gradient(Color.CYAN, Color.BLUE),
	)
	shape.set_position(Vector3(0.0, 1.0, 0.0))
	handles.append(shape)


func _exit_tree() -> void:
	for handle in handles:
		if handle.is_valid:
			handle.release()
	mold.dispose()
```

Attach this script to a `Node3D` in a scene with an active `Camera3D` positioned
to see the shape. Creating the shape returns a handle; keep that handle to move,
recolor, resize, or release it later.

Call `dispose()` when your system is done. It clears the runtime and the
shapes it owns. Mold also cleans up if the scene or `SubViewport` goes away,
but disposing it yourself makes the lifetime clear.

The later snippets go inside functions on this script and use the same `mold`
runtime. Keep any handles you need to update later in `handles` or their own
member variables.

## Shared and automatic runtimes

For a small script or quick prototype, the shared runtime is shorter:

```gdscript
var shape := MoldRuntime.create(
	MoldShape.cuboid(Vector3(2.0, 2.0, 2.0), 0.4),
	MoldStyle.dual_gradient(Color.CYAN, Color.BLUE),
)
```

If you need custom settings, call `MoldRuntime.configure_shared(settings)` before
anything uses it. The shared runtime draws in the root viewport and survives
scene changes. Every caller shares its capacity, mesh cache, and immediate
frame, so remember to release every retained handle you create there.

`MoldRuntime.for_node(self, settings)` is another option. It shares a runtime within
the current scene or `SubViewport`. The first call chooses its settings; later
calls reuse it and reject conflicting settings. Its handles stop being valid
when that scene or viewport leaves the tree.

This automatic runtime is what `MoldNode3D` and `MoldPolylineNode3D` use. For a
procedural system that can own its runtime, `MoldRuntime.create_instance(self)` is
usually the easier choice to manage.

## Lines and rounded shapes

`line_2d` draws a flat rectangle between endpoints, while `line_3d` draws a
cylinder. Thickness is the full width of the line. Move the endpoints through
the handle when you want to change its length or direction:

```gdscript
var handle := mold.create(
	MoldShape.line_3d(Vector3.ZERO, Vector3.UP * 2.0, 0.12, 0.35),
	MoldStyle.opaque(Color.WHITE),
)
handle.set_line_positions(Vector3.ZERO, Vector3.RIGHT * 3.0)
```

Both line types support roundness.
For a rounded `line_2d`, pass the billboard
mode after thickness, then roundness.

Rectangle lines default to `CORNER_LOCAL` rounding, which keeps the caps round.
Use `SHAPE_RELATIVE` if you want the rounding to stretch with the line.
The same controls are available on Rectangle resources in the Inspector when
line mode is enabled.

Rounded cuboids, cylinders, and prisms keep their edge radius consistent across
the shape, with limits based on the shortest dimension. Changing their
proportions, including the length of a rounded cylinder line, can select another
cached mesh. See [mesh generation](../../docs/mesh-generation.md) for when
scaling can save that work.

## Polylines

A `MoldPolyline` draws a connected stroke in its local XY plane. Each point can
have its own color and thickness multiplier. Paths can be open or closed, with
miter, bevel, or round joins and butt, square, or round end caps.

```gdscript
var path := MoldPolyline.new([
	MoldPolylinePoint.new(Vector3.LEFT, Color.RED),
	MoldPolylinePoint.new(Vector3.UP, Color.WHITE, 1.5),
	MoldPolylinePoint.new(Vector3.RIGHT, Color.BLUE),
], 0.08, false, MoldPolyline.Join.ROUND, MoldPolyline.Cap.ROUND,
	4.0, 8, MoldDash.new(8, 12, 0.25))

var path_handle := mold.create_polyline(
	path, MoldStyle.transparent(Color.WHITE))
path_handle.set_polyline_point(
	1, MoldPolylinePoint.new(Vector3.UP * 1.5, Color.GREEN, 1.5))
```

Reuse the same `MoldPolyline` for unchanged paths so shapes can share its mesh.
`set_polyline`, `set_polyline_point`, and `set_polyline_points` replace the
handle's path; they do not edit the original path object. Moving the whole handle
keeps its mesh. Immediate drawing also supports `draw.polyline(path)`.

To author a path in the editor, add `MoldPolylineNode3D`, create its
`MoldPolylineResource`, and edit the nested points in the Inspector. The node
provides a preview and handles the runtime registration for you.

## GPU polylines

Animated paths can use `MoldGpuPolylineRenderer` to update points without
rebuilding a stroke mesh.
The polyline backend policy routes `Auto` paths to GPU expansion whenever it is
supported, and otherwise falls back to cached CPU geometry.
See [GPU polylines](../../docs/gpu-polylines.md) for the API and limitations, and
[Polyline Backend](../../examples/polyline_backend/polyline_backend.tscn) for the
interactive CPU/GPU comparison demo.

## Partial shapes and billboards

A torus can use an angular span to draw part of a ring. A 2D shape can face the
camera, or turn only around world Y to stay upright, like a Doom sprite:

```gdscript
var torus := mold.create(
	MoldShape.torus(1.0, 0.25, 0.0, PI * 1.5),
	MoldStyle.dual_gradient(Color.VIOLET, Color.CYAN),
)
var badge := mold.create(
	MoldShape.disc(0.5).with_billboard(),
	MoldStyle.transparent(Color.WHITE),
)
var upright_badge := mold.create(
	MoldShape.disc(0.5).with_billboard(MoldShape.BillboardMode.FACE_CAMERA_Y),
	MoldStyle.transparent(Color.WHITE),
)
var view_line := mold.create(
	MoldShape.line_2d(
		Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, 1.0), 0.1,
		MoldShape.BillboardMode.FACE_CAMERA,
	),
	MoldStyle.opaque(Color.WHITE),
)
```

The two badges show the full camera-facing and upright options. The final line
keeps its endpoints in 3D space and turns its width toward the camera.

## Colors and gradients

`dual_radial()` blends by distance from the local origin of a 2D or 3D shape, including rims.
Use `dual_radial_bounds()` to fit the gradient to the shape's boundary:

```gdscript
var centered := MoldStyle.dual_radial(Color.WHITE, Color.BLUE)
var fitted := MoldStyle.dual_radial_bounds(Color.WHITE, Color.BLUE)
```

`dual_radial_bounds()` blends from the inner edge to the outer edge on a 3D torus;
other 3D primitives treat it as radial. Angular color rotates around local Y
from +X toward +Z, fitting a torus's start/span range. Directional gradients
also work on 3D shapes. You can choose linear RGB or Oklab interpolation separately from the
blend mode. Oklab can give nicer color transitions, but costs extra GPU work.
See [blending](../../docs/blending.md) for the modes and renderer differences.

## Dashes

Dashes work on rings, rims, and lines. The count-based pattern below
fits 12 periods around the ring, with gaps taking up 45% of each period:

```gdscript
var dash := MoldDash.new(
	12,
	12,
	0.45,
	0.0,
	MoldDash.Type.CHEVRON,
	0.8,
)

var ring := mold.create(
	MoldShape.ring(1.5, 0.12, 0.0, TAU, dash),
	MoldStyle.additive(Color.CYAN),
)

var dashed_line := MoldShape.line_3d(
	Vector3.LEFT, Vector3.RIGHT, 0.12, 0.35,
).with_dash(MoldDash.new(10, 10, 0.5))
```

For a line, a count-based pattern stretches across the endpoint span.
Fixed-length dash patterns are also available when you want the dash and gap
lengths to stay in local-space units.

Flat rectangle lines support normal, chevron, and rounded dash profiles.
Cylinder lines use the normal profile. Their gaps are shader cuts, so there are
no extra cap faces inside those gaps.

## Update many shapes at once

Use the bulk APIs when many shapes change together. Reuse the input arrays
across frames to avoid creating more temporary data.

```gdscript
var positions := PackedVector3Array()
positions.resize(handles.size())

for index in handles.size():
	positions[index] = calculate_position(index)

mold.update_positions_bulk(handles, positions)
```

`calculate_position(index)` stands for your own animation function. Allocate
`positions` once and refill it when updating the shapes. The other bulk methods
are:

| Change | Method and input arrays |
| --- | --- |
| Colors | `update_colors_bulk(handles, colors)` with a `PackedColorArray`. |
| Full transforms | `update_transforms_bulk(handles, positions, rotations, scales)` with packed position/scale arrays and `Array[Quaternion]` rotations. |
| Line endpoints | `update_line_positions_bulk(handles, starts, ends)` with two `PackedVector3Array` values. |

All arrays in a call must have equal lengths. Mold reads them during the call,
skips invalid handles, and uses the last value if you include a handle more than
once. The return value counts accepted entries, including duplicates; endpoint
updates also skip handles that are not lines. Finish any worker writes before
passing the arrays to Mold.

Use position-only updates when rotation and scale are unchanged. Color-only
updates likewise avoid touching the transform. See
[batching](../../docs/batching.md) for how these edits reach the renderer.

## Immediate drawing

For content you want to describe again every frame, the immediate API saves you
from keeping a handle for each shape.
`draw()` replaces the previous immediate
frame for that context. `with_state()` restores your drawing settings when the
callback ends:

```gdscript
mold.draw(func(draw: MoldImmediate) -> void:
	draw.with_state(func() -> void:
		draw.style = MoldStyle.opaque(Color.CYAN)
		draw.thickness = 0.04
		draw.dash = MoldDash.new(10, 10, 0.5)
		draw.line(Vector3.LEFT, Vector3.RIGHT)
	)
)
```

Run this drawing code each frame if the content is animated. Commands stay
visible until the next immediate frame replaces them or the runtime shuts down.
Keep immediate drawing coordinated within a context, since starting another
frame replaces what earlier callers drew.

For camera-dependent drawing and editor visualization, extend
`MoldImmediateDrawer3D` from a tool script. Mold invokes all drawers in a viewport
through one shared frame, so compatible commands still batch together:

```gdscript
@tool
extends MoldImmediateDrawer3D

@export_range(0.0, 60.0, 0.1) var preview_time := 0.0:
	set(value):
		preview_time = value
		request_redraw()

func draw_molds(draw: MoldImmediate, camera: Camera3D) -> void:
	draw.style = MoldStyle.opaque(Color.CYAN)
	draw.line(Vector3.ZERO, Vector3.FORWARD * 2.0)
```

Call `request_redraw()` after externally owned preview data changes. Editor
cameras automatically trigger another frame when their transform, projection,
viewport, or culling mask changes. Editor previews use each shape's requested
detail exactly; runtime drawers use the normal screen-space LOD policy. Enable
`continuously_redraw` only for editor animation that changes without an Inspector
or transform edit.

## Mesh cache and statistics

Prewarm shapes before a busy frame if you want to generate their meshes ahead
of time. You can also read the context's statistics to see how many shapes and
batches it currently holds:

```gdscript
mold.prewarm([
	MoldShape.sphere(1.0, MoldShape.Detail.MEDIUM),
	MoldShape.cuboid(Vector3.ONE, 0.35),
])

var stats := mold.statistics
print("%d molds in %d batches" % [stats.active_mold_count, stats.batch_count])
```

`active_mold_count` counts retained shapes. Use `immediate_command_count` and
`immediate_batch_count` for immediate drawing. `batch_count` includes both kinds.
Call `clear_unused_meshes()` when you want to drop cached meshes that are no
longer in use.

Prewarmed meshes still count toward the unused-cache limit. See
[mesh generation](../../docs/mesh-generation.md) for the cache settings.

## More guides

- [Performance choices](../../docs/performance.md)
- [Performance test metrics](../../docs/performance-metrics.md)
- [Custom materials](../../docs/custom-materials.md)
- [Rendering game UI](../../docs/ui-rendering.md)
- [Architecture and runtime ownership](../../docs/architecture.md)
