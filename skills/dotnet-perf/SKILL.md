---
name: dotnet-perf
description: Use when optimizing C#/.NET code, touching a hot path (per-file, per-line, per-entry loops, parsing, walking, ranking, serialization), writing BenchmarkDotNet benchmarks, or investigating why .NET code is slow or allocating.
---

# .NET performance

Performance claims are measured or they're labeled as guesses. A number you can't reproduce doesn't count.

## Steps

1. **Baseline.** Before editing, write or run a BenchmarkDotNet benchmark for the code path with `[MemoryDiagnoser]` on. Save the numbers. You're done with this step when you have a mean, allocated bytes and a Gen0 count for the current code.
2. **Find the cost.** Profile (`dotnet-trace`, `dotnet-counters`, or PerfView/VS profiler on Windows) or bisect with micro-benchmarks. Until the data confirms a cause, write it as "guess: ...".
3. **Change one thing**, then re-run the same benchmark.
4. **Compare with the best external tool for the job** (rg, fd, jq, Everything), measured as process-level wall time against the published native exe. Beating your own previous version isn't enough.
5. **Record it.** Put the before/after table in the commit body. Copy the brief JSON to a committed `bench/results/` when the repo has one.

## Hot-path rules

- No allocations inside per-entry loops. Use `Span<T>`/`ReadOnlySpan<char>`, `stackalloc` for small fixed buffers, `ArrayPool<T>.Shared`, and `string.Create`. Reuse buffers across iterations.
- No LINQ, reflection, boxing, closures that capture, or `params` arrays on hot paths. Write `foreach` over arrays or spans.
- Prefer struct-of-arrays over arrays of objects for large collections. For data that persists, memory-mapped files beat deserializing.
- Enumerate the filesystem with `FileSystemEnumerable<T>` and a transform delegate rather than `FileInfo`/`DirectoryInfo`. Prune early.
- Use `SearchValues<T>` for character-set scans, `Vector<T>`/`TensorPrimitives` for numeric work, and `CollectionsMarshal.AsSpan`/`GetValueRefOrAddDefault` to avoid copies and double lookups.
- Use source generators instead of reflection: `JsonSerializerContext`, `[GeneratedRegex]`, `[LoggerMessage]`.
- Parallelize only after the single-threaded path is lean. Use work-stealing over per-item tasks and per-worker state over shared locks. Benchmark worker counts rather than assuming `ProcessorCount`.
- For deadlines, check a `Stopwatch` inside the loop. `CancelAfter` fires late and nondeterministically.
- Measure startup too. NativeAOT is the default for CLIs because JIT startup dominates short runs.

## BenchmarkDotNet setup

```csharp
BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args,
    DefaultConfig.Instance
        .AddJob(Job.Default.WithWarmupCount(1).WithIterationCount(5))
        .AddExporter(JsonExporter.Brief)
        .WithArtifactsPath("artifacts/bench"));
```

- The bench project lives in `bench/Name.Bench` and runs in Release through `dotnet build.cs bench`. Every benchmark class has `[MemoryDiagnoser]`.
- Build inputs from seeded fixtures so runs are comparable.
- An `--external` mode times the published exe (path from `NAME_EXE`) against the competitor tool and reports p50 and p95.
- Benches run on main or locally, not as a PR gate on shared runners.
