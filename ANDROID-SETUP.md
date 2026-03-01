# Android Phone Backup — Complete Setup Guide

This guide sets up automatic, wireless backups from your Android phone to your Windows PC.
Once done, everything runs hands-free whenever your phone is home on WiFi.

**What gets backed up:**
| Category | Where it ends up on your PC |
|---|---|
| Photos & screenshots | `C:\android-backup\Photos` |
| Downloads | `C:\android-backup\Downloads` |
| Documents | `C:\android-backup\Documents` |
| Signal messages | `C:\android-backup\Signal` |
| WhatsApp messages | `C:\android-backup\WhatsApp` |
| App data (Swift Backup) | `C:\android-backup\Documents\SwiftBackup` |
| SMS/MMS (SMS Backup & Restore) | `C:\android-backup\Documents\SMS-Backup` |

> This guide uses `C:\android-backup` as the backup location. You can change this during setup if you prefer a different drive or folder.

---

## Before You Start

You need to complete the **Windows PC setup first**, before touching your phone.

### Run the Windows setup script

**On your PC:**

1. **Download the files:** Go to [github.com/kftwin/android-wifi-photo-sync](https://github.com/kftwin/android-wifi-photo-sync), click the green **Code** button, then click **Download ZIP**
2. **Extract the ZIP:** Right-click the downloaded file → **Extract All** → choose a location like `C:\android-wifi-photo-sync` → click **Extract**
3. Click the **Start menu** and search for **PowerShell**
4. Right-click **Windows PowerShell** → click **Run as administrator**
5. A blue terminal window opens. Type the following and press Enter — replace the path if you extracted to a different folder:
   ```
   cd "C:\android-wifi-photo-sync"
   ```
6. Then run the script:
   ```
   .\setup-windows.ps1
   ```
7. If Windows blocks the script with a security warning, run this first, then try step 6 again:
   ```
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
8. The script installs Syncthing, creates `C:\android-backup` with all backup subfolders, sets up firewall rules, and starts Syncthing automatically. It prints `[OK]` for each step.
9. When it finishes, open your browser and go to **http://127.0.0.1:8384** — you should see the Syncthing web interface. Leave this tab open.

> **Want to save backups to a different drive?** Run the script like this instead:
> ```
> .\setup-windows.ps1 -BackupRoot "D:\Phone-Backup"
> ```
> Use any drive letter and folder name you like. Substitute your path wherever this guide shows `C:\android-backup`.

> If you see a red error about "not running as administrator", close PowerShell and repeat from step 3, making sure to right-click and choose "Run as administrator".

---

## Part 1 — Install Syncthing on Your Phone

### Step 1: Install Syncthing-Fork

**On your phone:**

1. Open the **Google Play Store**
2. Search for **Syncthing-Fork**
3. Install the app by **Catfriend1** — the icon is a pair of arrows in a circle

> The original "Syncthing" app on Play Store is no longer maintained. You specifically need **Syncthing-Fork** by Catfriend1.

### Step 2: Grant permissions

**On your phone:**

1. Open **Syncthing-Fork**
2. When it asks for **Storage access** → tap **Allow**
3. When it asks for **Notifications / run in background** → tap **Allow**
4. If you see a banner saying "Fix battery optimization" — tap it and follow the prompt (or continue to Step 3)

### Step 3: Disable battery optimization

This is the most important phone setting. Without it, Android will kill Syncthing in the background and your phone will stop syncing.

**On your phone:**

1. Open the **Settings** app
2. Tap **Apps**
3. Scroll down and tap **Syncthing-Fork**
4. Tap **Battery**
5. Select **Unrestricted**

> The option may be labeled differently on your phone: look for **"No restrictions"**, **"Unrestricted"**, or **"Don't optimize"**. Avoid "Optimized" and "Restricted".

Also do this:

6. While still in **Settings → Apps → Syncthing-Fork**, tap **Mobile data**
7. Turn on **Allow background data usage** (some phones tie background WiFi activity to this setting)

Finally, remove Syncthing-Fork from any sleeping apps list:

8. Go to **Settings → Device Care → Battery → Background usage limits**
9. Check the **Sleeping apps** and **Deep sleeping apps** lists
10. If Syncthing-Fork appears in either list, tap it and remove it

---

## Part 2 — Add Your Backup Folders in Syncthing-Fork

You're going to tell Syncthing-Fork which folders on your phone to watch and sync to your PC.

### Step 4: Add your Photos folder

**On your phone:**

1. Open **Syncthing-Fork**
2. Tap the **Folders** tab at the bottom
3. Tap the **+** button (or "Add Folder")
4. Tap the folder icon next to **Folder Path** to browse
5. Navigate to: **Internal Storage → DCIM → Camera**
6. Tap **Use this folder**
7. Set **Folder Label** to `Photos`
8. Scroll down to **Folder Type** → set it to **Send Only**
9. Tap **Save**

> **Send Only is critical.** This ensures data flows from your phone to your PC only — never the other way. If you choose "Send & Receive", files on your PC could be deleted if they're not on your phone.

> You can combine Camera and Screenshots into one folder, or keep them separate. To add Screenshots separately, repeat this step pointing to `DCIM/Screenshots` and label it `Screenshots`.

### Step 5: Add your Downloads folder

**On your phone:**

1. Tap **+** to add another folder
2. Browse to: **Internal Storage → Download**
3. Set **Folder Label** to `Downloads`
4. Set **Folder Type** to **Send Only**
5. Tap **Save**

### Step 6: Add your Documents folder

**On your phone:**

1. Tap **+** to add another folder
2. Browse to: **Internal Storage → Documents**
3. Set **Folder Label** to `Documents`
4. Set **Folder Type** to **Send Only**
5. Tap **Save**

> SMS backups and app backups will be saved into subfolders here later. No extra Syncthing folder is needed for them.

### Step 7: Add your Signal folder

> Complete Part 4 (Signal backups) first so you know where Signal saves its backup files, then come back here.
>
> If you set Signal to back up into `Downloads/Signal-Backups/`, you can skip this step — the Downloads folder (Step 5) already covers it.
>
> If you chose a separate folder for Signal backups, add it here: tap **+**, browse to that folder, label it `Signal`, type **Send Only**, tap **Save**.

### Step 8: Add the WhatsApp folder (special steps required)

WhatsApp stores its backup in a protected system folder that normal apps cannot access. Syncthing-Fork has a special mode for this.

**First, make sure WhatsApp has created at least one local backup** — complete Part 5, then return here.

**On your phone:**

1. Open **Syncthing-Fork** → tap **+** to add a folder
2. Look for **Android Special Folder** — it may appear as a toggle labeled "Use SAF" or a separate menu item. Tap it.
3. A system folder picker opens (this looks different from the normal file browser)
4. Navigate through: **Internal Storage → Android → media → com.whatsapp → WhatsApp → Backups**
5. Tap **Use this folder**
6. Grant Syncthing-Fork permission when prompted — tap **Allow**
7. Set **Folder Label** to `WhatsApp`
8. Set **Folder Type** to **Send Only**
9. Tap **Save**

> If you cannot find `Android/media/com.whatsapp`, WhatsApp has not created a backup yet. Go to Part 5, run a manual backup, then return here.

---

## Part 3 — Connect Your Phone to Your PC

Now you will introduce the phone and PC to each other so they sync together.

### Step 9: Find your PC's Syncthing ID

**On your PC:**

1. Open your browser and go to **http://127.0.0.1:8384**
2. Click **Actions** in the top-right corner
3. Click **Show ID**
4. A QR code and a long device ID string appear — keep this window open

### Step 10: Add your PC as a device in Syncthing-Fork

**On your phone:**

1. Open **Syncthing-Fork**
2. Tap the **Devices** tab
3. Tap **+** to add a new device
4. Either:
   - Tap the **QR code icon** and point your phone camera at your PC screen to scan the code
   - Or tap **Enter manually** and type the device ID shown on your PC
5. Set **Device Name** to something like `Home PC`
6. Tap **Save**

### Step 11: Accept the phone on your PC

**On your PC:**

1. Watch the Syncthing web UI at **http://127.0.0.1:8384** — within a minute, a yellow popup will appear at the bottom: _"New Device — [device ID] wants to connect"_
2. Click **Add Device**
3. Give it a name like `Android Phone`
4. Click **Save**

### Step 12: Share each phone folder with your PC

**On your phone** — for each folder you added (Photos, Downloads, Documents, Signal, WhatsApp):

1. Open **Syncthing-Fork** → tap the **Folders** tab
2. Tap the folder name
3. Tap **Edit** (pencil icon)
4. Tap **Sharing** or **Share With**
5. Select `Home PC` (the device you just added)
6. Tap **Save**

### Step 13: Accept each folder share on your PC

**On your PC** — for each folder the phone shares, a yellow popup appears:
_"Android Phone wants to share folder [name]"_

For each popup:

1. Click **Add**
2. In the dialog that opens, change two things:
   - **Folder Type** → set to **Receive Only** (the PC receives files but never sends them back)
   - **Folder Path** → set to the matching path from the table below
3. Click **Save**

| Phone folder label | Set this as the PC folder path |
|---|---|
| Photos | `C:\android-backup\Photos` |
| Downloads | `C:\android-backup\Downloads` |
| Documents | `C:\android-backup\Documents` |
| Signal | `C:\android-backup\Signal` |
| WhatsApp | `C:\android-backup\WhatsApp` |

> If a popup does not appear, wait 60 seconds and refresh the page. Make sure both devices are on the same WiFi network.

### Step 14: Confirm sync is working

**On your PC:**

1. Wait 3–5 minutes after completing Step 13
2. Open **File Explorer** and navigate to `C:\android-backup\Photos`
3. You should see photos from your phone appearing

If nothing appears after 5 minutes, see the Troubleshooting section at the bottom.

### Step 15: Enable versioning (deleted file protection)

This makes Syncthing keep a copy of every file deleted from your phone for 365 days, so you can recover it later.

**On your PC:**

1. Open **PowerShell as administrator** (Start menu → search PowerShell → right-click → Run as administrator)
2. Navigate to the project folder:
   ```
   cd "C:\android-wifi-photo-sync"
   ```
3. Run the setup script again (it is safe to re-run — it skips anything already done):
   ```
   .\setup-windows.ps1
   ```

> Deleted files are kept in a hidden `.stversions` folder inside each backup folder — for example `C:\android-backup\Photos\.stversions\`. To recover a deleted file, open that folder and find the file by date.

---

## Part 4 — Signal Message Backup

### Step 16: Enable Signal backups

**On your phone:**

1. Open **Signal**
2. Tap your **profile picture** in the top-left corner
3. Tap **Chats**
4. Tap **Chat Backups**
5. Toggle **Enable Backups** on
6. Signal displays a **30-digit backup passphrase**

> ⚠️ **Save this passphrase immediately** in a password manager (Bitwarden, 1Password, etc.) or write it down and keep it somewhere safe. Without it, your backup file cannot be opened — ever.

7. Signal shows a **folder picker** — navigate to your `Downloads` folder, create a new folder called `Signal-Backups` inside it, then tap **Use this folder**
8. Set backup frequency to **Daily**
9. Tap **Create Backup** to run the first backup now

Signal writes a `.backup` file to `Downloads/Signal-Backups/`. Syncthing's Downloads folder picks it up automatically — no extra configuration needed.

---

## Part 5 — WhatsApp Message Backup

### Step 17: Enable WhatsApp local backups

**On your phone:**

1. Open **WhatsApp**
2. Tap the **three dots** (top-right corner) → **Settings**
3. Tap **Chats**
4. Tap **Chat backup**
5. Under **Back up to Google Drive** → set to **Never** (removes the Google Drive dependency)
6. Under **Back up to local storage** → set frequency to **Daily**
7. Tap **Back Up Now** to create your first backup immediately

After the backup completes, Syncthing-Fork copies the backup file to `C:\android-backup\WhatsApp\` on the next sync.

> If you have not added the WhatsApp folder to Syncthing-Fork yet (Step 8), go back and do that now.

---

## Part 6 — SMS/MMS Backup

### Step 18: Install SMS Backup & Restore

**On your phone:**

1. Open the **Play Store** and search **SMS Backup & Restore** (by SyncTech)
2. Install it and open it
3. Grant **SMS permission** and **Storage permission** when prompted
4. Tap **Set Up A Backup**

### Step 19: Configure backup location and schedule

**On your phone:**

1. Tap **Backup Location** → select **Local Backup**
2. Tap the folder icon to browse → navigate to **Internal Storage → Documents**
3. Create a new folder called `SMS-Backup` inside Documents
4. Select `SMS-Backup` as your backup location
5. Enable **Automatic Backups** → set schedule to **Daily**
6. Under **Back up**, make sure both **SMS** and **MMS** are checked
7. Tap **Back Up Now** to create the first backup immediately

The backup files land in `Documents/SMS-Backup/`. Syncthing's Documents folder copies them to `C:\android-backup\Documents\SMS-Backup\` automatically.

---

## Part 7 — App Data Backup (Swift Backup)

### Step 20: Install and configure Swift Backup

**On your phone:**

1. Open the **Play Store** and search **Swift Backup**
2. Install it and open it
3. Grant **Storage permission** and **Notification permission** when prompted
4. Tap the **gear icon** (Settings)
5. Tap **Backup Location**
6. Navigate to **Internal Storage → Documents** and create a folder called `SwiftBackup`
7. Select `SwiftBackup` as your backup location

### Step 21: Run your first backup

**On your phone:**

1. Go back to the Swift Backup main screen
2. Tap **Backup**
3. Select **Apps + Data**
4. Tap **Start Backup**

The backup files land in `Documents/SwiftBackup/` and Syncthing copies them to `C:\android-backup\Documents\SwiftBackup\` automatically.

### Step 22: Schedule nightly backups

**On your phone:**

1. In Swift Backup → **Settings** → **Schedule**
2. Set to run **Nightly**
3. Enable **Only while charging** and **Only on WiFi**

> **Note:** Some apps — mostly banking apps and some games — do not allow their data to be backed up. This is an Android security restriction. Swift Backup still saves the app installer (APK) so you can reinstall the app, but saved data like login state or game progress will not restore for those apps.

---

## Part 8 — Recovering Deleted Files

Syncthing keeps a copy of every file deleted from your phone for 365 days.

**On your PC:**

1. Open **File Explorer**
2. Navigate to the backup folder — for example `C:\android-backup\Photos`
3. Enable hidden files: click **View** in the toolbar → **Show** → **Hidden items**
4. Open the `.stversions` folder
5. Find your file — files are organised by date
6. Copy it back to the main folder or wherever you need it

---

## Part 9 — Restore After Factory Reset

Follow this exact order when setting up a new or reformatted phone.

### Step A — WhatsApp (do this BEFORE finishing WhatsApp setup)

> ⚠️ If you complete WhatsApp registration without restoring your backup first, your message history cannot be recovered. Do this before you open WhatsApp for the first time on the new phone.

**On your PC:**
1. Connect your phone to your PC with a USB cable
2. On your phone, tap **File Transfer** (or **MTP**) when the USB prompt appears
3. Copy the entire contents of `C:\android-backup\WhatsApp\` to your phone at: `Internal Storage\WhatsApp\Backups\`

**On your phone:**
4. Install **WhatsApp** from the Play Store
5. When setup asks **"Restore backup?"** → tap **Restore**
6. Complete phone number verification — messages restore automatically

### Step B — Signal (during first-launch setup)

**On your PC:**
1. Copy the `.backup` file from `C:\android-backup\Signal\` to your phone via USB — put it anywhere accessible

**On your phone:**
2. Install **Signal** from the Play Store
3. On first launch, tap **Transfer or Restore Account** → **Restore Backup**
4. Browse to the backup file you copied
5. Enter your **30-digit passphrase** from your password manager
6. Complete phone number verification — all messages and attachments restore

### Step C — Photos, Downloads, and other files

**Option 1 — USB (faster for large amounts of data):**
1. Connect phone via USB
2. Copy folders from `C:\android-backup\` back to your phone

**Option 2 — WiFi (hands-free):**
1. Set up Syncthing-Fork again (repeat Parts 1–3 of this guide)
2. Files sync back automatically — the PC keeps its copy regardless of what was on your phone

### Step D — Apps (Swift Backup)

**On your phone:**
1. Install **Swift Backup** from the Play Store (or find the APK in `C:\android-backup\Documents\SwiftBackup\`)
2. Open Swift Backup → tap **Restore**
3. Copy `C:\android-backup\Documents\SwiftBackup\` to your phone via USB first, then point Swift Backup at that folder
4. Restore apps one at a time
5. After each restore, re-grant any special permissions the app needs (accessibility, notification access, etc.)

### Step E — SMS/MMS

**On your phone:**
1. Install **SMS Backup & Restore** from the Play Store
2. Open the app → tap **Restore**
3. Browse to `Documents/SMS-Backup/` and select the most recent `.xml` file
4. Tap **Restore** — all SMS and MMS messages are imported

---

## Checking If Everything Is Working

**On your PC:**

1. Open **PowerShell** (no need for admin this time — just search PowerShell in the Start menu and open it normally)
2. Navigate to the project folder:
   ```
   cd "C:\android-wifi-photo-sync"
   ```
3. Run:
   ```
   .\check-sync-status.ps1
   ```
4. This shows whether Syncthing is running, whether your phone is connected, and how many files are in each backup folder

---

## Troubleshooting

**Phone shows as disconnected in the Syncthing web UI**
- Make sure both devices are on the same WiFi network (not one on a guest network and the other on the main network)
- Open Syncthing-Fork on your phone — this wakes it up if Android put it to sleep
- If you have a VPN active on either device, turn it off — VPNs prevent direct local network connections

**Files not appearing in `C:\android-backup\` after 5 minutes**
- Check the Syncthing web UI at **http://127.0.0.1:8384** — is your phone listed and shown as Connected?
- If Syncthing is not running on the PC: open PowerShell as administrator and run `Start-ScheduledTask -TaskName Syncthing`
- Check that each folder on the PC is set to **Receive Only** (click the folder in the web UI, then Edit, and check Folder Type)

**Sync worked once but stopped after a few days**
- Android may have re-added Syncthing-Fork to its sleeping apps list — repeat Step 3
- Open Syncthing-Fork and check for any error banners at the top of the screen

**WhatsApp folder not appearing in the folder picker (Step 8)**
- WhatsApp must create at least one local backup first — complete Part 5, then return to Step 8
- Verify the folder exists by opening a file manager app and browsing to `Android/media/com.whatsapp/WhatsApp/Backups/`

**Signal backup file not syncing**
- Signal backup is OFF by default — complete Part 4 (Step 16) to enable it
- Confirm the backup file exists on your phone at `Downloads/Signal-Backups/`
