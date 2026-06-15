#!/usr/bin/env bash
# Launch complete QA workflow with server + workflow in organized terminal tabs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_TOOL_DIR="$HOME/Data/b8bz8z5a/qa-tool"
ENV="${1:-preprod-avg}"

echo "🚀 Launching QA Workflow System"
echo "   Environment: $ENV"
echo ""

# Check if QA server is already running
if curl -s --max-time 2 http://localhost:8884 >/dev/null 2>&1; then
    echo "✅ QA server already running"
    SERVER_RUNNING=true
else
    echo "⚠️  QA server not running - will start it"
    SERVER_RUNNING=false
fi

# Build the AppleScript to create tabs in CURRENT window
osascript <<EOF
tell application "iTerm"
    activate

    tell current window
        tell current session
            -- Tab 1: Workflow Orchestrator (MAIN CONTROL)
            write text "cd '$SCRIPT_DIR' && clear && echo '==========================================' && echo '  🎯 QA + SF Workflow Orchestrator' && echo '==========================================' && echo 'Environment: $ENV' && echo '' && echo '📌 This tab controls the entire workflow' && echo '📌 Check other tabs for detailed logs' && echo '' && sleep 2 && ./qa-deploy-flow.sh --env $ENV --no-deploy --interactive ; echo '' ; echo '=========================================' && echo '✅ Workflow Complete!' && echo '=========================================' && echo '' && echo 'Review all tabs, then press ENTER to close...' ; read"
            set name to "🎯 Orchestrator"
        end tell

        -- Wait a moment
        delay 1

        -- Tab 2: QA Test Logs
        set tab2 to (create tab with default profile)
        tell tab2's current session
            write text "cd '$QA_TOOL_DIR' && clear && echo '==========================================' && echo '  QA Test Execution Logs' && echo '==========================================' && echo 'Environment: $ENV' && echo '' && echo '📋 Live test logs appear below:' && echo '' && tail -f reports/logs-$ENV.txt 2>/dev/null || (echo 'Waiting for tests to start...' && while [ ! -f reports/logs-$ENV.txt ]; do sleep 1; done && tail -f reports/logs-$ENV.txt)"
            set name to "QA Logs"
        end tell

        -- Focus back on Tab 1 (Orchestrator)
        select first tab
    end tell
end tell
EOF

echo ""
echo "✅ QA Workflow launched in iTerm2"
echo "   Tab 1: 🎯 Orchestrator (Main Control - Stay Here)"
echo "   Tab 2: QA Logs (Switch here to watch tests)"
echo ""
echo "💡 IMPORTANT:"
echo "   - Stay on Tab 1 for workflow control and prompts"
echo "   - Switch to Tab 2 to watch detailed test execution"
echo "   - All interactions happen in Tab 1"
