# Rendering backends

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

Mold uses the renderer selected by your project. Check colors, transparency,
and masks in the renderer and build you plan to ship.

## Choose a renderer

Forward+, Mobile, and Compatibility are supported. Forward+ is the visual
reference, and Mobile should look similar. Compatibility uses an LDR/sRGB
framebuffer, so HDR emission and advanced blending can look different.

Both language ports use the same shape and color approach. C# requires Godot
.NET; use GDScript for web exports.

## Colors and effects

Ordinary colors and gradients are adjusted for the renderer's output color
space. This keeps their brightness similar, but does not make every blend
result identical. Some advanced blend modes use approximations in spatial
shaders. See [blending](blending.md) for the supported behavior.

## Depth and stencil

The MultiMesh spatial-shader path supports `LessEqual`, `Greater`, and `Always`
depth tests. Stencil supports reading, writing, and depth-fail writes. A stencil
reader uses the transparent pass, including for otherwise opaque shapes.

Custom shaders own their depth, blend, face-culling, and stencil declarations.
See [custom materials](custom-materials.md) before overriding their render state.

## UI and limitations

Mold draws in 3D space. Use a camera-aligned plane for HUD shapes and native
`CanvasLayer`/`Control` nodes for text and interaction. See
[UI rendering](ui-rendering.md) for the setup.

GPU polylines work through textures and spatial shaders without a
`RenderingDevice` dependency. Headless mode cannot use that backend. Test browser
exports and your target GPU separately; see [GPU polylines](gpu-polylines.md).
