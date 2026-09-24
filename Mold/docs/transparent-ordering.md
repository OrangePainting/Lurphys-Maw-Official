# Transparency ordering

Mold defaults to **NativeCompatible**, which gives supported transparent Mold objects individual engine renderers so the engine can sort them alongside its ordinary transparent objects. **Batched** uses batch-slot ordering to reduce submission overhead. Opaque and dither geometry retain their existing rendering paths.

NativeCompatible matches the engine's object-level sorting behavior.

## Selecting a mode

```csharp
var mold = MoldRuntime.CreateInstance(this, new MoldWorldSettings
{
    TransparentOrderingMode = MoldTransparentOrderingMode.NativeCompatible,
});
mold.TransparentOrderingMode = MoldTransparentOrderingMode.Batched;
```

```gdscript
var settings := MoldWorldSettings.new()
settings.transparent_ordering_mode = MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE
var mold := MoldRuntime.create_instance(self, settings)
mold.transparent_ordering_mode = MoldWorldSettings.TransparentOrderingMode.BATCHED
```

Native batches use pooled MeshInstance3D nodes, sharing meshes, shaders, and the existing seven-texel appearance data. Each native slot owns a pooled material carrying its index; this avoids Godot's finite global instance-uniform buffer, including the much smaller Compatibility limit. Native material counts therefore grow with native slots. GPU polylines already use MeshInstance3D. Custom-material batches remain batched and are not promised native ordering. Both ports use AABB-center sorting for native shapes.

**C# settings resources:** The resource class now resides in `MoldWorldSettings.cs` so Godot can save and reload it. Its public type and properties are unchanged. Settings resources that reference the old `MoldTypes.cs` script must be recreated or retargeted to the new settings script.

**C# migration:** Batched no longer sorts alpha-transparent instance uploads back-to-front. It preserves slot order, matching the GDScript port and current Mold behavior. Selecting Batched is therefore not an exact 0.7.1 visual-compatibility switch. Transparent LOD restrictions are preserved.

`NativeCompatible = 0` and `Batched = 1` are stable enum values. New and omitted settings default to native mode; invalid values normalize to native mode. Changing modes preserves handles and switches the rendering path. Native pools are created on first use and reused until their owning batch/world is retired.

## Performance scene

The Performance Test scene offers **Native Compatible** and **Batched** under **Transparency ordering**. Its four gradient styles use alpha 0.75 and back-face culling. The existing 20,000-object default, count presets, animation, update-mode controls, and Manual LOD are retained. Unity also retains its Retained/Immediate control.

Switching mode keeps the workload and other controls, discards pending measurements, and shows “Warming up…” for 120 completed frames before collecting a fresh 120-frame rolling window. Count/API rebuilds preserve selection. Selecting the already-active mode does nothing.

For automatic comparisons, pass `--benchmark-ordering=native` or `--benchmark-ordering=batched`; omission selects native. Unsupported values exit with an error before creating the world. Godot user arguments follow its `--` separator. Existing `--benchmark-count`, `--benchmark-warmup`, and `--benchmark-frames` options remain available. Results identify `transparent_ordering_mode`, `workload_alpha`, and the rendering backend.

Native mode delegates individual renderer visibility to the engine. Mold's GPU-culling statistics and logical batch count do not represent actual native draw calls. The HUD measures CPU and wall-clock frame time, not GPU execution time. Use the engine profiler for actual GPU/draw counts. Large native workloads can be substantially slower; choose Batched explicitly for maximum throughput when its ordering is acceptable.

## Local release identity

This is a focused backport onto the supplied 0.7.1 packages, delivered locally as 0.8.0. It is distinct from the broader existing repository tag named v0.8.0. These packages do not add OIT, polygons, curves, or later geometry-deformation features. Consult the included files and local validation report rather than assuming the public v0.8.0 tag describes this build.
