# Build loop and tests

## build.cs

`build.cs` is a .NET 10 file-based app at the repo root, run as `dotnet build.cs <target> [--rid <rid>]`. It replaces Makefiles, npm scripts and shell scripts.

```csharp
#:package XenoAtom.Terminal@2.2.0
#:property RestorePackagesWithLockFile=false

return BuildScript.Run(args);

record Options(string Target, string? Rid) { public static Options? Parse(string[] args) { /* ... */ } }
record Step(string Name, string[] Args, IReadOnlyDictionary<string, string>? Environment = null)
{
    public string CommandLine() => "dotnet " + string.Join(' ', Args);
}
static class Targets
{
    public static readonly string[] NAMES = ["restore", "build", "test", "e2e", "publish", "ci"];
    public static Step[] For(Options o) => o.Target switch { /* "ci" => [restore --locked-mode, build --no-restore, publish, test --no-build, e2e --no-build with NAME_EXE] */ };
}
```

- `Runner.RunAll` runs the steps in order. After the first failure it marks the rest `Skipped` and exits with the failing step's own exit code. A usage error exits `2`.
- Get the repo root from `AppContext.GetData("EntryPointFileDirectoryPath")`.
- Report each step as a `[i/n] name ───` header and the `$ dotnet ...` line, then `✓`/`✗` with elapsed time. End with a summary table and the total time.
- On Windows, append the VS Installer dir to the child PATH so NativeAOT can find `vswhere.exe`.

CI is one line in every OS of the matrix: `dotnet build.cs ci`. Use `actions/setup-dotnet` with `global-json-file`, cache keyed on `**/packages.lock.json`, `permissions: contents: read`, and `concurrency` with cancel-in-progress. Benchmarks run in a separate workflow on main only, because shared runners are too noisy to gate PRs.

## Unit tests (TUnit)

- The test project has `OutputType Exe` and runs with `dotnet test --project tests/Name.Tests -c Release`. Assertions look like `await Assert.That(x).IsEqualTo(y)`.
- Unit test pure logic: parsing, mode detection, config, planners, formatting. Glue code doesn't get unit tests.
- Wrap external tools in a small interface (`IRemoteShell`) and test against a **real** local implementation (`LocalBashShell`) in a temp dir, not a mock. Use `[Before(Test)]` to create a `TempDir` and `[After(Test)]` to dispose it.
- When a prerequisite is missing, call `Skip.Test(reason)` so the test is skipped with a reason rather than silently passing. On Windows, find Git Bash and skip System32's WSL `bash.exe`.

## E2E against the native exe

- A harness uses `[Before(TestSession)]`. When `NAME_EXE` is set (CI), it uses that path. Otherwise it publishes once to `artifacts/e2e` and throws if the publish fails.
- Snapshot the CLI output in every mode. Assert that plain mode contains zero ESC bytes, and assert the exit code of every documented path.
- For MCP servers, run JSON-RPC over stdio: initialize, tools/list, an unknown tool returns `-32602`, and closing stdin exits cleanly.
- Build fixture trees in temp dirs from a shared `Name.Fixtures` project. Include unicode names, long paths, symlinks and unreadable dirs where they apply.

## Evals and benches

- Use evals when the output's *quality* matters (ranking, matching). Run them as a console app with `queries.json` and a committed `baseline.json`, and fail when the score drops below the baseline. Tests check correctness; evals check quality.
- For benches, see the `dotnet-perf` skill.

## Docs that keep agents on track

- Keep `AGENTS.md` short: what the tool is, status, links to specs, "rules that came from spikes" (one-line gotchas), the loop command, and what done means.
- `docs/decisions.md` lists entries newest first as `## YYYY-MM-DD: decision`. Each entry says what was decided, why, and the evidence (the command and its output). Mark superseded entries instead of deleting them.
- `docs/specs/cli.md` holds the tables for commands, flags, output modes and exit codes. The e2e suite enforces it, so when behavior and spec disagree, fix one of them in the same change.
