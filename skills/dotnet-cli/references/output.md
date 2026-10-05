# Output

Beautiful in a terminal, boring when piped. The same run has to read well to a human at a TTY, to `grep`, to CI logs and to an agent.

## Modes

| Mode | Chosen when | Looks like |
|---|---|---|
| `Json` | `--json` | one JSON object per line on stdout, source-gen serialized |
| `Plain` | `--plain`, `CI` set, or stdout redirected | no escape bytes, stable line prefixes |
| `Agent` | `--agent` or agent env var (`CLAUDECODE`, `CODEX_*`) | plain, never prompts, plus a one-line stderr footer (counts, elapsed, truncation + flag for more) |
| `GitHubActions` | `GITHUB_ACTIONS=true` | plain plus `::group::`, `::warning::`, `::error::` and a `$GITHUB_STEP_SUMMARY` append |
| `Pretty` | everything else (TTY) | color, spinners, links |

Only add the modes the tool needs. Detection is a pure function over `CliEnvironment` so it can be unit tested:

```csharp
public static OutputMode Detect(bool json, bool plain, CliEnvironment env) =>
    json ? OutputMode.Json
    : plain ? OutputMode.Plain
    : IsAgent(env) ? OutputMode.Agent
    : env.GetVariable("GITHUB_ACTIONS") == "true" ? OutputMode.GitHubActions
    : env.StdoutRedirected || !string.IsNullOrEmpty(env.GetVariable("CI")) ? OutputMode.Plain
    : OutputMode.Pretty;
```

## Two shapes of output

**Result tools** (search, list, query) print data. Hide the writer behind `IResultWriter` with one implementation per mode, chosen once by `ResultWriters.For(mode)`.

**Step tools** (deploy, sync, build) print progress. Hide that behind `IReporter`:

```csharp
public interface IReporter
{
    bool CanPrompt { get; }
    void Title(string title, IReadOnlyList<Fact> facts);
    Task<T> StepAsync<T>(string name, Func<StepScope, Task<T>> work); // scope.Detail / Note / Skip
    void Info(string message);
    void Warn(string message);
    void Error(string message, string? hint);
    void Trace(string line);             // streamed child output, --verbose only
    bool Confirm(string question);       // false when !CanPrompt
    void Finish(bool ok, string headline, TimeSpan elapsed);
}
```

`PrettyReporter` and `PlainReporter` are the two implementations. Features only ever see `IReporter`.

## Pretty style

- Each step is one line: a Braille spinner at 80ms while it runs, then `✓ name  1.2s  detail` or `✗ name  0.4s`. A step always shows its duration.
- Use color to carry meaning, not decoration: green ✓, red ✗, yellow warnings, dim metadata (sizes, ages, durations), bold for the one thing the reader needs. Cyan is for names and targets.
- Align label/value rows with `{label,-12}` rather than drawing tables. Use a table only for a final summary of several measured steps.
- Make paths and URLs clickable with OSC 8 (`BeginLink`/`EndLink`).
- Wrap redraws in DEC 2026 synchronized output, and rate-limit OSC 9;4 taskbar progress.
- Finish with a single headline: `✓ deployed 2.4.1 to production in 1m04s`.
- `NO_COLOR` drops color but keeps bold, dim and links. XenoAtom handles detection.
- `--verbose` streams child output as `│ line` and turns live widgets off, because they fight with streamed lines.
- Escape user text before putting it in markup. In XenoAtom markup `[` and `]` are doubled.

XenoAtom calls: `Terminal.WriteMarkupLine("[green]✓[/] ...")`, `Terminal.LiveAsync(new Markup(() => line), () => done ? Stop : Continue)`, and `Terminal.Prompt(new ConfirmationPrompt(...).Default(false))` from `XenoAtom.Terminal.UI`.

## Plain style

Use stable prefixes so the output is greppable:

```
> package
ok package (3.1s)  theme-2.4.1.zip 4.2 MB
- migrate (skipped: nothing pending)
warning: drift on wp-config.php
FAILED swap
error: swap failed on production (exit 1): ...
  hint: run `name unlock production` if no deploy is running
```

## Formatting helpers

Keep these in one `Durations` file:

- Durations: under 1s as `NNNms`, under 60s as `N.Ns`, otherwise `NmSSs`.
- Sizes: B/KB/MB.
- Ages: `just now`, `5m ago`, `3h ago`, `2d ago`.
- Parsing for budget flags like `2s` and `500ms`.

## Errors

```
✗ production deploys need confirmation
  hint: pass --yes when running without a terminal
```

Errors are one line plus an actionable hint, written to stderr. Never print a stack trace for an expected failure.
