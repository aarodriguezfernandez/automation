# SF Exports Sync Feature

## Overview

The sf-exports sync feature ensures all developers work from the same baseline data when running QA workflows. This prevents number mismatches between different QA runs.

**Problem solved:** When Developer A runs QA and then Developer B runs QA, their numbers won't match unless they're using the same baseline sf-exports data.

**Solution:** Automatically sync sf-exports to/from Nexcess stage server before and after QA runs.

## Configuration

### 1. Main Configuration (.env)

Add these variables to your `.env` file with **YOUR Nexcess username**:

```bash
# SF Exports Nexcess Sync Configuration
# Size: ~46MB (reasonable for rsync)
# Other developers pull before QA to ensure consistent baselines
# IMPORTANT: Use YOUR own Nexcess SSH username
NEXCESS_SF_HOST="YOUR_NEXCESS_USER@f5f43580ac.nxcli.io"
NEXCESS_SF_PATH="/home/a5c5b759/sf-exports"
```

Replace `YOUR_NEXCESS_USER` with your actual Nexcess SSH username.

### 2. Server Details (.env.servers)

Server configuration is stored in `.env.servers` (created automatically). This file contains:
- Avigilon stage server details
- Pelco stage server details
- SF exports sync path

**Note:** The `.env.servers` file should be committed to version control (without sensitive data) or shared among team members.

## How It Works

### Automatic Sync in simple-qa-sf.sh

1. **Before QA runs:** Pulls latest sf-exports from Nexcess
   - Ensures you start with team's most recent baseline
   - Your QA results will be comparable with others
   - Uses `--delete` to mirror exactly (removes old exports)

2. **After EVERY QA run:** Pushes new exports to Nexcess
   - Happens even if you run with `--skip-sf`
   - Shares your fresh results with the team
   - Uses `--delete` to mirror exactly (removes old exports from server)
   - Becomes the new baseline for next developer
   
**Important:** The push runs after every QA run (not just SF crawls) to keep the team in sync even when running different environments (e.g., preprod-avg vs preprod-pel).

### Workflow Visualization

```
Developer A:
  1. Pull sf-exports from Nexcess (gets baseline)
  2. Run QA workflow
  3. Push new sf-exports to Nexcess (shares results)

Developer B:
  1. Pull sf-exports from Nexcess (gets Dev A's baseline)
  2. Run QA workflow (numbers match Dev A's baseline)
  3. Push new sf-exports to Nexcess (becomes new baseline)
```

## Usage

### Option 1: Automatic (integrated in simple-qa-sf.sh)

The sync happens automatically when you run the QA workflow:

```bash
# Normal usage - sync enabled by default
./src/workflows/simple-qa-sf.sh --env preprod-avg

# Skip sync if needed (for testing without credentials)
./src/workflows/simple-qa-sf.sh --env preprod-avg --skip-sync

# Test mode (shows what would be synced)
./src/workflows/simple-qa-sf.sh --env preprod-avg --test
```

### Option 2: Manual sync (standalone script)

Use the standalone script for manual control:

```bash
# Pull latest exports before running QA
./src/workflows/sync-sf-exports.sh pull

# Push your new exports after running QA
./src/workflows/sync-sf-exports.sh push

# Sync both ways (pull first, then push)
./src/workflows/sync-sf-exports.sh both
```

## File Size

- **Current size:** ~46MB
- **Reasonable for rsync:** Yes, syncs quickly over network
- **Contains:** Timestamped crawl directories with HTML, reports, and metadata
- **Cleanup:** Old exports are automatically removed via `--delete` flag

## How --delete Works

The sync uses `rsync --delete` to ensure exact mirroring:

**On Pull:**
- Your local `sf-exports/` becomes exact copy of Nexcess
- Old local exports not on Nexcess are deleted
- Prevents accumulation of stale local data

**On Push:**
- Nexcess becomes exact copy of your local `sf-exports/`
- Old exports on Nexcess not in your local are deleted
- Team always gets your current state, not accumulated history

This means the shared directory only contains the latest exports from whoever pushed last.

## Server Location

**Target:** Nexcess Stage Server (Avigilon)
- **Server:** f5f43580ac.nxcli.io
- **User:** YOUR_NEXCESS_USER (each developer has their own username)
- **Path:** /home/a5c5b759/sf-exports (shared directory, same for everyone)
- **Why stage?** Most accessible for all developers, stable environment

## Troubleshooting

### Sync fails with "Permission denied"

Ensure your SSH key is set up for the Nexcess server (use YOUR username):

```bash
# Test SSH connection (replace YOUR_NEXCESS_USER)
ssh YOUR_NEXCESS_USER@f5f43580ac.nxcli.io "echo Connection successful"
```

### Skip sync for local testing

Use the `--skip-sync` flag:

```bash
./src/workflows/simple-qa-sf.sh --env preprod-avg --skip-sync
```

### Variables not loaded

1. Check `.env` file exists and contains `NEXCESS_SF_HOST` and `NEXCESS_SF_PATH`
2. Verify `.env.servers` file exists (created automatically)
3. Run in test mode to see configuration: `--test`

## Benefits

1.  **Consistent baselines** - All devs compare against same data
2.  **No manual steps** - Automatic pull/push in workflow
3.  **Version history** - Timestamped directories preserve history
4.  **Team collaboration** - Share results automatically
5.  **No conflicts** - Timestamped directories don't collide

## Related Files

- [simple-qa-sf.sh](../src/workflows/simple-qa-sf.sh) - Main QA workflow with integrated sync
- [sync-sf-exports.sh](../src/workflows/sync-sf-exports.sh) - Standalone sync script
- [.env](../.env) - Configuration variables
- [.env.servers](../.env.servers) - Server details (both sites)
- [get-static-info.sh](../src/sf/get-static-info.sh) - Now uses .env.servers variables
