# QA Workflow Automation

Unified orchestration for QA testing and Screaming Frog crawls.

## Quick Start

```bash
# Dry run (safe, shows what would happen)
./qa-deploy-flow.sh --dry-run --env preprod-avg

# Real execution (no deployment)
./qa-deploy-flow.sh --env preprod-avg --no-deploy

# Full workflow with deployment option
./qa-deploy-flow.sh --env preprod-avg --allow-deploy
```

## Features

- ✅ Automated QA test execution (Playwright)
- ✅ Screaming Frog integration (manual for now)
- ✅ Unified report generation
- ✅ Google Chat notifications
- ✅ Deployment gate validation
- ✅ Timestamped output directories
- ✅ Dry-run mode for safe testing
- ✅ Automatic fallback (API → direct npm)

## Architecture

```
src/workflows/
├── qa-deploy-flow.sh       # Main orchestrator
├── lib/
│   ├── gchat.sh           # Google Chat notifications
│   ├── qa-client.sh       # QA tool integration
│   └── report-builder.sh  # Report generation & gates
└── runs/                   # Timestamped output directories
    └── {env}-{timestamp}/
        ├── qa-stats.json
        ├── qa-failed.txt
        ├── unified-report.txt
        └── sf-exports/
```

## Workflow Steps

1. **Validate** - Check environment variables
2. **QA Tests** - Run Playwright visual regression + accessibility
3. **Screaming Frog** - Crawl site for SEO/technical issues
4. **Collect Results** - Gather all outputs
5. **Generate Report** - Unified report with pass/fail gates
6. **Send Notification** - GChat webhook
7. **Evaluate Gates** - Check deployment blockers

## Deployment Gates

### Critical Blockers (prevent deployment)
- ❌ Internal 404s > 0
- ❌ QA failed tests > 5
- ❌ Critical accessibility violations > 0

### Warnings (review required)
- ⚠️  Missing meta descriptions > 10
- ⚠️  External 404s > 50
- ⚠️  Visual changes > 3

## Environment Variables

Required in `.env`:
```bash
# QA Tool
QA_TOOL_DIR="$HOME/Data/b8bz8z5a/qa-tool"
QA_SERVER_URL="http://localhost:8884"

# Screaming Frog
GCHAT_WEBHOOK="https://chat.googleapis.com/..."

# Environment configs
QA_ENVS="preprod-avg,stage-avg,prod-avg"
```

## Supported Environments

- `preprod-avg` - Pre-production Avigilon
- `stage-avg` - Staging Avigilon
- `prod-avg` - Production Avigilon
- `preprod-pel` - Pre-production Pelco
- `stage-pel` - Staging Pelco
- `prod-pel` - Production Pelco

## Output Structure

```
runs/preprod-avg-20260612-011500/
├── qa-stats.json          # Test statistics
├── qa-failed.txt          # Failed test list
├── qa-last.json           # Full test results
├── unified-report.txt     # Combined report
└── sf-exports/            # Screaming Frog data
    ├── *-report.txt
    └── *-metrics.json
```

## Integration with Existing Tools

### QA Tool Integration
- **Server Mode**: Uses HTTP API at `http://localhost:8884/run-tests`
- **Direct Mode**: Falls back to `npm run full:approve`
- **Auto-detect**: Checks if server is running, chooses best method

### Screaming Frog Integration
- **Current**: Manual execution via `src/sf/sf-extract.sh`
- **Future**: Automated non-interactive mode

## Safety Features

- **No deploy by default**: `--no-deploy` flag prevents accidental deployments
- **Dry-run mode**: Test workflow without executing
- **Error handling**: `set -euo pipefail` for bash safety
- **Timestamped outputs**: Never overwrite previous runs
- **User confirmations**: Required for destructive operations

## Troubleshooting

**QA server not running:**
```
⚠️  QA server is not running
   Falling back to direct execution
```
Solution: Start QA server with `cd ~/Data/b8bz8z5a/qa-tool && npm start`

**Missing GChat webhook:**
```
⚠️  GCHAT_WEBHOOK not set - skipping notification
```
Solution: Add `GCHAT_WEBHOOK` to `.env` file

**Permission denied:**
```bash
chmod +x src/workflows/qa-deploy-flow.sh
chmod +x src/workflows/lib/*.sh
```

## Future Enhancements

- [ ] Automated Screaming Frog execution
- [ ] Parallel QA + SF execution
- [ ] Jira ticket auto-creation from failures
- [ ] Buddy API deployment integration
- [ ] Historical metrics tracking
- [ ] Email notifications
- [ ] Cron scheduling
- [ ] Web dashboard

## Examples

### Pre-deployment Check
```bash
# Run full checks before deploying
./qa-deploy-flow.sh --env preprod-avg --no-deploy

# If gates pass, manually deploy on Buddy
# Then run post-deployment verification
```

### Post-deployment Verification
```bash
# Verify production after deploy
./qa-deploy-flow.sh --env prod-avg --no-deploy
```

### Weekly QA Runs
```bash
# Run twice per week for all environments
for env in preprod-avg stage-avg prod-avg; do
  ./qa-deploy-flow.sh --env $env --no-deploy
done
```

## Support

Issues or questions? Check:
- [QA Tool Repo](https://github.com/aarodriguezfernandez/qa-tool)
- [Automation Repo](https://github.com/aarodriguezfernandez/automation)
