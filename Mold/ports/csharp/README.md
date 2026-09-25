# Mold Godot for C#

Version 0.8.0 defaults to NativeCompatible transparency. The Performance Test scene switches between Native Compatible and Batched on a 75%-alpha workload. See [Transparency ordering](../../docs/transparent-ordering.md) for behavior, costs, and upgrade notes.

This guide covers creating and updating Mold shapes from C#. For installation,
requirements, and the full list of example scenes, start with the
[main README](../../README.md). This directory is also a runnable Godot project,
so you can open it and try the examples directly.

Use the .NET build of Godot and build the project before running the C# scenes.

## Create a runtime you own

For most procedural systems, create a `MoldRuntimeInstance` and keep it for as
long as that system needs to draw. You control its settings, mesh cache, and
cleanup. The following script creates a rounded cuboid and places it one unit
above the origin:

```csharp
using System.Collections.Generic;
using Godot;
using Mold;

public partial class MoldExample : Node3D
{
    private MoldRuntimeInstance _mold = null!;
    private readonly List<MoldHandle> _handles = [];

    public override void _Ready()
    {
        _mold = MoldRuntime.CreateInstance(this);
        MoldHandle shape = _mold.Create(
            MoldShape.Cuboid(new Vector3(2, 2, 2), 0.4f),
            MoldStyle.DualGradient(Colors.Cyan, Colors.Blue));
        shape.SetPosition(new Vector3(0, 1, 0));
        _handles.Add(shape);
    }

    public override void _ExitTree()
    {
        foreach (MoldHandle handle in _handles)
            if (handle.IsValid)
                handle.Release();
        _mold.Dispose();
    }
}
```

Attach this script to a `Node3D` in a scene with an active `Camera3D` positioned
to see the shape. Creating the shape returns a handle; keep that handle to move,
recolor, resize, or release it later.

Call `Dispose()` when your system is done. It clears the runtime and the
shapes it owns. Mold also cleans up if the scene or `SubViewport` goes away,
but disposing it yourself makes the lifetime clear.

The later snippets go inside methods on this script and use the same `_mold`
runtime. Add any retained handles you need to update later to `_handles` or
keep them in their own fields.

## Shared and automatic runtimes

For a small script or quick prototype, the shared runtime is shorter:

```csharp
MoldHandle shape = MoldRuntime.Create(
    MoldShape.Cuboid(new Vector3(2, 2, 2), 0.4f),
    MoldStyle.DualGradient(Colors.Cyan, Colors.Blue));
```

If you need custom settings, call `MoldRuntime.ConfigureShared(settings)` before
anything uses it. The shared runtime draws in the root viewport and survives
scene changes. Every caller shares its capacity, mesh cache, and immediate
frame, so remember to release every retained handle you create there.

`MoldRuntime.For(this, settings)` is another option. It shares a runtime within
the current scene or `SubViewport`. The first call chooses its settings; later
calls reuse it and reject conflicting settings. Its handles stop being valid
when that scene or viewport leaves the tree.

This automatic runtime is what `MoldNode3D` and `MoldPolylineNode3D` use. For a
procedural system that can own its runtime, `MoldRuntime.CreateInstance(this)` is
usually the easier choice to manage.

## Lines and rounded shapes

`Line2D` draws a flat rectangle between endpoints, while `Line3D` draws a
cylinder. Thickness is the full width of the line. Move the endpoints through
the handle when you want to change its length or direction:

```csharp
MoldHandle handle = _mold.Create(
    MoldShape.Line3D(Vector3.Zero, Vector3.Up * 2.0f, 0.12f, 0.35f),
    MoldStyle.Opaque(Colors.White));
handle.SetLinePositions(Vector3.Zero, Vector3.Right * 3.0f);
```

Both line types support roundness.
For a rounded `Line2D`, pass roundness after
the diameter; the optional billboard mode comes after roundness.

Rectangle lines default to `CornerLocal` rounding, which keeps the caps round.
Use `ShapeRelative` if you want the rounding to stretch with the line.
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

```csharp
MoldPolyline path = new(
    [
        new(Vector3.Left, Colors.Red),
        new(Vector3.Up, Colors.White, 1.5f),
        new(Vector3.Right, Colors.Blue),
    ],
    thickness: 0.08f,
    join: MoldPolylineJoin.Round,
    cap: MoldPolylineCap.Round,
    dash: new MoldDash(8, 12, 0.25f));

MoldHandle pathHandle = _mold.Create(path, MoldStyle.Transparent(Colors.White));
pathHandle.SetPolylinePoint(1,
    new MoldPolylinePoint(Vector3.Up * 1.5f, Colors.Green, 1.5f));
```

Reuse the same `MoldPolyline` for unchanged paths so shapes can share its mesh.
`SetPolyline`, `SetPolylinePoint`, and `SetPolylinePoints` replace the handle's
path; they do not edit the original path object. Moving the whole handle keeps
its mesh. Immediate drawing also supports `draw.Polyline(path)`.

To author a path in the editor, add `MoldPolylineNode3D`, create its
`MoldPolylineResource`, and edit the nested points in the Inspector. The node
provides a preview and handles the runtime registration for you.

## GPU polylines

Animated paths can use `MoldGpuPolylineRenderer` to update points without
rebuilding a stroke mesh.
The polyline backend policy routes `Auto` paths to GPU expansion whenever it is
supported, and otherwise falls back to cached CPU geometry.
See [GPU polylines](../../docs/gpu-polylines.md) for the API and limitations, and
Polyline Backend for the
interactive CPU/GPU comparison demo.

## Partial shapes and billboards

A torus can use an angular span to draw part of a ring. A 2D shape can face the
camera, or turn only around world Y to stay upright, like a Doom sprite:

```csharp
MoldHandle torus = _mold.Create(
    MoldShape.Torus(1.0f, 0.25f, 0.0f, Mathf.Pi * 1.5f),
    MoldStyle.DualGradient(Colors.Violet, Colors.Cyan));
MoldHandle badge = _mold.Create(
    MoldShape.Disc(0.5f).WithBillboard(),
    MoldStyle.Transparent(Colors.White));
MoldHandle uprightBadge = _mold.Create(
    MoldShape.Disc(0.5f).WithBillboard(MoldShape.BillboardMode.FaceCameraY),
    MoldStyle.Transparent(Colors.White));
MoldHandle viewLine = _mold.Create(
    MoldShape.Line2D(
        new(-1, 0, -1), new(1, 0, 1), 0.1f,
        MoldShape.BillboardMode.FaceCamera),
    MoldStyle.Opaque(Colors.White));
```

The two badges show the full camera-facing and upright options. The final line
keeps its endpoints in 3D space and turns its width toward the camera.

## Colors and gradients

`DualRadial()` blends by distance from the local origin of a 2D or 3D shape, including rims.
Use `DualRadialBounds()` to fit the gradient to the shape's boundary:

```csharp
MoldStyle centered = MoldStyle.DualRadial(Colors.White, Colors.Blue);
MoldStyle fitted = MoldStyle.DualRadialBounds(Colors.White, Colors.Blue);
```

`DualRadialBounds()` blends from the inner edge to the outer edge on a 3D torus;
other 3D primitives treat it as radial. Angular color rotates around local Y
from +X toward +Z, fitting a torus's start/span range. Directional gradients
also work on 3D shapes. You can choose linear RGB or Oklab interpolation separately from the
blend mode. Oklab can give nicer color transitions, but costs extra GPU work.
See [blending](../../docs/blending.md) for the modes and renderer differences.

## Dashes

Dashes work on rings, rims, and lines. The count-based pattern below
fits 12 periods around the ring, with gaps taking up 45% of each period:

```csharp
MoldDash dash = new(
    fillCount: 12,
    totalCount: 12,
    spacing: 0.45f,
    type: MoldDashType.Chevron,
    modifier: 0.8f);

MoldHandle ring = _mold.Create(
    MoldShape.Ring(1.5f, 0.12f, dash),
    MoldStyle.Additive(Colors.Cyan));

MoldShape dashedLine = MoldShape.Line3D(
    Vector3.Left, Vector3.Right, 0.12f, 0.35f).WithDash(
        new MoldDash(10, 10, 0.5f));
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

```csharp
_mold.UpdatePositions(handles, positions);
_mold.UpdateColors(handles, colors);
_mold.UpdateTransforms(handles, positions, rotations, scales);
_mold.UpdateLinePositions(lineHandles, starts, ends);
```

Here `handles` and `lineHandles` are `MoldHandle[]` arrays, with matching
`Vector3[]`, `Quaternion[]`, or `Color[]` values. These methods accept
`ReadOnlySpan<T>`, so arrays can be passed directly. If you keep handles in a
list, build and reuse an array for bulk animation.

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
`BeginImmediate()` replaces the previous
immediate frame for that context. `StateScope()` restores your drawing settings
when the scope ends:

```csharp
using MoldImmediateFrame draw = _mold.BeginImmediate();
using (draw.StateScope())
{
    draw.Color = Colors.Cyan;
    draw.Thickness = 0.04f;
    draw.Dash = new MoldDash(10, 10, 0.5f);
    draw.Line(Vector3.Left, Vector3.Right);
}
```

Run this drawing code each frame if the content is animated. Commands stay
visible until the next immediate frame replaces them or the runtime shuts down.
Keep immediate drawing coordinated within a context, since starting another
frame replaces what earlier callers drew.

For camera-dependent drawing and editor visualization, derive a tool script from
`MoldImmediateDrawer3D`. Mold invokes all drawers in a viewport through one shared
frame, so compatible commands still batch together:

```csharp
[Tool]
public partial class AimGuide : MoldImmediateDrawer3D
{
    private float _previewTime;

    [Export(PropertyHint.Range, "0,60,0.1")]
    public float PreviewTime
    {
        get => _previewTime;
        set { _previewTime = value; RequestRedraw(); }
    }

    public override void DrawMolds(MoldImmediateFrame draw, Camera3D? camera)
    {
        draw.Color = Colors.Cyan;
        draw.Line(Vector3.Zero, Vector3.Forward * 2);
    }
}
```

Call `RequestRedraw()` after externally owned preview data changes. Editor cameras
automatically trigger another frame when their transform, projection, viewport,
or culling mask changes. Editor previews use each shape's requested detail exactly;
runtime drawers use the normal screen-space LOD policy. Enable `ContinuouslyRedraw`
only for editor animation that changes without an Inspector or transform edit.

## Mesh cache and statistics

Prewarm shapes before a busy frame if you want to generate their meshes ahead
of time. You can also read the context's statistics to see how many shapes and
batches it currently holds:

```csharp
_mold.Prewarm(new[]
{
    MoldShape.Sphere(1.0f, MoldShape.Detail.Medium),
    MoldShape.Cuboid(Vector3.One, 0.35f),
});

MoldStatistics stats = _mold.Statistics;
GD.Print($"{stats.ActiveMoldCount} molds in {stats.BatchCount} batches");
```

`ActiveMoldCount` counts retained shapes. Use `ImmediateCommandCount` and
`ImmediateBatchCount` for immediate drawing. `BatchCount` includes both kinds.
Call `ClearUnusedMeshes()` when you want to drop cached meshes that are no
longer in use.

Prewarmed meshes still count toward the unused-cache limit. See
[mesh generation](../../docs/mesh-generation.md) for the cache settings.

## Managed and SIMD processing

C# defaults to `SIMD` for cached bounds calculations, using
`System.Numerics.Vector4` when hardware acceleration is available. You can
switch a live context to `Managed` and check which mode it actually uses:

```csharp
_mold.SetPositionUpdateMode(MoldPositionUpdateMode.Managed);
MoldPositionUpdateMode effective = _mold.EffectivePositionUpdateMode;
bool supported = MoldContext.IsPositionUpdateModeAvailable(
    MoldPositionUpdateMode.SIMD);
```

Set `PositionUpdateMode` on `MoldWorldSettings` to choose the initial mode.
Settings are copied when the runtime is created, so use
`SetPositionUpdateMode` for later changes.

Unsupported hardware falls back to Managed while keeping the requested mode
set to SIMD. Small groups use the scalar calculation in either mode. Switching
does not require rebuilding existing bounds. Both modes run synchronously;
SIMD speeds up the calculation without moving it to worker threads.

The performance scene has a Managed/SIMD selector. Benchmarks also accept
`--benchmark-mode=managed` or `--benchmark-mode=simd` after Godot's `--` separator.
Results include `position_update_mode`, `effective_position_update_mode`, and
`simd_available`. Benchmark an exported build on your target hardware to see
which works better for your project.

## More guides

- [Performance choices](../../docs/performance.md)
- [Performance test metrics](../../docs/performance-metrics.md)
- [Custom materials](../../docs/custom-materials.md)
- [Rendering game UI](../../docs/ui-rendering.md)
- [Architecture and runtime ownership](../../docs/architecture.md)
