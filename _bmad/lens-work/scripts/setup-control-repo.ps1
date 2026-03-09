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
#   .\setup-control-repo.ps1 -Org weberbot -ReleaseRepo my-release -CopilotRepo my-copilot
#   .\setup-control-repo.ps1 -ReleaseOrg myorg -CopilotOrg otherorg -GovernanceOrg governance-team
#   .\setup-control-repo.ps1 -Org weberbot -BaseUrl https://github.company.com
#   .\setup-control-repo.ps1 -Help
#
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Org,

    [string]$ReleaseOrg,

    [string]$ReleaseRepo = "bmad.lens.release",

    [string]$ReleaseBranch = "beta",

    [string]$CopilotOrg,

    [string]$CopilotRepo = "bmad.lens.copilot",

    [string]$CopilotBranch = "beta",

    [string]$GovernanceOrg,

    [string]$GovernanceRepo = "lens-governance",

    [string]$GovernanceBranch = "main",

    [string]$GovernancePath = "TargetProjects\lens\lens-governance",

    [string]$BaseUrl = "https://github.com",

    [switch]$DryRun,

    [switch]$Help
)

# -- Help -------------------------------------------------------------------
if ($Help) {
    Get-Content $PSCommandPath | Select-String '^#' | ForEach-Object { $_.Line -replace '^# ?', '' }
    exit 0
}

# -- Validate ---------------------------------------------------------------
if (-not $Org -and -not $ReleaseOrg -and -not $CopilotOrg -and -not $GovernanceOrg) {
    Write-Host "Error: -Org is required (or specify -ReleaseOrg, -CopilotOrg, -GovernanceOrg individually)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\setup-control-repo.ps1 -Org <github-org-or-user>"
    exit 1
}

# -- Apply fallbacks --------------------------------------------------------
if (-not $ReleaseOrg) { $ReleaseOrg = $Org }
if (-not $CopilotOrg) { $CopilotOrg = $Org }
if (-not $GovernanceOrg) { $GovernanceOrg = $Org }

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
Write-Host "Base URL: $BaseUrl" -ForegroundColor DarkGray
Write-Host "Root:     $ProjectRoot" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Warn "Dry run mode: no changes will be made"
    Write-Host ""
}

# -- 1. Release Repo --------------------------------------------------------
$ReleaseUrl = "${BaseUrl}/${ReleaseOrg}/${ReleaseRepo}.git"
$ReleasePath = Join-Path $ProjectRoot $ReleaseRepo
Invoke-CloneOrPull -RemoteUrl $ReleaseUrl -LocalPath $ReleasePath -BranchName $ReleaseBranch -RepoLabel "${ReleaseOrg}/${ReleaseRepo}"

# -- 2. Copilot Adapter Repo ------------------------------------------------
$CopilotUrl = "${BaseUrl}/${CopilotOrg}/${CopilotRepo}.git"
$CopilotPath = Join-Path $ProjectRoot ".github"
Invoke-CloneOrPull -RemoteUrl $CopilotUrl -LocalPath $CopilotPath -BranchName $CopilotBranch -RepoLabel "${CopilotOrg}/${CopilotRepo} (.github)"

# -- 3. Governance Repo -----------------------------------------------------
$GovernanceUrl = "${BaseUrl}/${GovernanceOrg}/${GovernanceRepo}.git"
$GovernanceFullPath = Join-Path $ProjectRoot $GovernancePath
Invoke-CloneOrPull -RemoteUrl $GovernanceUrl -LocalPath $GovernanceFullPath -BranchName $GovernanceBranch -RepoLabel "${GovernanceOrg}/${GovernanceRepo}"

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
Write-Host "  $ReleaseOrg/$ReleaseRepo -> $ReleaseRepo\    (branch: $ReleaseBranch)" -ForegroundColor Green
Write-Host "  $CopilotOrg/$CopilotRepo -> .github\               (branch: $CopilotBranch)" -ForegroundColor Green
Write-Host "  $GovernanceOrg/$GovernanceRepo -> $GovernancePath\  (branch: $GovernanceBranch)" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Run the module installer to generate IDE-specific adapters:"
Write-Host "  .\_bmad\lens-work\scripts\install.ps1" -ForegroundColor Cyan
Write-Host ""
