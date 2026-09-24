# Performance test metrics

For the 0.8.0 default, mode switching, native renderer costs, and custom-material exceptions, see [Transparency ordering](transparent-ordering.md). Existing batching details below apply to Batched and the unchanged opaque/dither paths.

The performance scene helps you see where time is going as you increase the
number of shapes. Start with frame time, then use the CPU timings to see which
part of the work gets more expensive. **Always compare in a build on your target
hardware** before committing to a performance choice.

Open the C# scene
or the [GDScript scene](../examples/performance/performance.tscn)
to try it.

## Reading the numbers

The HUD shows the last 120 frames and refreshes twice per second. Changing the
shape count or pausing/resuming animation clears that window. Give the numbers
a moment to settle after a change, since the first frames can include mesh
creation and initial uploads.

| Metric | What it tells you |
| --- | --- |
| Frame mean / p95 | Average frame time and the time that about 95% of frames fall below. A high p95 can reveal slow frames hidden by the average. |
| Simulation | Time spent calculating the animated positions in the sample. |
| Bulk update | Time spent passing those positions to Mold, including validation and any transform or bounds work done by that call. |
| Renderer CPU | Time Mold spends preparing and submitting rendering, including LOD, bounds, packing, and uploads. |
| LOD CPU | The part of Renderer CPU spent checking mesh detail. Manual LOD still has a small check cost. |
| Upload CPU | The part of Renderer CPU spent submitting buffers and textures, including Godot image staging. |
| Upload KiB/frame and calls | How much instance data Mold submits and how many upload calls it makes. Includes unused capacity and texture padding. |
| Updated | Entries accepted by the bulk update, which may include values that did not change. Zero while paused. |
| Molds / batches / meshes | The current shape count, batch count, and mesh-cache statistics. |

LOD CPU and Upload CPU are already included in Renderer CPU, so don't add them
again. Renderer CPU covers Mold's work; it is not Godot's entire rendering time,
and none of these counters measures GPU execution time.

Frame time uses the elapsed wall-clock time between `_Process` calls. This
includes engine work and waits such as VSync. FPS is `1000 / mean frame time in
milliseconds`. The p95 calculation sorts the samples and interpolates between
the two nearest entries.

## Reading metrics in your own code

Metrics are off by default. Enable them on the context you want to measure:

```csharp
context.PerformanceMetrics.Enabled = true;
MoldPerformanceMetrics metrics = context.PerformanceMetrics;
// Read on the following frame: fields describe the latest completed sync.
```

```gdscript
context.performance_metrics.enabled = true
var metrics := context.performance_metrics
```

Read the result on the following frame, after Mold has prepared and submitted
the previous frame's rendering. `RenderSequence`/`render_sequence` increases
when a measured submission completes, so you can tell whether a new result is
available. The performance scene waits for that first result before recording
a sample.

Mold reuses the metrics object. If you want to keep a history, copy its numerical
fields into your own samples. The values describe the latest measured
submission; they do not add together several cameras or submissions. Reading
them does not wait for the GPU.

## Running a benchmark

Benchmark mode hides the HUD, skips warmup frames, collects samples, then prints
one `MOLD_BENCHMARK` JSON record and exits. Pass the benchmark arguments after
Godot's `--` separator:

```text
-- --benchmark --benchmark-count=10000 --benchmark-warmup=120 --benchmark-frames=600
```

Add `--benchmark-static` to disable animation. C# also accepts
`--benchmark-mode=managed` and `--benchmark-mode=simd` to compare its CPU backends.
The result includes both the requested and effective backend, so you can see if
SIMD was unavailable.

The sample reserves space for its measurements ahead of time. In interactive
mode, formatting, percentile sorting, and statistics queries happen when the
HUD refreshes. They are outside the Simulation and Bulk update timers, but still
contribute to frame time. Benchmark mode removes that HUD work.

## JSON fields

The main frame fields are `frame_mean_ms`, `frame_median_ms`, `frame_p95_ms`, and
`fps_from_mean`. `update_mean_ms` and `update_p95_ms` combine Simulation and Bulk
update for compatibility with earlier benchmark results. They exclude the later
Renderer CPU phase.

The more detailed fields are:

- `simulation_mean_ms`, `simulation_p95_ms`
- `bulk_update_mean_ms`, `bulk_update_p95_ms`
- `render_cpu_mean_ms`, `render_cpu_p95_ms`
- `lod_cpu_mean_ms`, `lod_cpu_p95_ms`
- `upload_cpu_mean_ms`, `upload_cpu_p95_ms`
- `upload_bytes_mean`, `upload_calls_mean`, `updated_molds_mean`
- `port`, `metrics_enabled`, `hud_refresh_hz`, `gpu_time_measured`

The record also includes the workload, renderer, Godot version, VSync mode, and
frame cap. Keep these with your results so you know what you compared.

## Making a useful comparison

Keep shape count, animation, detail, culling, camera framing, renderer, and build
settings the same when comparing a change. Use an exported game with a real
graphics device. Headless runs can check that the counters and JSON work, but
they cannot tell you what drawing the scene costs on the GPU.

Upload bytes count the instance buffers and textures Mold submits. They exclude
mesh creation, uniforms, driver copies, and data written by the GPU. Use an
engine or GPU profiler when you need GPU timings, allocations, or memory usage.
The [performance guide](performance.md) explains the settings worth comparing.
