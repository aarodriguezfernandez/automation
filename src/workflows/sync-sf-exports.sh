#!/usr/bin/env bash
# sync-sf-exports.sh - Manually sync sf-exports with Nexcess
# Usage: ./sync-sf-exports.sh [pull|push|both]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOMATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [[ -f "$AUTOMATION_ROOT/.env" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env"
  set +a
fi

# Load server configuration (if exists)
if [[ -f "$AUTOMATION_ROOT/.env.servers" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env.servers"
  set +a
fi

# Configuration
SF_EXPORTS_DIR="$AUTOMATION_ROOT/src/sf/sf-exports"
NEXCESS_SF_HOST="${NEXCESS_SF_HOST:-}"
NEXCESS_SF_PATH="${NEXCESS_SF_PATH:-}"

# Default action
ACTION="${1:-both}"

usage() {
  cat <<EOF
Usage: $0 [pull|push|both]

Manually sync sf-exports with Nexcess server

ACTIONS:
  pull    Pull latest exports FROM Nexcess TO local
  push    Push local exports FROM local TO Nexcess
  both    Pull first, then push (default)

CONFIGURATION:
  Set these environment variables in .env:
    NEXCESS_SF_HOST    - SSH hostname with user (e.g., user@server.nexcess.net)
    NEXCESS_SF_PATH    - Remote path to sf-exports directory

  Note: Syncs to stage server (~46MB), ensures team uses same baseline data

EXAMPLES:
  # Pull latest exports before running QA
  $0 pull

  # Push your new exports after running QA
  $0 push

  # Sync both ways (pull first, then push)
  $0 both

EOF
  exit 0
}

if [[ "$ACTION" == "-h" ]] || [[ "$ACTION" == "--help" ]]; then
  usage
fi

# Validate configuration
if [[ -z "$NEXCESS_SF_HOST" ]] || [[ -z "$NEXCESS_SF_PATH" ]]; then
  echo "❌ Error: Nexcess not configured"
  echo ""
  echo "Set these environment variables in .env:"
  echo "  NEXCESS_SF_HOST    - SSH hostname with user (e.g., user@server.nexcess.net)"
  echo "  NEXCESS_SF_PATH    - Remote path to sf-exports"
  echo ""
  exit 1
fi

# Ensure local directory exists
mkdir -p "$SF_EXPORTS_DIR"

pull_exports() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📥 Pulling sf-exports from Nexcess"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "FROM: ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"
  echo "  TO: ${SF_EXPORTS_DIR}/"
  echo ""
  echo "Note: You may be prompted for SSH password if key auth is not configured"
  echo ""

  # Allow both SSH key and password authentication
  # --delete ensures local matches remote exactly
  if rsync -avz --delete --progress "${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/" "${SF_EXPORTS_DIR}/"; then
    echo ""
    echo "✅ Successfully pulled sf-exports from Nexcess"
    echo "   (local directory now matches remote exactly)"
    echo ""
    return 0
  else
    echo ""
    echo "❌ Failed to pull sf-exports from Nexcess"
    echo ""
    echo "Possible reasons:"
    echo "  - Incorrect password or authentication failed"
    echo "  - Network timeout or server unreachable"
    echo "  - Incorrect path or permissions"
    echo ""
    return 1
  fi
}

push_exports() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📤 Pushing sf-exports to Nexcess"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "FROM: ${SF_EXPORTS_DIR}/"
  echo "  TO: ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"
  echo ""
  echo "Note: You may be prompted for SSH password if key auth is not configured"
  echo ""

  # Allow both SSH key and password authentication
  # --delete ensures remote matches local exactly
  if rsync -avz --delete --progress "${SF_EXPORTS_DIR}/" "${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"; then
    echo ""
    echo "✅ Successfully pushed sf-exports to Nexcess"
    echo "   (remote directory now matches your local exactly)"
    echo ""
    return 0
  else
    echo ""
    echo "❌ Failed to push sf-exports to Nexcess"
    echo ""
    echo "Possible reasons:"
    echo "  - Incorrect password or authentication failed"
    echo "  - Network timeout or server unreachable"
    echo "  - Incorrect path or permissions"
    echo ""
    return 1
  fi
}

# Execute action
case "$ACTION" in
  pull)
    pull_exports
    ;;
  push)
    push_exports
    ;;
  both)
    if pull_exports; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      push_exports
    fi
    ;;
  *)
    echo "❌ Error: Unknown action '$ACTION'"
    echo ""
    usage
    ;;
esac
