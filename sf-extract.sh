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
  OUTDIR="$(pwd)/sf-exports/${SITE}-${TS}"

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

  SITE=$(
    echo "$URL" |
    sed -E 's#https?://##' |
    sed 's#/$##' |
    tr '.' '-'
  )

  get_crawl_type "$URL"
  SITE="${SITE}-${CRAWL_TYPE}"

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

    printf "%2d) %-35s %6s URLs\n" \
      "$((idx+1))" \
      "$crawl_url" \
      "$crawl_urls"

    idx=$((idx+1))
  done

  read -rp "Select crawl: " choice

  SELECTED="${CRAWLS[$((choice-1))]}"

  IFS='|' read -r CRAWL_ID CRAWL_URL CRAWL_URLS <<< "$SELECTED"

  SITE=$(
  echo "$CRAWL_URL" |
  sed -E 's#https?://##' |
  sed 's#/$##' |
  tr '.' '-'
  )

  get_crawl_type "$CRAWL_URL"
  SITE="${SITE}-${CRAWL_TYPE}"

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
  python3 ./sf-report.py "$CSV" "$CRAWL_TYPE"
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

echo
read -rp "Send report to GChat? [y/N] " SEND_GCHAT

if [[ "$SEND_GCHAT" =~ ^[Yy]$ ]]; then
  send_gchat
else
  echo "Skipping GChat"
fi

# Show tabs for reference
# "$SF" --help export-tabs > export-tabs.txt 2>&1
