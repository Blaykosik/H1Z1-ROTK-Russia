# Troubleshooting Guide

This guide covers common issues, error messages, and solutions when running the H1Z1 ROTK direct UDP bypass.

---

## 1. "Administrator privileges are required"

### Symptom:
When running `START.cmd`, a warning appears stating that administrator rights are missing.

### Cause:
WinDivert is a Windows kernel driver. Intercepting outbound network packets requires administrative elevation.

### Solution:
1. Right-click `START.cmd` (or `scripts\start.cmd`).
2. Select **Run as administrator**.
3. Confirm the Windows User Account Control (UAC) prompt.

---

## 2. Lobby connects, but Match does not load

### Symptom:
You can log into the game, character select works, and ping shows green (~55–60 ms) in menus, but when joining a match, the screen hangs on "Waiting for world ready" or disconnects.

### Cause:
ROTK dynamically spins up match server instances. The current filter covers:
- Login / Gateway: `162.19.94.95`
- Match Subnet: `162.19.126.0/24` (ports `20000 - 23000`)

If ROTK allocates an instance in a completely new subnet or port range, the game traffic for that match will not match the filter and will be dropped by your ISP.

### Solution:
1. Check the destination endpoint in your game logs:
   - Path: `<ROTK_Install_Dir>\Logs\H1Z1 PlayClient (Live).log`
   - Look for lines containing `connect request (ExternalGatewayApi_3) address=...`
2. Open an Issue on GitHub:
   - Provide the **Destination IP** and **UDP Port** (e.g. `162.19.127.50:20250`).
   - **DO NOT** paste entire log files, tickets, or account tokens!

---

## 3. WinDivert failed to initialize / Driver error

### Symptom:
`START.cmd` outputs:
`[ERROR] Failed to start winws.exe. Please verify that your antivirus or another WinDivert tool is not blocking or holding the driver.`

### Potential Causes & Solutions:

#### A. Another WinDivert Tool is Running
If you have **GoodbyeDPI**, **zapret**, or another packet-filtering tool running simultaneously, both cannot open WinDivert handles with conflicting priority.
- **Fix**: Temporarily close or stop the other DPI utility before starting `START.cmd`.

#### B. Antivirus / Windows Defender False Positive
Security software occasionally flags `WinDivert64.sys` because packet filtering drivers can theoretically be abused by malware.
- The bundled `WinDivert64.sys` is an authentic, digitally signed build from the official WinDivert release (Thumbprint: `043589F75FCE2795E7F2CC3E526D46784D5DDAB3`).
- **Fix**: Add the project folder to your security software's exclusions list.

#### C. Stale Driver Service
If an earlier session did not clean up properly:
1. Run `STOP.cmd` as Administrator.
2. If the issue persists, run an administrative Command Prompt and execute:
   ```cmd
   sc.exe stop windivert
   sc.exe delete windivert
   ```
3. Run `START.cmd` again.

---

## 4. "It does not work on my ISP"

### Context:
This project has been empirically verified and tested on **Beeline (Russia)** via direct Ethernet routing to OVH France.

Different Russian regional operators or local sub-providers may configure intermediate filtering rules differently:
- Some providers may enforce different packet thresholds.
- Some providers may filter both inbound and outbound UDP.

If the bypass does not resolve connectivity on your ISP:
1. Open an Issue on GitHub with the **Bug Report** template.
2. Specify your **ISP name**, **region/city**, and the exact symptom observed.
