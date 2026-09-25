# Changelog

## 0.8.0 — Local NativeCompatible backport (2026-09-11)

- Make C# settings resources serializable through their own named script file; normalize missing/invalid ordering values on reload.

### Breaking changes

- Default supported transparent rendering to NativeCompatible; select Batched explicitly for batch-slot rendering. Native mode can increase object, material, and draw overhead.
- Godot C# Batched mode now preserves slot order instead of sorting transparent uploads. Transparent LOD restrictions remain.

### Features

- Add NativeCompatible/Batched settings and live world/context switching, pooled native renderers, and native shader instance addressing.
- Add two-mode performance-scene selection with alpha 0.75, selection persistence, 120-frame warmup after switching, and identified benchmark output.
- Preserve existing geometry, immediate APIs, and appearance-buffer layouts. No OIT or later geometry features are included.

This local package is distinct from the existing broader public v0.8.0 release history.


## [0.7.1](https://github.com/dklassic/MoldGodot/compare/v0.7.0...v0.7.1) (2026-09-07)

### ⚠ BREAKING CHANGES

* remove public polyline dash properties, constructor arguments, `WithDash`/`with_dash`, and authoring controls from both ports; remove these calls and settings when upgrading. Polylines currently render solid strokes. ([eb96f14](https://github.com/dklassic/MoldGodot/commit/eb96f148d69767f9a488df8fbf4d445f93e59cd1))

### Features

* add texture-backed `MoldGpuPolylineRenderer` streams to C# and GDScript for animated planar paths, with point uploads that reuse stroke topology, joins and caps, per-point width and HDR color, manual bounds, and opt-in custom materials. ([ba99bf3](https://github.com/dklassic/MoldGodot/commit/ba99bf355b3093730d3591dbaa76695437093941))
* make `Auto` select GPU rendering for eligible retained and authored polylines on Forward+, Mobile, and Compatibility, with CPU fallback and stable handles when eligibility changes; editor previews remain CPU-rendered. ([ba99bf3](https://github.com/dklassic/MoldGodot/commit/ba99bf355b3093730d3591dbaa76695437093941))
* add interactive Polyline Backend examples and GPU-polyline regression fixtures for both ports. ([ba99bf3](https://github.com/dklassic/MoldGodot/commit/ba99bf355b3093730d3591dbaa76695437093941))

### Documentation

* add GPU-polyline and rendering-backend guides, expand the API and bulk-update documentation, and refresh the project and port READMEs. ([ba99bf3](https://github.com/dklassic/MoldGodot/commit/ba99bf355b3093730d3591dbaa76695437093941))
* build a bookmarked, linked documentation PDF and include it in both release archives. ([894d664](https://github.com/dklassic/MoldGodot/commit/894d664d66b981a03c18703586a8b6c6a77647c8))

## [0.7.0](https://github.com/dklassic/MoldGodot/compare/v0.6.0...v0.7.0) (2026-09-07)


### Features

* add camera-aware `MoldImmediateDrawer3D` rendering to both ports, with shared per-viewport batching, editor previews, layer filtering, camera-change redraws, optional continuous redraws, and an editor animation scrubber in the Immediate API examples ([f39e7f6](https://github.com/dklassic/MoldGodot/commit/f39e7f6679a6404dc7c18cb8f2aa3cdb317992fa))
* add `Auto` and `CPU` polyline backend policies to C# and GDScript nodes and context creation APIs; backend resolution now belongs to `MoldWorld`, with Auto currently selecting the CPU path at the future compute-renderer seam ([9537c03](https://github.com/dklassic/MoldGodot/commit/9537c036fa1703d42b4e02f1c5d1ae2bb17493c5))
* expose polyline point colors through Godot's HDR intensity picker in both ports, preserving authored channel values above 1.0 ([9537c03](https://github.com/dklassic/MoldGodot/commit/9537c036fa1703d42b4e02f1c5d1ae2bb17493c5))
* support `DualRadial`, `DualRadialBounds`, and `DualAngular` color modes on 3D primitives, including radial-thickness blending for torus bounds ([f85d008](https://github.com/dklassic/MoldGodot/commit/f85d0086f5f0d4c9503238cb9d46cf72a2dce9d6))


### Performance

* reduce immediate recording and synchronization work with bounded preparation caches, independent color and gradient packing, compatible-batch reuse, and transform, bounds, and LOD reuse; add staged CPU benchmarks and mutable-input regression coverage ([f85d008](https://github.com/dklassic/MoldGodot/commit/f85d0086f5f0d4c9503238cb9d46cf72a2dce9d6))


### Bug Fixes

* correct line and polyline subpixel coverage, alpha-to-coverage output, perspective width measurement, endpoint padding, and local-AA fallbacks across retained, immediate, and editor-preview rendering ([d4b94bd](https://github.com/dklassic/MoldGodot/commit/d4b94bd4d64c41c73bb761b63ed18ad578a67d42))


### Documentation

* refresh the project and port READMEs for the immediate drawer, expanded color modes, and polyline backend APIs ([e078a43](https://github.com/dklassic/MoldGodot/commit/e078a43c96627d87226d5d0a1b2d1c5864a8ab1a), [9537c03](https://github.com/dklassic/MoldGodot/commit/9537c036fa1703d42b4e02f1c5d1ae2bb17493c5))

## [0.6.0](https://github.com/dklassic/MoldGodot/compare/v0.5.1...v0.6.0) (2026-09-06)


### ⚠ BREAKING CHANGES

* move the C# `Radius` and `Diameter` measurement types from `Mold` to `Mold.MoldMath`; add `using Mold.MoldMath` where these types are referenced ([dc9dfd9](https://github.com/dklassic/MoldGodot/commit/dc9dfd9574dfaac83aa1b357052fa77c888786de))
* rename depth-test values from `Default`/`DEFAULT` and `Inverted`/`INVERTED` to `LessEqual`/`LESS_EQUAL` and `Greater`/`GREATER`, matching their actual comparisons ([dc9dfd9](https://github.com/dklassic/MoldGodot/commit/dc9dfd9574dfaac83aa1b357052fa77c888786de))


### Features

* add opt-in renderer, LOD, upload, and payload performance metrics plus richer interactive and JSON benchmark output for both ports ([807e1a5](https://github.com/dklassic/MoldGodot/commit/807e1a5d2852bd047f6890bfe8bbc8acf1e26fe7), [39c508d](https://github.com/dklassic/MoldGodot/commit/39c508db9179622e30654fb4c6789805a564eedf))
* add bulk color and full-transform updates alongside the existing bulk position and line APIs ([9eeb3d7](https://github.com/dklassic/MoldGodot/commit/9eeb3d7ae85973dfcf916464124e1ea4a5d60453))
* add Managed and SIMD position-processing modes to the C# port, with hardware-aware fallback and per-runtime selection ([ba93042](https://github.com/dklassic/MoldGodot/commit/ba93042de47935658e35ee0ed55c44a7d7503a1e))
* accept zero-sized shapes, zero-length lines, and zero-scale transforms as retained but non-drawing molds, allowing them to become visible after later updates ([dc9dfd9](https://github.com/dklassic/MoldGodot/commit/dc9dfd9574dfaac83aa1b357052fa77c888786de))


### Performance

* reduce transform-update, LOD, bounds, batch-dirtying, and GPU-upload work; cache active slots and avoid repeated unchanged-property writes ([19600c5](https://github.com/dklassic/MoldGodot/commit/19600c5dcb66017d155402745b5c271ffc9feaea), [9eeb3d7](https://github.com/dklassic/MoldGodot/commit/9eeb3d7ae85973dfcf916464124e1ea4a5d60453), [a09bcfa](https://github.com/dklassic/MoldGodot/commit/a09bcfa94c5fd15aa224149aacf7779c1556d8cb))
* vectorize C# cached-bounds reduction and streamline renderer synchronization in both ports ([ba93042](https://github.com/dklassic/MoldGodot/commit/ba93042de47935658e35ee0ed55c44a7d7503a1e))


### Bug Fixes

* rework polyline antialiasing with analytic joins, round outlines, endpoint coverage, and robust opaque alpha-to-coverage or fallback handling ([018c393](https://github.com/dklassic/MoldGodot/commit/018c3937897e28cded8fae87274f2b6c71b7a173))
* correct automatic and explicit depth-write behavior across blend modes, stencil reads, authoring previews, and retained rendering ([dc9dfd9](https://github.com/dklassic/MoldGodot/commit/dc9dfd9574dfaac83aa1b357052fa77c888786de))


### Documentation

* expand and reorganize the architecture, batching, blending, mesh-generation, performance, custom-material, metrics, and UI-rendering guides ([b66c1bd](https://github.com/dklassic/MoldGodot/commit/b66c1bd664d55b06a417f683525e37eafed9af7b), [39b9186](https://github.com/dklassic/MoldGodot/commit/39b9186e502853b467a0626a11ebbca5b7b8ff76))

## [0.5.1](https://github.com/dklassic/MoldGodot/compare/v0.5.0...v0.5.1) (2026-09-04)


### Bug Fixes

* restore polyline geometry by carrying the screen-space extrusion vector in `ARRAY_CUSTOM0` instead of `ARRAY_TANGENT`; Godot stores tangents octahedron-encoded, which normalized away the extrusion length and inflated every polyline to roughly one world unit per side ([69e8af1](https://github.com/dklassic/MoldGodot/commit/69e8af1caa9b89627c8dfbaa2b4c5471d6d0d0e0))
* refresh `mold_viewport_size` on editor previews whenever the viewport resizes, so thin-line antialiasing no longer keeps the size captured at the last property edit ([69e8af1](https://github.com/dklassic/MoldGodot/commit/69e8af1caa9b89627c8dfbaa2b4c5471d6d0d0e0))
* publish `mold_viewport_size` to GDScript custom-material previews, matching the C# port and the instanced runtime path ([69e8af1](https://github.com/dklassic/MoldGodot/commit/69e8af1caa9b89627c8dfbaa2b4c5471d6d0d0e0))
* guard the polyline edge scale against a zero projected width instead of dividing by an epsilon floor, which could expand a degenerate line by five orders of magnitude ([69e8af1](https://github.com/dklassic/MoldGodot/commit/69e8af1caa9b89627c8dfbaa2b4c5471d6d0d0e0))
* restore the canonical `contract/` copies of the shader and mesh-golden fixtures so `tools/sync_contracts.py` no longer reverts the line-rasterization contract in both ports ([69e8af1](https://github.com/dklassic/MoldGodot/commit/69e8af1caa9b89627c8dfbaa2b4c5471d6d0d0e0))

## [0.5.0](https://github.com/dklassic/MoldGodot/compare/v0.4.0...v0.5.0) (2026-09-03)


### ⚠ BREAKING CHANGES

* replace the shape-specific rectangle, cuboid, cylinder, and capsule line factories with `Line2D`/`line_2d` and `Line3D`/`line_3d`; 3D lines now consistently use cylinder topology ([0d989cc](https://github.com/dklassic/MoldGodot/commit/0d989cc121659ba468c156c83c78201a640de25b))
* disable face culling by default; select back- or front-face culling explicitly for one-sided rendering ([6ad8330](https://github.com/dklassic/MoldGodot/commit/6ad8330a2e9140aee2e99882a3b3cf601a09300d))


### Features

* add end caps to partial torus spans and Mold Logo example scenes for both ports ([5d60e17](https://github.com/dklassic/MoldGodot/commit/5d60e17c826a982893ca9d0ef2fd483221a3de4b))
* add `FaceCameraY`/`FACE_CAMERA_Y` billboarding to keep 2D shapes upright around world Y ([c5ec1de](https://github.com/dklassic/MoldGodot/commit/c5ec1de35e180adc4f7c5d0b55487c254dce19fb))
* add Off, Medium, and High local-antialiasing quality modes and roundness controls for unified 2D and 3D lines ([0d989cc](https://github.com/dklassic/MoldGodot/commit/0d989cc121659ba468c156c83c78201a640de25b))


### Improvements

* make thin-line and polyline antialiasing viewport-aware and derivative-based across joins, caps, angular masks, and dashes ([b49b536](https://github.com/dklassic/MoldGodot/commit/b49b5363c47a4c31710650f9421b5e55ae5f2d67))
* localize rounded 3D fillets by the shortest relevant dimension for `Line3D`, cuboids, cylinders, and regular prisms, preserving straight bodies and planar faces on elongated shapes ([b8fabd3](https://github.com/dklassic/MoldGodot/commit/b8fabd323cbf3ade0038f84488ea928bd9d7fd2b), [90623cd](https://github.com/dklassic/MoldGodot/commit/90623cd9a0ccc3420dbc07c3a04a5395bc72a86f))


### Packaging

* include examples, shared and port documentation, the changelog, and portable documentation links in release archives ([4d85012](https://github.com/dklassic/MoldGodot/commit/4d85012c4e434412f8b4a08c1e5e55caa11979d5))

## [0.4.0](https://github.com/dklassic/MoldGodot/compare/v0.3.0...v0.4.0) (2026-09-02)


### Features

* add registered custom `ShaderMaterial` support to the C# and GDScript runtime and authoring APIs, including transparent batch sorting and a documented per-instance shader interface ([bbda52f](https://github.com/dklassic/MoldGodot/commit/bbda52f6d99cc77fe2238c6510199960d5ad981f))
* add angular clipping for rectangle and regular-polygon fills and rims, plus corner-local and shape-relative rectangle roundness modes ([0496732](https://github.com/dklassic/MoldGodot/commit/049673249696fae89231c3857d36c3bd9d2a3f8a))
* add C# and GDScript UI showcase scenes and a HUD rendering guide ([7fe178a](https://github.com/dklassic/MoldGodot/commit/7fe178adb352f666d07f1d2d251bed51b1fe8b34))
* add normal-visualization example scenes for both ports ([b6549b7](https://github.com/dklassic/MoldGodot/commit/b6549b701de0b80b5ec4570ddde30cb34d59af9c))


### Bug Fixes

* calculate automatic-LOD projected diameters from shape-specific bounds ([d567f26](https://github.com/dklassic/MoldGodot/commit/d567f26675ea43abe9ef79734a22ad4bd148c947))


### Packaging

* include the proprietary license in generated port archives ([c6859cb](https://github.com/dklassic/MoldGodot/commit/c6859cbb6553db3f9db923b11635870b13cdec8c))

## [0.3.0](https://github.com/dklassic/MoldGodot/compare/v0.2.0...v0.3.0) (2026-09-01)


### Features

* expand immediate drawing and color styling ([2b22486](https://github.com/dklassic/MoldGodot/commit/2b22486e1af82f5ab6b197d7cc6254df81c7d2b2))
