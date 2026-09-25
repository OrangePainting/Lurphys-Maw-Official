# Mesh generation and caching

Mold generates meshes when it needs them, then keeps them around for reuse.
Many shapes can share one mesh even when their sizes are different. This saves
CPU work, but keeping more mesh variants also uses more memory.

## What needs a different mesh

All six 2D shape families share a quad. The shader uses each shape's data to draw
its outline, corners, rim, and angular span, so those edits do not generate a
new mesh.

3D shapes use generated `ArrayMesh` geometry. Their detail level and features
such as prism side count or hemisphere caps decide which mesh they need.
Rounded cuboids, cylinders, and prisms also account for their proportions so
that a round edge stays round after the mesh is scaled.

This means resizing a rounded 3D shape with `SetShape`/`set_shape` can select a
new mesh. `SetScale`/`set_scale` stretches the existing mesh instead, which is
cheaper when you can accept the stretched appearance. Uniform scaling is an
easy way to reuse a shape without changing its proportions.

## Lines

Rectangle lines place the shared quad between two local XY endpoints. Cylinder
lines align a cylinder between two local 3D endpoints. Thickness is the full
width of the line, so a cylinder line's radius is half its thickness.

Moving endpoints normally just changes the line's transform. Rounded cylinder
lines also account for the ratio between length and thickness when shaping the
ends, so a length change can select a different rounded mesh.

## Rounded shapes

Rounded cuboids are built from six subdivided faces, with connected rounded
edges and corners. The corner radius is shared across all three axes and is
limited to a quarter of the shortest dimension. Rounded cylinders and prisms
also limit their end rounding to fit the shorter dimension, leaving room for a
straight body.

`MoldShape.Detail` controls how many subdivisions these curves use. Higher detail
looks smoother up close, at the cost of more vertices and triangles.

Roundness is rounded to a set of cache values rather than keeping a mesh for
every possible floating-point value. `RoundnessResolution`/
`roundness_resolution` defaults to `256`. Lowering it lets more similar shapes
share a mesh; raising it preserves finer differences in their rounded edges.

## Spheres, hemispheres, and capsules

Spheres start as an icosahedron and subdivide its triangles. The five detail
levels produce 20, 80, 320, 1,280, and 5,120 triangles. This spreads triangles
more evenly than a sphere built from latitude rings, which bunch up at the
poles.

Hemispheres and capsules use latitude rings because they need a clean equator
or separate caps. Capsules share one mesh per detail level. The vertex shader
extends the middle while keeping both ends spherical, so each height and radius
does not need its own cached mesh.

## Tori and billboards

Tori share meshes by detail level, with separate variants for full and partial
rings. The shader applies the major radius, tube thickness, and angular range;
partial rings also need end-cap geometry. Different partial spans can reuse the
same partial-ring mesh.

Billboarded 2D shapes keep the shared quad and turn it toward the camera in the
vertex shader. Camera-facing rectangle lines keep their endpoints in place and
turn their width toward the camera.

## Polylines

CPU polylines generate stroke meshes from their paths. Reusing a path shares its
cached geometry. Point edits return a replacement path and generate new geometry.
Moving or recoloring the whole handle also reuses the path and mesh.

With `Auto`, supported paths use GPU expansion instead. For frequently changing
points, a GPU stream avoids rebuilding stroke meshes. See [GPU polylines](gpu-polylines.md).

## Managing the cache

Mold keeps meshes that are still in use, plus a limited number of unused meshes
in case you need them again. `RetainedUnusedMeshCount`/
`retained_unused_mesh_count` defaults to `64`. When that limit is exceeded,
Mold drops the least recently used spare meshes.

Use `MoldContext.Prewarm(...)`/`prewarm(...)` before a busy frame to generate the
shapes you expect to need. Prewarmed meshes are still subject to the unused-cache
limit. `ClearUnusedMeshes()`/`clear_unused_meshes()` drops meshes that no shape
currently uses.

Mesh-generation work is adapted from Keijiro Takahashi's MetaMesh. See the
[third-party notices](../THIRD_PARTY_NOTICES.md) for attribution.
