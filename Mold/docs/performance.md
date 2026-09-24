# Performance

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

Performance depends on the workload and transparency ordering mode. NativeCompatible uses individual engine objects; Batched reduces submission overhead when batch-slot ordering is acceptable.
This is a guide on every performance implications for Mold. Note that **Always benchmark, especially in build,** before
committing to a specific choice.

## Frustum culling

Frustum Culling can lower GPU usage by not rendering shapes when they are out of view.
However maintaining the culling itself has additional performance cost, which means sometimes
it might be just cheaper to draw them at all times.

Godot has two choices:

- `None`: Draw all things at all times, best if most of the shapes are mostly on screen.
- `BatchBounds`: Has CPU cost. Calculates the bound of each MultiMesh and submit to Godot for Godot to reject them.

## Automatic LOD

Automatic LOD is a feature that allows smooth transition of mesh details.
This in itself is a cost saving measure for keeping everything smooth while not needing to
show the highest quality of everything at all times.

However Automatic LOD itself comes with three caveats:

- The determination of which LOD to use itself has CPU cost.
- This forces the generation of all mesh detail by default, which will increase memory footprint.
- LOD transitioning shapes will consume two batches of rendering because they're using different mesh,
which don't always has performance implication, but something to keep in mind.

If your project has minimal camera distance changes for example an isometric game,
turning it off and hand author each mesh detail might be the better choice.

## Batch operation and backend choices

Batch operations are available through `MoldContext` for lowering the CPU cost. Currently there are:

- `UpdatePositions(handles, positions)`: position only
- `UpdateTransforms(handles, positions, rotations, scales)`: full transform
- `UpdateColors(handles, colors)`: color only
- `UpdateLinePositions(handles, starts, ends)`: line specific

If you're updating a lot of shapes at once, using these APIs will have significant performance improvements.

Additionally, in C# the batch operation has two backend options avaiable:

- `Managed`: well, the normal-ish way of updating
- `SIMD`: utilizing `System.Numerics` for vectorized performance improvements.

`SIMD` is the default option which generally should run faster, but you can still use the `Managed` backend if you need it,
for example if the `SIMD` path runs slower due to imcopatible hardware which may or may not lead to worse performance.

## Mesh generation

By default Mold cahces the mesh generated for each shapes, they will reused on every matching ratios.
Mesh generation cache is a trade-off between CPU cost and memory footprint
and when needed `MoldContext` can use `ClearUnusedMeshes()` to clean up the mesh cache.

Therefore a good practice is to "SetScale" instead of "SetShape" whenever you can get away with it,
albiet at the cost of potential non-uniform appearance.

Note that 2D shapes, spheres, cuboids, and hemisphere does not subject to this characteristic due to
their uniform mesh. Meaning `SetScale` and `SetShape` for scaling yields the same result.

Additionally the amount of unique mesh used is also proportional to the batches needed render the shapes.
This doesn't always translate to performance impact but it is something to keep in mind and avoid if you can get away with it.

## Local anti-aliasing for 2D shapes

Mold uses derivative to enable the smooth look of the 2D shapes. This has GPU performance cost,
while small, adds up if you're running a very shape heavy game.

There are three options available for the anti-aliasing:

- `High`: uses the Euclidean derivative length, `length(vec2(dFdx(value), dFdy(value)))`,
for the best diagonal coverage.
- `Medium`: uses the cheaper `fwidth(value)` approximation.
- `Off`

The default is `High`.

## Oklab colorspace blending

Oklab colorspace blending loops great, but it needs to perform additional colorspace conversion
both in and out of Oklab colorspace which means extra GPU performance cost.

This is the reason why Oklab is not the default color blending option, please use it conciously
and sparingly.