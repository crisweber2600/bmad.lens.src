#!/usr/bin/env bash
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
#   ./setup-control-repo.sh --org <github-org-or-user>
#   ./setup-control-repo.sh --org weberbot --governance-path TargetProjects/lens/lens-governance
#   ./setup-control-repo.sh --org weberbot --branch beta
#   ./setup-control-repo.sh --help
#
# OPTIONS:
#   --org <name>              GitHub org or user that owns the repos (REQUIRED)
#   --branch <name>           Branch to checkout for release and copilot repos (default: beta)
#   --governance-path <path>  Local path for governance repo clone (default: TargetProjects/lens/lens-governance)
#   --governance-repo <name>  Governance repo name (default: lens-governance)
#   --host <hostname>         Git host (default: github.com)
#   --dry-run                 Show what would be done without making changes
#   -h, --help                Show this help message
#
# =============================================================================

set -euo pipefail

# -- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# -- Defaults ---------------------------------------------------------------
ORG=""
BRANCH="beta"
GOVERNANCE_PATH="TargetProjects/lens/lens-governance"
GOVERNANCE_REPO="lens-governance"
HOST="github.com"
DRY_RUN=false

# -- Project root (where this script is run from, or computed) ---------------
PROJECT_ROOT="$(pwd)"

# -- Parse Arguments --------------------------------------------------------
show_help() {
  sed -n '2,/^# =/p' "$0" | sed 's/^# //'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      shift
      ORG="$1"
      ;;
    --branch)
      shift
      BRANCH="$1"
      ;;
    --governance-path)
      shift
      GOVERNANCE_PATH="$1"
      ;;
    --governance-repo)
      shift
      GOVERNANCE_REPO="$1"
      ;;
    --host)
      shift
      HOST="$1"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      show_help
      exit 1
      ;;
  esac
  shift
done

# -- Validate required args --------------------------------------------------
if [[ -z "$ORG" ]]; then
  echo -e "${RED}Error: --org is required${RESET}"
  echo ""
  show_help
  exit 1
fi

# -- Helper Functions -------------------------------------------------------
log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${RED}[ERR]${RESET}  $1"; }

clone_or_pull() {
  local remote_url="$1"
  local local_path="$2"
  local branch="$3"
  local repo_label="$4"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -d "$local_path/.git" ]]; then
      log_info "[DRY-RUN] Would pull latest for ${repo_label} at ${local_path} (branch: ${branch})"
    else
      log_info "[DRY-RUN] Would clone ${repo_label} → ${local_path} (branch: ${branch})"
    fi
    return
  fi

  if [[ -d "$local_path/.git" ]]; then
    log_info "Pulling latest for ${repo_label} (${local_path})..."
    (
      cd "$local_path"
      git fetch origin
      git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch"
      git pull origin "$branch"
    )
    log_ok "${repo_label} updated (branch: ${branch})"
  else
    log_info "Cloning ${repo_label} → ${local_path} (branch: ${branch})..."
    mkdir -p "$(dirname "$local_path")"
    git clone --branch "$branch" "$remote_url" "$local_path"
    log_ok "${repo_label} cloned (branch: ${branch})"
  fi
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${BOLD}LENS Workbench v2 — Control Repo Setup${RESET}"
echo -e "${DIM}Org:  ${ORG}${RESET}"
echo -e "${DIM}Host: ${HOST}${RESET}"
echo -e "${DIM}Root: ${PROJECT_ROOT}${RESET}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  log_warn "Dry run mode: no changes will be made"
  echo ""
fi

# -- 1. Release Repo --------------------------------------------------------
RELEASE_URL="https://${HOST}/${ORG}/bmad.lens.release.git"
RELEASE_PATH="${PROJECT_ROOT}/bmad.lens.release"
clone_or_pull "$RELEASE_URL" "$RELEASE_PATH" "$BRANCH" "bmad.lens.release"

# -- 2. Copilot Adapter Repo ------------------------------------------------
COPILOT_URL="https://${HOST}/${ORG}/bmad.lens.copilot.git"
COPILOT_PATH="${PROJECT_ROOT}/.github"
clone_or_pull "$COPILOT_URL" "$COPILOT_PATH" "$BRANCH" "bmad.lens.copilot (.github)"

# -- 3. Governance Repo -----------------------------------------------------
GOVERNANCE_URL="https://${HOST}/${ORG}/${GOVERNANCE_REPO}.git"
GOVERNANCE_FULL_PATH="${PROJECT_ROOT}/${GOVERNANCE_PATH}"
clone_or_pull "$GOVERNANCE_URL" "$GOVERNANCE_FULL_PATH" "main" "lens-governance"

# -- 4. Output directories --------------------------------------------------
if [[ "$DRY_RUN" != true ]]; then
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/initiatives"
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/personal"
  log_ok "Output directory structure verified"
else
  log_info "[DRY-RUN] Would create _bmad-output/lens-work/ directories"
fi

# -- Summary ----------------------------------------------------------------
echo ""
echo -e "${BOLD}Setup Complete${RESET}"
echo ""
echo -e "  ${GREEN}bmad.lens.release${RESET}   → bmad.lens.release/      (branch: ${BRANCH})"
echo -e "  ${GREEN}bmad.lens.copilot${RESET}   → .github/                (branch: ${BRANCH})"
echo -e "  ${GREEN}${GOVERNANCE_REPO}${RESET}  → ${GOVERNANCE_PATH}/     (branch: main)"
echo ""
echo -e "Next: Run the module installer to generate IDE-specific adapters:"
echo -e "  ${CYAN}./_bmad/lens-work/scripts/install.sh${RESET}"
echo ""
