# Security, Trust & Anti-Cheat Architecture

> **Core Principle**: Do not ask for blind trust — provide full verification.  
> A new user visiting this repository should be able to verify every claim, binary, and script in under two minutes without taking the author's word for granted.

---

## 1. What This Project Actually Is

**H1Z1 ROTK Russia** is a narrow network DPI-bypass configuration for H1Z1: Return of the King (ROTK), built on the battle-tested open-source components **zapret** (`winws`) and **WinDivert**.

* **No Game Injection**: The project does **not** inject code, DLLs, or hooks into the `H1Z1.exe` process.
* **No Memory Modification**: It does **not** open, read, scan, or modify game memory (`ReadProcessMemory` / `WriteProcessMemory` are nowhere in the code).
* **No File Patching**: It does **not** patch, replace, or alter `H1Z1.exe`, game assets, configuration files, or launcher binaries.
* **No Anti-Cheat Interference**: It does **not** interact with, hook, or disable the BattlEye API or drivers.
* **Network Stack Level Only**: It operates exclusively at the Windows network stack level via the WinDivert packet filter driver, processing **only** pre-filtered UDP traffic destined for ROTK game servers.

---

## 2. Comparison with `zapret`

If you are already familiar with **zapret** (widely used in Russia for YouTube and Discord DPI circumvention):
* This project uses the **exact same technology class** and the **exact same `winws.exe` / WinDivert engine** from bol-van's upstream repository.
* It is **not** an untested new tool or proprietary protocol; it is a **game-specific zapret / winws profile** configured with a strict, dedicated filter specifically for H1Z1 ROTK.

---

## 3. BattlEye & Anti-Cheat Policy

We believe in complete, unvarnished honesty regarding anti-cheat compatibility:

* **What we do**: The project runs alongside the game as an independent Windows network filtering service. It does not touch game memory, files, or anti-cheat components. It has been tested and verified in live ROTK matches without triggering anti-cheat alerts.
* **Official BattlEye Policy**: According to the [official BattlEye FAQ](https://www.battleye.com/support/faq/):
  > *"When do you ban?"*  
  > *"We only ban for intentional cheating/hacking and software/hardware that is designed to circumvent BattlEye protection."*  
  > *"Incompatible third-party software may be blocked or result in a kick from the game, which is not in itself a ban."*
* **What we do NOT promise**:
  * ❌ We do **not** claim "100% ban safe".
  * ❌ We do **not** claim "impossible to get banned".
  * ❌ We do **not** claim to be "BattlEye approved" or "ROTK approved".  
    Neither BattlEye Innovations nor the Return of the King team have officially endorsed or reviewed this project.
  * ⚠️ We cannot guarantee future policy changes or heuristic updates made by BattlEye or ROTK.

---

## 4. Why Windows Defender / Antiviruses May Flag This

Security software (Windows Defender, VirusTotal, Kaspersky, etc.) may occasionally display heuristic warnings or categorize components of this project as `RiskTool`, `PUA` (Potentially Unwanted Application), or `HackTool`.

### Why does this happen?
1. **Low-Level Packet Interception Driver (`WinDivert64.sys`)**: WinDivert is a kernel-mode driver that intercepts raw network packets. Because some malicious programs or network sniffer tools also utilize packet capture drivers, antivirus heuristic engines often flag drivers of this type generically.
2. **Packet Desynchronization (`winws.exe`)**: `winws` modifies and crafts network packet headers (such as inserting STUN prefixes) to circumvent Deep Packet Inspection (DPI). Antivirus heuristics frequently classify packet-crafting tools as `RiskTool:Win32/Zapret` or `HackTool`.
3. **Official Upstream Warning**: Upstream author bol-van explicitly warns in the [official zapret repository](https://github.com/bol-van/zapret) that antivirus vendors regularly flag `winws.exe` and `WinDivert` as false positives due to generic heuristics.

### Recommended Safety Protocol
> [!CAUTION]
> **We never recommend "just turning off your antivirus" or running blind exclusions.**

Instead, follow this rigorous verification checklist:
1. **Verify Download Origin**: Ensure your archive was downloaded directly from the official [GitHub Releases](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases) page.
2. **Verify SHA-256 Checksum**: Check that the release ZIP hash matches the published [`SHA256SUMS.txt`](../SHA256SUMS.txt).
3. **Compare Upstream Binary Hashes**: Check that bundled binaries match official upstream releases bit-for-bit (see [`BINARY_PROVENANCE.md`](../BINARY_PROVENANCE.md)).
4. **Inspect Source Scripts**: Review [`scripts/watcher.ps1`](../scripts/watcher.ps1), [`START.cmd`](../START.cmd), and [`INSTALL_AUTO.cmd`](../INSTALL_AUTO.cmd) — they are short, plain-text scripts containing zero obfuscated code.
5. **Add Targeted Exclusion Only If Satisfied**: Only after you have independently confirmed that the files are authentic upstream artifacts, add an exclusion specifically for the folder `%ProgramData%\H1Z1-ROTK-Russia` or your portable extraction folder.

**Our Commitment**: This project will **never** attempt to silently whitelist itself in Windows Defender using commands like `Add-MpPreference -ExclusionPath`. All security decisions remain 100% under your explicit control.

---

## 5. Security Audit: Zero Hidden Network Activity

An automated security scan across all project scripts confirms:

| Potential Threat Vector | Present in Project? | Technical Audit Detail |
| :--- | :---: | :--- |
| **Telemetry / Tracking** | ❌ **NONE** | No telemetry libraries, tracking beacons, or analytics collectors. |
| **External HTTP / HTTPS Calls** | ❌ **NONE** | Scripts contain zero `Invoke-WebRequest`, `curl`, `wget`, or WebClient calls. |
| **Remote Backend Server** | ❌ **NONE** | The project has no dedicated server, API endpoint, or remote infrastructure. |
| **Auto-Updater** | ❌ **NONE** | No background updater; files are never downloaded or executed dynamically. |
| **DNS Requests by Scripts** | ❌ **NONE** | Scripts only interact with raw IP addresses defined in local filter files. |
| **Credential / Password Theft** | ❌ **NONE** | No access to Steam credentials, ROTK account data, tokens, or cookies. |
| **Process / DLL Injection** | ❌ **NONE** | No `CreateRemoteThread`, `VirtualAllocEx`, or `SetWindowsHookEx` APIs. |
| **Game Memory Modification** | ❌ **NONE** | No `OpenProcess`, `ReadProcessMemory`, or `WriteProcessMemory` calls. |

### What the Project Actually Does
1. **Process Watcher (`watcher.ps1`)**: Listens to local Windows WMI process notifications (`Win32_ProcessStartTrace` / `Win32_ProcessStopTrace`) strictly to detect when `H1Z1.exe` starts and stops.
2. **Local Engine Execution**: Launches the local, verified `winws.exe` binary with argument `@rotk_winws.conf`.
3. **Local Packet Filtering**: `winws` asks `WinDivert64.sys` to divert packets matching the exact ROTK destination IP and port criteria, sends a dummy STUN prefix frame on connection start, and unhooks when idle.

---

## 6. Strict Target Filter Scope

The WinDivert filter string defined in [`config/filter.txt`](../config/filter.txt) is mathematically bounded:

```text
outbound and ip and udp and (ip.DstAddr == 162.19.94.95 or (ip.DstAddr >= 162.19.126.0 and ip.DstAddr <= 162.19.126.255)) and udp.DstPort >= 20000 and udp.DstPort <= 23000
```

### What this filter intercepts:
* Destination IP `162.19.94.95` (ROTK Login / Gateway Server)
* Destination IP subnet `162.19.126.0/24` (`162.19.126.0` - `162.19.126.255`, OVH ROTK match server cluster)
* Protocol: **UDP only** (TCP is completely ignored)
* Direction: **Outbound only**
* Ports: **20000 through 23000 only**

### What this filter CANNOT touch:
* **Web Browsing & HTTPS**: Ignored (TCP ports 80, 443).
* **Discord Voice & Chat**: Ignored (routes to Discord voice servers, not OVH ROTK IPs).
* **Steam Client & Downloads**: Ignored (Steam content servers use TCP/UDP on different subnets).
* **DNS Resolution**: Ignored (UDP port 53).
* **Other Games**: Ignored (connect to separate game server IP ranges).

---

## 7. How to Verify Downloaded Files

You can independently verify any downloaded release archive in PowerShell:

```powershell
# Verify the release archive SHA-256
Get-FileHash .\H1Z1-ROTK-Russia-v1.2.1.zip -Algorithm SHA256
```

Compare the output hash with [`SHA256SUMS.txt`](../SHA256SUMS.txt) in the repository.

To verify the runtime binaries after extracting:
```powershell
Get-FileHash .\_runtime\* -Algorithm SHA256 | Format-Table -AutoSize
```

All checksums are permanently recorded in [`BINARY_PROVENANCE.md`](../BINARY_PROVENANCE.md).

---

## 8. Disclaimers & Acknowledgments

* **Independent Project**: H1Z1 ROTK Russia is an independent, open-source community research and compatibility configuration.
* **No Affiliation**: This project is **not** affiliated with, authorized, maintained, sponsored, or endorsed by Return of the King (ROTK), Daybreak Game Company, Standing Stone Games, BattlEye Innovations, bol-van, or the WinDivert project.
* **Upstream Acknowledgments**:
  * **[bol-van](https://github.com/bol-van)** — creator of [zapret](https://github.com/bol-van/zapret) and `winws`.
  * **[basil00](https://github.com/basil00)** — creator of [WinDivert](https://github.com/basil00/WinDivert).
  * **[Cygwin Contributors](https://cygwin.com/)** — authors of the Cygwin POSIX emulation layer.
