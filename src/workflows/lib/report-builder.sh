#!/usr/bin/env bash
# report-builder.sh - Unified report generation

build_unified_report() {
  local env="$1"
  local output_dir="$2"
  local report_file="$output_dir/unified-report.txt"

  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo "📝 Building unified report..."

  {
    echo "========================================="
    echo "  QA + Screaming Frog Report"
    echo "========================================="
    echo "Environment: $env"
    echo "Timestamp: $timestamp"
    echo "========================================="
    echo

    # QA Test Results
    if [[ -f "$output_dir/qa-stats.json" ]]; then
      echo "## QA Test Results"
      echo "-------------------"

      local qa_stats
      qa_stats=$(cat "$output_dir/qa-stats.json")

      local total passed failed
      total=$(echo "$qa_stats" | jq -r '.combined.total // 0')
      passed=$(echo "$qa_stats" | jq -r '.combined.passed // 0')
      failed=$(echo "$qa_stats" | jq -r '.combined.failed // 0')

      echo "Total Tests: $total"
      echo "Passed: $passed"
      echo "Failed: $failed"

      if [[ "$failed" -gt 0 ]]; then
        echo
        echo "❌ FAILED TESTS:"
        if [[ -f "$output_dir/qa-failed.txt" ]]; then
          cat "$output_dir/qa-failed.txt" | head -20
          local count
          count=$(wc -l < "$output_dir/qa-failed.txt")
          if [[ "$count" -gt 20 ]]; then
            echo "   ... and $((count - 20)) more"
          fi
        fi
      else
        echo "✅ All tests passed!"
      fi

      echo
    else
      echo "## QA Test Results"
      echo "-------------------"
      echo "⚠️  No QA stats available"
      echo
    fi

    # Screaming Frog Results
    local sf_report
    sf_report=$(find "$output_dir" -name "*-report.txt" -type f -not -name "unified-report.txt" | head -1)

    if [[ -f "$sf_report" ]]; then
      echo "## Screaming Frog Results"
      echo "-------------------------"

      # Safety check: limit SF report to first 10000 lines to prevent disk issues
      local line_count
      line_count=$(wc -l < "$sf_report" 2>/dev/null || echo "0")
      local file_size
      file_size=$(du -h "$sf_report" | cut -f1)

      echo "Report: $(basename "$sf_report") (${line_count} lines, ${file_size})"
      echo

      if [[ "$line_count" -gt 10000 ]]; then
        echo "⚠️  Large report detected - showing first 10000 lines"
        echo
        head -10000 "$sf_report"
        echo
        echo "... [truncated $(($line_count - 10000)) lines for safety]"
      else
        cat "$sf_report"
      fi
      echo
    else
      echo "## Screaming Frog Results"
      echo "-------------------------"
      echo "⚠️  No SF report available"
      echo
    fi

    # Deployment Gates
    echo "## Deployment Gates"
    echo "-------------------"
    evaluate_gates "$output_dir"

  } > "$report_file"

  echo "✅ Report saved: $report_file"
  echo
}

evaluate_gates() {
  local output_dir="$1"
  local blockers=()
  local warnings=()

  # Check QA failures
  if [[ -f "$output_dir/qa-stats.json" ]]; then
    local failed
    failed=$(jq -r '.combined.failed // 0' "$output_dir/qa-stats.json")

    if [[ "$failed" -gt 5 ]]; then
      blockers+=("❌ BLOCKER: QA has $failed failed tests (threshold: 5)")
    elif [[ "$failed" -gt 0 ]]; then
      warnings+=("⚠️  WARNING: QA has $failed failed tests")
    fi
  fi

  # Check SF metrics
  local sf_metrics
  sf_metrics=$(find "$output_dir" -name "*-metrics.json" -type f | head -1)

  if [[ -f "$sf_metrics" ]]; then
    local internal_404s missing_meta

    internal_404s=$(jq -r '.internal_404 // 0' "$sf_metrics")
    missing_meta=$(jq -r '.missing_meta // 0' "$sf_metrics")

    if [[ "$internal_404s" -gt 0 ]]; then
      blockers+=("❌ BLOCKER: $internal_404s internal 404s found")
    fi

    if [[ "$missing_meta" -gt 10 ]]; then
      warnings+=("⚠️  WARNING: $missing_meta pages missing meta descriptions")
    fi
  fi

  # Output gates
  if [[ ${#blockers[@]} -gt 0 ]]; then
    echo "🚫 DEPLOYMENT BLOCKED"
    echo
    for blocker in "${blockers[@]}"; do
      echo "$blocker"
    done
    echo
  fi

  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "⚠️  WARNINGS (Review Required)"
    echo
    for warning in "${warnings[@]}"; do
      echo "$warning"
    done
    echo
  fi

  if [[ ${#blockers[@]} -eq 0 ]] && [[ ${#warnings[@]} -eq 0 ]]; then
    echo "✅ ALL GATES PASSED"
    echo
    echo "Safe to proceed with deployment"
    return 0
  elif [[ ${#blockers[@]} -eq 0 ]]; then
    echo "⚠️  Warnings present but no blockers"
    echo "Deployment allowed with caution"
    return 0
  else
    echo "❌ Critical blockers present"
    echo "DO NOT DEPLOY until issues are resolved"
    return 1
  fi
}

check_deployment_gates() {
  local output_dir="$1"

  evaluate_gates "$output_dir" > /dev/null 2>&1
  return $?
}
