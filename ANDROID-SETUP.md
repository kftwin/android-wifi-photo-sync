# Android Phone Backup — Setup Guide

This guide walks through everything needed on your Android phone to back up automatically to your Windows PC whenever you're home on the same WiFi network.

**What gets backed up:**
| Category | App used | Destination on PC |
|---|---|---|
| Photos | Syncthing-Fork | `H:\android-backup\Camera` |
| Screenshots | Syncthing-Fork | `H:\android-backup\Screenshots` |
| Downloads | Syncthing-Fork | `H:\android-backup\Downloads` |
| Documents + app/SMS exports | Syncthing-Fork | `H:\android-backup\Documents` |
| Signal messages | Syncthing-Fork | `H:\android-backup\Signal` |
| WhatsApp messages | Syncthing-Fork (SAF) | `H:\android-backup\WhatsApp` |
| App data + APKs | Swift Backup | `H:\android-backup\Documents\SwiftBackup` |
| SMS/MMS | SMS Backup & Restore | `H:\android-backup\Documents\SMS-Backup` |

**Before you start:** Run `setup-windows.ps1` on your PC first.

---

## Part 1 — Syncthing-Fork Setup

### Step 1: Install Syncthing-Fork

Install from one of:
- **Google Play Store**: search "Syncthing-Fork" (by Catfriend1) — [play.google.com](https://play.google.com/store/apps/details?id=com.github.catfriend1.syncthingandroid)
- **F-Droid**: search "Syncthing-Fork" — preferred if you have F-Droid installed

> The original "Syncthing" app from the Play Store is unmaintained. Make sure you install **Syncthing-Fork** by Catfriend1.

### Step 2: Grant permissions

On first launch, Syncthing-Fork will ask for:
- **Storage access** — tap Allow
- **Run in background / notification** — tap Allow

### Step 3: Disable battery optimization (CRITICAL)

Without this, Android will kill Syncthing when your screen is off and sync will stop working.

1. Open **Android Settings**
2. Go to **Apps** → find **Syncthing-Fork**
3. Tap **Battery**
4. Select **Unrestricted** (not "Optimized" or "Restricted")

> On some phones this is under **Battery & performance** → **App battery saver** → set to **No restrictions**.

Syncthing-Fork will also show a persistent notification banner prompting you to fix this — tap it if you see it.

---

## Part 2 — Add Syncthing Shared Folders

### Step 4: Add the five standard folders

For each folder below:
1. In Syncthing-Fork, tap the **+** button (or "Add Folder")
2. Set **Folder Path** to the path listed below — tap the folder icon to browse if needed
3. Set **Folder Type** to **Send Only**
4. Tap Save

> ⚠️ **Send Only is critical.** If you accidentally select "Send & Receive", files from your PC could sync back to your phone. Double-check each folder.

| Folder label | Path on Android |
|---|---|
| Camera | `/storage/emulated/0/DCIM/Camera` |
| Screenshots | `/storage/emulated/0/DCIM/Screenshots` |
| Downloads | `/storage/emulated/0/Download` |
| Documents | `/storage/emulated/0/Documents` |
| Signal | See note below |

> **Note on Signal (newer versions):** Signal no longer auto-creates a fixed backup folder. When you enable backups in Part 4, Signal's file picker will ask you to choose a folder. Choose `Downloads/Signal-Backups/` (create it if it doesn't exist). Then come back and set this Syncthing folder path to `/storage/emulated/0/Download/Signal-Backups`. You can add the Syncthing folder before or after enabling Signal backups — just make sure the paths match.

### Step 5: Add the WhatsApp folder (Android Special Folder)

WhatsApp stores its backup in a restricted folder (`Android/media/...`) that normal apps can't access. Syncthing-Fork has a special mode for this.

1. In Syncthing-Fork, tap **+** → **Add Folder**
2. Scroll down to find **Android Special Folder** (or look for a "Use SAF" toggle)
3. Tap **Select via system picker** — the Android folder picker opens
4. Navigate to: `Internal Storage` → `Android` → `media` → `com.whatsapp` → `WhatsApp` → `Backups`
5. Tap **Use this folder** (or the folder itself depending on your Android version)
6. Grant Syncthing-Fork permission when prompted
7. Set **Folder Type** to **Send Only**
8. Set **Folder Label** to `WhatsApp`
9. Tap Save

> If you can't see `Android/media` in the picker, try a file manager app (e.g. Files by Google) to confirm WhatsApp has created its backup folder. You may need to complete Part 5 (enabling WhatsApp backup) first, then return here.

---

## Part 3 — Pair with Your Windows PC

### Step 6: Get your Windows Syncthing device ID

On your Windows PC:
1. Open a browser and go to **http://127.0.0.1:8384**
2. In the Syncthing web UI, click **Actions** (top right) → **Show ID**
3. A QR code and a long device ID string appear — keep this open

### Step 7: Add the Windows PC as a device in Syncthing-Fork

On your Android phone:
1. In Syncthing-Fork, tap the **Devices** tab
2. Tap **+** to add a new device
3. Either:
   - Tap the QR icon and scan the QR code from your PC screen
   - Or tap **Manual** and paste/type the device ID from your PC
4. Set a name like `Home PC`
5. Tap Save

### Step 8: Accept the device on your PC

On your Windows PC:
1. The Syncthing web UI at **http://127.0.0.1:8384** will show a popup: _"New Device wants to connect"_
2. Click **Add Device** → give it a name like `Android Phone` → click Save

### Step 9: Share your folders with the PC

On your Android phone, for each folder you added:
1. Open the folder in Syncthing-Fork
2. Tap **Share With** → select `Home PC`
3. Tap Save

### Step 10: Accept each folder share on your PC

On your Windows PC, for each of the six folders:
1. A popup appears in the Syncthing web UI: _"Android Phone wants to share folder X"_
2. Click **Add** on the popup
3. In the dialog:
   - Set **Folder Type** to **Receive Only**
   - Set **Folder Path** to the matching path below
4. Click Save

| Folder label | PC path |
|---|---|
| Camera | `H:\android-backup\Camera` |
| Screenshots | `H:\android-backup\Screenshots` |
| Downloads | `H:\android-backup\Downloads` |
| Documents | `H:\android-backup\Documents` |
| Signal | `H:\android-backup\Signal` (or skip — Signal backups land in Downloads if you used Downloads/Signal-Backups) |
| WhatsApp | `H:\android-backup\WhatsApp` |

> After saving, Syncthing will start syncing. The status bar on both devices will show progress.

### Step 11: Verify sync is working

1. Wait 2–3 minutes after completing Step 10
2. On your PC, open `H:\android-backup\Camera`
3. You should see photos from your phone's camera roll appearing

If you don't see files after 5 minutes:
- Check that both devices are on the same WiFi network
- Check that Syncthing is running on the PC (`check-sync-status.ps1`)
- Check the Syncthing-Fork notifications on your phone

### Step 12: Apply staggered versioning (run on PC)

After pairing, run this in PowerShell on your PC to enable 365-day versioning on all backup folders:

```powershell
# Stop Syncthing briefly, patch config, restart
Stop-ScheduledTask -TaskName Syncthing
# Re-run the versioning patcher from setup-windows.ps1:
. .\setup-windows.ps1   # dot-source to load functions
Set-StaggeredVersioning
Start-ScheduledTask -TaskName Syncthing
```

> Versioned files that are deleted on your phone will be kept in `H:\android-backup\<folder>\.stversions\` for 365 days rather than being permanently deleted.

---

## Part 4 — Signal Message Backup

### Step 13: Enable Signal local backups

1. Open **Signal** → tap your profile icon (top left) → **Chats**
2. Tap **Chat Backups**
3. Toggle **Enable Backups** on
4. Signal will show a **30-digit backup passphrase** — this is critical

> ⚠️ **Save your Signal passphrase now.** Without it, your backup file is permanently unreadable. Copy it into your password manager (Bitwarden, 1Password, etc.) before leaving this screen.

5. Signal will show a **folder picker** — navigate to `Downloads/Signal-Backups/` and tap **Use this folder**
   - Create `Signal-Backups` inside `Downloads` first if it doesn't exist (you can do this in any file manager)
6. Set backup frequency to **Daily**
7. Tap **Create Backup** to create the first backup immediately

Signal writes its backup to whatever folder you chose (step 5). If you chose `Downloads/Signal-Backups/`, Syncthing's Downloads folder will pick it up automatically. Alternatively, add a dedicated `Signal` Syncthing folder pointing to `/storage/emulated/0/Download/Signal-Backups/`.

---

## Part 5 — WhatsApp Message Backup

### Step 14: Enable WhatsApp local backup

1. Open **WhatsApp** → tap ⋮ (three dots, top right) → **Settings** → **Chats**
2. Tap **Chat backup**
3. Under **Back up to Google Drive**, set to **Never** (removes Google dependency)
4. Under **Back up to local storage**, set frequency to **Daily**
5. Tap **Back Up Now** to create the first backup immediately

After the backup completes, a `.crypt15` file appears in WhatsApp's backup folder. Syncthing-Fork's Android Special Folder picks this up on the next sync cycle and copies it to `H:\android-backup\WhatsApp\`.

---

## Part 6 — SMS Backup

### Step 15: Install and configure SMS Backup & Restore

1. Install **SMS Backup & Restore** (by SyncTech) from the Play Store
2. Open the app → grant SMS and storage permissions
3. Tap **Set Up A Backup** (or the three-dot menu → **Settings**)
4. Under **Backup location**, select **Local Backup** → browse to `/storage/emulated/0/Documents/SMS-Backup/`
   - If the folder doesn't exist, create it
5. Enable **Automatic Backups** → set schedule to **Daily**
6. Under **Back up**, check both **SMS** and **MMS**
7. Tap **Back Up Now** to run the first backup immediately

The XML backup files land in `Documents/SMS-Backup/`, which Syncthing's Documents folder picks up automatically — no extra configuration needed.

---

## Part 7 — App Data Backup (Swift Backup)

### Step 16: Install and configure Swift Backup

1. Install **Swift Backup** from the Play Store
2. Open the app → grant storage and notification permissions
3. Tap **Settings** (gear icon)
4. Set **Backup Location** to `/storage/emulated/0/Documents/SwiftBackup/`
5. Return to the main screen → tap **Backup** → select **Apps + Data**
6. Tap **Start Backup** to run the first backup

Swift Backup exports APKs and app data (for apps that allow it without root) into `Documents/SwiftBackup/`. This gets synced to `H:\android-backup\Documents\SwiftBackup\` through the Documents Syncthing folder automatically.

### Step 17: Schedule Swift Backup

1. In Swift Backup → **Settings** → **Schedule**
2. Set to run **Nightly** while **charging** and on **WiFi**
3. This ensures a fresh backup is always available without any manual steps

### Note: Apps that won't fully restore

Some apps opt out of Android's backup API. These include most banking apps, some games, and a few social apps. For these:
- The **APK** (app installer) is still backed up by Swift Backup — you can reinstall the app from it
- But **app data** (login state, settings, game progress) will be lost and must be re-entered after reinstall

This is an Android OS restriction, not a limitation of Swift Backup.

---

## Part 8 — Versioned File Recovery

Syncthing keeps deleted files in `.stversions` folders for 365 days.

If you accidentally deleted a file and need it back:
1. On your PC, navigate to `H:\android-backup\<folder>\.stversions\`
2. Files are organized by date — find the version you need
3. Copy it back to the main folder

Example: deleted photo from Camera → look in `H:\android-backup\Camera\.stversions\`

---

## Part 9 — Restore After Factory Reset

Use this section when you reformat your phone or get a new device.

### Restore order (IMPORTANT — follow this sequence)

**Step A — WhatsApp (do this BEFORE completing WhatsApp setup)**
1. Connect phone to PC via USB — copy `H:\android-backup\WhatsApp\` to `/sdcard/WhatsApp/Backups/`
   - Or create a mobile hotspot, start Syncthing on PC, allow Syncthing-Fork after install to sync the WhatsApp folder
2. Install WhatsApp from Play Store
3. During WhatsApp setup, when prompted **"Restore backup?"** → tap **Restore**
4. Complete phone number verification

> ⚠️ If you complete WhatsApp registration without restoring first, your message history cannot be recovered without additional technical workarounds. Get the backup file in place before finishing setup.

**Step B — Signal (during Signal first-launch)**
1. Install Signal from Play Store
2. On first launch, tap **Transfer or Restore Account** → **Restore Backup**
3. Browse to the restored Signal backup file (copy from `H:\android-backup\Signal\` via USB first)
4. Enter your 30-digit passphrase from your password manager
5. Complete phone number verification — all messages and attachments restore

**Step C — Files (Camera, Screenshots, Downloads, Documents)**
1. Connect phone to PC via USB
2. Copy folders from `H:\android-backup\` back to your phone's storage
3. Or: set up Syncthing-Fork first (repeat Part 1–3), let it sync — files flow back automatically since the PC is Receive Only and won't delete source data

**Step D — Apps (Swift Backup)**
1. Install Swift Backup from Play Store (or from the APK in `Documents/SwiftBackup/`)
2. Open Swift Backup → **Restore** → point to `Documents/SwiftBackup/`
3. Restore apps one at a time — re-grant any special permissions (accessibility, notification access, etc.) after each restore
4. Banking apps and other opted-out apps reinstall but require re-login

**Step E — SMS**
1. Install SMS Backup & Restore from Play Store
2. Open app → **Restore** → browse to `Documents/SMS-Backup/`
3. Select the most recent XML backup → tap Restore
4. All SMS and MMS messages are imported into your default messaging app

---

## Troubleshooting

**Sync stopped working after a few days**
- Check battery optimization — Android may have reset it. Re-apply Step 3.
- Open Syncthing-Fork → check for any error banners

**WhatsApp folder not appearing in folder picker**
- WhatsApp must create at least one backup first (Step 14) before the folder exists
- Try a full file manager app to verify the path: `Android/media/com.whatsapp/WhatsApp/Backups/`

**Files not appearing in `H:\android-backup\` on the PC**
- Run `check-sync-status.ps1` on the PC to see if Syncthing is running and if folders show completion
- Verify both devices are on the same WiFi SSID (not one on 2.4GHz guest and the other on 5GHz)

**Signal backup folder is empty**
- Signal backup is NOT enabled by default. Complete Step 13.
