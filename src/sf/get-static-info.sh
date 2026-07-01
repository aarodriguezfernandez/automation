#!/bin/bash
set -euo pipefail

SITE="${1:-}"

case "$SITE" in
  avigilon)
    USER=a5c5b759_1
    SERVER=f5f43580ac.nxcli.io
    S3_BUCKET=ci791087-vsa-s3-avigilon-static
    BLITZ_PATH=www.avigilon.com
    SITE_ROOT=/home/a5c5b759/avigilon.com/html
    ;;
  pelco)
    USER=ae288e2a_1
    SERVER=4df4da2b36.nxcli.io
    S3_BUCKET=ci791087-vsa-s3-pelco-static
    BLITZ_PATH=www.pelco.com
    SITE_ROOT=/home/ae288e2a/pelco.com/html
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