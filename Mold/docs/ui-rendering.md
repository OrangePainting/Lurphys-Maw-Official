# Rendering game UI with Mold

Mold is useful for UI made from animated shapes: health bars, cooldown rings,
reticles, minimaps, markers, and selection outlines. Create the shapes once,
keep their handles, and update them as the game changes.

Use Godot's `CanvasLayer` and `Control` nodes for text, buttons, input, focus,
accessibility, and automatic layout. Mold draws in 3D space, so the usual setup
is a flat layer of shapes facing an orthographic camera, with native controls
placed over it.

## Start with the showcase

The C# and
[GDScript](../examples/ui_showcase/ui_showcase.tscn) UI showcases
are runnable examples. They include a speedometer, motion tracker, navigation
compass, and radial weapon selector. Mold draws their plates, ticks, rings,
icons, and fills, while native `Label` controls display the changing text.

The moving 3D scene behind the HUD renders into a separate `SubViewport`. Its
texture appears on a quad behind the UI. This lets the gameplay camera move
freely while the HUD keeps a steady coordinate system.

## Set up the camera and coordinates

For a simple HUD, start with this scene structure:

```text
HudRoot (Node3D, owns the Mold runtime)
├── Camera3D (orthogonal, current)
└── Interface (CanvasLayer)
    └── LabelsAndInput (Control)
```

Use one coordinate system for both shapes and controls. A `16 × 9` canvas is
convenient: `(0, 0)` is the top-left and `(16, 9)` is the bottom-right.
The following helper centers that canvas at the world origin and flips Y,
since UI coordinates run downward while Godot's world Y runs upward:

```csharp
private const float CanvasWidth = 16f;
private const float CanvasHeight = 9f;

private static Vector3 UiPoint(float x, float y) =>
    new(x - CanvasWidth * 0.5f, CanvasHeight * 0.5f - y, 0f);
```

```gdscript
const CANVAS_WIDTH := 16.0
const CANVAS_HEIGHT := 9.0

func ui_point(x: float, y: float) -> Vector3:
	return Vector3(x - CANVAS_WIDTH * 0.5, CANVAS_HEIGHT * 0.5 - y, 0.0)
```

Place the camera at `(0, 0, 10)`, looking along its default `-Z` direction.
Make it current, choose orthogonal projection, and set its size to `9`.
With the default Keep Height setting, this shows the whole canvas at 16:9.

Wider displays reveal more space at the sides. On narrower displays, either
letterbox the viewport or adjust the layout to fit the available area.

## Create the shapes once

Create an owned runtime when the HUD enters the tree and keep handles for its
visual elements. Manual LOD is a useful choice here because the HUD's screen
size is predictable.

These snippets belong in a `Node3D` script attached to `HudRoot`. Use the
coordinate helper above; C# also needs `using Godot;` and `using Mold;`.

```csharp
private MoldRuntimeInstance _ui = null!;
private MoldHandle _healthFill;

public override void _Ready()
{
    Camera3D camera = GetNode<Camera3D>("Camera3D");
    camera.Projection = Camera3D.ProjectionType.Orthogonal;
    camera.Size = CanvasHeight;
    camera.Position = new(0f, 0f, 10f);

    _ui = MoldRuntime.CreateInstance(this, new MoldWorldSettings
    {
        Capacity = 256,
        LodMode = MoldLodMode.Manual,
        RetainedUnusedMeshCount = 32,
    });

    _healthFill = _ui.Create(
        MoldShape.Rectangle(new Vector2(3.2f, 0.22f), 0.45f),
        MoldStyle.DualGradient(
            new Color("55e6a5"), new Color("b4ff82"), Vector3.Right,
            MoldGradientSpace.Object, MoldStyle.BlendMode.Opaque,
            MoldColorInterpolation.Oklab),
        UiState(20));
    _healthFill.SetPosition(UiPoint(2.2f, 1.1f));
}

private static MoldRenderState UiState(int order) => new(
    SortingOrder: order,
    DepthTest: MoldDepthTest.Always,
    DepthWrite: MoldDepthWrite.Disabled,
    FaceCull: MoldFaceCull.Disabled);
```

```gdscript
var ui: MoldRuntimeInstance
var health_fill: MoldHandle

func _ready() -> void:
	var camera: Camera3D = $Camera3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CANVAS_HEIGHT
	camera.position = Vector3(0.0, 0.0, 10.0)

	var settings := MoldWorldSettings.new()
	settings.capacity = 256
	settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	settings.retained_unused_mesh_count = 32
	ui = MoldRuntime.create_instance(self, settings)

	health_fill = ui.create(
		MoldShape.rectangle(Vector2(3.2, 0.22), 0.45),
		MoldStyle.dual_gradient(
			Color("55e6a5"), Color("b4ff82"), Vector3.RIGHT,
			MoldStyle.GradientSpace.OBJECT, MoldStyle.BlendMode.OPAQUE,
			MoldStyle.ColorInterpolation.OKLAB),
		ui_state(20)
	)
	health_fill.set_position(ui_point(2.2, 1.1))

func ui_state(order: int) -> MoldRenderState:
	return MoldRenderState.new(
		1, order, MoldRenderState.DepthTest.ALWAYS,
		MoldRenderState.DepthWrite.DISABLED,
		MoldRenderState.StencilFlags.DISABLED,
		MoldRenderState.StencilCompare.ALWAYS, 0,
		MoldRenderState.FaceCull.DISABLED)
```

`DepthTest.Always` lets the HUD draw regardless of scene depth. Disabling depth
writes prevents one UI shape from blocking later layers through the depth
buffer. Disabling face culling lets the shapes remain visible from either side.

Use a few consistent sorting orders, such as background `-100`, panels `0`,
values `10`, icons `20`, and alerts `100`. Different orders and blend modes can
split batches, so there is little reason to give every element a unique state.

These shapes are useful starting points:

| UI element | Mold geometry |
| --- | --- |
| Panel or filled bar | `Rectangle` |
| Border or focus outline | `RectangleRim` |
| Cooldown or objective progress | `Ring` with an angular span |
| Reticle, badge, or marker | `Disc`, `Ring`, or `RegularPolygon` |
| Divider or tick | `Line2D` |
| Minimap route or graph | `MoldPolyline` |
| Dashed radar or selection outline | `MoldDash` on a ring or rim |

## Update the handles

During `_Process`, update the values that changed. For a bar, change its width
and move its center so the left edge stays in place:

```csharp
private void SetBar(MoldHandle handle, float left, float y, float fullWidth,
    float height, float value)
{
    float width = fullWidth * Mathf.Clamp(value, 0f, 1f);
    handle.SetShape(MoldShape.Rectangle(new Vector2(width, height), 0.45f));
    handle.SetPosition(UiPoint(left + width * 0.5f, y));
}
```

```gdscript
func set_bar(handle: MoldHandle, left: float, y: float,
		full_width: float, height: float, value: float) -> void:
	var width := full_width * clampf(value, 0.0, 1.0)
	handle.set_shape(MoldShape.rectangle(Vector2(width, height), 0.45))
	handle.set_position(ui_point(left + width * 0.5, y))
```

For a cooldown, keep the ring's radius and change its angular span. For a route,
replace the path with `SetPolyline`/`set_polyline`. If many markers move at once,
use `UpdatePositions`/`update_positions_bulk`.

Keep the handles instead of releasing and recreating them every frame. Mold can
reuse their meshes and batches where possible. Store the values you need for
later edits, such as a ring's radius, thickness, and dash settings, beside the
handle.

## Keep native text aligned

Create `Label`, `Button`, and other controls below a `CanvasLayer`. Use the HUD
camera to convert your logical coordinates into screen positions:

```csharp
Vector2 screen = camera.UnprojectPosition(UiPoint(x, y));
label.Position = screen;
```

```gdscript
var screen := camera.unproject_position(ui_point(x, y))
label.position = screen
```

Update these positions when the camera or viewport changes. Project two points
one logical unit apart to find the pixel scale for font sizes and control
bounds.

Native controls give you font shaping, localization, keyboard focus,
accessibility, clipping, and input handling. A button can use a `Control` for
its clickable area while Mold draws its background. Mold shapes do not inherit
Control anchors, containers, themes, clipping masks, or mouse filtering, so keep
that layout and interaction code in the native UI layer.

## Cleanup and world-space UI

Release the handles and dispose your owned runtime in `_ExitTree`. Disposing
the runtime also clears the shapes it owns. If you connect resize or other
signals, disconnect them when the HUD leaves the tree.

For a panel that belongs in the game world, use the same create-once and update
approach, but keep the normal depth test so scenery can hide it. Project its
text anchors through the gameplay camera if the text still uses screen controls.
