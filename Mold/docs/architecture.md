# Architecture

Mold keeps your shapes, meshes, and rendering batches in a `MoldWorld`.
You talk to it through `MoldContext`, so you don't need to create or manage a
renderer yourself. This guide explains what happens behind that API.

## Choosing who owns the runtime

For most procedural systems, create a `MoldRuntimeInstance` with
`MoldRuntime.CreateInstance(node)` in C# or
`MoldRuntime.create_instance(node)` in GDScript. Keep it for as long as the
system needs to draw, then dispose it. This gives you control over its settings,
mesh cache, and cleanup.

There are also two shortcuts:

- `MoldRuntime.For(node)`/`MoldRuntime.for_node(node)` shares a runtime within
  the current scene or `SubViewport`. This is what the authoring nodes use.
- `MoldRuntime.Create(...)`/`MoldRuntime.create(...)` uses the shared runtime
  for the root viewport. It is convenient for a small script, but it survives
  scene changes, so remember to release the shapes you create.

Mold hides its renderer nodes in the scene tree. Owned and automatic runtimes
also shut down when their scene or `SubViewport` goes away. Disposing your owned
runtime yourself is still the clearest way to say that your system is done.

## Creating and updating shapes

Creating a shape returns a `MoldHandle`. Keep that handle and use it to move,
recolor, resize, or release the shape. Mold stores its own copy of the shape and
style, so changing the original descriptor later does not change an existing
shape.

Handles also remember which world and slot they belong to. When a slot is
reused, it gets a new generation number. This prevents an old handle from
accidentally editing a newer shape, and keeping a shape handle does not keep its
world alive.

Mold tracks transform changes separately from color and other property changes.
Moving a shape therefore does not require repacking its unchanged colors,
dashes, or emission. Releasing a shape fills its batch slot with the last entry,
so batches stay compact without shifting every remaining shape.

Rectangle and cylinder lines store their endpoints in local space. Mold combines
the line's placement with the handle's transform. Moving the endpoints usually
reuses the same mesh; changing the proportions of a rounded cylinder line can
require a different rounded mesh.

## Drawing shapes in batches

Mold groups shapes that can render together into batches. Each batch owns a
`MultiMeshInstance3D`, a `MultiMesh`, and a material. Shapes need compatible
meshes, blend modes, render states, and custom materials to share a batch.
Colors, gradients, dashes, and transforms can differ within that batch.
See [batching](batching.md) for the settings that affect this.

Transforms are sent through Godot's bulk MultiMesh buffer, so Mold can update a
whole batch without making a separate engine call for every shape.

The other shape properties live in a floating-point texture. The shader reads the
entry belonging to each shape. This is how differently colored or dashed shapes can
share the same material. The [custom-material guide](custom-materials.md) lists
the layout if you need to read it in your own shader.

Generated meshes are cached and can be shared by several batches. Built-in
shaders are also reused when their blend, depth, stencil, and face-culling
settings match.

## How shapes get their appearance

The six 2D shape families all start with the same quad. The fragment shader
calculates which pixels belong to the shape using a signed-distance function
(SDF). It also handles rims, dashes, and smooth edges. `High` local
anti-aliasing is the default; `Medium` and `Off` reduce the shader work.

3D shapes use meshes generated at runtime. Some shapes also change their
vertices in the shader. For example, capsules can change height while keeping
their caps round, without generating a separate mesh for every height.
CPU polylines have their own generated stroke meshes. GPU polylines instead
expand fixed carrier meshes from point and segment textures in a spatial shader.
Their streams belong to the world and are cleaned up with it. See
[GPU polylines](gpu-polylines.md) for backend selection and streaming updates. See
[mesh generation](mesh-generation.md) for the cache and shape details.

Mold starts by converting the colors you supply from sRGB to linear RGB.
Oklab gradients take an extra conversion through Oklab for the blend. Mold
converts the final output back to sRGB when the renderer needs it.
This keeps ordinary colors similar across renderers, although HDR emission and
advanced blending can still look different in Compatibility. See
[blending](blending.md) for those differences.

## Depth, transparency, and stencil

Mold renders into the scene viewport, using Godot's cameras, visual layers, and
depth buffer. `MoldRenderState` controls how a batch interacts with them.
Godot exposes three depth-test choices through this rendering path:
`LessEqual`, `Greater`, and `Always`. Stencil reads use the transparent pass,
even for a shape whose style is otherwise opaque.

The C# renderer sorts ordinary `Transparent` shapes from back to front within
each batch when depth writes are disabled. Those shapes use discrete automatic
LOD changes, even in `Continuous` mode, because a crossfade would split each
shape across two separately sorted draws. Explicitly enabling depth writes
allows the continuous transition again.

The GDScript renderer currently has neither that per-instance transparent sort
nor the automatic fallback to discrete LOD. Keep this difference in mind when
working with overlapping transparent shapes. Custom shaders also need to handle
their own transparency and LOD behavior.

## Authoring in the editor

`MoldNode3D` and `MoldPolylineNode3D` let you author retained shapes in the editor.
Each node registers a handle with the automatic runtime for its scene or
`SubViewport`, then updates that handle when you edit its resources or transform.
It releases the handle when it leaves, including before joining a different
scene or viewport runtime.

Editor previews use cached meshes and the same shader logic as runtime rendering.
The preview child is internal and is not saved into your scene.

## Language and integration

The C# port targets .NET 8 and uses Godot's `Vector2`, `Vector3`, `Quaternion`,
`Color`, and `Transform3D` types. Most of the API lives in `Mold`. The `Radius`
and `Diameter` helpers live in `Mold.MoldMath`, so you can import them only when
you want those names in your code.
