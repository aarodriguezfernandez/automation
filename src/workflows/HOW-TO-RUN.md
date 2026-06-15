# How to Run the QA Workflow

## Quick Start (Recommended)

**One command - Interactive menu in iTerm2:**

```bash
cd ~/automation
./src/workflows/run-qa-sf.sh
```

**Step 1:** Select URL to test:
```
1) https://preprod.avigilon.com
2) https://stage.avigilon.com
3) https://www.avigilon.com
4) https://preprod.pelco.com
5) https://stage.pelco.com
6) https://www.pelco.com
```

**Step 2:** Choose what to run:
```
1) QA tests only
2) Screaming Frog crawl only  
3) Both QA + SF (recommended)
```

**Step 3:** iTerm2 opens automatically with your workflow

The script automatically:
- Determines QA environment variables
- Configures SF crawl URL  
- Launches organized iTerm2 window with 2 tabs:
  - **Tab 1**: ⭐ Live Test Execution Logs **(WATCH THIS!)**
  - **Tab 2**: Workflow Control (Interactive Prompts)

All visual output is centralized in this one window. 
- **Tab 1** shows tests running in real-time
- **Tab 2** prompts you to review and confirm each step
- **Interactive choice** to run new SF crawl or use existing

## Alternative: Manual Run

If you prefer to run components separately:

1. **Start QA Server** (in one terminal):
   ```bash
   cd ~/Data/b8bz8z5a/qa-tool
   npm start
   ```

2. **Run Workflow** (in another terminal):
   ```bash
   cd ~/automation
   ./src/workflows/qa-deploy-flow.sh --env preprod-avg --no-deploy
   ```

## What You'll See

```
==========================================
  QA Workflow - preprod-avg
==========================================

⏳ Starting workflow...

▶️  Step 1: Running QA tests...
🧪 Running tests... (45s)

▶️  Step 2: Running Screaming Frog...
✅ SF step skipped (will use existing reports)

▶️  Step 3: Collecting results...
📊 Collecting QA results...

▶️  Step 4: Generating unified report...
📝 Building unified report...

▶️  Step 5: Sending to GChat...
⚠️  GCHAT_WEBHOOK not set - skipping notification

✅ Workflow complete!
```

## Output Location

Results are saved to timestamped directories:
```
~/automation/src/workflows/runs/preprod-avg-YYYYMMDD-HHMMSS/
├── qa-last.json        # Full test results
├── qa-stats.json       # Test statistics summary
├── sf-report.txt       # Screaming Frog report
└── unified-report.txt  # Combined report with gates
```

## Available Environments

- `preprod-avg` - Pre-production Avigilon (2 URLs - quick test)
- `stage-avg` - Staging Avigilon
- `prod-avg` - Production Avigilon
- `preprod-pel` - Pre-production Pelco
- `stage-pel` - Staging Pelco
- `prod-pel` - Production Pelco

## Testing vs Production

**During Testing (Current Mode):**
- ✅ GChat notifications are DISABLED
- ✅ Uses `--no-deploy` flag (default)
- ✅ Review reports manually before any deployment
- ✅ All output visible in terminal

**For Production Use (After Approval):**
1. Enable `GCHAT_WEBHOOK` in `.env`
2. Still use `--no-deploy` for safety
3. Manually deploy after verifying gates pass

## Troubleshooting

**QA Server not starting:**
- Check if port 8884 is already in use: `lsof -i :8884`
- Kill existing process if needed: `kill -9 <PID>`

**Workflow hangs:**
- Check Tab 1 to see if QA server is responding
- Check `~/Data/b8bz8z5a/qa-tool/reports/logs-preprod-avg.txt` for errors

**Permission denied:**
```bash
chmod +x ~/automation/src/workflows/*.sh
```
