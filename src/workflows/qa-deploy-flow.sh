#!/usr/bin/env bash
# qa-deploy-flow.sh - Unified QA + Screaming Frog workflow orchestrator

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOMATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helper libraries
source "$SCRIPT_DIR/lib/gchat.sh"
source "$SCRIPT_DIR/lib/qa-client.sh"
source "$SCRIPT_DIR/lib/sf-client.sh"
source "$SCRIPT_DIR/lib/report-builder.sh"

# Source .env if exists
if [[ -f "$AUTOMATION_ROOT/.env" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env"
  set +a
fi

# Global variables
ENV=""
DRY_RUN=false
NO_DEPLOY=true  # Default to true for safety
INTERACTIVE=false
OUTPUT_DIR=""
TIMESTAMP=""

# Helper function for interactive pause
pause_for_review() {
  if [[ "$INTERACTIVE" == "true" ]]; then
    local message="${1:-Press ENTER to continue}"
    echo ""
    echo "⏸️  $message"
    read -r -p "   "
    echo ""
  fi
}

# Cleanup handler
cleanup_on_exit() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo
    echo "❌ Workflow failed with exit code: $exit_code"
  fi
  exit $exit_code
}

trap cleanup_on_exit EXIT

# Usage information
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Unified QA + Screaming Frog workflow orchestrator

OPTIONS:
  --env ENV         Environment to test (e.g., preprod-avg, stage-avg)
  --dry-run         Show what would run without executing
  --no-deploy       Run checks but skip deployment (default: true)
  --allow-deploy    Allow deployment if gates pass (requires confirmation)
  --interactive     Pause for review after each step (recommended for testing)
  -h, --help        Show this help message

EXAMPLES:
  # Dry run for preprod
  $0 --dry-run --env preprod-avg

  # Real execution without deployment
  $0 --env preprod-avg --no-deploy

  # Full workflow with deployment option
  $0 --env preprod-avg --allow-deploy

EOF
  exit 0
}

# Parse arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        ENV="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --no-deploy)
        NO_DEPLOY=true
        shift
        ;;
      --allow-deploy)
        NO_DEPLOY=false
        shift
        ;;
      --interactive)
        INTERACTIVE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
  done

  if [[ -z "$ENV" ]]; then
    echo "❌ Error: --env is required"
    echo
    usage
  fi
}

# Create timestamped output directory
create_output_dir() {
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  OUTPUT_DIR="$AUTOMATION_ROOT/src/workflows/runs/${ENV}-${TIMESTAMP}"

  if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$OUTPUT_DIR"
    echo "📁 Output directory: $OUTPUT_DIR"
  else
    echo "📁 [DRY RUN] Would create: $OUTPUT_DIR"
  fi
}

# Validate environment variables
validate_env_vars() {
  echo "🔍 Validating environment..."

  local missing=()

  if [[ -z "${GCHAT_WEBHOOK:-}" ]]; then
    missing+=("GCHAT_WEBHOOK")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "⚠️  Missing optional environment variables:"
    for var in "${missing[@]}"; do
      echo "   - $var"
    done
    echo
    echo "   (Notifications may be disabled)"
  else
    echo "✅ Environment validated"
  fi

  echo
}

# Main workflow
main_workflow() {
  local run_mode="${RUN_MODE:-both}"

  echo
  echo "========================================="
  echo "  QA + Screaming Frog Workflow"
  echo "========================================="
  echo "Environment: $ENV"
  echo "Run Mode: $run_mode"
  echo "Dry Run: $DRY_RUN"
  echo "Allow Deploy: $([ "$NO_DEPLOY" == "true" ] && echo "No" || echo "Yes")"
  echo "========================================="
  echo

  # Step 1: Validate
  validate_env_vars

  # Step 2: Create output directory
  create_output_dir

  # Step 3: Run QA tests (if enabled)
  if [[ "$run_mode" == "qa-only" ]] || [[ "$run_mode" == "both" ]]; then
    if [[ "$DRY_RUN" == "false" ]]; then
      echo "▶️  Step 1: Running QA tests..."
      echo
      if ! run_qa_tests "$ENV"; then
        echo "❌ QA tests failed"
        return 1
      fi
      pause_for_review "QA tests complete. Review results above, then press ENTER to continue..."
    else
      echo "▶️  [DRY RUN] Would run QA tests for: $ENV"
      echo
    fi
  else
    echo "⏭️  Step 1: Skipping QA tests (not selected)"
    echo
  fi

  # Step 4: Run Screaming Frog (if enabled)
  if [[ "$run_mode" == "sf-only" ]] || [[ "$run_mode" == "both" ]]; then
    if [[ "$DRY_RUN" == "false" ]]; then
      echo "▶️  Step 2: Running Screaming Frog..."
      echo
      run_screaming_frog_flow
      pause_for_review "SF crawl complete. Review results above, then press ENTER to continue..."
    else
      echo "▶️  [DRY RUN] Would run Screaming Frog for: $ENV"
      echo
    fi
  else
    echo "⏭️  Step 2: Skipping Screaming Frog (not selected)"
    echo
  fi

  # Adjust step numbering based on what ran
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "▶️  [DRY RUN] Would run Screaming Frog for: $ENV"
    echo
  fi

  # Step 5: Collect results
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "▶️  Step 3: Collecting results..."
    echo
    collect_all_results
    pause_for_review "Results collected. Press ENTER to continue..."
  else
    echo "▶️  [DRY RUN] Would collect results to: $OUTPUT_DIR"
    echo
  fi

  # Step 6: Generate unified report
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "▶️  Step 4: Generating unified report..."
    echo
    build_unified_report "$ENV" "$OUTPUT_DIR"
    echo
  else
    echo "▶️  [DRY RUN] Would generate unified report"
    echo
  fi

  # Step 7: Display report
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "========================================="
    echo "  REPORT"
    echo "========================================="
    cat "$OUTPUT_DIR/unified-report.txt"
    echo "========================================="
    pause_for_review "Review the report above. Press ENTER to continue..."
  fi

  # Step 8: Send to GChat
  if [[ "$DRY_RUN" == "false" ]]; then
    pause_for_review "Ready to send to GChat. Press ENTER to send OR Ctrl+C to cancel..."
    echo "▶️  Step 5: Sending to GChat..."
    echo
    if send_file_to_gchat "$OUTPUT_DIR/unified-report.txt"; then
      echo "✅ Notification sent"
    else
      echo "⚠️  Notification failed (continuing anyway)"
    fi
    echo
  else
    echo "▶️  [DRY RUN] Would send report to GChat"
    echo
  fi

  # Step 9: Check deployment gates
  if [[ "$DRY_RUN" == "false" ]]; then
    if check_deployment_gates "$OUTPUT_DIR"; then
      echo "✅ All deployment gates passed"

      if [[ "$NO_DEPLOY" == "false" ]]; then
        echo
        offer_deployment
      else
        echo
        echo "ℹ️  Deployment skipped (--no-deploy flag active)"
      fi
    else
      echo "❌ Deployment blocked by failed gates"
      return 1
    fi
  else
    echo "▶️  [DRY RUN] Would evaluate deployment gates"
  fi

  echo
  echo "✅ Workflow completed successfully!"
}

# Run Screaming Frog (opens in new terminal tab)
run_screaming_frog_flow() {
  if ! run_sf_crawl_automated "$ENV"; then
    echo "❌ Screaming Frog crawl failed"
    return 1
  fi
  return 0
}

# Collect all results
collect_all_results() {
  # Collect QA results
  if ! get_qa_results "$ENV" "$OUTPUT_DIR"; then
    echo "⚠️  Failed to collect QA results"
  fi

  # Collect SF results
  if ! collect_sf_results "$ENV" "$OUTPUT_DIR"; then
    echo "⚠️  Failed to collect SF results (continuing anyway)"
  fi
}

# Offer deployment option
offer_deployment() {
  echo "========================================="
  echo "  DEPLOYMENT OPTION"
  echo "========================================="
  echo
  echo "All gates have passed. You can proceed with deployment."
  echo
  read -rp "Do you want to trigger Buddy deployment? [y/N] " DEPLOY_CONFIRM

  if [[ ! "$DEPLOY_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "   Deployment cancelled by user"
    return 0
  fi

  echo
  echo "🚀 Buddy deployment trigger:"
  echo "   (Manual deployment integration - to be implemented)"
  echo "   Go to: https://app.buddy.works/"
}

# Main entry point
main() {
  parse_args "$@"
  main_workflow
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
