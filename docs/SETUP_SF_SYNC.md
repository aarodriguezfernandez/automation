# Setting Up SF Exports Sync

## For Other Developers

### Quick Setup (5 minutes)

1. **Update your `.env` file:**

Add these two lines to your local `.env` file:

```bash
# SF Exports Nexcess Sync Configuration
NEXCESS_SF_HOST="a5c5b759_1@f5f43580ac.nxcli.io"
NEXCESS_SF_PATH="/home/a5c5b759/sf-exports"
```

2. **Verify SSH access:**

Test that you can connect to the Nexcess stage server:

```bash
ssh a5c5b759_1@f5f43580ac.nxcli.io "echo Connected successfully"
```

If this fails, you'll need SSH key access to the Nexcess stage server.

3. **Test the sync:**

Run a test sync to verify everything works:

```bash
# Test mode (shows what would happen without actually syncing)
./src/workflows/simple-qa-sf.sh --env preprod-avg --test

# Or test manual sync
./src/workflows/sync-sf-exports.sh pull
```

4. **Done!** 

Now when you run QA workflows, it will automatically:
- Pull latest sf-exports before starting (get team's baseline)
- Push your new exports after completion (share with team)

## Why This Matters

**Before:** You run QA, then I run QA → our numbers don't match because we're comparing against different baselines.

**After:** We both pull the same baseline from Nexcess before running QA → our numbers match!

## Daily Usage

### Normal QA Run (with sync)

```bash
# Just run as normal - sync happens automatically
./src/workflows/simple-qa-sf.sh --env preprod-avg
```

The script will:
1. 📥 Pull latest sf-exports from Nexcess (get baseline)
2. ▶️  Run your QA tests
3. 🕷️ Run SF crawls
4. 📤 Push new sf-exports to Nexcess (share results)

### Skip Sync (if needed)

```bash
# If you don't have Nexcess access yet or testing locally
./src/workflows/simple-qa-sf.sh --env preprod-avg --skip-sync
```

### Manual Sync Control

```bash
# Pull before QA
./src/workflows/sync-sf-exports.sh pull

# Push after QA
./src/workflows/sync-sf-exports.sh push

# Both
./src/workflows/sync-sf-exports.sh both
```

## File Size

The sf-exports directory is currently **~46MB**. Sync time over Nexcess network is typically 5-10 seconds.

## Troubleshooting

### "Permission denied" error

You need SSH key access to the Nexcess stage server. Contact the team lead to get your public key added to the server.

### "Nexcess not configured" message

Your `.env` file is missing the configuration. Add the two lines from step 1 above.

### Sync is too slow

You can skip it for local testing with `--skip-sync` flag.

### I don't want automatic sync

Use `--skip-sync` flag every time, or manually sync with the standalone script.

## Questions?

See [SF_EXPORTS_SYNC.md](SF_EXPORTS_SYNC.md) for full documentation.
