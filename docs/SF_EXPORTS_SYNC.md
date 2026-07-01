# SF Exports Sync Feature

## Overview

The sf-exports sync feature ensures all developers work from the same baseline data when running QA workflows. This prevents number mismatches between different QA runs.

**Problem solved:** When Developer A runs QA and then Developer B runs QA, their numbers won't match unless they're using the same baseline sf-exports data.

**Solution:** Automatically sync sf-exports to/from Nexcess stage server before and after QA runs.

## Configuration

### 1. Main Configuration (.env)

Add these variables to your `.env` file:

```bash
# SF Exports Nexcess Sync Configuration
# Default to Avigilon stage server for sf-exports sync
# Size: ~46MB (reasonable for rsync)
# Other developers pull before QA to ensure consistent baselines
NEXCESS_SF_HOST="a5c5b759_1@f5f43580ac.nxcli.io"
NEXCESS_SF_PATH="/home/a5c5b759/sf-exports"
```

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

2. **After SF crawls complete:** Pushes new exports to Nexcess
   - Shares your fresh results with the team
   - Becomes the new baseline for next developer

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

## Server Location

**Target:** Nexcess Stage Server (Avigilon)
- **Server:** f5f43580ac.nxcli.io
- **User:** a5c5b759_1
- **Path:** /home/a5c5b759/sf-exports
- **Why stage?** Most accessible for all developers, stable environment

## Troubleshooting

### Sync fails with "Permission denied"

Ensure your SSH key is set up for the Nexcess server:

```bash
# Test SSH connection
ssh a5c5b759_1@f5f43580ac.nxcli.io "echo Connection successful"
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

1. ✅ **Consistent baselines** - All devs compare against same data
2. ✅ **No manual steps** - Automatic pull/push in workflow
3. ✅ **Version history** - Timestamped directories preserve history
4. ✅ **Team collaboration** - Share results automatically
5. ✅ **No conflicts** - Timestamped directories don't collide

## Related Files

- [simple-qa-sf.sh](../src/workflows/simple-qa-sf.sh) - Main QA workflow with integrated sync
- [sync-sf-exports.sh](../src/workflows/sync-sf-exports.sh) - Standalone sync script
- [.env](../.env) - Configuration variables
- [.env.servers](../.env.servers) - Server details (both sites)
- [get-static-info.sh](../src/sf/get-static-info.sh) - Now uses .env.servers variables
