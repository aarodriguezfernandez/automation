# Setup Guide - QA + Screaming Frog Workflow

Simple setup guide for new developers.

## Prerequisites

1. **Screaming Frog SEO Spider**
   - Download from: https://www.screamingfrogseospider.com/
   - Install to: `/Applications/Screaming Frog SEO Spider.app/`
   - License required for full functionality

2. **Basic Tools**
   - `jq` - JSON processor
   - `curl` - HTTP client
   - Git

## Installation

### 1. Clone Repository

```bash
git clone <repository-url>
cd automation
```

### 2. Configure Environment

Copy and edit `.env`:

```bash
# Create .env if it doesn't exist
cp .env.example .env  # Or create from scratch

# Edit .env
nano .env
```

**Required configuration:**

```bash
# QA Server (remote)
QA_URL="http://50.28.85.146:8888"
QA_USER="admin"
QA_PASS="your-password-here"

# GChat Webhook (testing)
GCHAT_WEBHOOK_TEST="your-test-webhook-url"

# GChat Webhook (production) 
GCHAT_WEBHOOK="your-production-webhook-url"
```

**Ask your team lead for:**
- QA server credentials (`QA_USER`, `QA_PASS`)
- GChat webhook URLs

### 3. Make Scripts Executable

```bash
chmod +x src/workflows/simple-qa-sf.sh
chmod +x src/workflows/watch-qa-completion.sh
chmod +x src/sf/sf-extract.sh
```

### 4. Test Installation

```bash
cd src/workflows

# Test mode (dry run - safe to run)
./simple-qa-sf.sh --env preprod-avg --test
```

You should see:
- Test workflow output
- GChat test notification (if webhook configured)

## Usage

### Basic Workflow

```bash
cd automation/src/workflows

# Full workflow (without local QA)
./simple-qa-sf.sh --env preprod-avg
```

**What happens:**
1. QA tests start on remote server
2. SF crawl runs (preprod) - interactive prompts
3. You're prompted to deploy via Buddy
4. LIVE production SF crawl
5. STATIC production SF crawl

### Important Flags

```bash
# Test mode (dry run)
./simple-qa-sf.sh --env preprod-avg --test

# Skip QA tests (SF only)
./simple-qa-sf.sh --env preprod-avg --skip-qa

# Skip SF crawl (QA only)
./simple-qa-sf.sh --env preprod-avg --skip-sf
```

### Available Environments

- `preprod-avg` - Preprod Avigilon
- `preprod-pel` - Preprod Pelco
- `stage-avg` - Stage Avigilon
- `stage-pel` - Stage Pelco
- `prod-avg` - Production Avigilon
- `prod-pel` - Production Pelco

## Local QA Tool (Optional)

**Note:** `--local` flag is for developers who have the qa-tool project locally.

**If you don't have qa-tool locally:**
- **Don't use** the `--local` flag
- Script will use remote QA server automatically

**If you have qa-tool locally:**
```bash
# The script will auto-start local server if needed
./simple-qa-sf.sh --env preprod-avg --local
```

## GChat Notifications

All notifications go to the configured webhook in `.env`.

**During testing:**
- Use `GCHAT_WEBHOOK_TEST` 
- Notifications go to test space

**For production:**
- Switch to `GCHAT_WEBHOOK`
- Edit line in `.env` or ask team lead

## Screaming Frog Interactive Mode

When SF runs, you'll see prompts:

```
1) Use existing crawl
2) Run new crawl

Select option:
```

**For new crawl:**
- Choose option 2
- Enter URL (e.g., https://preprod.avigilon.com)
- Choose crawl type (Live/Static)

**For existing crawl:**
- Choose option 1
- Select from list

## Common Tasks

### Weekly QA Run

```bash
cd automation/src/workflows

# 1. Run preprod check
./simple-qa-sf.sh --env preprod-avg

# 2. Review GChat notifications
# 3. Deploy via Buddy (if approved)
# 4. Complete LIVE + STATIC verification (prompts in script)
```

### Quick SF Crawl Only

```bash
./simple-qa-sf.sh --env preprod-avg --skip-qa
```

### Test Before Running

```bash
./simple-qa-sf.sh --env preprod-avg --test
```

## Troubleshooting

### Issue: QA Server Connection Failed

**Solution:**
- Check QA_URL in `.env`
- Verify credentials (QA_USER, QA_PASS)
- Contact team if server is down

### Issue: Screaming Frog Not Found

**Solution:**
- Install Screaming Frog to `/Applications/`
- Check path: `/Applications/Screaming Frog SEO Spider.app/`

### Issue: GChat Notifications Not Arriving

**Solution:**
- Check `GCHAT_WEBHOOK_TEST` in `.env`
- Verify webhook URL with team
- Test with curl:
  ```bash
  curl -X POST -H "Content-Type: application/json" \
    -d '{"text":"Test"}' \
    "$GCHAT_WEBHOOK_TEST"
  ```

### Issue: Permission Denied

**Solution:**
```bash
chmod +x src/workflows/*.sh
chmod +x src/sf/*.sh
```

## Getting Help

**Documentation:**
- Main workflow: `src/workflows/README.md`
- SF extract: `src/sf/` documentation

**Ask your team:**
- QA server credentials
- GChat webhook URLs
- Buddy deployment access
- Any environment-specific details

## File Structure

```
automation/
├── .env                        # Configuration (you create this)
├── SETUP.md                    # This file
├── src/
│   ├── workflows/
│   │   ├── README.md           # Detailed workflow docs
│   │   ├── simple-qa-sf.sh     # Main workflow script
│   │   └── watch-qa-completion.sh
│   └── sf/
│       └── sf-extract.sh       # SF extraction script
```

## Quick Reference

```bash
# Test installation
./simple-qa-sf.sh --env preprod-avg --test

# Full workflow
./simple-qa-sf.sh --env preprod-avg

# QA only
./simple-qa-sf.sh --env preprod-avg --skip-sf

# SF only
./simple-qa-sf.sh --env preprod-avg --skip-qa
```

## Next Steps

1. ✅ Install Screaming Frog
2. ✅ Configure `.env`
3. ✅ Run test mode
4. ✅ Try a real workflow (preprod)
5. ✅ Ask team lead about production access

---

**Simple. Clean. Ready to use.**
