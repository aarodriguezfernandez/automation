#!/bin/bash

DATE=$(date +"%Y-%m-%d_%H-%M")
REPORT="$HOME/automation/reports/$DATE-report.txt"

echo "Daily Check Report - $DATE" > "$REPORT"
echo "==============================" >> "$REPORT"

# QA Tool

# Curl checks

# Screaming Frog placeholder

echo "" >> "$REPORT"
echo "Done: $REPORT"