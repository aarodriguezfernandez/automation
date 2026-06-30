#!/usr/bin/env bash
set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

SF="/Applications/Screaming Frog SEO Spider.app/Contents/MacOS/ScreamingFrogSEOSpiderLauncher"

list_crawls() {
  "$SF" --headless --list-crawls 2>/dev/null | grep "^║" | grep "https://"
}

extract_crawl_id() {
  echo "$1" | awk -F'│' '{print $1}' | tr -d '║' | xargs
}

get_crawl_type() {
  if [[ "$1" == *"preprod"* ]]; then
    CRAWL_TYPE="preprod"
    clear_preprod_caches "$1"
  else
    echo
    echo "1) Live"
    echo "2) Static"
    read -rp "Select crawl type: " TYPE

    case "$TYPE" in
      1) CRAWL_TYPE="live" ;;
      2) CRAWL_TYPE="static" ;;
      *) echo "Invalid option"; exit 1 ;;
    esac
  fi
}

clear_preprod_caches() {
  if [[ "$1" == *"pelco"* ]]; then
    # Pelco preprod doesn't require cache clearing
    return 0
  fi
  user=a5c5b759_1
  server=f5f43580ac.nxcli.io
  
  echo "Clearing preprod caches..."
  # Run the cache clearing commands, navigation resave and capture exit status
  if ! ssh -T "$user@$server" '
    preprod_release=$(readlink -f /home/a5c5b759/preprod.avigilon.com/html/../)
    echo -e "Accessing $preprod_release for preprod..."
    cd "$preprod_release" || exit 1
    echo -e "Resaving main navigation..."
    ./craft resave/entries --element-id=135609 --propagate-to=avigilonEn && 
    echo -e "Clearing seomatic metabundle caches..."
    ./craft clear-caches/seomatic-metabundle-caches
  '; then
    echo "Warning: Cache clear failed for preprod" >&2
    # Continue anyway since this shouldn't block the crawl
  fi
}

confirm_static_hosts() {
  echo
  echo "==================================="
  echo "STATIC CRAWL SELECTED"
  echo "Update /etc/hosts before continuing."
  echo
  echo "Expected: production domain should point to the static AWS/S3 target."
  echo "Do not continue until hosts is correct."
  echo "==================================="
  echo

  read -rp "Have you updated /etc/hosts for STATIC? [y/N] " HOSTS_READY

  if [[ ! "$HOSTS_READY" =~ ^[Yy]$ ]]; then
    echo "Aborting static crawl."
    exit 1
  fi
}

choose_mode() {
  echo
  echo "1) Use existing crawl"
  echo "2) Run new crawl"
  echo

  read -rp "Select option: " MODE
}

export_crawl() {
  echo
  echo "Exporting crawl..."

  TS=$(date +"%Y%m%d-%H%M%S")
  SHORT_ID=$(echo "$CRAWL_ID" | cut -c1-8)
  OUTDIR="$(pwd)/src/sf/sf-exports/${SITE}-${SHORT_ID}-${TS}"

  mkdir -p "$OUTDIR"

  echo "Export OUTDIR: [$OUTDIR]"

  echo
  echo "Exporting crawl..."

  if ! "$SF" \
    --headless \
    --load-crawl "$CRAWL_ID" \
    --output-folder "$OUTDIR" \
    --export-tabs "Internal:HTML,Response Codes:External Client Error (4xx),Response Codes:Internal Client Error (4xx)" \
    --bulk-export "Response Codes:External:External Client Error (4xx) Inlinks,Response Codes:Internal:Internal Client Error (4xx) Inlinks" \
    --overwrite
  then
    echo
    echo "ERROR: Export failed"
    exit 1
  fi

  CSV="$OUTDIR/internal_html.csv"

  if [ ! -s "$CSV" ]; then
    echo
    echo "ERROR: CSV missing or empty"
    exit 1
  fi

  echo
  echo "Export complete"
  find "$OUTDIR" -type f

  run_report
}

run_new_crawl() {
  read -rp "Enter URL: " URL

  BASE_SITE=$(
    echo "$URL" |
    sed -E 's#https?://##' |
    sed 's#/$##' |
    tr '.' '-'
  )

  get_crawl_type "$URL"

  if [[ "$CRAWL_TYPE" == "static" ]]; then
    confirm_static_hosts
  fi

  SITE="${BASE_SITE}-${CRAWL_TYPE}"

  echo
  echo "Crawling: $URL"
  "$SF" \
  --headless \
  --crawl "$URL" 

  echo
  echo "Crawl complete"

  LATEST_CRAWL=$(
  "$SF" --headless --list-crawls 2>/dev/null |
    grep "^║" |
    grep "$URL" |
    head -1
  )

  CRAWL_ID=$(extract_crawl_id "$LATEST_CRAWL")

  echo
  echo "CRAWL_ID: $CRAWL_ID"

  export_crawl
}

choose_crawl() {
  CRAWLS=()

  while IFS='│' read -r id name url mode urls complete modified version _; do
    id=$(echo "$id" | tr -d '║' | xargs)
    url=$(echo "$url" | xargs)
    urls=$(echo "$urls" | xargs)

    CRAWLS+=("$id|$url|$urls")
  done < <(list_crawls)

  echo "Available crawls:"

  idx=0
  for crawl in "${CRAWLS[@]}"; do
    IFS='|' read -r crawl_id crawl_url crawl_urls <<< "$crawl"

    printf "%2d) %-35s %6s URLs (%s)\n" \
      "$((idx+1))" \
      "$crawl_url" \
      "$crawl_urls" \
      "$crawl_id"

    idx=$((idx+1))
  done

  read -rp "Select crawl: " choice

  SELECTED="${CRAWLS[$((choice-1))]}"

  IFS='|' read -r CRAWL_ID CRAWL_URL CRAWL_URLS <<< "$SELECTED"

  BASE_SITE=$(
  echo "$CRAWL_URL" |
  sed -E 's#https?://##' |
  sed 's#/$##' |
  tr '.' '-'
  )

  get_crawl_type "$CRAWL_URL"
  SITE="${BASE_SITE}-${CRAWL_TYPE}"

  echo "CRAWL_ID=[$CRAWL_ID]"
  echo
  echo "Selected:"
  echo "ID:   $CRAWL_ID"
  echo "URL:  $CRAWL_URL"
  echo "URLs: $CRAWL_URLS"
  echo "SITE: $SITE"

  export_crawl

  echo "OUTDIR: $OUTDIR"
  ls -ld "$OUTDIR"

}

run_report() {
  CSV="$OUTDIR/internal_html.csv"
  echo
  echo "Generating report..."
  python3 "$(dirname "$0")/sf-report.py" "$CSV" "$CRAWL_TYPE" "$BASE_SITE" "$CRAWL_ID"
}

send_gchat() {
  REPORT_FILE=$(find "$OUTDIR" -name '*-report.txt' | head -1)

  WEBHOOK_URL="${GCHAT_WEBHOOK:-}"

  echo "GCHAT_WEBHOOK length: ${#WEBHOOK_URL}"

  if [[ -z "$WEBHOOK_URL" ]]; then
    echo "GCHAT_WEBHOOK not set"
    return 1
  fi

  MESSAGE=$(cat "$REPORT_FILE")

  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg text "$MESSAGE" '{text:$text}')" \
    "$WEBHOOK_URL"

  echo
  echo "Sent to GChat"

  echo
  echo "REPORT_FILE: $REPORT_FILE"
}

choose_mode

if [[ "$MODE" == "1" ]]; then
  choose_crawl
elif [[ "$MODE" == "2" ]]; then
  run_new_crawl
else
  echo "Invalid option"
  exit 1
fi

if [[ "${CRAWL_TYPE:-}" == "static" ]] && [[ "${MODE:-}" == "2" ]]; then
  echo
  echo "==================================="
  echo "STATIC CRAWL COMPLETE"
  echo "If you are done with static crawls, restore /etc/hosts now."
  echo "If running more static crawls, make sure /etc/hosts points to the correct site."
  echo "==================================="
fi

echo
read -rp "Send report to GChat? [y/N] " SEND_GCHAT

if [[ "$SEND_GCHAT" =~ ^[Yy]$ ]]; then
  send_gchat
else
  echo "Skipping GChat"
fi

# Clean old export directories (keep 3 most recent per site+type)
echo
echo "Cleaning old export directories..."
EXPORT_DIR="$(pwd)/src/sf/sf-exports"
if [ -d "$EXPORT_DIR" ]; then
  cd "$EXPORT_DIR" || exit 1

  # Extract unique site+type patterns from directory names
  # Handle both formats: site-type-SHORTID-TIMESTAMP and site-type-TIMESTAMP
  PATTERNS=$(find . -mindepth 1 -maxdepth 1 -type d -name "*-*" | \
    sed -E 's|^\./||' | \
    sed -E 's/^(.*)-[a-f0-9]{8}-[0-9]{8}-[0-9]{6}$/\1/' | \
    sed -E 's/^(.*)-[0-9]{8}-[0-9]{6}$/\1/' | \
    sort -u)

  # For each pattern, keep 3 most recent and delete the rest
  echo "$PATTERNS" | while IFS= read -r pattern; do
    if [ -n "$pattern" ]; then
      # Find dirs matching this pattern, sort by modification time, keep 3 newest
      TO_DELETE=$(find . -mindepth 1 -maxdepth 1 -type d -name "${pattern}-*" -print0 | \
        xargs -0 ls -td 2>/dev/null | \
        tail -n +4)

      if [ -n "$TO_DELETE" ]; then
        echo "$TO_DELETE" | while IFS= read -r dir; do
          echo "  Removing: $dir"
          rm -rf "$dir"
        done
      fi
    fi
  done

  echo "Done. Kept 3 most recent per site+type."
fi

# Show tabs for reference
# "$SF" --help export-tabs > export-tabs.txt 2>&1
