# Setting Up SF Exports Sync

## For Other Developers

### Quick Setup (5 minutes)

**Note:** SF sync is **OPTIONAL** but **REQUIRES SSH access** to Nexcess.
- **With SSH key:** Automatic (no password prompts)
- **With password:** You'll be prompted to enter password each time
- **Without SSH access:** Workflow skips sync if not configured

1. **Update your `.env` file:**

If you don't have a `.env` file yet:
```bash
cp .env.example .env
# Then edit .env and fill in your credentials
```

Add these two lines to your `.env` file with **YOUR Nexcess username**:

```bash
# SF Exports Nexcess Sync Configuration
NEXCESS_SF_HOST="YOUR_NEXCESS_USER@f5f43580ac.nxcli.io"
NEXCESS_SF_PATH="/home/a5c5b759/sf-exports"
```

**Important:** Replace `YOUR_NEXCESS_USER` with your actual Nexcess SSH username.

Example: If your username is `john_doe_1`, it would be:
```bash
NEXCESS_SF_HOST="john_doe_1@f5f43580ac.nxcli.io"
```

2. **Setup SSH access (REQUIRED for sync):**

The sync uses rsync over SSH. You can authenticate with:
- **SSH Key (recommended):** Automatic, no password prompts
- **Password:** You'll be prompted each time (works but slower)

**Option A: Test with existing credentials**

If you already have access, test it (replace YOUR_NEXCESS_USER):
```bash
ssh YOUR_NEXCESS_USER@f5f43580ac.nxcli.io "echo Connected successfully"
```

If prompted for password and it works, you're ready! The sync will prompt for password each time.

**Option B: Setup SSH key (recommended for automation)**

For automatic sync without password prompts:

a) Generate SSH key (if you don't have one):
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

b) Share your **public key** with team lead to add to Nexcess server:
```bash
cat ~/.ssh/id_ed25519.pub
# Or: cat ~/.ssh/id_rsa.pub
```

c) Once your key is added, test again (with YOUR username):
```bash
ssh YOUR_NEXCESS_USER@f5f43580ac.nxcli.io "echo Connected successfully"
```

**Without SSH access:**
- Sync is skipped if credentials aren't in .env
- Use `--skip-sync` flag to explicitly disable
- Workflow continues with local exports only

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
- **Or skip gracefully if SSH isn't configured**

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
