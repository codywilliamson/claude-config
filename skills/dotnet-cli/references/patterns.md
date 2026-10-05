# Patterns

## Environment injection

```csharp
public sealed record CliEnvironment(
    string CurrentDirectory, bool StdoutRedirected, bool StdinRedirected,
    Func<string, string?> GetVariable, TimeProvider Clock, string Version)
{
    public static CliEnvironment FromProcess() => new(
        Environment.CurrentDirectory, Console.IsOutputRedirected, Console.IsInputRedirected,
        Environment.GetEnvironmentVariable, TimeProvider.System,
        typeof(CliEnvironment).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0");
}
```

Tests build one with a dictionary-backed `GetVariable` and a `FakeTimeProvider`.

A `RunContext` record carries the per-run state into commands: the reporter, the clock, a `Stopwatch` for elapsed time, a lazily loaded config, and factories such as `ServerFor(target)`. Keep config lazy so a `doctor` command can report a broken config as a failed check instead of crashing on it.

## Command wiring (XenoAtom.CommandLine)

```csharp
new CommandApp("name") { new CommandUsage(), new HelpOption(), new VersionOption(env.Version), Deploy(), Doctor() }
```

- A private `Define(name, description, options, action)` helper adds the common flags (`--root=`, `--plain`, `--json`, `--verbose`) to every command and routes the action through `Execute`.
- Option values live in locals that the lambdas capture. Positionals go into a `List<string>`.
- Quirk: root positionals are rejected once subcommands exist. For a tool whose default action takes a positional (like `name <query>`), build two apps and pick one by checking whether `args[0]` is a known command.
- Validate inside the action and throw `CommandOptionException("limit must be at least 1", "limit")`.

## Error boundary

There is exactly one, in `Execute`:

```csharp
try { return await action(run, ct); }
catch (ToolException e) { reporter.Error(e.Message, e.Hint); return e.ExitCode; }
catch (OperationCanceledException) when (ct.IsCancellationRequested) { return ExitCode.Aborted; }
```

`ToolException` has factory methods like `ToolException.Usage(message, hint)`. Name it after the tool (`DeployException`).

## Process runner

```csharp
public static Task<ProcessResult> RunAsync(string file, IEnumerable<string> args, CancellationToken ct,
    string? stdin = null, string? workingDirectory = null, Action<string>? onLine = null);

public sealed record ProcessResult(int ExitCode, string Stdout, string Stderr)
{
    public bool Succeeded => ExitCode == 0;
    public string Tail(int maxChars = 1500); // prefers stderr, prefixes … when cut
}
```

- Pass arguments through `ArgumentList` and set `UseShellExecute=false` and `CreateNoWindow`. Use UTF-8 for stdout/stderr and write stdin as UTF-8 without BOM.
- If the executable isn't found, the runner returns exit `127` with a message instead of throwing.
- On cancel, call `Kill(entireProcessTree: true)` and rethrow.
- Streaming goes through the `onLine` callback, which you wire to `reporter.Trace`.
- To run a command on a remote machine, pipe the script body to `ssh alias "bash -s -- 'arg'"` on stdin and single-quote each argument (`'` becomes `'\''`). Set `BatchMode=yes` and `ConnectTimeout`. Exit 255 means the ssh transport failed: retry those with backoff, and only for idempotent scripts.
- Scripts hand results back as `KEY=value` stdout lines, parsed strictly against `[A-Z0-9_]+=`. Larger payloads travel as base64 JSON.

## Config

- `DotEnv.Parse` supports `KEY=value`, an optional `export ` prefix, quotes, and `#` comments.
- `Config.Load(root, getEnv)` resolves each key as `NonEmpty(getEnv(k)) ?? NonEmpty(file[k])`. It collects every missing key, then throws once: `missing config: A, B` with the hint `set them in .env or the environment`.
- Find the project root by walking up from the cwd to a marker file. `--root` overrides it.

## Safety

- **Plan/apply**: `PlanCommand` is a thin wrapper that calls the same `Inspection.RunAsync` the apply path uses, then stops.
- **Confirm**: prompt on a TTY. Without one, require `--yes` and otherwise throw `Usage("production deploys need confirmation", "pass --yes when running without a terminal")`.
- **Doctor**: a `Checklist.CheckAsync(name, work)` wrapper runs every check as a reporter step. Failures increment a counter and the remaining checks still run. Run local checks before remote ones. The command exits `Failed` with "N problems".
- **Locks**: a `RemoteLock : IAsyncDisposable` built on an atomic `mkdir` that holds owner JSON (token, action, by, startedAt). Release it with `CancellationToken.None`. A token mismatch only warns. Ship an `unlock` command for stale locks, and give "locked" its own exit code.
- **Idempotent steps**: upload to a `.part` file, check its hash, then rename. Back up before a migration. Auto-roll back when verification fails, unless a migration has already started.
- Side effects such as notifications never change the exit code.
