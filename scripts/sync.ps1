$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = $repoRoot
$target = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }

New-Item -ItemType Directory -Force -Path $target | Out-Null

$excludeFiles = @(".credentials.json", "history.jsonl", "stats-cache.json")
$excludeDirs = @(
  ".git",
  "scripts",
  "cache",
  "debug",
  "downloads",
  "file-history",
  "paste-cache",
  "plans",
  "projects",
  "session-env",
  "shell-snapshots",
  "statsig",
  "telemetry",
  "todos",
  "ide"
)

$args = @(
  $source,
  $target,
  "/E",
  "/R:1",
  "/W:1",
  "/NFL",
  "/NDL",
  "/NJH",
  "/NJS",
  "/NP",
  "/NS"
)

foreach ($f in $excludeFiles) { $args += "/XF"; $args += $f }
foreach ($d in $excludeDirs) { $args += "/XD"; $args += $d }

& robocopy @args | Out-Null
if ($LASTEXITCODE -ge 8) {
  throw "Robocopy failed with exit code $LASTEXITCODE"
}

Write-Host "Synced $source -> $target"
