# Using Mold in code

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

Create a runtime, keep the handles for shapes that persist, and update them
as the game changes. This guide collects the code workflow; start with the
[main README](../README.md) for installation and examples.

## Create and manage a runtime

For procedural content, create and keep your own `MoldRuntimeInstance`.
This gives your system its own settings, capacity, mesh cache, and immediate
frame. You are responsible for disposing it when the system is done.

Use `MoldRuntime.CreateInstance(this)` in C# or
`MoldRuntime.create_instance(self)` in GDScript. The language guides include
complete scripts with creation and cleanup:

- [C# runtime example](../ports/csharp/README.md#create-a-runtime-you-own)
- [GDScript runtime example](../ports/gdscript/README.md#create-a-runtime-you-own)

For a small script or quick prototype, `MoldRuntime.Create(...)`/`create(...)`
uses a shared runtime. It survives scene changes, so release every retained
handle. `MoldRuntime.For(...)`/`for_node(...)` shares a runtime within a scene
or `SubViewport`. See [architecture](architecture.md) for ownership choices.

## Create shapes and styles

Rectangles and cylinders have line modes, available through
`MoldShape.Line2D`/`line_2d` and `MoldShape.Line3D`/`line_3d`.
Thickness is the full line width. Use `SetLinePositions`/`set_line_positions`
to change local endpoints, or the handle's transform to move the whole line.

2D shapes can face the camera with `WithBillboard`/`with_billboard`.
`FaceCamera` turns toward the camera; `FaceCameraY` rotates only around world Y.
Rounded 3D shapes fit their edges to their proportions, so changing proportions
can require a different cached mesh. `SetScale`/`set_scale` stretches the
existing shape when that appearance is acceptable.

The language guides cover partial shapes, polylines, colors, gradients, and dashes:

- [C# shapes and styles](../ports/csharp/README.md#lines-and-rounded-shapes)
- [GDScript shapes and styles](../ports/gdscript/README.md#lines-and-rounded-shapes)

See [blending](blending.md) for blend modes and color interpolation, and
[mesh generation](mesh-generation.md) for mesh reuse.

## Update and draw each frame

Keep handles for shapes that persist. Move, recolor, or resize them as values
change instead of releasing and recreating them every frame.

For many shapes at once, use the bulk position, color, transform, or line-endpoint
APIs. These methods read matching arrays during the call; C# also accepts spans.
Call Mold APIs on the main thread.

For content you want to describe again each frame, use the immediate API.
Starting another immediate frame replaces the previous one for that context,
so keep those calls coordinated. Immediate shapes do not use retained handles.

`MoldImmediateDrawer3D` supports camera-driven drawing and editor previews.
The language guides include complete examples:

- [C# immediate drawing](../ports/csharp/README.md#immediate-drawing)
- [GDScript immediate drawing](../ports/gdscript/README.md#immediate-drawing)

## Choose the next guide

- [Architecture and runtime ownership](architecture.md)
- [Batching, culling, and LOD](batching.md)
- [Bulk position updates](bulk-position-updates.md)
- [GPU polylines](gpu-polylines.md)
- [Custom materials](custom-materials.md)
- [Mesh generation and caching](mesh-generation.md)
