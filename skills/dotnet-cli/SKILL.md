---
name: dotnet-cli
description: Use when creating, scaffolding, or changing a C#/.NET command-line tool, script, or file-based app (`dotnet run app.cs`), including its output, exit codes, build script, tests, or NativeAOT publishing.
---

# .NET CLIs and scripts

House style for C# tools: one small NativeAOT binary, fast startup, output that looks good in a terminal and stays clean when piped or read by an agent. Distilled from fetchle and hp-deploy.

## Pick the scale first

- **Script**: one file, run with `dotnet run tool.cs`, no repo scaffolding. See [references/file-based-apps.md](references/file-based-apps.md).
- **Tool**: a real CLI with commands, tests and a release. Use the layout below and [references/project-setup.md](references/project-setup.md).

Graduate a script to a tool once it needs a second file, tests, or more than one command.

## Layout (tool)

```
Name.slnx
global.json  Directory.Build.props  Directory.Packages.props  .editorconfig
build.cs                      # every dev step: dotnet build.cs <target>
src/Name/
  Program.cs                  # encoding, ctrl+c, app.RunAsync. nothing else
  Cli/NameApp.cs              # command wiring + the error boundary
  Cli/CliEnvironment.cs       # the only file that touches Console/Environment
  Features/<Command>/         # vertical slice per command
  Shared/                     # only what 2+ features use: Output, Processes, Config, Json
tests/Name.Tests/             # TUnit, pure logic + real-tool tests in temp dirs
tests/Name.E2E/               # drives the published native exe (when output is a contract)
```

Every command is `sealed class XCommand(RunContext run)` with `Task<ExitCode> RunAsync(XOptions options, CancellationToken ct)` and a positional `sealed record XOptions(...)`.

## Rules

**Startup and dependencies**
- NativeAOT is the default (`PublishAot` on the exe, `IsAotCompatible` on libraries). Fall back to framework-dependent only when a dependency forces it, and write that down.
- `TreatWarningsAsErrors` + `TrimmerSingleWarn=false`: every IL2xxx/IL3xxx warning breaks the build. Fix by removing reflection, never by suppressing.
- Check any new package publishes AOT with zero warnings before adding it. Default stack: `XenoAtom.CommandLine`, `XenoAtom.Terminal` (+ `.UI` for prompts and spinners), `System.Text.Json` source-gen, `TUnit`. No hosting, no DI container, no logging framework.
- All JSON goes through a source-generated `JsonSerializerContext` of records.

**Inputs**
- `CliEnvironment` record (cwd, stdout/stdin redirected, `Func<string,string?> GetVariable`, `TimeProvider`, version) is built once in `Program` and passed down. Features never read `Console`, `Environment` or `DateTime.Now`.
- Config: process env wins over `.env`. Collect *every* missing key into one error before failing.
- Validate args up front and fail before doing any work.

**Output**: see [references/output.md](references/output.md) for the mode table, the reporter interface and the visual style.
- Choose the mode once, as a pure function: `--json` > `--plain` > agent env (`CLAUDECODE`, `CODEX_*`) > CI / redirected stdout (plain) > TTY (pretty).
- Plain mode emits zero escape bytes. Live widgets (spinners, progress) only in pretty mode, never when stdout is redirected.
- Results go to stdout, everything else (progress, warnings, errors) to stderr.

**Errors and exit codes**
- One typed exception for expected failures carrying `Message`, `Hint` and `ExitCode`. The app's single error boundary prints `✗ message` + `hint: ...` and returns the code. A stack trace means a bug.
- Exit codes are a documented enum: `0` success, `1` failed / no results, `2` usage, then tool-specific codes from `3`. The parser returns its own codes on bad args, so track whether an action ran and map parser failures to `2`.
- Error text is lowercase, prefixed with the tool name, and names the bad value: `name: unknown target 'prdo', use staging or production`.

**Safety (anything destructive or remote)**
- `plan` and `apply` share one inspection path, so plan can't drift from apply.
- Destructive actions confirm on a TTY and require `--yes` without one. Declining is its own exit code, not a failure.
- First ctrl+c cancels the token and lets the current step finish and release locks. The second one kills the process.
- Leases are `await using` and release with `CancellationToken.None`. Steps are idempotent so a re-run resumes.
- Child processes are argv-only (`ArgumentList`, no shell). Cancelling kills the whole tree. Patterns are in [references/patterns.md](references/patterns.md).

**Help**
- `--help` is one dense screen with usage, flags and two real examples. Agents read help too, so make it copy-pasteable.

## The loop

`build.cs` is a file-based app holding every target: `restore, build, test, e2e, publish, ci` (+ `bench`, `eval` when they exist). `ci` runs restore (locked) → build → publish → unit → e2e against the published exe, and stops on the first failure. Details are in [references/testing.md](references/testing.md).

Done means `dotnet build.cs ci` passes **against the native exe**, not just the JIT build. Show the command and its output.

For hot paths (per-file, per-line, per-entry loops), load the `dotnet-perf` skill.
