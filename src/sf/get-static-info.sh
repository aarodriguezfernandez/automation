#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOMATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [[ -f "$AUTOMATION_ROOT/.env" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env"
  set +a
fi

# Load server configuration
if [[ -f "$AUTOMATION_ROOT/.env.servers" ]]; then
  set -a
  source "$AUTOMATION_ROOT/.env.servers"
  set +a
fi

SITE="${1:-}"

case "$SITE" in
  avigilon)
    USER="$AVIGILON_USER"
    SERVER="$AVIGILON_SERVER"
    S3_BUCKET="$AVIGILON_S3_BUCKET"
    BLITZ_PATH="$AVIGILON_BLITZ_PATH"
    SITE_ROOT="$AVIGILON_SITE_ROOT"
    ;;
  pelco)
    USER="$PELCO_USER"
    SERVER="$PELCO_SERVER"
    S3_BUCKET="$PELCO_S3_BUCKET"
    BLITZ_PATH="$PELCO_BLITZ_PATH"
    SITE_ROOT="$PELCO_SITE_ROOT"
    ;;
  *)
    echo "Usage: $0 avigilon|pelco"
    exit 1
    ;;
esac

ssh -T "$USER@$SERVER" <<EOF
static_html=\$(aws-cli/bin/aws s3 ls s3://$S3_BUCKET/ --recursive | grep -Ei "\.html$" | wc -l | xargs)

static_tag=\$(aws-cli/bin/aws s3 cp s3://$S3_BUCKET/index.html - | grep Cached || true)

prod_release=\$(readlink -f "$SITE_ROOT")

live_html=\$(find "\$prod_release/cache/blitz/$BLITZ_PATH/" -type f -name "*.html" | wc -l | xargs)

live_tag=\$(grep Cached "\$prod_release/cache/blitz/$BLITZ_PATH/index.html" || true)

  if [ "\$static_tag" = "\$live_tag" ]; then
    tag_match="yes"
  else
    tag_match="no"
  fi

  html_diff=\$((static_html - live_html))

  echo "STATIC_HTML=\$static_html"
  echo "LIVE_HTML=\$live_html"
  echo "HTML_DIFF=\$html_diff"
  echo "TAG_MATCH=\$tag_match"
EOF