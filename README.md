<div align="center">

<br/>

```
██╗     ██╗   ██╗███╗   ███╗██╗   ██╗██╗   ██╗███╗   ██╗
██║     ██║   ██║████╗ ████║██║   ██║╚██╗ ██╔╝████╗  ██║
██║     ██║   ██║██╔████╔██║██║   ██║ ╚████╔╝ ██╔██╗ ██║
██║     ██║   ██║██║╚██╔╝██║╚██╗ ██╔╝  ╚██╔╝  ██║╚██╗██║
███████╗╚██████╔╝██║ ╚═╝ ██║ ╚████╔╝    ██║   ██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═══╝     ╚═╝   ╚═╝  ╚═══╝
```

**Automatic photo & video backup to your own SMB server — private, local, no cloud.**

<br/>

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white) ![iOS](https://img.shields.io/badge/iOS-16%2B-000000?style=flat-square&logo=apple&logoColor=white) ![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-0071E3?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square) ![Open Source](https://img.shields.io/badge/open%20source-✓-brightgreen?style=flat-square) ![Status](https://img.shields.io/badge/status-active_development-yellow?style=flat-square)

</div>

---

## What is Lumvyn?

Lumvyn is an open-source iOS app that automatically detects new photos and videos from your local photo library and syncs them reliably to a configured SMB server — no cloud, no subscriptions, no middleman.

Designed for privacy-conscious users and self-hosters who want full control over their media backups. Everything runs on-device.

---

## Why Lumvyn?

Most self-hosted photo solutions solve a different problem: they give you a **gallery**. Lumvyn gives you a **backup**.

That distinction matters more than it sounds.

---

### vs. PhotoPrism / Immich / Nextcloud Photos

These are full-stack web applications. They require a server with a running Docker stack, a database, a web UI, and an indexing pipeline. They are powerful — but that power comes with overhead:

|                                 | PhotoPrism / Immich                                | Lumvyn                               |
| ------------------------------- | -------------------------------------------------- | ------------------------------------ |
| **Server requirements**         | Docker, PostgreSQL, 2–4 GB RAM minimum             | Any SMB share — even a Raspberry Pi  |
| **iOS client**                  | Third-party app or browser                         | Native SwiftUI app                   |
| **Setup complexity**            | `docker-compose` + reverse proxy + DNS             | Install Samba, done                  |
| **Maintenance**                 | Regular updates, DB migrations, storage management | None — it's just a file server       |
| **Open source**                 | Yes                                                | Yes — MIT licensed                   |
| **Data format**                 | Proprietary DB + managed file structure            | Plain files in your folder structure |
| **Offline access to originals** | Via web UI or sync app                             | Always — files are just files        |
| **What happens if server dies** | Restore DB + volumes + config                      | Copy files from the share, done      |

> These tools are great if you want face recognition, albums, sharing links, and a web gallery. Lumvyn doesn't compete with that — it's the foundation underneath it. Run both if you want: Lumvyn pushes files to the NAS, PhotoPrism indexes from the same folder.

---

### vs. iCloud / Google Photos

|                            | iCloud / Google Photos                      | Lumvyn                              |
| -------------------------- | ------------------------------------------- | ----------------------------------- |
| **Data location**          | Apple / Google servers                      | Your hardware only                  |
| **Privacy**                | Subject to platform ToS, potential scanning | Zero third-party access             |
| **Cost**                   | Monthly subscription (50 GB–2 TB)           | One-time — your existing NAS        |
| **Vendor lock-in**         | High — proprietary formats and APIs         | None — files stay as-is             |
| **Works without internet** | No                                          | Yes — LAN-only is fully supported   |
| **Open source**            | No — closed platform                        | Yes — MIT licensed, fully auditable |

---

### vs. rsync / shell scripts

Rolling your own backup script is fine — until you need it to:

- run reliably in iOS background mode
- resume after a network drop mid-upload
- deduplicate across sessions without re-scanning everything
- handle Live Photos, burst sets, and HEIC correctly
- expose a settings UI that your non-technical family member can use

Lumvyn handles all of that out of the box.

---

### The Lumvyn position in one sentence

> **A zero-infrastructure, privacy-first iOS backup client that treats your NAS as what it is — a file system.**

No database. No web server. No Docker. Just files on a share you control.

---

## Features

### 📸 Media Detection

Automatically detects new photos and videos from the local iOS Photos library — no manual triggers needed.

### 🔄 Upload Queue

|                       |                                                       |
| --------------------- | ----------------------------------------------------- |
| Background processing | Runs even when the app is not in the foreground       |
| Auto-resume           | Restarts automatically when network becomes available |
| Retry logic           | Failed uploads are retried with exponential backoff   |
| Progress tracking     | Live upload progress per asset                        |

### 🖧 SMB Integration

| Capability                |                                                |
| ------------------------- | ---------------------------------------------- |
| Connection test           | Validate server config before uploading        |
| Share & directory listing | Browse remote shares directly from the app     |
| File upload               | Chunked, reliable transfer to SMB target       |
| Remote deletion           | Remove files from server (used in mirror mode) |

### ⚙️ Settings & Configuration

| Setting                | Options                                        |
| ---------------------- | ---------------------------------------------- |
| SMB Host / Share path  | Any SMB-compatible server                      |
| Credentials            | Stored securely in iOS Keychain                |
| Auto-upload            | On / Off                                       |
| Background upload      | On / Off                                       |
| Network policy         | WiFi-only · Cellular allowed · Both            |
| Upload schedule        | Immediately · Hourly · Daily · Weekly · Manual |
| Max concurrent uploads | Configurable limit                             |

### 🎛️ Filters & Selection

**Media types:** Photos · Videos · Live Photos · Screenshots · Panoramas · Bursts · Slow-Motion · Time-Lapse · HDR

**Date range:** All time · Last 24h · Last 7 days · Last 30 days · Custom range

**Album filter:** Select specific albums to include or exclude

### 🔁 Sync Modes

| Mode     | Behavior                                                 |
| -------- | -------------------------------------------------------- |
| `backup` | Upload-only — never deletes remote files                 |
| `mirror` | Full two-way sync — removes remote files deleted locally |

### 🧹 Deduplication

SHA256 fingerprint per asset, persisted across sessions. Already-uploaded files are skipped automatically — even after reinstall if the store is restored.

### 🔒 Encryption

Optional AES-GCM encryption with a password-derived key. Encrypts data before it leaves the device.

### 🌍 Localization

German and English, switchable in-app. All settings auto-save immediately — no manual save step.

---

## Architecture

Lumvyn follows a clean separation between state, services, and UI — no business logic in views.

```
lumvyn/
├── Services/
│   ├── SMBClient.swift          # SMB abstraction layer (swap for prod impl)
│   ├── DeduplicationService.swift
│   └── UploadQueueManager.swift
├── Stores/
│   └── SettingsStore.swift      # Centralized app state + auto-persistence
├── de.lproj/                    # German localizations
├── en.lproj/                    # English localizations
└── ...
```

**Tech Stack:**

- **UI** — SwiftUI
- **Concurrency** — async/await + Combine
- **Media** — Photos framework
- **Crypto** — CryptoKit (AES-GCM)
- **Networking** — Network framework
- **Background** — BackgroundTasks
- **Auth** — Keychain

---

## Getting Started

### Requirements

- Xcode 15+ (latest recommended)
- iOS 16+ device or simulator
- macOS with Xcode toolchain
- A running SMB server (NAS, Linux/Samba, macOS, or Windows)

### Installation

```bash
git clone <repo-url>
cd photoSync
open lumvyn.xcodeproj
```

Select a scheme in Xcode, then build & run.

**Quick compilation check (without full build):**

```bash
swiftc -emit-module -swift-version 5 $(find lumvyn -name "*.swift")
```

---

## SMB Server Setup

Lumvyn connects to any SMB2/SMB3-compatible server. Below are setup guides and recommended configurations per platform.

---

### Linux (Samba) — Recommended for self-hosting

<details>
<summary><strong>1. Install Samba</strong></summary>

**Debian / Ubuntu**

```bash
sudo apt update && sudo apt install samba
```

**RHEL / CentOS / Fedora**

```bash
sudo dnf install samba
```

**Arch Linux**

```bash
sudo pacman -S samba
```

</details>

<details>
<summary><strong>2. Create a dedicated backup user</strong></summary>

```bash
# Create system user (no login shell)
sudo useradd -M -s /sbin/nologin lumvyn

# Set Samba password for that user
sudo smbpasswd -a lumvyn
sudo smbpasswd -e lumvyn

# Create the backup directory and set ownership
sudo mkdir -p /srv/lumvyn-backup
sudo chown lumvyn:lumvyn /srv/lumvyn-backup
sudo chmod 770 /srv/lumvyn-backup
```

</details>

<details>
<summary><strong>3. Configure /etc/samba/smb.conf</strong></summary>

```ini
[global]
   workgroup = WORKGROUP
   server string = Lumvyn Backup Server
   server role = standalone server

   # Security
   security = user
   map to guest = never
   smb encrypt = required          # enforce SMB3 encryption
   min protocol = SMB2
   max protocol = SMB3

   # Performance
   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes
   max xmit = 65535

   # Logging (optional, reduce for production)
   log level = 1
   log file = /var/log/samba/log.%m
   max log size = 50

[lumvyn]
   comment = Lumvyn Photo Backup
   path = /srv/lumvyn-backup
   valid users = lumvyn
   read only = no
   browseable = no                 # hide from network discovery
   create mask = 0640
   directory mask = 0750
   force user = lumvyn
```

Test the config before restarting:

```bash
testparm
```

</details>

<details>
<summary><strong>4. Start & enable Samba</strong></summary>

**Debian / Ubuntu**

```bash
sudo systemctl enable smbd && sudo systemctl restart smbd
```

**RHEL / Arch**

```bash
sudo systemctl enable smb && sudo systemctl restart smb
```

</details>

<details>
<summary><strong>5. Firewall (optional)</strong></summary>

```bash
# ufw
sudo ufw allow from <your-phone-ip> to any port 445

# firewalld
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --reload
```

> **Tip:** Restrict port 445 to your local network or the specific device IP. Never expose SMB to the internet.

</details>

**In the Lumvyn app:**

```
Host:       192.168.x.x   (your server IP)
Share:      lumvyn
Username:   lumvyn
Password:   <your smbpasswd>
```

---

### macOS

<details>
<summary><strong>Setup</strong></summary>

1. System Settings → General → **Sharing** → enable **File Sharing**
2. Click **Options…** → check **Share files and folders using SMB**
3. Enable your user account for SMB access and set a password
4. Under **Shared Folders**, add the target folder and set permissions to **Read & Write** for your user
5. Your server address: `smb://<your-mac-ip>/<share-name>`
  </details>

---

### Windows

<details>
<summary><strong>Setup</strong></summary>

1. Control Panel → Network and Sharing Center → **Advanced sharing settings**
2. Enable **File and printer sharing** under the Private profile
3. Right-click the target folder → Properties → **Sharing** → Advanced Sharing
4. Check **Share this folder**, provide a share name
5. Click **Permissions** → add your user with **Full Control**
6. Your server address: `\\<your-windows-ip>\<share-name>`

> **Note:** Make sure Windows Defender Firewall allows SMB (port 445) on private networks.

</details>

---

### NAS Devices (Synology, QNAP, TrueNAS)

Most NAS systems support SMB2/SMB3 out of the box. Enable it in the network services panel, create a dedicated shared folder and a local user with write access, then use the NAS IP and share name directly in Lumvyn.

> **Security recommendation:** Always use a dedicated user with access limited to the backup share only. Do not use admin credentials in the app.

---

## Configuration

All settings are persisted automatically and applied immediately — no manual save required.

| Setting               | Description                           |
| --------------------- | ------------------------------------- |
| `SMB Host / IP`       | Address of your SMB server            |
| `Share Path`          | Path to the target share              |
| `Username / Password` | Stored securely in Keychain           |
| `Upload Scheduling`   | Control when uploads run              |
| `Network Conditions`  | WiFi-only, cellular, or unrestricted  |
| `Deduplication`       | Enable/disable SHA256 duplicate check |
| `Encryption`          | Toggle AES-GCM encryption per upload  |

---

## SMB Client

The current implementation uses a `DummySMBClient` for development — it writes to the local sandbox instead of a real server.

**For production**, replace this with a real SMB implementation:

```
lumvyn/Services/SMBClient.swift
```

The interface is fully abstracted, so swapping the client requires no changes to the rest of the codebase.

---

## Known Issues / Roadmap

- [ ] Replace `DummySMBClient` with production SMB implementation
- [ ] Audit `@unchecked Sendable` in localization helpers
- [ ] Improve network transition handling during background uploads

---

## Contributing

PRs are welcome. Keep them:

- **Small and focused** — one concern per PR
- **Cleanly separated** — no UI/business logic mixing
- **Well-described** — what does it change and why?

For larger changes, open an issue first.

---

## License

MIT — see [`LICENSE`](./LICENSE) for details.

---

<div align="center">

Built with Swift · Made for self-hosters · No cloud, ever.

</div>
