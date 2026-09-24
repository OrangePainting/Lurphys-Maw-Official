# GPU polylines

Use `MoldGpuPolylineRenderer` for paths whose points change frequently.
Create the paths with
`SetData`/`set_data`, animate with `UpdatePoints`/`update_points`, and dispose the
stream when finished. Disposing the owning runtime also disposes its streams.

The Godot implementation uses a fixed ArrayMesh and two floating-point textures.
Its vertex shader expands neighboring points into stroke geometry, then feeds
Godot's existing polyline coverage/color shader. Point updates upload a texture;
they do not regenerate or upload a stroke mesh. There is no compute dispatch,
RenderingDevice requirement, or GDExtension dependency.

Forward+, Mobile, and Compatibility are supported. `IsSupported`/`is_supported()`
returns false in headless mode. Desktop rendering has been tested on all three
renderers; browser exports and other GPU/driver combinations still need target
validation. C# retains Godot's existing .NET web-export limitation.

## Retained and authored paths

`MoldContext.Create(polyline, ..., backend: MoldPolylineBackend.Auto)` and
`create_polyline(..., MoldPolylineBackend.Mode.AUTO)` use the GPU backend when
eligible. `MoldPolylineNode3D.Backend`/`backend` uses the same world policy.
`IsUsingGpuBackend`/`is_using_gpu_backend` reports the node's actual allocation.
Editor previews continue using CPU meshes.

Explicit `CPU` always uses cached geometry. `Auto` selects GPU
expansion whenever the backend supports the path and material. This includes
multiple retained handles sharing the same immutable path object. It falls back
to CPU when GPU rendering is unavailable, the point count exceeds stream capacity,
the color mode is unsupported, or a custom material has not opted into the GPU
shader contract. If eligibility changes, Mold switches backends before the next rendering
update. The handle stays valid. Each GPU path currently owns a
separate draw.

`SetPolyline`, `SetPolylinePoint`, and `SetPolylinePoints` keep their create-and-replace
path behavior. When point count and closed/open topology stay unchanged, a GPU
handle reuses its carrier mesh and uploads new point data. These convenience
setters still allocate replacement path objects. Use the explicit stream API for
large animated datasets.

## Create and update a stream

### C#

Keep the runtime, stream, and point array in fields. The setup belongs in
`_Ready`, point updates in your animation method, and disposal in `_ExitTree`.
Use `using Godot;` and `using Mold;` in the script.

```csharp
MoldRuntimeInstance runtime = MoldRuntime.CreateInstance(this);
MoldGpuPolylineRenderer stream = runtime.CreateGpuPolylineRenderer();
MoldGpuPolylinePoint[] points =
[
    new(new Vector3(-1, 0, 0), 0.05f, Colors.Cyan),
    new(new Vector3( 0, 1, 0), 0.08f, Colors.White),
    new(new Vector3( 1, 0, 0), 0.05f, Colors.Magenta),
];
stream.SetData(points, [new MoldGpuPolylineRange(0, points.Length)]);
stream.Join = MoldPolylineJoin.Round;
stream.Cap = MoldPolylineCap.Round;
stream.Configure(MoldStyle.Transparent(Colors.White));

// In an animation update: reuse your point array.
points[1].Position.Y = animatedHeight;
stream.UpdatePoints(points);

// On teardown:
stream.Dispose();
runtime.Dispose();
```

### GDScript

GDScript uses eight packed floats per point to avoid one object allocation per
animated point. The fields are **x, y, z, absolute thickness, r, g, b, a**.

```gdscript
var runtime := MoldRuntime.create_instance(self)
var stream := runtime.create_gpu_polyline_renderer()
var points := PackedFloat32Array([
    -1, 0, 0, 0.05, 0, 1, 1, 1,
     0, 1, 0, 0.08, 1, 1, 1, 1,
     1, 0, 0, 0.05, 1, 0, 1, 1,
])
stream.set_data(points, [MoldGpuPolylineRange.new(0, 3)])
stream.join = MoldPolyline.Join.ROUND
stream.cap = MoldPolyline.Cap.ROUND
stream.configure(MoldStyle.transparent(Color.WHITE))

points[9] = animated_height
stream.update_points(points)

stream.dispose()
runtime.dispose()
```

Points use absolute stroke thickness; `MoldPolylinePoint` instead multiplies a
path's base thickness. `SetPolyline`/`set_polyline` performs that conversion.
Ranges may describe multiple open or closed paths. Open paths require at least
two points; closed paths require three. The stream shares one transform, style,
render state, and sorting order across its ranges. Points and thickness must be
finite, and thickness positive. Keep those values valid on every update;
initial validation does not make later point data safe automatically.

`SetTransform`/`set_transform` sets the transform relative to the owning world.
`SetVisible`/`set_visible` controls the whole stream. Points may preserve a Z
coordinate, but joins and width are calculated in local XY; this is a planar
stroke renderer, not a camera-facing 3D ribbon or tube renderer.

## Bounds, materials, and costs

Updates recalculate conservative CPU bounds by default. Supply a fixed animation
envelope with `SetLocalBounds`/`set_local_bounds` and pass `false` to point updates
to skip that scan. Include the full animated stroke, joins, caps, and anticipated
AA expansion in manual bounds. Automatic bounds include stroke/miter padding and
an extra local-space margin; extreme zoom-out can require a larger manual bound.

Miter, bevel, and round joins; butt, square, and round caps; per-point colors and
widths; Single/DualGradient colors; and the existing Godot blend/depth/stencil
behavior are supported. GPU point colors retain float/HDR precision; CPU mesh
vertex colors remain subject to Godot's vertex-color quantization. Existing
Godot blend-mode approximations still apply.

Custom materials must opt in with boolean metadata `MoldGpuPolyline = true` and
implement the GPU shader contract. C# can start with
`MoldGpuPolylineRenderer.CreateShader(mode, state)`; GDScript can assign
`MoldGpuPolylineRenderer.shader_source(mode, state)` to a Shader's `code`.
Set the metadata on the ShaderMaterial, then use `SetMaterial`/`set_material` on a
stream, or register it as the retained path's custom material. Mold duplicates the
material before setting uniforms. The custom shader owns its render modes;
changing the stream's render state does not rewrite custom shader source.
The shared `mold_gpu_polyline.gdshaderinc` exposes the point/segment texture layout
and vertex attribute generator for more extensive customization.

`SetData` records the distances along each path.
Point uploads therefore preserve rest-length progress; call SetData if a custom
shader needs new distance metrics. Public polyline dashes remain unsupported.
Round subdivisions do not affect the stroke outline.

The carrier uses 12 vertices per segment for miter joins without round caps,
otherwise 36. The extra vertices cover the joins and caps. A change
between these layouts rebuilds the carrier; ordinary point motion does not.

<details>
<summary>Texture capacity and upload details</summary>

Point payload is 32 bytes per point, plus texture row padding and engine copies.
Textures use 1024-wide rows with a maximum of 4096 rows per stream; split larger
streams. ImageTexture updates upload a whole image. GDScript packed-array copy
and byte conversion costs remain, so CPU point production and upload time should
be measured separately from GPU expansion. Shared retained paths each receive a
GPU stream under `Auto`.

</details>

## Try the example

Open the C# demo
or [GDScript demo](../examples/polyline_backend/polyline_backend.tscn).
Both show an animated wave field and provide Auto/CPU
buttons, an animation toggle, a line-count control from 8 to 1024, and frame,
point-production, and update timing readouts. They start at 128 paths with 192
points each. Topology changes only when Set is pressed or relevant exported
settings change. The timings include normal frame overhead and are not GPU timer
queries.
