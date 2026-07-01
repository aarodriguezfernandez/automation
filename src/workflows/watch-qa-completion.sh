#!/usr/bin/env bash
# watch-qa-completion.sh - Watch for QA test completion and notify GChat
# Lightweight background watcher

set -euo pipefail

AUTOMATION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load environment
if [[ -f "$AUTOMATION_ROOT/.env" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env"
  set +a
fi

ENV="${1:-}"
QA_TOOL_DIR="${QA_TOOL_DIR:-$HOME/Data/b8bz8z5a/qa-tool}"

# Use GCHAT_WEBHOOK from .env (loaded above)

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 preprod-avg"
  exit 1
fi

QA_STATS="$QA_TOOL_DIR/reports/stats-$ENV.json"

echo "👀 Watching for QA completion: $ENV"
echo "   Monitoring: $QA_STATS"
echo ""

# Get initial timestamp
initial_time=0
if [[ -f "$QA_STATS" ]]; then
  initial_time=$(stat -f %m "$QA_STATS" 2>/dev/null || stat -c %Y "$QA_STATS" 2>/dev/null || echo 0)
fi

echo "   Initial timestamp: $initial_time"
echo "   Waiting for new results..."
echo ""

# Watch for changes (lightweight - check every 10 seconds)
max_wait=7200  # 2 hours max
elapsed=0
check_interval=10

while [ $elapsed -lt $max_wait ]; do
  if [[ -f "$QA_STATS" ]]; then
    current_time=$(stat -f %m "$QA_STATS" 2>/dev/null || stat -c %Y "$QA_STATS" 2>/dev/null || echo 0)

    if [ "$current_time" -gt "$initial_time" ]; then
      # File updated! Wait a bit to ensure writing is complete
      sleep 2

      # Parse results
      total=$(jq -r '.combined.total // 0' "$QA_STATS")
      passed=$(jq -r '.combined.passed // 0' "$QA_STATS")
      failed=$(jq -r '.combined.failed // 0' "$QA_STATS")

      # Build message
      if [[ $failed -gt 0 ]]; then
        MESSAGE="⚠️ QA Tests Complete (with failures)

Environment: $ENV
Total: $total
Passed: $passed
Failed: $failed

Time: $(date '+%Y-%m-%d %H:%M:%S')"
      else
        MESSAGE="✅ QA Tests Complete

Environment: $ENV
Total: $total
Passed: $passed
Failed: $failed

Time: $(date '+%Y-%m-%d %H:%M:%S')"
      fi

      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "✅ QA Tests Completed!"
      echo "$MESSAGE"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      # Send to GChat (testing webhook)
      echo "📤 Sending notification to GChat..."
      json_payload=$(jq -n --arg text "$MESSAGE" '{text: $text}')

      response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "$json_payload" \
        "${GCHAT_WEBHOOK_TEST}")

      http_code=$(echo "$response" | tail -n1)

      if [[ "$http_code" == "200" ]]; then
        echo "✅ Notification sent to GChat (testing space)"
      else
        echo "⚠️ Failed to send to GChat (HTTP $http_code)"
      fi

      # macOS notification (optional)
      if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$MESSAGE\" with title \"QA Tests Complete\" sound name \"Glass\"" 2>/dev/null || true
      fi

      exit 0
    fi
  fi

  echo -ne "\r   ⏳ Watching... (${elapsed}s / ${max_wait}s)   "
  sleep $check_interval
  elapsed=$((elapsed + check_interval))
done

echo ""
echo "⚠️  Watcher exceeded max wait time (${max_wait}s)"
echo "   Tests may have failed to complete or took too long"
exit 1
