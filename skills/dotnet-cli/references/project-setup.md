# Project setup

Copy these and adjust names. Bump versions to current ones when scaffolding, and check that the bumped versions still publish AOT clean.

## global.json

```json
{
  "sdk": { "version": "10.0.400", "rollForward": "latestFeature" },
  "test": { "runner": "Microsoft.Testing.Platform" }
}
```

TUnit needs the `test.runner` line. `dotnet test --project <path>` is the MTP form.

## Directory.Build.props (root)

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <!-- report every IL2xxx/IL3xxx, not one per package -->
    <TrimmerSingleWarn>false</TrimmerSingleWarn>
    <InvariantGlobalization>true</InvariantGlobalization>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
    <Deterministic>true</Deterministic>
    <IncludeSourceRevisionInInformationalVersion>false</IncludeSourceRevisionInInformationalVersion>
    <Version>0.0.0</Version>
  </PropertyGroup>
</Project>
```

`src/Directory.Build.props` imports the root and adds `<IsAotCompatible>true</IsAotCompatible>` so every src library runs the trim/AOT analyzers:

```xml
<Project>
  <Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" />
  <PropertyGroup><IsAotCompatible>true</IsAotCompatible></PropertyGroup>
</Project>
```

## The exe csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <AssemblyName>name</AssemblyName>
    <PublishAot>true</PublishAot>
    <!-- PublishAot adds a host-RID ILCompiler pack, so the lock file differs per OS -->
    <RestorePackagesWithLockFile>false</RestorePackagesWithLockFile>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="XenoAtom.CommandLine" />
    <PackageReference Include="XenoAtom.Terminal" />
    <InternalsVisibleTo Include="Name.Tests" />
  </ItemGroup>
</Project>
```

Third-party packages stay pinned through the test project's lock file. Refresh the lock files after an SDK bump, because the ILLink version moves.

Embed helper scripts or templates as resources rather than shipping loose files: `<EmbeddedResource Include="**/*.sh" LogicalName="%(Filename)%(Extension)" />`.

## Directory.Packages.props

Versions only. Csprojs carry `PackageReference` with no version.

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="XenoAtom.CommandLine" Version="2.0.3" />
    <PackageVersion Include="XenoAtom.Terminal" Version="2.2.0" />
    <PackageVersion Include="XenoAtom.Terminal.UI" Version="3.10.0" />
    <PackageVersion Include="TUnit" Version="1.72.16" />
    <PackageVersion Include="BenchmarkDotNet" Version="0.15.8" />
  </ItemGroup>
</Project>
```

## .editorconfig essentials

Warnings are errors, so all of these break the build:

```ini
root = true
[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 4
insert_final_newline = true
[*.{json,xml,csproj,props,slnx}]
indent_size = 2
[*.{ps1,cmd}]
end_of_line = crlf
[*.cs]
csharp_style_namespace_declarations = file_scoped:warning
csharp_prefer_braces = true:warning
csharp_style_prefer_primary_constructors = true:suggestion
# const fields UPPER_SNAKE, private fields _camel (IDE1006 naming rules)
```

## Program.cs

```csharp
Console.OutputEncoding = new UTF8Encoding(false);
using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    if (cts.IsCancellationRequested) { return; } // second ctrl+c: let it die
    e.Cancel = true;
    cts.Cancel();
};
return (int)await new NameApp(CliEnvironment.FromProcess()).RunAsync(args, cts.Token);
```

## Publishing

- `dotnet publish src/Name -c Release -o artifacts/publish [-r <rid>]`.
- Windows needs the VS C++ build tools, and NativeAOT linking needs `vswhere.exe` on PATH. Add `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer` to the child PATH in `build.cs`.
- Cross-OS binaries come from a CI matrix (windows/ubuntu/macos). NativeAOT doesn't cross-compile across OSes.
- Versioning: release-please reads conventional commits and bumps `<Version>`.
