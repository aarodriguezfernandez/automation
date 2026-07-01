#!/usr/bin/env bash
# gchat.sh - Google Chat webhook notification helper

send_to_gchat() {
  local message="$1"
  local webhook_url="${GCHAT_WEBHOOK:-}"

  if [[ -z "$webhook_url" ]]; then
    echo "⚠️  GCHAT_WEBHOOK not set - skipping notification"
    return 1
  fi

  echo "📤 Preparing GChat message..."
  echo "   Formatting report for readability..."

  # Build JSON payload with proper formatting
  local json_payload
  json_payload=$(jq -n --arg text "$message" '{
    text: $text,
    cards: [{
      sections: [{
        widgets: [{
          textParagraph: {
            text: $text
          }
        }]
      }]
    }]
  }')

  echo "   Sending to GChat webhook..."

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json; charset=UTF-8" \
    -d "$json_payload" \
    "$webhook_url")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Sent to GChat successfully"
    sleep 1  # Brief pause so user can see the success message
    return 0
  else
    echo "❌ GChat send failed (HTTP $http_code)"
    echo "   Response: $(echo "$response" | head -n -1)"
    return 1
  fi
}

send_file_to_gchat() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    echo "❌ File not found: $file_path"
    return 1
  fi

  local message
  message=$(cat "$file_path")

  send_to_gchat "$message"
}

format_gchat_message() {
  local title="$1"
  local body="$2"

  cat <<EOF
*${title}*

${body}
EOF
}
