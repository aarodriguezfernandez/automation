#!/usr/bin/env bash
# Launch QA+SF workflow in iTerm2 with interactive menu

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Launching QA + SF Workflow in iTerm2..."

# Build the command that will run in iTerm2
WORKFLOW_CMD="cd '$SCRIPT_DIR' && bash '$SCRIPT_DIR/run-qa-sf.sh'"

# Open iTerm2 and run the interactive workflow
osascript <<EOF
tell application "iTerm"
    activate

    -- Create new window
    set newWindow to (create window with default profile)

    tell newWindow
        tell current session
            write text "$WORKFLOW_CMD"
            set name to "QA + SF Workflow"
        end tell
    end tell
end tell
EOF

echo "✅ Workflow launched in iTerm2"
echo "   Follow the prompts in the new window"
