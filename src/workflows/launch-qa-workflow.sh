#!/usr/bin/env bash
# Launch QA workflow in a dedicated terminal window with visual progress

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="${1:-preprod-avg}"

# Create the command to run in the terminal
WORKFLOW_CMD="cd '$SCRIPT_DIR' && echo '=========================================' && echo '  QA Workflow - Visual Monitor' && echo '=========================================' && echo '' && ./qa-deploy-flow.sh --env $ENV --no-deploy ; echo '' ; echo 'Press any key to close...' ; read -n 1"

# Open new Terminal window and run the workflow
osascript <<EOF
tell application "Terminal"
    -- Create new window
    set newWindow to do script "$WORKFLOW_CMD"

    -- Bring Terminal to front
    activate

    -- Set window title
    tell newWindow
        set custom title to "QA Workflow: $ENV"
    end tell
end tell
EOF

echo "✅ QA Workflow launched in dedicated Terminal window"
echo "   Environment: $ENV"
echo "   Watch progress in the Terminal window that just opened"
