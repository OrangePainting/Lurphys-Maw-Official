# How batching works

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

Batching lets Mold draw many shapes together using Godot's `MultiMesh`.
You don't need to arrange the batches yourself, but the choices you make about
meshes and render states affect how many batches Mold needs.

## What can share a batch

Shapes can share a batch when they use the same mesh, blend mode,
custom-material handle, render state, and local anti-aliasing quality. Render
state includes visual layers, sorting order, depth testing and writing, stencil,
and face culling.

Transforms, colors, gradients, dashes, and emission can differ without splitting
that batch. Large retained workloads are also divided into groups of slots,
so matching shapes are not guaranteed to fit in one batch. Changing a setting
that requires a different batch moves only the affected shape. If you change it back, Mold can group it with matching shapes
again.

Size changes often reuse the same mesh, but there are exceptions. Rounded
cuboids, cylinders, and prisms use meshes fitted to their proportions, so changing
those proportions can need another mesh. Detail level, prism side count,
hemisphere caps, and whether a torus is partial or full also affect mesh sharing.
See [mesh generation](mesh-generation.md) for more details.

## Frustum culling

By default, Mold calculates a bounding box around each batch and gives it to
Godot. Godot can skip the batch when that box is outside the camera's view.
This is batch-level culling: a batch that is partly visible can still draw shapes
that are off screen.

Set `Culling` to `None` in C#, or `culling_mode` to
`MoldWorldSettings.CullingMode.NONE` in GDScript, if you want to skip Mold's
bounds calculation. If your shader moves vertices beyond their normal bounds,
add `CullingBoundsPadding`/`culling_bounds_padding` to leave enough room.

Calculating bounds has a CPU cost. If most shapes are always on screen,
benchmark both options before choosing. The [performance guide](performance.md)
goes through this trade-off.

## Automatic LOD

LOD lowers mesh detail when a shape takes up less screen space. Mold uses the
viewport's active `Camera3D` and never chooses a detail level above the one you
authored.

There are three modes:

- `Continuous`, the default, fades between two mesh detail levels using
  dithering. Both meshes are drawn during the transition.
- `Automatic` switches between levels directly. A small threshold margin
  (hysteresis) stops shapes from switching back and forth near a boundary.
- `Manual` keeps the detail you authored. This is a useful choice for a fixed
  camera or UI where you already know how much detail you need.

2D SDF shapes, polylines, unrounded cuboids, and unrounded regular prisms keep
fixed meshes. Automatic LOD does not simplify them.

`LodThresholdPixels` sets the screen-size boundaries, and `LodBias` shifts the
quality choice. `LodEvaluationBudget` limits how many retained entries Mold
checks in a frame, taking turns through the list. With an orthographic camera,
Mold can skip repeat checks until a relevant camera, viewport, or shape change.

These examples show the default quality settings:

```csharp
var settings = new MoldWorldSettings
{
    LocalAaQuality = MoldLocalAaQuality.High,
    LodMode = MoldLodMode.Continuous,
    LodThresholdPixels = new Vector4(16, 32, 64, 128),
    LodEvaluationBudget = 4096,
};
```

```gdscript
var settings := MoldWorldSettings.new()
settings.local_aa_quality = MoldWorldSettings.LocalAaQuality.HIGH
settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
settings.lod_threshold_pixels = Vector4(16.0, 32.0, 64.0, 128.0)
settings.lod_evaluation_budget = 4096
```

Use `MoldLodMode.Automatic` or `MoldLodMode.Manual` in C#, and
`MoldWorldSettings.LodMode.AUTOMATIC` or `.MANUAL` in GDScript, to change modes.
Statistics include counts by detail level, active transitions, and how many
shapes changed LOD batches in the latest frame.

C# makes one exception for ordinary `Transparent` shapes with depth writes
disabled: they switch detail directly so a two-mesh fade does not break their
back-to-front ordering. GDScript currently keeps the two-mesh transition and
does not sort instances within a transparent batch.

## Updating many shapes

Use the bulk APIs when you are changing a lot of shapes at once:

| Change | C# | GDScript |
| --- | --- | --- |
| Positions | `UpdatePositions()` | `update_positions_bulk()` |
| Full transforms | `UpdateTransforms()` | `update_transforms_bulk()` |
| Colors | `UpdateColors()` | `update_colors_bulk()` |
| Line endpoints | `UpdateLinePositions()` | `update_line_positions_bulk()` |

Pass matching arrays, or spans in C#, for handles and values. Mold reads them
during the call, skips invalid handles, and uses the last value if you include
a handle more than once.

See [bulk position updates](bulk-position-updates.md) for backend selection
and update examples.

Mold tracks changed transforms separately from changed properties. Position-only
updates reuse the existing rotation, scale, and shape bounds where possible.
Only the affected groups need their bounds recalculated. Bounds can shrink
after a move or removal, as well as grow.

C# defaults to `MoldPositionUpdateMode.SIMD` for its bounds work. It uses
`System.Numerics.Vector4` when hardware acceleration is available and the group
is large enough; otherwise it uses the scalar calculation. You can select
`Managed` if you want to compare the two on your target hardware.

Unchanged batches usually skip synchronization. When an upload is needed, Godot
still receives a complete transform buffer or property texture for the batch's
allocated capacity. Updating fewer CPU records does not mean Mold sends only
those bytes to the GPU. Camera changes and C# transparent sorting can also
require another upload.

## Anti-aliasing and render state

Local anti-aliasing quality is a world setting. `High` gives the smoothest
diagonal edges, `Medium` uses a cheaper approximation, and `Off` leaves hard
edges. Set `LocalAaQuality`/`local_aa_quality` before creating the runtime.

Face culling is disabled by default. Use `MoldFaceCull.Back` in C# or
`MoldRenderState.FaceCull.BACK` in GDScript when you want to hide back faces.
Depth and stencil settings are covered in [blending](blending.md).
