# NAS Migration Guide

When you're ready to add a NAS to your backup setup, this guide covers adding it as a second receive node. Your Android phone needs **zero reconfiguration** — the NAS just joins the existing Syncthing cluster.

## Architecture After Migration

```
Android Phone (Send Only)
       │
       ├──── WiFi LAN ───→ Windows PC (Receive Only)  [H:\android-backup\]
       │
       └──── WiFi/LAN ──→ NAS (Receive Only)          [/volume1/android-backup/]
```

Both the PC and NAS receive everything independently. If the PC is off when you come home, the NAS still syncs. Both are full copies.

---

## Option A — Syncthing via Docker (recommended for most NAS devices)

Works on: Synology, QNAP, TrueNAS SCALE, Unraid, any NAS running Docker.

```bash
docker run -d \
  --name=syncthing \
  --restart=unless-stopped \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -p 8385:8384 \
  -p 22001:22000/tcp \
  -p 22001:22000/udp \
  -p 21028:21027/udp \
  -v /volume1/docker/syncthing/config:/var/syncthing/config \
  -v /volume1/android-backup:/var/syncthing/data \
  lscr.io/linuxserver/syncthing:latest
```

**Notes:**
- Change `/volume1/` to your NAS volume path (e.g. `/mnt/user/` on Unraid, `/pool/` on TrueNAS)
- Ports are offset by 1 (8385, 22001, 21028) to avoid conflicting with the PC if it's on the same subnet
- The NAS Syncthing web UI will be at `http://<NAS-IP>:8385`

---

## Option B — Native Syncthing Package

Works on: Synology (via SynoCommunity), TrueNAS CORE, FreeBSD-based NAS.

**Synology (SynoCommunity):**
1. Add SynoCommunity package source: `https://packages.synocommunity.com`
2. In Package Center → search "Syncthing" → Install
3. Open Syncthing from the main menu

**TrueNAS CORE / FreeBSD:**
```bash
pkg install syncthing
sysrc syncthing_enable=YES
sysrc syncthing_user=syncthing
service syncthing start
```

**TrueNAS SCALE (Linux-based):**
Use Option A (Docker) or install via the TrueNAS Apps catalog (search "Syncthing").

---

## Step 1: Create the backup folder on the NAS

Create a folder on the NAS that will receive the backups. Example for Synology:

```
/volume1/android-backup/
```

Make sure the user Syncthing runs as has read/write access to this folder.

---

## Step 2: Get the NAS device ID

1. Open the NAS Syncthing web UI (e.g. `http://192.168.1.x:8385`)
2. Click **Actions** → **Show ID**
3. Copy the full device ID or keep the QR code ready

---

## Step 3: Add the NAS as a device on your Windows PC

1. Open the PC Syncthing web UI: `http://127.0.0.1:8384`
2. Click **Add Remote Device**
3. Paste the NAS device ID
4. Name it `NAS`
5. Click **Save**

---

## Step 4: Accept the PC on the NAS

1. In the NAS Syncthing web UI, a popup will appear: _"New device wants to connect"_
2. Click **Add Device** → name it `Home PC` → Save

---

## Step 5: Share all six folders with the NAS

On your **Windows PC** Syncthing web UI, for each of the six folders:

1. Click the folder → **Edit**
2. Go to the **Sharing** tab
3. Check the box next to `NAS`
4. Click **Save**

| Folder | Share with NAS |
|---|---|
| Camera | ✓ |
| Screenshots | ✓ |
| Downloads | ✓ |
| Documents | ✓ |
| Signal | ✓ |
| WhatsApp | ✓ |

---

## Step 6: Accept each folder on the NAS and set to Receive Only

On the **NAS** Syncthing web UI, for each folder share request:

1. Click **Add** on the popup
2. Set **Folder Type** to **Receive Only**
3. Set **Folder Path** to the NAS path, e.g.:
   - Camera → `/volume1/android-backup/Camera`
   - Screenshots → `/volume1/android-backup/Screenshots`
   - Downloads → `/volume1/android-backup/Downloads`
   - Documents → `/volume1/android-backup/Documents`
   - Signal → `/volume1/android-backup/Signal`
   - WhatsApp → `/volume1/android-backup/WhatsApp`
4. Click **Save**

Syncthing will begin syncing all existing files to the NAS. First sync may take hours depending on total size.

---

## Step 7: Verify

1. Wait for initial sync to complete (watch the NAS Syncthing web UI for 100% on all folders)
2. Browse to `/volume1/android-backup/Camera` on the NAS — you should see your photos
3. Run `check-sync-status.ps1` on your PC — the NAS should appear as a connected device

---

## No Phone Reconfiguration Needed

Your Android phone only syncs to one place: your Windows PC. The PC then propagates everything to the NAS. Adding the NAS required zero changes to Syncthing-Fork on your phone.

If you later want the phone to sync directly to the NAS (bypassing the PC), you can add the NAS as a device in Syncthing-Fork — but this is optional and not necessary for the backup to work.

---

## Optional: Enable Versioning on NAS

After accepting all folders on the NAS, enable staggered versioning so the NAS also keeps deleted files for 365 days:

For each folder on the NAS Syncthing web UI:
1. Click the folder → **Edit** → **Versioning** tab
2. Select **Staggered File Versioning**
3. Set **Maximum Age** to `365` days
4. Click **Save**
