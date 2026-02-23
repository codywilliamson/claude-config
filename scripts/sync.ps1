# sync claude-config repo to local claude code installation
# idempotent — safe to run multiple times, on any machine

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/codywilliamson/claude-config.git"
$RepoDir = if ($env:CLAUDE_CONFIG_REPO) { $env:CLAUDE_CONFIG_REPO } else { Join-Path $HOME "dev\claude-config" }
$TargetDir = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }

# --- helpers ---
function Info($msg)  { Write-Host "→ $msg" -ForegroundColor Blue }
function Ok($msg)    { Write-Host "✓ $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "! $msg" -ForegroundColor Yellow }

# --- step 1: ensure repo exists locally ---
if (Test-Path (Join-Path $RepoDir ".git")) {
  Info "pulling latest from claude-config repo"
  try {
    git -C $RepoDir pull --ff-only origin main 2>$null
  } catch {
    try { git -C $RepoDir pull --ff-only origin master 2>$null }
    catch { Warn "pull failed — using local copy as-is" }
  }
} else {
  Info "cloning claude-config repo to $RepoDir"
  $parent = Split-Path -Parent $RepoDir
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  git clone $RepoUrl $RepoDir
}

# --- step 2: ensure target dir exists ---
if (-not (Test-Path $TargetDir)) {
  New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

# --- step 3: sync tracked config files ---
$syncItems = @("CLAUDE.md", "settings.json", "statusline-command.sh", "agents", "commands", "hooks", "skills")

foreach ($item in $syncItems) {
  $src = Join-Path $RepoDir $item
  $dst = Join-Path $TargetDir $item

  if (-not (Test-Path $src)) {
    Warn "skipping $item (not in repo)"
    continue
  }

  if (Test-Path $src -PathType Container) {
    # sync directory — mirror contents
    if (-not (Test-Path $dst)) {
      New-Item -ItemType Directory -Force -Path $dst | Out-Null
    }
    # remove files in dst that aren't in src
    if (Test-Path $dst) {
      Get-ChildItem -Path $dst -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($dst.Length)
        $srcFile = Join-Path $src $rel
        if (-not (Test-Path $srcFile)) { Remove-Item $_.FullName -Force }
      }
    }
    # copy all files from src
    Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($src.Length)
      $dstFile = Join-Path $dst $rel
      $dstDir = Split-Path -Parent $dstFile
      if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
      Copy-Item $_.FullName $dstFile -Force
    }
  } else {
    Copy-Item $src $dst -Force
  }
}

Ok "synced config files"

# --- step 4: fix machine-specific paths in settings.json ---
$settingsPath = Join-Path $TargetDir "settings.json"
if (Test-Path $settingsPath) {
  $content = Get-Content $settingsPath -Raw

  # normalize target path for json (forward slashes)
  $jsonPath = $TargetDir -replace '\\', '/'

  # replace placeholder
  $content = $content -replace '__CLAUDE_HOME__', $jsonPath

  # fix hardcoded paths from other machines
  $content = $content -replace '/home/[^/]*/\.claude', $jsonPath
  $content = $content -replace '/Users/[^/]*/\.claude', $jsonPath
  $content = $content -replace 'C:\\Users\\[^\\]*\\.claude', $jsonPath
  $content = $content -replace 'C:/Users/[^/]*/\.claude', $jsonPath

  Set-Content $settingsPath $content -NoNewline
  Ok "fixed paths in settings.json"
}

# --- step 5: ensure .gitignore exists in target ---
$srcGitignore = Join-Path $RepoDir ".gitignore"
$dstGitignore = Join-Path $TargetDir ".gitignore"
if ((-not (Test-Path $dstGitignore)) -and (Test-Path $srcGitignore)) {
  Copy-Item $srcGitignore $dstGitignore
  Ok "copied .gitignore"
}

# --- step 6: install plugins ---
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
  $plugins = @(
    @{ repo = "anthropics/claude-plugins-official"; name = "frontend-design" },
    @{ repo = "anthropics/claude-plugins-official"; name = "typescript-lsp" },
    @{ repo = "anthropics/claude-plugins-official"; name = "claude-md-management" },
    @{ repo = "anthropics/claude-plugins-official"; name = "superpowers" },
    @{ repo = "anthropics/claude-plugins-official"; name = "github" },
    @{ repo = "anthropics/claude-code"; name = "security-guidance" },
    @{ repo = "anthropics/claude-code"; name = "feature-dev" }
  )

  Info "installing plugins (skips already-installed)"
  foreach ($p in $plugins) {
    try {
      claude plugin install $p.repo $p.name 2>$null
      Ok "installed $($p.name)"
    } catch {
      Ok "$($p.name) already installed"
    }
  }
} else {
  Warn "claude cli not found — skipping plugin install"
  Warn "install claude code first, then re-run this script"
}

Write-Host ""
Ok "claude config synced to $TargetDir"
