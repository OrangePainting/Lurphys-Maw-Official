# Bulk position updates

Use bulk updates when many shapes move together. Pass the handles and their
new positions in matching arrays, then keep those arrays for the next update.
This avoids a separate setter call for every shape.

## Update positions

```csharp
int updated = context.UpdatePositions(handles, positions);
```

```gdscript
var updated := context.update_positions_bulk(handles, positions)
```

Use matching handle and position arrays, or spans in C#. Positions use Godot's
`Vector3`. The call reads your inputs and finishes the update before returning.

Mold skips stale handles and handles from another world. If a handle appears
more than once, the last position wins. Accepted counts can include positions
that did not change. The input lengths must match.

Position-only updates keep the existing rotation, scale, and shape. Use the
full-transform, color, or line-endpoint APIs for those changes; see
[batching](batching.md).

## Choose a backend

C# has two choices:

- `Managed` uses the scalar calculation.
- `SIMD`, the default, uses `System.Numerics.Vector4` to calculate several
  bounds values together when hardware acceleration is available.

Choose the initial mode in `MoldWorldSettings.PositionUpdateMode`. Settings
are copied when the runtime is created, so use the context setter for later
changes:

```csharp
context.SetPositionUpdateMode(MoldPositionUpdateMode.Managed);
var requested = context.PositionUpdateMode;
var effective = context.EffectivePositionUpdateMode;
bool available = MoldContext.IsPositionUpdateModeAvailable(
    MoldPositionUpdateMode.SIMD);
```

Each runtime has its own choice. Unsupported hardware falls back to Managed
while preserving the requested SIMD mode. Small groups use the scalar
calculation in either mode. GDScript uses its own synchronous implementation
and has no backend selector.

## When updates finish

Both C# backends and the GDScript API finish before returning. SIMD speeds up
the bounds calculation; it does not move the work to worker threads.

Call Mold APIs on the main thread. If other work calculates your input
positions, finish it before passing the results to Mold. You can reuse the
input arrays as soon as the call returns.

## Measure the result

Compare full frame time in a build on your target hardware. Faster bounds
calculations do not necessarily mean a proportionally faster frame: Godot still
receives a complete transform buffer or property texture when a batch needs
an upload.

The C# performance scene has a Managed/SIMD selector. Benchmarks accept
`--benchmark-mode=managed` or `--benchmark-mode=simd` after Godot's `--`
separator. See [performance metrics](performance-metrics.md) for the counters
and benchmark arguments.
