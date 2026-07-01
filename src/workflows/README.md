# QA + Screaming Frog Workflow

Simple unified workflow for QA testing and Screaming Frog crawls.

## Quick Start

```bash
cd ~/automation/src/workflows
./simple-qa-sf.sh --env preprod-avg --local
```

## What It Does

**Complete deployment workflow in one script:**

1. **Preprod Testing**
   - Starts QA tests (local or remote server)
   - Runs SF crawl (preprod)
   - Background watcher notifies when QA completes

2. **Deployment Prompt**
   - Reviews results
   - Prompts to deploy via Buddy
   - Waits for deployment confirmation

3. **Production Verification**
   - Runs SF crawl (LIVE production)
   - Runs SF crawl (STATIC production with /etc/hosts)

## Usage

### Basic Commands

```bash
# Full workflow (local testing)
./simple-qa-sf.sh --env preprod-avg --local

# Test mode (dry run)
./simple-qa-sf.sh --env preprod-avg --test --local

# Skip steps
./simple-qa-sf.sh --env preprod-avg --skip-sf --local    # QA only
./simple-qa-sf.sh --env preprod-avg --skip-qa            # SF only
```

### Flags

- `--env ENV` - QA environment (preprod-avg, stage-avg, prod-avg, preprod-pel, stage-pel, prod-pel)
- `--local` - Use local QA server (localhost:8884) - auto-starts if needed
- `--test` - Dry run mode (no execution)
- `--skip-qa` - Skip QA tests
- `--skip-sf` - Skip Screaming Frog
- `--help` - Show help

## Environments

| Environment   | Description         |
| ------------- | ------------------- |
| `preprod-avg` | Preprod Avigilon    |
| `stage-avg`   | Stage Avigilon      |
| `prod-avg`    | Production Avigilon |
| `preprod-pel` | Preprod Pelco       |
| `stage-pel`   | Stage Pelco         |
| `prod-pel`    | Production Pelco    |

## GChat Notifications

All notifications go to the GChat webhook configured in `.env`:

**Current:** `GCHAT_WEBHOOK_TEST` (testing - Yong and I)  
**Production:** `GCHAT_WEBHOOK` (VSA Websites QA)

**Notifications sent:**

- 🚀 QA Tests Started
- ✅ QA Tests Complete (with results)
- 🕷️ SF Crawl Started (preprod, LIVE, STATIC)
- ✅ SF Crawl Complete (preprod, LIVE, STATIC)

## Configuration

All configuration in `.env`:

```bash
# QA Server
QA_URL="http://50.28.85.146:8888"       # Remote server
QA_URL_LOCAL="http://localhost:8884"    # Local server
QA_USER="admin"
QA_PASS="..."

# GChat Webhooks
GCHAT_WEBHOOK_TEST="..."  # Currently active (testing)
GCHAT_WEBHOOK="..."       # Production (switch when ready)
```

## Output

Results saved to timestamped directories:

```
~/automation/src/workflows/runs/{env}-{timestamp}/
├── qa-stats.json         # QA test statistics (if available)
├── qa-last.json          # Full QA results (if available)
├── watcher.log           # QA completion watcher log
├── sf-output.log         # Preprod SF output
├── live-crawl.log        # LIVE SF output
└── static-crawl.log      # STATIC SF output
```

## Workflow Steps

### 1. Start Script

```bash
./simple-qa-sf.sh --env preprod-avg --local
```

### 2. Preprod Phase

- QA tests start (browser opens)
- SF crawl runs (interactive prompts)
- Script continues while QA runs in background

### 3. Deployment Phase

- **Prompt:** "Ready to deploy? [y/N]"
- Shows Buddy deployment instructions
- **Prompt:** "Press ENTER when deployment is complete..."

### 4. LIVE Production Phase

- **Prompt:** "Run LIVE production crawl? [y/N]"
- Runs sf-extract.sh (interactive - enter URL, choose options)

### 5. STATIC Production Phase

- **Prompt:** "Run STATIC production crawl? [y/N]"
- **Prompt:** "Have you configured /etc/hosts? [y/N]"
- Runs sf-extract.sh (interactive - select STATIC mode)
- Reminds to restore /etc/hosts

### 6. Complete

- Shows summary of all results
- QA completion notification arrives (background)

## Requirements

### 1. QA Server

For local testing, QA server must be running (script auto-starts):

```bash
cd ~/Data/b8bz8z5a/qa-tool
npm start
```

### 2. Screaming Frog

Installed at: `/Applications/Screaming Frog SEO Spider.app/`

### 3. Environment Variables

Set in `.env` (see Configuration section)

## Scripts

### Main Scripts

- **`simple-qa-sf.sh`** - Complete workflow (this is all you need)
- **`watch-qa-completion.sh`** - Background watcher for QA completion (auto-started)

### Supporting Scripts

Uses existing:

- `src/sf/sf-extract.sh` - Screaming Frog extraction (3x: preprod, LIVE, STATIC)

## Troubleshooting

**QA server not starting:**

```bash
# Check if running
curl http://localhost:8884

# Or use remote server (remove --local flag)
./simple-qa-sf.sh --env preprod-avg
```

**SF crawl fails:**

```bash
# Test sf-extract.sh directly
cd ~/automation
./src/sf/sf-extract.sh
```

**GChat notifications not arriving:**

- Check `GCHAT_WEBHOOK_TEST` in `.env`
- Verify webhook URL is correct

**Forgot to restore /etc/hosts:**

- Script reminds you after STATIC crawl
- Check `/etc/hosts` and remove static entries

## Examples

### Weekly QA Run (Avigilon)

```bash
# Monday morning
./simple-qa-sf.sh --env preprod-avg --local

# Review GChat notifications
# Deploy via Buddy if no issues
# Complete LIVE + STATIC verification
```

### Quick QA Check (No SF)

```bash
./simple-qa-sf.sh --env preprod-avg --skip-sf --local
```

### SF Only (No QA)

```bash
./simple-qa-sf.sh --env preprod-avg --skip-qa
```

### Test Before Running

```bash
./simple-qa-sf.sh --env preprod-avg --test --local
```

## Switching to Production GChat

When ready to send to team (after testing):

**Edit `.env` line 16:**

```bash
# Change from TEST to production
GCHAT_WEBHOOK="${GCHAT_WEBHOOK_PROD}"
```

Or manually update the URL.

---
