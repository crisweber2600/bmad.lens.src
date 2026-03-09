# =============================================================================
# LENS Workbench v2 — Control Repo Setup
#
# PURPOSE:
#   Bootstraps a new control repo by cloning all required authority domains:
#   - bmad.lens.release   → Release module (read-only dependency)
#   - bmad.lens.copilot   → Copilot adapter (.github/ content)
#   - lens-governance     → Governance repo (constitutional authority)
#
#   Safe to re-run: pulls latest if repos already exist.
#
# USAGE:
#   .\setup-control-repo.ps1 -Org <github-org-or-user>
#   .\setup-control-repo.ps1 -Org weberbot -GovernancePath TargetProjects\lens\lens-governance
#   .\setup-control-repo.ps1 -Org weberbot -Branch beta
#   .\setup-control-repo.ps1 -Help
#
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Org,

    [string]$Branch = "beta",

    [string]$GovernancePath = "TargetProjects\lens\lens-governance",

    [string]$GovernanceRepo = "lens-governance",

    [string]$Host = "github.com",

    [switch]$DryRun,

    [switch]$Help
)

# -- Help -------------------------------------------------------------------
if ($Help) {
    Get-Content $PSCommandPath | Select-String '^#' | ForEach-Object { $_.Line -replace '^# ?', '' }
    exit 0
}

# -- Validate ---------------------------------------------------------------
if (-not $Org) {
    Write-Host "Error: -Org is required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\setup-control-repo.ps1 -Org <github-org-or-user>"
    exit 1
}

$ProjectRoot = Get-Location

# -- Helper Functions -------------------------------------------------------

function Write-Info   { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok     { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Warn   { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err    { param([string]$Msg) Write-Host "[ERR]  $Msg" -ForegroundColor Red }

function Invoke-CloneOrPull {
    param(
        [string]$RemoteUrl,
        [string]$LocalPath,
        [string]$BranchName,
        [string]$RepoLabel
    )

    if ($DryRun) {
        if (Test-Path (Join-Path $LocalPath ".git")) {
            Write-Info "[DRY-RUN] Would pull latest for $RepoLabel at $LocalPath (branch: $BranchName)"
        }
        else {
            Write-Info "[DRY-RUN] Would clone $RepoLabel -> $LocalPath (branch: $BranchName)"
        }
        return
    }

    if (Test-Path (Join-Path $LocalPath ".git")) {
        Write-Info "Pulling latest for $RepoLabel ($LocalPath)..."
        Push-Location $LocalPath
        try {
            git fetch origin
            $null = git checkout $BranchName 2>$null
            if ($LASTEXITCODE -ne 0) {
                git checkout -b $BranchName "origin/$BranchName"
            }
            git pull origin $BranchName
            Write-Ok "$RepoLabel updated (branch: $BranchName)"
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Info "Cloning $RepoLabel -> $LocalPath (branch: $BranchName)..."
        $parentDir = Split-Path $LocalPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        git clone --branch $BranchName $RemoteUrl $LocalPath
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to clone $RepoLabel"
            exit 1
        }
        Write-Ok "$RepoLabel cloned (branch: $BranchName)"
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "LENS Workbench v2 — Control Repo Setup" -ForegroundColor White -NoNewline
Write-Host ""
Write-Host "Org:  $Org" -ForegroundColor DarkGray
Write-Host "Host: $Host" -ForegroundColor DarkGray
Write-Host "Root: $ProjectRoot" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Warn "Dry run mode: no changes will be made"
    Write-Host ""
}

# -- 1. Release Repo --------------------------------------------------------
$ReleaseUrl = "https://${Host}/${Org}/bmad.lens.release.git"
$ReleasePath = Join-Path $ProjectRoot "bmad.lens.release"
Invoke-CloneOrPull -RemoteUrl $ReleaseUrl -LocalPath $ReleasePath -BranchName $Branch -RepoLabel "bmad.lens.release"

# -- 2. Copilot Adapter Repo ------------------------------------------------
$CopilotUrl = "https://${Host}/${Org}/bmad.lens.copilot.git"
$CopilotPath = Join-Path $ProjectRoot ".github"
Invoke-CloneOrPull -RemoteUrl $CopilotUrl -LocalPath $CopilotPath -BranchName $Branch -RepoLabel "bmad.lens.copilot (.github)"

# -- 3. Governance Repo -----------------------------------------------------
$GovernanceUrl = "https://${Host}/${Org}/${GovernanceRepo}.git"
$GovernanceFullPath = Join-Path $ProjectRoot $GovernancePath
Invoke-CloneOrPull -RemoteUrl $GovernanceUrl -LocalPath $GovernanceFullPath -BranchName "main" -RepoLabel "lens-governance"

# -- 4. Output directories --------------------------------------------------
if (-not $DryRun) {
    $dirs = @(
        (Join-Path $ProjectRoot "_bmad-output\lens-work\initiatives"),
        (Join-Path $ProjectRoot "_bmad-output\lens-work\personal")
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Ok "Output directory structure verified"
}
else {
    Write-Info "[DRY-RUN] Would create _bmad-output\lens-work\ directories"
}

# -- Summary ----------------------------------------------------------------
Write-Host ""
Write-Host "Setup Complete" -ForegroundColor White
Write-Host ""
Write-Host "  bmad.lens.release   -> bmad.lens.release\      (branch: $Branch)" -ForegroundColor Green
Write-Host "  bmad.lens.copilot   -> .github\                (branch: $Branch)" -ForegroundColor Green
Write-Host "  $GovernanceRepo  -> $GovernancePath\     (branch: main)" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Run the module installer to generate IDE-specific adapters:"
Write-Host "  .\_bmad\lens-work\scripts\install.ps1" -ForegroundColor Cyan
Write-Host ""
