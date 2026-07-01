#!/usr/bin/env bash
# simple-qa-sf.sh - Simple parallel QA + SF workflow
# Mimics natural CLI usage: start both, wait for completion, send report

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
QA_TOOL_DIR="${QA_TOOL_DIR:-$HOME/Data/b8bz8z5a/qa-tool}"
QA_SERVER_URL="${QA_URL:-${QA_SERVER_URL:-http://localhost:8884}}"
SF_SCRIPT="$AUTOMATION_ROOT/src/sf/sf-extract.sh"
SF_EXPORTS_DIR="$AUTOMATION_ROOT/src/sf/sf-exports"

# Nexcess sync configuration
NEXCESS_SF_HOST="${NEXCESS_SF_HOST:-}"
NEXCESS_SF_PATH="${NEXCESS_SF_PATH:-}"

# Flags
ENV=""
TEST_MODE=false
SKIP_QA=false
SKIP_SF=false
USE_LOCAL=false
SKIP_SYNC=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Simple parallel QA + Screaming Frog workflow

OPTIONS:
  --env ENV         QA environment (preprod-avg, stage-avg, prod-avg, etc.)
  --test            Test mode: skip actual QA and SF execution
  --skip-qa         Skip QA tests (SF only)
  --skip-sf         Skip Screaming Frog (QA only)
  --skip-sync       Skip sf-exports sync with Nexcess (pull before, push after)
  --local           Use local QA server (localhost:8884) instead of remote
  -h, --help        Show this help

EXAMPLES:
  # Full run (QA + SF) - local testing
  $0 --env preprod-avg --local

  # Test mode (dry run)
  $0 --env preprod-avg --test

  # QA only (skip SF) - local testing
  $0 --env preprod-avg --skip-sf --local

  # SF only (skip QA)
  $0 --env preprod-avg --skip-qa

  # Skip Nexcess sync (for testing without credentials)
  $0 --env preprod-avg --skip-sync

NEXCESS SYNC:
  Set these environment variables in .env to enable sf-exports sync:
    NEXCESS_SF_HOST    - SSH hostname with user (e.g., user@server.nexcess.net)
    NEXCESS_SF_PATH    - Remote path to sf-exports directory

  Note: sf-exports is ~46MB, syncs to stage server for team baseline consistency

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"
      shift 2
      ;;
    --test)
      TEST_MODE=true
      shift
      ;;
    --skip-qa)
      SKIP_QA=true
      shift
      ;;
    --skip-sf)
      SKIP_SF=true
      shift
      ;;
    --skip-sync)
      SKIP_SYNC=true
      shift
      ;;
    --local)
      USE_LOCAL=true
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

# Validate required args
if [[ -z "$ENV" ]]; then
  echo "❌ Error: --env is required"
  usage
fi

# Override QA server URL if --local flag is set
if [[ "$USE_LOCAL" == "true" ]]; then
  QA_SERVER_URL="http://localhost:8884"
fi

# Create timestamped output directory
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$AUTOMATION_ROOT/src/workflows/runs/${ENV}-${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# ============================================
# SF Exports Sync Functions
# ============================================

sync_enabled() {
  if [[ "$SKIP_SYNC" == "true" ]]; then
    return 1
  fi

  if [[ -z "$NEXCESS_SF_HOST" ]] || [[ -z "$NEXCESS_SF_PATH" ]]; then
    return 1
  fi

  return 0
}

pull_sf_exports() {
  if ! sync_enabled; then
    if [[ "$SKIP_SYNC" == "true" ]]; then
      echo "⏭️  Skipping sf-exports pull (--skip-sync)"
    else
      echo "⏭️  Skipping sf-exports pull (Nexcess not configured)"
      echo "   Set NEXCESS_SF_HOST and NEXCESS_SF_PATH in .env to enable sync"
    fi
    echo ""
    return 0
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📥 Pulling sf-exports from Nexcess"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Syncing FROM: ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"
  echo "          TO: ${SF_EXPORTS_DIR}/"
  echo ""

  if [[ "$TEST_MODE" == "true" ]]; then
    echo "[TEST MODE] Would run:"
    echo "  rsync -avz --delete --progress ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/ ${SF_EXPORTS_DIR}/"
    echo ""
    return 0
  fi

  # Allow both SSH key and password authentication
  # If SSH key is set up: automatic
  # If not: user will be prompted for password
  echo "   Note: You may be prompted for SSH password if key auth is not configured"
  echo ""

  # --delete ensures local matches remote exactly (removes old exports)
  if rsync -avz --delete --progress \
    "${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/" "${SF_EXPORTS_DIR}/"; then
    echo ""
    echo "✅ Successfully pulled sf-exports from Nexcess"
    echo "   (local directory now matches remote exactly)"
    echo ""
  else
    echo ""
    echo "⚠️  Failed to pull sf-exports from Nexcess"
    echo "   Possible reasons:"
    echo "   - Incorrect password"
    echo "   - Network timeout"
    echo "   - Server unreachable"
    echo "   - Incorrect path or permissions"
    echo ""
    echo "   Continuing with local exports..."
    echo ""
  fi
}

push_sf_exports() {
  if ! sync_enabled; then
    if [[ "$SKIP_SYNC" == "true" ]]; then
      echo "⏭️  Skipping sf-exports push (--skip-sync)"
    else
      echo "⏭️  Skipping sf-exports push (Nexcess not configured)"
    fi
    echo ""
    return 0
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📤 Pushing sf-exports to Nexcess"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Syncing FROM: ${SF_EXPORTS_DIR}/"
  echo "          TO: ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"
  echo ""

  if [[ "$TEST_MODE" == "true" ]]; then
    echo "[TEST MODE] Would run:"
    echo "  rsync -avz --delete --progress ${SF_EXPORTS_DIR}/ ${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"
    echo ""
    return 0
  fi

  # Allow both SSH key and password authentication
  # If SSH key is set up: automatic
  # If not: user will be prompted for password
  echo "   Note: You may be prompted for SSH password if key auth is not configured"
  echo ""

  # --delete ensures remote matches local exactly (removes old exports from server)
  if rsync -avz --delete --progress \
    "${SF_EXPORTS_DIR}/" "${NEXCESS_SF_HOST}:${NEXCESS_SF_PATH}/"; then
    echo ""
    echo "✅ Successfully pushed sf-exports to Nexcess"
    echo "   (remote directory now matches your local exactly)"
    echo ""
  else
    echo ""
    echo "❌ Failed to push sf-exports to Nexcess"
    echo "   Possible reasons:"
    echo "   - Incorrect password"
    echo "   - Network timeout"
    echo "   - Server unreachable"
    echo "   - Incorrect path or permissions"
    echo ""
    echo "   Your local exports are still available but not shared with team"
    echo ""
  fi
}

echo ""
echo "========================================="
echo "  Simple QA + SF Workflow"
echo "========================================="
echo "Environment:  $ENV"
echo "QA Server:    $QA_SERVER_URL"
echo "Test Mode:    $TEST_MODE"
echo "Skip QA:      $SKIP_QA"
echo "Skip SF:      $SKIP_SF"
echo "Skip Sync:    $SKIP_SYNC"
echo "Output:       $OUTPUT_DIR"
echo "========================================="
echo ""

# ============================================
# Step 0: Pull latest sf-exports from Nexcess
# ============================================
pull_sf_exports

# ============================================
# Step 1: Start QA Tool (background browser)
# ============================================
if [[ "$SKIP_QA" == "false" ]]; then
  if [[ "$TEST_MODE" == "false" ]]; then
    echo "▶️  Starting QA tests..."
    echo "   Environment: $ENV"
    echo "   Server: $QA_SERVER_URL"
    echo ""

    # Check if QA server is running first
    echo "   Checking if QA server is running..."
    if ! curl -s --max-time 2 "$QA_SERVER_URL" >/dev/null 2>&1; then
      if [[ "$USE_LOCAL" == "true" ]]; then
        echo "   ⚠️  Local QA server not running"
        echo "   🚀 Starting local QA server..."
        echo ""

        if [[ ! -d "$QA_TOOL_DIR" ]]; then
          echo "❌ QA tool directory not found: $QA_TOOL_DIR"
          exit 1
        fi

        # Start server in background
        cd "$QA_TOOL_DIR" || exit 1
        npm start > /tmp/qa-server.log 2>&1 &
        server_pid=$!

        echo "   Started with PID: $server_pid"
        echo "   Waiting for server to be ready..."

        # Wait up to 30 seconds for server to start
        max_wait=30
        elapsed=0
        while [ $elapsed -lt $max_wait ]; do
          if curl -s --max-time 2 "$QA_SERVER_URL" >/dev/null 2>&1; then
            echo "   ✓ QA server is ready"
            echo ""
            break
          fi
          sleep 1
          elapsed=$((elapsed + 1))
          echo -ne "\r   Waiting... (${elapsed}s)   "
        done

        if [ $elapsed -ge $max_wait ]; then
          echo ""
          echo "❌ QA server failed to start within ${max_wait}s"
          echo "   Check logs: /tmp/qa-server.log"
          exit 1
        fi

        cd "$AUTOMATION_ROOT" || exit 1
      else
        echo "❌ QA server is not running at $QA_SERVER_URL"
        exit 1
      fi
    else
      echo "   ✓ QA server is already running"
      echo ""
    fi

    # Build curl command with auth
    curl_cmd=(curl -s -X POST)
    if [[ -n "${QA_USER:-}" ]] && [[ -n "${QA_PASS:-}" ]]; then
      curl_cmd+=(-u "${QA_USER}:${QA_PASS}")
    fi
    curl_cmd+=(-H "Content-Type: application/json")
    curl_cmd+=(-d "{\"script\":\"full:approve\",\"env\":\"$ENV\"}")
    curl_cmd+=("$QA_SERVER_URL/run-tests")

    # Start QA tests (API call triggers browser)
    response=$("${curl_cmd[@]}" 2>&1 || echo "ERROR")

    if [[ "$response" == "ERROR" ]] || [[ -z "$response" ]]; then
      echo "❌ Failed to start QA tests"
      exit 1
    fi

    echo "✅ QA tests started (browser should open)"
    echo "   Tests are running in the background"
    echo ""

    # Send start notification to GChat (testing webhook)
    echo "📤 Sending start notification to GChat..."

    START_MESSAGE="🚀 QA Tests Started

Environment: $ENV
Server: $QA_SERVER_URL
Time: $(date '+%Y-%m-%d %H:%M:%S')

Tests are running..."

    start_payload=$(jq -n --arg text "$START_MESSAGE" '{text: $text}')
    start_response=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Content-Type: application/json; charset=UTF-8" \
      -d "$start_payload" \
      "${GCHAT_WEBHOOK_TEST}")

    start_http_code=$(echo "$start_response" | tail -n1)

    if [[ "$start_http_code" == "200" ]]; then
      echo "   ✓ Start notification sent"
    else
      echo "   ⚠️  Start notification failed (HTTP $start_http_code)"
    fi
    echo ""

    # Start watcher in background to notify when complete
    echo "👀 Starting completion watcher..."
    nohup "$SCRIPT_DIR/watch-qa-completion.sh" "$ENV" > "$OUTPUT_DIR/watcher.log" 2>&1 &
    WATCHER_PID=$!
    echo "   Watcher started (PID: $WATCHER_PID)"
    echo "   You'll receive GChat notification when tests complete"
    echo ""
  else
    echo "▶️  [TEST MODE] Would start QA tests for: $ENV"
    echo "   Would check server at: $QA_SERVER_URL"
    echo ""

    # Send TEST notification to GChat
    echo "📤 Sending TEST notification to GChat..."

    TEST_MESSAGE="🧪 TEST MODE - QA Workflow

Environment: $ENV
Server: $QA_SERVER_URL
Mode: Dry run (no actual execution)
Time: $(date '+%Y-%m-%d %H:%M:%S')

This is a test notification."

    test_payload=$(jq -n --arg text "$TEST_MESSAGE" '{text: $text}')
    test_response=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Content-Type: application/json; charset=UTF-8" \
      -d "$test_payload" \
      "${GCHAT_WEBHOOK_TEST}")

    test_http_code=$(echo "$test_response" | tail -n1)

    if [[ "$test_http_code" == "200" ]]; then
      echo "   ✓ Test notification sent to GChat"
    else
      echo "   ⚠️  Test notification failed (HTTP $test_http_code)"
    fi
    echo ""
  fi
else
  echo "⏭️  Skipping QA tests"
  echo ""
fi

# ============================================
# Step 2: Run Screaming Frog (interactive)
# ============================================
SF_OUTDIR=""
LIVE_OUTDIR=""
STATIC_OUTDIR=""

if [[ "$SKIP_SF" == "false" ]]; then
  if [[ "$TEST_MODE" == "false" ]]; then
    echo "▶️  Starting Screaming Frog crawl..."
    echo "   sf-extract.sh will prompt you for all options"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Run SF script as-is - completely interactive
    # User sees all prompts and makes all choices
    cd "$AUTOMATION_ROOT" || exit 1

    # Save output to temp file while still showing to user
    SF_LOG="$OUTPUT_DIR/sf-output.log"

    if bash "$SF_SCRIPT" 2>&1 | tee "$SF_LOG"; then
      # Extract OUTDIR from SF output
      SF_OUTDIR=$(grep -oE "Export OUTDIR: \[.*\]" "$SF_LOG" | sed 's/Export OUTDIR: \[\(.*\)\]/\1/' | tail -1)

      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "✅ Screaming Frog crawl complete"
      if [[ -n "$SF_OUTDIR" ]]; then
        echo "   Output: $SF_OUTDIR"
      fi
      echo ""
    else
      echo ""
      echo "❌ Screaming Frog crawl failed or was cancelled"
      echo ""
    fi
  else
    echo "▶️  [TEST MODE] Would run sf-extract.sh"
    echo "   (interactive - you'd see all the normal prompts)"
    echo ""
  fi
else
  echo "⏭️  Skipping Screaming Frog"
  echo ""
fi

# ============================================
# Step 3: Display SF report (if available)
# ============================================
if [[ "$TEST_MODE" == "false" ]] && [[ "$SKIP_SF" == "false" ]]; then
  if [[ -n "$SF_OUTDIR" ]] && [[ -d "$SF_OUTDIR" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Screaming Frog Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Find SF report in the output directory
    SF_REPORT=$(find "$SF_OUTDIR" -name "*-report.txt" | head -1)
    if [[ -f "$SF_REPORT" ]]; then
      cat "$SF_REPORT"
    else
      echo "SF report not found in: $SF_OUTDIR"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

# ============================================
# Step 4: Deployment Prompt
# ============================================
if [[ "$TEST_MODE" == "false" ]] && [[ "$SKIP_SF" == "false" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Deployment"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Review the preprod results above."
  echo ""
  read -rp "🚀 Ready to deploy? [y/N] " DEPLOY_READY

  if [[ ! "$DEPLOY_READY" =~ ^[Yy]$ ]]; then
    echo ""
    echo "⏭️  Deployment skipped - workflow stopped"
    echo ""
    exit 0
  fi

  echo ""
  echo "▶️  Deploy now via Buddy:"
  echo "   1. Go to: https://app.buddy.works/"
  echo "   2. Select the appropriate pipeline"
  echo "   3. Trigger deployment for: $ENV"
  echo ""

  read -rp "Press ENTER when deployment is complete... "

  echo ""
  echo "✅ Deployment confirmed"
  echo ""

  # ============================================
  # Step 5: LIVE Production SF Crawl
  # ============================================
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  LIVE Production Crawl"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Now run SF crawl for LIVE production site"
  echo ""

  read -rp "Run LIVE production crawl? [y/N] " RUN_LIVE

  if [[ "$RUN_LIVE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "📤 Sending LIVE crawl notification..."


    LIVE_START_MESSAGE="🕷️ LIVE Production Crawl Started

Time: $(date '+%Y-%m-%d %H:%M:%S')

Running LIVE crawl (interactive mode)..."

    live_start_payload=$(jq -n --arg text "$LIVE_START_MESSAGE" '{text: $text}')
    curl -s -X POST \
      -H "Content-Type: application/json; charset=UTF-8" \
      -d "$live_start_payload" \
      "${GCHAT_WEBHOOK_TEST}" > /dev/null 2>&1

    echo "   ✓ Notification sent"
    echo ""
    echo "▶️  Starting LIVE crawl..."
    echo "   sf-extract.sh will prompt you for all options"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$AUTOMATION_ROOT" || exit 1
    LIVE_LOG="$OUTPUT_DIR/live-crawl.log"

    if bash "$SF_SCRIPT" 2>&1 | tee "$LIVE_LOG"; then
      LIVE_OUTDIR=$(grep -oE "Export OUTDIR: \[.*\]" "$LIVE_LOG" | sed 's/Export OUTDIR: \[\(.*\)\]/\1/' | tail -1)

      echo ""
      echo "✅ LIVE crawl complete"
      if [[ -n "$LIVE_OUTDIR" ]]; then
        echo "   Output: $LIVE_OUTDIR"
      fi
      echo ""

      # Send completion notification
      LIVE_COMPLETE_MESSAGE="✅ LIVE Production Crawl Complete

Time: $(date '+%Y-%m-%d %H:%M:%S')

LIVE crawl finished successfully!"

      live_complete_payload=$(jq -n --arg text "$LIVE_COMPLETE_MESSAGE" '{text: $text}')
      curl -s -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "$live_complete_payload" \
        "${GCHAT_WEBHOOK_TEST}" > /dev/null 2>&1
    else
      echo ""
      echo "❌ LIVE crawl failed"
      echo ""
    fi
  else
    echo "⏭️  LIVE crawl skipped"
    echo ""
  fi

  # ============================================
  # Step 6: STATIC Production SF Crawl
  # ============================================
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  STATIC Production Crawl"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⚠️  STATIC crawl requires /etc/hosts configuration"
  echo "   Point production domain to static target (S3/AWS)"
  echo ""

  read -rp "Run STATIC production crawl? [y/N] " RUN_STATIC

  if [[ "$RUN_STATIC" =~ ^[Yy]$ ]]; then
    echo ""
    read -rp "Have you configured /etc/hosts for STATIC? [y/N] " HOSTS_READY

    if [[ ! "$HOSTS_READY" =~ ^[Yy]$ ]]; then
      echo ""
      echo "⏭️  STATIC crawl skipped - /etc/hosts not ready"
      echo ""
    else
      echo ""
      echo "📤 Sending STATIC crawl notification..."

      STATIC_START_MESSAGE="🕷️ STATIC Production Crawl Started

Time: $(date '+%Y-%m-%d %H:%M:%S')

Running STATIC crawl (interactive mode)...
Make sure to select STATIC mode!"

      static_start_payload=$(jq -n --arg text "$STATIC_START_MESSAGE" '{text: $text}')
      curl -s -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "$static_start_payload" \
        "${GCHAT_WEBHOOK_TEST}" > /dev/null 2>&1

      echo "   ✓ Notification sent"
      echo ""
      echo "▶️  Starting STATIC crawl..."
      echo "   sf-extract.sh will prompt you for all options"
      echo "   ⚠️  Make sure to select 'STATIC' mode when prompted!"
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      cd "$AUTOMATION_ROOT" || exit 1
      STATIC_LOG="$OUTPUT_DIR/static-crawl.log"

      if bash "$SF_SCRIPT" 2>&1 | tee "$STATIC_LOG"; then
        STATIC_OUTDIR=$(grep -oE "Export OUTDIR: \[.*\]" "$STATIC_LOG" | sed 's/Export OUTDIR: \[\(.*\)\]/\1/' | tail -1)

        echo ""
        echo "✅ STATIC crawl complete"
        if [[ -n "$STATIC_OUTDIR" ]]; then
          echo "   Output: $STATIC_OUTDIR"
        fi
        echo ""
        echo "⚠️  Remember to restore /etc/hosts!"
        echo ""

        # Send completion notification
        STATIC_COMPLETE_MESSAGE="✅ STATIC Production Crawl Complete

Time: $(date '+%Y-%m-%d %H:%M:%S')

STATIC crawl finished successfully!
Don't forget to restore /etc/hosts."

        static_complete_payload=$(jq -n --arg text "$STATIC_COMPLETE_MESSAGE" '{text: $text}')
        curl -s -X POST \
          -H "Content-Type: application/json; charset=UTF-8" \
          -d "$static_complete_payload" \
          "${GCHAT_WEBHOOK_TEST}" > /dev/null 2>&1
      else
        echo ""
        echo "❌ STATIC crawl failed"
        echo ""
      fi
    fi
  else
    echo "⏭️  STATIC crawl skipped"
    echo ""
  fi
fi

# ============================================
# Final Step: Push sf-exports to Nexcess
# ============================================
# Always push after any QA run to keep team in sync
# Even if SF was skipped, QA might have generated data
# This ensures other developers running different envs get your latest exports
push_sf_exports

echo "✅ Complete workflow finished!"
echo ""
if [[ "$SKIP_QA" == "false" ]]; then
  echo "📝 QA tests are running in the background"
  echo "   You'll receive a notification when they complete"
  echo ""
fi
if [[ -n "$SF_OUTDIR" ]]; then
  echo "📁 Preprod SF results: $SF_OUTDIR"
fi
if [[ -n "$LIVE_OUTDIR" ]]; then
  echo "📁 LIVE SF results: $LIVE_OUTDIR"
fi
if [[ -n "$STATIC_OUTDIR" ]]; then
  echo "📁 STATIC SF results: $STATIC_OUTDIR"
fi
