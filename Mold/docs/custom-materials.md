# Custom materials

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

Custom materials let you draw Mold shapes with your own shader. Mold still
handles the meshes, transforms, batching, and visibility. You decide how the
shapes look.

This feature expects you to be comfortable writing Godot spatial shaders.
Mold's built-in effects do not automatically carry over: your shader needs to
handle the colors, shape masks, billboards, dashes, and other features you use.
Start with a simple 3D shape, then add the behavior your effect needs.

## Getting started

1. Write a spatial shader that reads Mold's instance data.
2. Create a `ShaderMaterial` using that shader.
3. Register it with the context that will draw your shapes.
4. Keep the returned material handle and use it in
   `MoldStyle.Custom`/`MoldStyle.custom`.
5. Draw shapes with that style, using retained handles or the immediate API.

A material registration belongs to one Mold world. Reuse its handle within that
world; register the material again if you need it in a different runtime.

## A minimal shader

Mold includes a helper file for reading the data belonging to each shape.
The installed path depends on your port:

- C#: `res://addons/mold/Runtime/Rendering/mold_instance_data.gdshaderinc`
- GDScript: `res://addons/mold/runtime/rendering/mold_instance_data.gdshaderinc`

This example colors a mesh and supports continuous LOD transitions. It is a
useful starting point for cuboids and spheres. Save it as
`res://materials/mold_hologram.gdshader` to use the registration examples below,
and change the include path if you are using C#.

```glsl
shader_type spatial;
render_mode unshaded, cull_back;

// Use the path for the installed port.
#include "res://addons/mold/runtime/rendering/mold_instance_data.gdshaderinc"

varying flat vec4 mold_color;
varying flat vec4 mold_lod;

void vertex() {
	mold_color = mold_instance_fetch(
		INSTANCE_ID, MOLD_INSTANCE_PRIMARY_COLOR);
	mold_lod = mold_instance_fetch(
		INSTANCE_ID, MOLD_INSTANCE_LOD_DATA);
}

void fragment() {
	// Required when the world uses Continuous LOD. Without this, both meshes
	// in a transition can be visible at once.
	if (!mold_lod_visible(mold_lod, FRAGCOORD.xy)) {
		discard;
	}

	ALBEDO = mold_output_color(mold_color.rgb);
}
```

`mold_output_color` converts Mold's linear RGB to the output the current Godot
renderer expects. Use it for colors you read from Mold. Values that are already
in the output color space do not need that conversion again.

For transparency, choose a transparent `render_mode` and write `ALPHA`.
For lighting, remove `unshaded` and use the normal spatial shader outputs.
Mold does not change your shader's render modes for you.

## Register and draw

### C#

```csharp
using Godot;
using Mold;

public partial class CustomMoldExample : Node3D
{
    private MoldRuntimeInstance _mold = null!;
    private MoldHandle _shape;

    public override void _Ready()
    {
        _mold = MoldRuntime.CreateInstance(this);

        Shader shader = GD.Load<Shader>(
            "res://materials/mold_hologram.gdshader");
        ShaderMaterial material = new() { Shader = shader };

        MoldMaterialHandle materialHandle = _mold.RegisterMaterial(material);
        MoldStyle style = MoldStyle.Custom(materialHandle, Colors.Cyan);

        _shape = _mold.Create(
            MoldShape.Cuboid(new Vector3(2, 2, 2), 0.25f),
            style);
    }

    public override void _ExitTree()
    {
        if (_shape.IsValid)
            _shape.Release();
        _mold.Dispose();
    }
}
```

### GDScript

```gdscript
extends Node3D

var mold: MoldRuntimeInstance
var shape: MoldHandle


func _ready() -> void:
	mold = MoldRuntime.create_instance(self)

	var shader := load("res://materials/mold_hologram.gdshader") as Shader
	var material := ShaderMaterial.new()
	material.shader = shader

	var material_handle := mold.register_material(material)
	var style := MoldStyle.custom(material_handle, Color.CYAN)
	shape = mold.create(
		MoldShape.cuboid(Vector3(2.0, 2.0, 2.0), 0.25),
		style,
	)


func _exit_tree() -> void:
	if shape and shape.is_valid:
		shape.release()
	if mold:
		mold.dispose()
```

The handle works while its world, registered material, and shader remain valid.
Check `IsValid`/`is_valid` if you keep it in a system that might outlive the
runtime. A handle registered with one world cannot be used in another.

## Use a custom material in the editor

1. Create a `.gdshader` using the include path for your port.
2. Create a `ShaderMaterial` with that shader and set its shader parameters.
3. Add or select a `MoldNode3D` or `MoldPolylineNode3D`.
4. Expand its `MoldStyleResource` and set **Mode** to **Custom**.
5. Assign **Custom Material** and choose the shape's **Color**.

The node handles registration when it joins a runtime and unregisters when it
leaves. It also supplies the instance data for the editor preview. Custom styles
currently expose one color, so the dual-color controls are hidden.

## Reading instance data

Each shape uses seven floating-point RGBA texture entries, also called texels.
Read them with `mold_instance_fetch(INSTANCE_ID, slot)`. Use the constants from
the include file so your shader is easier to read.

| Slot | Constant | Contents |
| ---: | --- | --- |
| 0 | `MOLD_INSTANCE_PRIMARY_COLOR` | Primary color, with linear RGB and alpha. |
| 1 | `MOLD_INSTANCE_SECONDARY_COLOR` | Secondary color slot; custom styles currently use a single color. |
| 2 | `MOLD_INSTANCE_SHAPE_DATA` | Dimensions and parameters that depend on the shape. |
| 3 | `MOLD_INSTANCE_DASH_DATA` | Dash spacing, profile, and related settings. |
| 4 | `MOLD_INSTANCE_FLAGS` | Emission strength, 2D flag, deformation kind, and packed flags. |
| 5 | `MOLD_INSTANCE_GRADIENT_DATA` | Gradient direction, extent, and mode data. |
| 6 | `MOLD_INSTANCE_LOD_DATA` | LOD coverage, inverted-dither flag, and planar angular range. |

The helpers cover the most common operations:

- `mold_instance_fetch(instance_id, slot)` reads one texture entry.
- `mold_local_aa_quality(flags_data)` returns Off (`0`), Medium (`1`), or High (`2`).
- `mold_lod_visible(lod_data, FRAGCOORD.xy)` tells you whether to keep a pixel
  during a continuous LOD fade.
- `mold_output_color(linear_color)` prepares Mold's RGB for the renderer.

Mold reserves the uniform name `mold_instance_data` and fills it for each batch.
Leave that parameter to Mold.

### Packed values for shape shaders

You only need these details when implementing the corresponding shape features:

- `flags.w` uses bit `1` to enable local anti-aliasing and bit `32` to choose
  High quality. Enabled without bit `32` means Medium. Without bit `1`, AA is Off.
- Billboard flags use bit `2` for a billboard and bit `16` for the world-Y mode.
- For rounded rectangles and rectangle rims, negative `shape_data.y` means
  corner-local rounding and stores `-width / height`. Non-negative values use
  the older shape-relative encoding. Handle both if your shader supports both.
- For rectangles, rectangle rims, regular polygons, and their rims,
  `lod_data.zw` holds the angular start and span in radians. The full shape uses
  `vec2(0.0, TAU)`. `lod_data.xy` still holds the LOD fade values.

## Keeping shapes in the same batch

Register a material once per world and reuse the handle for shapes that should
render together. Registering the same material twice creates separate material
identities, so those shapes cannot share a material batch.

Matching handles alone are not enough: the mesh, detail, render state, visual
layer, sorting order, and local anti-aliasing also need to match. See
[batching](batching.md) if the batch count is higher than you expect.

Mold duplicates your `ShaderMaterial` when a batch is created. Each copy gets its
own instance-data texture, which prevents batches from overwriting each other's
data.

Set shader parameters before registering the material, then treat that source
material as fixed. Changing it later does not update copies that already exist.
For a new set of parameter values, register a new material, create a new custom
style, and apply it with `SetStyle`/`set_style`. The shape moves to the new
material batch and can keep its mesh.

For values that change frequently, use the supported per-shape data, such as
color, or global shader data that your own system manages.

## Render-state settings

Your custom shader owns its blend mode, depth test and writes, face culling,
lighting, and stencil declarations. Set these in the shader itself.

Mold still applies the visual layer mask to the `MultiMeshInstance3D`, and maps
`SortingOrder`/`sorting_order` to material render priority in the `-128` to `127`
range. The other render-state fields can split batches, but do not override
your shader. If a depth or culling option seems to do nothing, check the shader's
`render_mode`.

## Supporting more shapes

The minimal shader colors the submitted mesh. To match the built-in appearance,
add the parts needed by your chosen shapes:

- **2D shapes:** implement their signed-distance masks. They all use a quad,
  so without the mask even a disc looks rectangular.
- **Capsules and tori:** apply their vertex deformation data to get the requested
  dimensions and, for tori, angular span and end caps.
- **Billboards and camera-facing lines:** turn or project the vertices toward
  the camera.
- **Dashes and thin lines:** add the fragment masks and edge coverage.
- **Polylines:** handle their vertex expansion and stroke coverage. Combine
  vertex color with the primary instance color for per-point tinting.
- **Continuous LOD:** call `mold_lod_visible` as shown above. Otherwise both
  meshes can appear at once during a transition. Manual or discrete Automatic
  LOD avoids that two-mesh fade.

For a more complete starting point, look at `mold_shader.gd` in GDScript.
In C#, `MoldEditorPreviewFactory.ShaderSource` in `MoldNode3D.cs` builds the base
shader, and `MultiMeshRendering.cs` adapts it for instancing. Keep the shape
logic you need and change the shading for your effect.

## GPU-polyline materials

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

See [GPU polylines](gpu-polylines.md) for stream setup and backend selection.

## Immediate drawing

Custom styles also work with an immediate frame. Register the material on the
same context that creates the frame, then reuse its style for the commands you
want to draw together. The same mesh and render-state batching rules apply.

## Troubleshooting

### The shape ignores its color

Check that you read `MOLD_INSTANCE_PRIMARY_COLOR` and pass its RGB through
`mold_output_color`. Missing data or applying the color conversion twice can
make the shape look white, black, or much brighter than expected.

### Every 2D shape looks rectangular

The shader needs a shape mask. A quad is the expected result from the minimal
shader above, even when you created a disc or ring.

### Shapes double during an LOD transition

Apply `mold_lod_visible` in the fragment shader, or choose Manual or discrete
Automatic LOD for that world.

### Registration is rejected

Use a valid `ShaderMaterial` with an assigned `Shader`. When drawing, make sure
the material handle belongs to the same world as the shape.
