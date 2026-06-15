#!/usr/bin/env bash
# qa-client.sh - QA tool integration helper

QA_TOOL_DIR="${QA_TOOL_DIR:-$HOME/Data/b8bz8z5a/qa-tool}"
# Use QA_URL from .env if set, otherwise fall back to localhost
QA_SERVER_URL="${QA_URL:-${QA_SERVER_URL:-http://localhost:8884}}"

check_qa_server() {
  local curl_cmd=(curl -s --max-time 2)
  if [[ -n "${QA_USER:-}" ]] && [[ -n "${QA_PASS:-}" ]]; then
    curl_cmd+=(-u "${QA_USER}:${QA_PASS}")
  fi
  curl_cmd+=("$QA_SERVER_URL")

  if "${curl_cmd[@]}" >/dev/null 2>&1; then
    echo "✅ QA server is running at $QA_SERVER_URL"
    return 0
  else
    echo "⚠️  QA server is not running at $QA_SERVER_URL"
    return 1
  fi
}

start_qa_server() {
  echo "🚀 Starting QA server..."

  if [[ ! -d "$QA_TOOL_DIR" ]]; then
    echo "❌ QA tool directory not found: $QA_TOOL_DIR"
    return 1
  fi

  # Start server in background
  cd "$QA_TOOL_DIR" || return 1
  npm start > /tmp/qa-server.log 2>&1 &
  local server_pid=$!

  echo "   Started with PID: $server_pid"
  echo "   Waiting for server to be ready..."

  # Wait up to 30 seconds for server to start
  local max_wait=30
  local elapsed=0
  while [ $elapsed -lt $max_wait ]; do
    if check_qa_server >/dev/null 2>&1; then
      echo "✅ QA server is ready"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
    echo -ne "\r   Waiting for server... (${elapsed}s)"
  done

  echo ""
  echo "❌ QA server failed to start within ${max_wait}s"
  echo "   Check logs: /tmp/qa-server.log"
  return 1
}

ensure_qa_server() {
  # Check if we're using localhost (local testing)
  if [[ "$QA_SERVER_URL" == *"localhost"* ]] || [[ "$QA_SERVER_URL" == *"127.0.0.1"* ]]; then
    if ! check_qa_server >/dev/null 2>&1; then
      start_qa_server
    else
      echo "✅ QA server is already running at $QA_SERVER_URL"
    fi
  else
    # Remote server, just check if it's available
    check_qa_server
  fi
}

run_qa_tests_direct() {
  local env="$1"

  echo "🧪 Running QA tests for: $env"
  echo "   Using direct npm execution"

  cd "$QA_TOOL_DIR" || {
    echo "❌ QA tool directory not found: $QA_TOOL_DIR"
    return 1
  }

  export CURRENT_ENV="$env"

  echo "   Environment: CURRENT_ENV=$CURRENT_ENV"
  echo

  if ! npm run full:approve; then
    echo "❌ QA tests failed"
    return 1
  fi

  echo "✅ QA tests completed"
  return 0
}

wait_for_tests_completion() {
  local env="$1"
  local max_wait="${2:-600}"  # Default 10 minutes
  local elapsed=0
  local check_interval=3

  echo "⏳ Waiting for tests to complete..."
  echo "   Environment: $env"
  echo "   Watching: $QA_TOOL_DIR/reports/"
  echo ""

  local report_file="$QA_TOOL_DIR/reports/last-$env.json"
  local stats_file="$QA_TOOL_DIR/reports/stats-$env.json"
  local log_file="$QA_TOOL_DIR/reports/logs-$env.txt"

  # Get initial timestamp (if file exists)
  local initial_time=0
  if [[ -f "$report_file" ]]; then
    initial_time=$(stat -f %m "$report_file" 2>/dev/null || stat -c %Y "$report_file" 2>/dev/null || echo 0)
  fi

  local last_log_size=0
  local dots=""

  # Wait for file to be created or updated
  while [ $elapsed -lt $max_wait ]; do
    # Show progress from log file if it exists
    if [[ -f "$log_file" ]]; then
      local current_log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
      if [[ $current_log_size -gt $last_log_size ]]; then
        # Log is growing - tests are running
        dots="${dots}."
        if [[ ${#dots} -gt 3 ]]; then
          dots="."
        fi
        echo -ne "\r   🧪 Running tests${dots} (${elapsed}s)   "
        last_log_size=$current_log_size
      fi
    fi

    # Check if report file was updated
    if [[ -f "$report_file" ]]; then
      local current_time=$(stat -f %m "$report_file" 2>/dev/null || stat -c %Y "$report_file" 2>/dev/null || echo 0)

      if [ "$current_time" -gt "$initial_time" ]; then
        # File was updated, wait a bit to ensure writing is complete
        echo -ne "\r   📝 Finalizing results...                    \n"
        sleep 2

        # Check if stats file also exists and is recent
        if [[ -f "$stats_file" ]]; then
          echo "✅ Tests completed (${elapsed}s total)"
          echo ""
          return 0
        fi
      fi
    else
      # File doesn't exist yet, still waiting
      echo -ne "\r   ⏳ Waiting for tests to start... (${elapsed}s)   "
    fi

    sleep $check_interval
    elapsed=$((elapsed + check_interval))
  done

  echo ""
  echo "⚠️  Tests exceeded max wait time (${max_wait}s)"
  return 1
}

run_qa_tests_api() {
  local env="$1"

  echo "🧪 Running QA tests for: $env"
  echo "   Using server API at $QA_SERVER_URL"

  # Build curl command with optional basic auth
  local curl_cmd=(curl -s -X POST)
  if [[ -n "${QA_USER:-}" ]] && [[ -n "${QA_PASS:-}" ]]; then
    curl_cmd+=(-u "${QA_USER}:${QA_PASS}")
  fi
  curl_cmd+=(-H "Content-Type: application/json")
  curl_cmd+=(-d "{\"script\":\"full:approve\",\"env\":\"$env\"}")
  curl_cmd+=("$QA_SERVER_URL/run-tests")

  local response
  response=$("${curl_cmd[@]}")

  if [[ -z "$response" ]]; then
    echo "❌ No response from QA server"
    return 1
  fi

  echo "✅ QA tests started via API"
  echo "   Response: $response"
  echo

  # Wait for tests to complete before returning
  if ! wait_for_tests_completion "$env"; then
    echo "❌ Tests did not complete in time"
    return 1
  fi

  return 0
}

run_qa_tests() {
  local env="$1"
  local use_api="${2:-auto}"

  if [[ "$use_api" == "auto" ]]; then
    # Ensure server is running (will start if needed for localhost)
    if ensure_qa_server; then
      run_qa_tests_api "$env"
    else
      echo "❌ Could not connect to QA server"
      return 1
    fi
  elif [[ "$use_api" == "true" ]]; then
    ensure_qa_server
    run_qa_tests_api "$env"
  else
    run_qa_tests_direct "$env"
  fi
}

get_qa_results() {
  local env="$1"
  local output_dir="$2"

  echo "📊 Collecting QA results for: $env"

  local reports_dir="$QA_TOOL_DIR/reports"

  # Check if reports exist
  if [[ ! -d "$reports_dir" ]]; then
    echo "❌ Reports directory not found: $reports_dir"
    return 1
  fi

  # Copy JSON report
  if [[ -f "$reports_dir/last-$env.json" ]]; then
    cp "$reports_dir/last-$env.json" "$output_dir/qa-last.json"
    echo "   ✓ Copied last-$env.json"
  else
    echo "   ⚠️  Missing last-$env.json"
  fi

  # Copy stats
  if [[ -f "$reports_dir/stats-$env.json" ]]; then
    cp "$reports_dir/stats-$env.json" "$output_dir/qa-stats.json"
    echo "   ✓ Copied stats-$env.json"
  else
    echo "   ⚠️  Missing stats-$env.json"
  fi

  # Copy failed list
  if [[ -f "$reports_dir/failed-$env.txt" ]]; then
    cp "$reports_dir/failed-$env.txt" "$output_dir/qa-failed.txt"
    echo "   ✓ Copied failed-$env.txt"
  else
    echo "   ℹ️  No failed tests (failed-$env.txt doesn't exist)"
  fi

  echo "✅ QA results collected"
  return 0
}

parse_qa_stats() {
  local stats_file="$1"

  if [[ ! -f "$stats_file" ]]; then
    echo "0,0,0"
    return 1
  fi

  local total passed failed
  total=$(jq -r '.combined.total // 0' "$stats_file")
  passed=$(jq -r '.combined.passed // 0' "$stats_file")
  failed=$(jq -r '.combined.failed // 0' "$stats_file")

  echo "$total,$passed,$failed"
}
