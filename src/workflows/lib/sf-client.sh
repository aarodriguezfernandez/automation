#!/usr/bin/env bash
# sf-client.sh - Screaming Frog automation helper

SF_EXTRACT="${AUTOMATION_ROOT}/src/sf/sf-extract.sh"
SF_EXPORTS="${AUTOMATION_ROOT}/src/sf/sf-exports"

# Map environment names to SF crawl URLs
get_sf_url_for_env() {
  local env="$1"

  case "$env" in
    preprod-avg)
      echo "https://preprod.avigilon.com"
      ;;
    stage-avg)
      echo "https://stage.avigilon.com"
      ;;
    preprod-pel)
      echo "https://preprod.pelco.com"
      ;;
    stage-pel)
      echo "https://stage.pelco.com"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

# Run SF crawl - just call the existing sf-extract.sh script directly
# It handles all the prompting (URL, crawl type, live/static, etc.)
run_sf_crawl_automated() {
  local env="$1"

  echo "🕷️  Starting Screaming Frog crawl workflow..."
  echo "   The script will prompt you for details"
  echo ""

  # Just run the original script - it handles everything
  cd "$AUTOMATION_ROOT" || return 1

  if "$SF_EXTRACT"; then
    echo ""
    echo "✅ SF crawl workflow completed successfully"
    return 0
  else
    echo ""
    echo "❌ SF crawl workflow failed"
    return 1
  fi
}

# Find the most recent SF export directory
get_latest_sf_export() {
  local pattern="$1"  # e.g., "preprod-avigilon-com"

  find "$SF_EXPORTS" -maxdepth 1 -type d -name "${pattern}*" | sort -r | head -1
}

# Copy SF report to workflow output directory
collect_sf_results() {
  local env="$1"
  local output_dir="$2"

  echo "📊 Collecting SF results for: $env"

  # Map env to SF directory pattern
  local pattern
  case "$env" in
    preprod-avg)
      pattern="preprod-avigilon-com-preprod"
      ;;
    preprod-pel)
      pattern="preprod-pelco-com-preprod"
      ;;
    *)
      echo "⚠️  Cannot determine SF export pattern for: $env"
      return 1
      ;;
  esac

  # Find latest export
  local latest_export
  latest_export=$(get_latest_sf_export "$pattern")

  if [[ -z "$latest_export" ]]; then
    echo "❌ No SF exports found matching: ${pattern}*"
    return 1
  fi

  echo "   Found: $(basename "$latest_export")"

  # Find the report file
  local report_file
  report_file=$(find "$latest_export" -name "*-report.txt" -type f | head -1)

  if [[ ! -f "$report_file" ]]; then
    echo "❌ Report file not found in: $latest_export"
    return 1
  fi

  # Copy report
  cp "$report_file" "$output_dir/sf-report.txt"
  echo "   ✓ Copied SF report"

  # Copy metrics if available
  local metrics_file="${report_file%.txt}-metrics.json"
  if [[ -f "$metrics_file" ]]; then
    cp "$metrics_file" "$output_dir/sf-metrics.json"
    echo "   ✓ Copied SF metrics"
  fi

  echo "✅ SF results collected"
  return 0
}
