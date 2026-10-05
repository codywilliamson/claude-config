# File-based apps (scripts)

.NET 10 runs a single `.cs` file with no project: `dotnet run tool.cs -- args`, or `dotnet tool.cs`. Use this for one-off and personal scripts in place of PowerShell or bash once the logic gets beyond a handful of lines.

```csharp
#!/usr/bin/env dotnet
#:package XenoAtom.Terminal@2.2.0
#:property InvariantGlobalization=true

using XenoAtom.Terminal;

if (args.Length == 0)
{
    Console.Error.WriteLine("usage: tool <path>");
    return 2;
}
// ...
return 0;
```

- The directives go at the top of the file: `#:package Name@version`, `#:property Key=Value`, `#:sdk Microsoft.NET.Sdk.Web`, and `#:project ../Lib/Lib.csproj`.
- Top-level statements return the exit code. Use `0` for success, `1` for failure, and `2` for usage.
- `AppContext.GetData("EntryPointFileDirectoryPath")` gives the script's own directory. Resolve paths from there, not from the cwd.
- The first run compiles and later runs hit the cache, so startup stays fast. `dotnet publish tool.cs` produces a NativeAOT exe by default. Keep the script AOT clean (source-gen JSON, no reflection) so it can be promoted to a binary later.
- On Windows, the AOT link step fails with `'vswhere.exe' is not recognized` unless `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer` is on PATH. A hello-world publishes to about 1 MB.
- On Unix, `chmod +x` plus the shebang makes `./tool.cs` run directly.
- The output rules from the main skill still apply at script size: results go to stdout and errors to stderr. Skip color when stdout is redirected (`Console.IsOutputRedirected`), and print `✓`/`✗` with durations for multi-step work.
- Run `dotnet project convert tool.cs` once the script outgrows a single file, then adopt the tool layout.
