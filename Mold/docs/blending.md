# Blending and render state

Blend modes decide how a shape's color combines with what is already on screen.
Mold provides a range of modes for solid shapes, translucent panels, glows, and
other effects. Some advanced modes are approximations in Godot, so check how
they look in the renderer your game uses.

## Choosing a blend mode

| Mode | What it does in Godot |
| --- | --- |
| `Opaque` | Draws a solid surface. |
| `Transparent` | Mixes the shape with the background using its alpha. |
| `Additive` | Adds color to the background, useful for glows. |
| `Multiplicative` | Multiplies with the background, useful for darkening. |
| `Subtractive` | Subtracts color from the background. |
| `Screen`, `Lighten`, `ColorDodge` | Use additive blending as an approximation. |
| `LinearBurn`, `ColorBurn`, `Darken` | Use multiplicative blending as an approximation. |
| `Dither` | Fades by drawing fewer pixels in a repeating pattern. |

`MoldStyle.Multiply` is also available as an alias for
`MoldStyle.Multiplicative`.

By default, `Opaque` and `Dither` write depth. The other built-in modes test
against the scene's depth but do not write their own. This lets them blend with
what is behind them, although overlapping transparent shapes depend on drawing
order.

For reference, ordinary transparent blending is `aC + (1-a)D`, where `C` is the
shape color, `D` is the background, and `a` is alpha multiplied by shape
coverage. Additive blending is `aC + D`. Godot's spatial shaders provide mix,
add, subtract, and multiply operations; the advanced names above do not give
you their exact image-editor blend equations.

`Dither` uses a 16×16 Bayer pattern. It can fade while still writing depth,
which is useful when ordinary transparency would cause sorting problems.
You will see the pattern, especially at lower resolutions.

## Dual colors and gradients

Color gradients are chosen separately from the blend mode, so you can use them
with opaque, transparent, additive, or other built-in styles.

- `DualRadial` blends by distance from the shape's local origin, including on rims.
- `DualRadialBounds` fits the radial blend to a 2D shape's boundary. On a 3D torus,
  it blends from the inner edge to the outer edge across radial thickness. Other
  3D primitives evaluate it exactly like `DualRadial`.
- `DualAngular` blends around the center of a 2D shape, or around local Y on a
  3D primitive, starting at +X and advancing toward +Z. Torus arcs fit their
  start/span range; a full revolution has a color seam. Points on the axis use
  the first color.
- `DualGradient` blends along a direction across a 2D or 3D shape's bounds.

On 3D primitives, radial distance uses the authored dimensions and is divided
by the largest local half-extent, then clamped to 0–1. The hemisphere origin
is the center of its base. A sphere is nearly uniform on its curved surface.
Object transforms carry these gradients with the shape; gradient direction and
space controls apply only to `DualGradient`. Lines retain Single/DualGradient
support only.

For `DualGradient`, `World` space keeps the direction fixed as the shape rotates.
`Object` space rotates the direction with the shape. World up is the default,
and moving the shape does not shift the gradient through it.

You can choose linear RGB or Oklab color interpolation and add emission.
Oklab often gives nicer transitions between colors, but the extra color
conversions cost GPU time. Use it where the difference is useful; see the
[performance guide](performance.md).

## Differences between renderers

Mold converts your colors from sRGB to linear RGB. For an Oklab gradient, it
also converts the endpoints to Oklab before storing them, then converts the
blended result back to linear RGB in the shader. The `mold_output_color` helper
checks Godot's `OUTPUT_IS_SRGB` flag and converts the final output when needed. Editor previews and runtime materials use this
same approach in both ports.

Forward+ is the visual reference, and Mobile should look similar. Compatibility
uses an LDR/sRGB framebuffer, so HDR emission and advanced blending can look
different even with the same style. Ordinary colors and gradients are adjusted
to keep their brightness similar, but that does not make every blending result
identical.

## Depth and sorting

`MoldRenderState` lets you override the style's depth-write default and choose a
depth test:

| Depth test | When to use it |
| --- | --- |
| `LessEqual` | Normal scene rendering, where closer geometry hides what is behind it. |
| `Greater` | Effects that should show where the shape is behind existing geometry. |
| `Always` | Overlays that should ignore the scene depth. |

These map to Godot's default, inverted, and disabled depth testing. They are the
three choices available through Mold's MultiMesh spatial-shader path. Godot controls the underlying depth comparison.

`SortingOrder`/`sorting_order` sets the material's render priority, clamped to
`-128` through `127`. Use a few consistent orders for layered effects and UI.
Godot treats each MultiMesh as a single visual when sorting batches.

Within a batch, C# sorts ordinary `Transparent` instances back to front when
depth writes are disabled. It also uses discrete LOD changes for those shapes
to avoid splitting one transparent shape across two draws. GDScript currently
does not have that per-instance sort or LOD exception.

## Face culling and stencil

Face culling is disabled by default, so both sides can render. Choose
`MoldFaceCull.Back` or `.Front` in C#, or
`MoldRenderState.FaceCull.BACK` or `.FRONT` in GDScript, when you need one-sided
rendering.

Stencil lets one shape write a mask and another draw according to that mask.
Mold supports reading, writing, and writing when the depth test fails. A shader
that reads stencil goes through Godot's transparent pass, even when its Mold
style is opaque.

Changing depth, stencil, face culling, or sorting can move a shape to a different
batch. Custom materials are a special case: their shaders own the blend, depth,
cull, and stencil settings. See [custom materials](custom-materials.md) before
using render-state overrides with your own shader.
