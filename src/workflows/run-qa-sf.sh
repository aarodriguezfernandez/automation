#!/usr/bin/env bash
# Simple launcher: Pick a URL, run both QA + SF automatically

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show menu
show_menu() {
  clear
  echo "========================================="
  echo "  QA + Screaming Frog Workflow"
  echo "========================================="
  echo ""
  echo "Select URL to test:"
  echo ""
  echo "  1) https://preprod.avigilon.com"
  echo "  2) https://stage.avigilon.com"
  echo "  3) https://www.avigilon.com"
  echo "  4) https://preprod.pelco.com"
  echo "  5) https://stage.pelco.com"
  echo "  6) https://www.pelco.com"
  echo ""
  echo "  0) Exit"
  echo ""
}

# Parse environment details
get_env_details() {
  local choice="$1"

  case "$choice" in
    1)
      DISPLAY_NAME="Preprod Avigilon"
      QA_ENV="preprod-avg"
      SF_URL="https://preprod.avigilon.com"
      ;;
    2)
      DISPLAY_NAME="Stage Avigilon"
      QA_ENV="stage-avg"
      SF_URL="https://stage.avigilon.com"
      ;;
    3)
      DISPLAY_NAME="Prod Avigilon"
      QA_ENV="prod-avg"
      SF_URL="https://www.avigilon.com"
      ;;
    4)
      DISPLAY_NAME="Preprod Pelco"
      QA_ENV="preprod-pel"
      SF_URL="https://preprod.pelco.com"
      ;;
    5)
      DISPLAY_NAME="Stage Pelco"
      QA_ENV="stage-pel"
      SF_URL="https://stage.pelco.com"
      ;;
    6)
      DISPLAY_NAME="Prod Pelco"
      QA_ENV="prod-pel"
      SF_URL="https://www.pelco.com"
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

# Main
main() {
  show_menu

  local choice
  read -rp "Enter choice: " choice

  if [[ "$choice" == "0" ]]; then
    echo "Cancelled"
    exit 0
  fi

  if ! get_env_details "$choice"; then
    echo "❌ Invalid selection"
    exit 1
  fi

  echo ""
  echo "Selected: $DISPLAY_NAME"
  echo "QA Environment: $QA_ENV"
  echo "SF URL: $SF_URL"
  echo ""
  echo "What would you like to run?"
  echo ""
  echo "  1) QA tests only"
  echo "  2) Screaming Frog crawl only"
  echo "  3) Both QA + SF (recommended)"
  echo ""

  local run_choice
  read -rp "Enter choice [3]: " run_choice
  run_choice=${run_choice:-3}

  case "$run_choice" in
    1)
      RUN_MODE="qa-only"
      echo ""
      echo "Will run: QA tests only"
      ;;
    2)
      RUN_MODE="sf-only"
      echo ""
      echo "Will run: Screaming Frog crawl only"
      ;;
    3)
      RUN_MODE="both"
      echo ""
      echo "Will run: Both QA tests + Screaming Frog crawl"
      ;;
    *)
      echo "❌ Invalid choice"
      exit 1
      ;;
  esac

  echo ""
  echo "✅ Configuration complete"
  echo ""
  read -rp "Press ENTER to launch workflow in iTerm2... "

  # Always launch in NEW iTerm2 window with all tabs organized
  echo ""
  echo "🚀 Opening iTerm2 with workflow tabs..."

  # Build command that sets up everything in iTerm2
  SETUP_CMD="export SELECTED_QA_ENV='$QA_ENV' SELECTED_SF_URL='$SF_URL' SELECTED_DISPLAY_NAME='$DISPLAY_NAME' RUN_MODE='$RUN_MODE' && cd '$SCRIPT_DIR' && ./launch-qa-workflow-full.sh '$QA_ENV'"

  osascript <<EOF
tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell newWindow
        tell current session
            write text "$SETUP_CMD"
            set name to "QA + SF: $DISPLAY_NAME"
        end tell
    end tell
end tell
EOF

  echo "✅ Workflow launched in iTerm2"
  echo "   All output will appear in the new iTerm2 window"
  exit 0
}

main "$@"
