# Quick Start: SF Exports Sync

## ✅ Feature is LIVE on main branch

The sf-exports sync feature is now active in the QA workflow. Here's what you need to know:

## For You (Primary User)

**Nothing changes!** Just run your normal QA workflow:

```bash
./src/workflows/simple-qa-sf.sh --env preprod-avg
```

The workflow now automatically:
1. 📥 Pulls latest sf-exports from Nexcess before starting
2. 🔄 Runs QA/SF as normal
3. 📤 Pushes new sf-exports to Nexcess after completion

Your local `.env` already has the sync configuration set up.

## For Other Developers

### One-Time Setup (2 minutes)

1. **Pull latest code:**
   ```bash
   git pull origin main
   ```

2. **Add sync config to your `.env`:**
   
   If you don't have a `.env` file:
   ```bash
   cp .env.example .env
   ```
   
   Then add these two lines with **YOUR Nexcess username**:
   ```bash
   NEXCESS_SF_HOST="YOUR_NEXCESS_USER@f5f43580ac.nxcli.io"
   NEXCESS_SF_PATH="/home/a5c5b759/sf-exports"
   ```
   
   **Replace `YOUR_NEXCESS_USER` with your actual Nexcess SSH username.**
   
   Example: `NEXCESS_SF_HOST="john_doe_1@f5f43580ac.nxcli.io"`

3. **Test SSH access (with YOUR username):**
   ```bash
   ssh YOUR_NEXCESS_USER@f5f43580ac.nxcli.io "echo OK"
   ```
   
   Replace `YOUR_NEXCESS_USER` with your actual Nexcess username.
   
   - If it works without password → You're all set!
   - If it prompts for password → Enter it (you'll be prompted each time sync runs)
   - If it fails → Contact team lead for SSH access

4. **Done!** Run QA normally:
   ```bash
   ./src/workflows/simple-qa-sf.sh --env preprod-avg
   ```

## What This Solves

**Before:** Developer A runs QA, then Developer B runs QA → numbers don't match because they're comparing against different baseline data.

**After:** Both developers pull the same baseline from Nexcess before running QA → numbers match! 🎉

## Manual Sync Control

If you want to manually control the sync:

```bash
# Pull latest before running QA
./src/workflows/sync-sf-exports.sh pull

# Push your results after running QA
./src/workflows/sync-sf-exports.sh push

# Do both
./src/workflows/sync-sf-exports.sh both
```

## Skip Sync (if needed)

If you don't have SSH access yet or want to work offline:

```bash
./src/workflows/simple-qa-sf.sh --env preprod-avg --skip-sync
```

The workflow continues normally with local exports only.

## Files Synced

- **Size:** ~46MB
- **Location:** `/Users/YOUR_USER/automation/src/sf/sf-exports/`
- **Remote:** `a5c5b759_1@f5f43580ac.nxcli.io:/home/a5c5b759/sf-exports/`
- **Content:** Timestamped SF crawl directories with reports, CSVs, metrics

## Sync Speed

- **Pull:** ~5 seconds (when up to date, only transfers new files)
- **Push:** ~4 seconds (rsync only sends changed files)

## Troubleshooting

### "Permission denied"
- SSH access not configured
- Contact team lead to get your SSH key added
- Or use password authentication if you have credentials

### "Failed to pull/push"
- Check internet connection
- Verify .env has correct NEXCESS_SF_HOST and NEXCESS_SF_PATH
- Test SSH manually: `ssh a5c5b759_1@f5f43580ac.nxcli.io`

### "Connection timeout"
- Network issue or server down
- Workflow continues with local exports
- Try again later or use --skip-sync

## Documentation

- [SF_EXPORTS_SYNC.md](SF_EXPORTS_SYNC.md) - Full technical documentation
- [SETUP_SF_SYNC.md](SETUP_SF_SYNC.md) - Detailed setup guide with SSH key instructions

## Questions?

Ask the team lead or check the docs above!
