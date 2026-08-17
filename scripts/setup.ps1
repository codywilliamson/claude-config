# first-time setup for claude-config (windows / powershell)
# detects os, checks prerequisites, finds obsidian vault, generates env, runs first sync
#
# usage:
#   git clone https://github.com/codywilliamson/claude-config.git ~\dev\claude-config
#   cd ~\dev\claude-config; .\scripts\setup.ps1

$ErrorActionPreference = "Stop"

# ── helpers ──────────────────────────────────────────────────────

function Info($msg)    { Write-Host "→ $msg" -ForegroundColor Blue }
function Ok($msg)      { Write-Host "✓ $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "! $msg" -ForegroundColor Yellow }
function Err($msg)     { Write-Host "✗ $msg" -ForegroundColor Red }
function Header($msg)  { Write-Host "`n$msg" -ForegroundColor Cyan -Bold }

# ── detect platform ─────────────────────────────────────────────

function Detect-Platform {
  $script:Platform = "windows"
  $osInfo = [System.Environment]::OSVersion
  $script:OsDisplay = "Windows $($osInfo.Version)"

  # check if running in WSL (unlikely in powershell, but cover it)
  if ($env:WSL_DISTRO_NAME) {
    $script:Platform = "wsl"
    $script:OsDisplay = "WSL ($env:WSL_DISTRO_NAME)"
  }

  # detect shell
  $script:ShellName = "powershell"
  if ($PSVersionTable.PSEdition -eq "Core") {
    $script:ShellName = "pwsh"
  }
}

# ── prerequisite checks ────────────────────────────────────────

function Check-Prerequisites {
  Header "checking prerequisites"

  $missing = @()

  # required
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if ($gitCmd) {
    $gitVer = (git --version) -replace 'git version ', ''
    Ok "git $gitVer"
  } else {
    Err "git not found"
    $missing += "git"
  }

  # required — scripts\sync.mjs runs on node
  $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
  if ($nodeCmd) {
    Ok "node $(node --version)"
  } else {
    Err "node not found — scripts\sync.mjs needs it"
    Err "  claude code installs via npm, so node is usually already present"
    $missing += "node"
  }

  # recommended
  foreach ($cmd in @("pnpm", "claude")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
      $ver = switch ($cmd) {
        "pnpm"   { pnpm --version }
        "claude" { try { claude --version } catch { "installed" } }
      }
      Ok "$cmd $ver"
    } else {
      Warn "$cmd not found (recommended)"
    }
  }

  if ($missing.Count -gt 0) {
    Err "missing required tools: $($missing -join ', ')"
    Err "install them and re-run setup"
    exit 1
  }
}

# ── find obsidian vault ─────────────────────────────────────────

function Find-ObsidianVault {
  Header "looking for obsidian vault"

  $candidates = @()
  $searchDirs = @(
    (Join-Path $HOME "dev\notes"),
    (Join-Path $HOME "Notes"),
    (Join-Path $HOME "Documents"),
    (Join-Path $HOME "Documents\Notes"),
    (Join-Path $HOME "Documents\Obsidian"),
    (Join-Path $HOME "Obsidian"),
    (Join-Path $HOME "vaults")
  )

  foreach ($dir in $searchDirs) {
    if (Test-Path $dir) {
      $vaults = Get-ChildItem -Path $dir -Recurse -Depth 3 -Directory -Filter ".obsidian" -ErrorAction SilentlyContinue
      foreach ($v in $vaults) {
        $candidates += $v.Parent.FullName
      }
    }
  }

  if ($candidates.Count -eq 0) {
    Warn "no obsidian vault found automatically"
    $input = Read-Host "enter your obsidian vault path (or press enter to skip)"
    if ($input) {
      $input = $input -replace '^~', $HOME
      if (Test-Path $input) {
        $script:WikiVaultPath = $input
        Ok "using vault: $script:WikiVaultPath"
      } else {
        Warn "path doesn't exist — skipping wiki vault config"
        $script:WikiVaultPath = ""
      }
    } else {
      $script:WikiVaultPath = ""
      Warn "skipped — you can set WIKI_VAULT_PATH later in .env.local"
    }
  } elseif ($candidates.Count -eq 1) {
    $script:WikiVaultPath = $candidates[0]
    Ok "found vault: $script:WikiVaultPath"
    $confirm = Read-Host "use this vault? [Y/n]"
    if ($confirm -match '^[Nn]') {
      $input = Read-Host "enter your obsidian vault path"
      $script:WikiVaultPath = $input -replace '^~', $HOME
    }
  } else {
    Info "found $($candidates.Count) vaults:"
    for ($i = 0; $i -lt $candidates.Count; $i++) {
      Write-Host "  $($i + 1)) $($candidates[$i])"
    }
    $choice = Read-Host "pick one (number) or enter a custom path"
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $candidates.Count) {
      $script:WikiVaultPath = $candidates[[int]$choice - 1]
    } else {
      $script:WikiVaultPath = $choice -replace '^~', $HOME
    }
    Ok "using vault: $script:WikiVaultPath"
  }
}

# ── ensure repo is cloned ──────────────────────────────────────

function Ensure-Repo {
  Header "checking claude-config repo"

  $repoUrl = "https://github.com/codywilliamson/claude-config.git"

  # check if we're running from inside the repo
  $scriptDir = Split-Path -Parent $PSScriptRoot
  $candidateRepo = $scriptDir
  # PSScriptRoot is scripts/, parent is the repo root
  $candidateRepo = Split-Path -Parent $PSScriptRoot

  if ((Test-Path (Join-Path $candidateRepo "CLAUDE.md")) -and (Test-Path (Join-Path $candidateRepo ".git"))) {
    $script:RepoDir = $candidateRepo
    Ok "running from repo: $script:RepoDir"
    return
  }

  # default location
  $script:RepoDir = if ($env:CLAUDE_CONFIG_REPO) { $env:CLAUDE_CONFIG_REPO } else { Join-Path $HOME "dev\claude-config" }

  if (Test-Path (Join-Path $script:RepoDir ".git")) {
    Ok "repo exists at $script:RepoDir"
    Info "pulling latest..."
    try { git -C $script:RepoDir pull --ff-only 2>$null } catch { Warn "pull failed — using local copy" }
  } else {
    Info "cloning claude-config to $script:RepoDir"
    $parent = Split-Path -Parent $script:RepoDir
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    git clone $repoUrl $script:RepoDir
    Ok "cloned to $script:RepoDir"
  }
}

# ── generate .env.local ────────────────────────────────────────

function Generate-Env {
  Header "generating .env.local"

  $envFile = Join-Path $script:RepoDir ".env.local"
  $claudeHome = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }
  $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  $content = @"
# machine-specific config — generated by setup.ps1 on $timestamp
# this file is gitignored and NOT committed to the repo
# edit these values for your local environment

# platform: $OsDisplay
PLATFORM=$Platform
SHELL_NAME=$ShellName

# where claude code stores its config
CLAUDE_HOME=$claudeHome

# where this repo lives
CLAUDE_CONFIG_REPO=$($script:RepoDir)

# obsidian vault path (used by wiki skill)
WIKI_VAULT_PATH=$WikiVaultPath

# project defaults — uncomment and edit as needed
# DEFAULT_DESIGN_SYSTEM=stripe
# TRELLO_BOARD_ID=
# JIRA_DOMAIN=
# JIRA_AGENT_EMAIL=
"@

  Set-Content $envFile $content -NoNewline
  Ok "wrote $envFile"
}

# ── run first sync ──────────────────────────────────────────────

function Run-FirstSync {
  Header "running first sync"

  $syncScript = Join-Path $script:RepoDir "scripts\sync.ps1"
  if (-not (Test-Path $syncScript)) {
    Err "sync.ps1 not found at $syncScript"
    return
  }

  $env:CLAUDE_CONFIG_REPO = $script:RepoDir
  if (-not $env:CLAUDE_HOME) { $env:CLAUDE_HOME = Join-Path $HOME ".claude" }

  & $syncScript push
}

# ── print summary ───────────────────────────────────────────────

function Print-Summary {
  Header "setup complete"

  $claudeHome = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }

  Write-Host ""
  Write-Host "  platform     $OsDisplay" -ForegroundColor White
  Write-Host "  shell        $ShellName" -ForegroundColor White
  Write-Host "  repo         $($script:RepoDir)" -ForegroundColor White
  Write-Host "  claude home  $claudeHome" -ForegroundColor White
  if ($WikiVaultPath) {
    Write-Host "  wiki vault  $WikiVaultPath" -ForegroundColor White
  }
  Write-Host ""

  Info "config synced to $claudeHome"
  Info "env file at $(Join-Path $script:RepoDir '.env.local')"
  Write-Host ""

  Write-Host "next steps:"
  Write-Host "  1. open a new terminal"
  Write-Host "  2. run 'claude' in any project"
  Write-Host "  3. try '/wiki ingest' to start your knowledge base"
  Write-Host "  4. try '/gac' after making changes for smart commits"
  Write-Host ""
  Write-Host "day to day:"
  Write-Host "  .\scripts\sync.ps1 status         what differs"
  Write-Host "  .\scripts\sync.ps1 push --git     pull latest, apply it"
  Write-Host "  .\scripts\sync.ps1 pull           capture local edits"
  Write-Host ""
  Write-Host "machine-only settings go in $claudeHome\settings.local.json"
  Write-Host "sync never overwrites it, and it always wins over the repo's base."
}

# ── main ────────────────────────────────────────────────────────

Write-Host "`nclaude-config setup" -ForegroundColor Cyan -Bold
Write-Host ("═" * 19) -ForegroundColor Cyan

Detect-Platform
Ok "detected: $OsDisplay ($ShellName)"

Check-Prerequisites
Ensure-Repo
Find-ObsidianVault
Generate-Env
Run-FirstSync
Print-Summary
