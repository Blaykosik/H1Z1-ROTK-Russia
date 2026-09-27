# H1Z1 ROTK Russia

**English** | [Русский](README_RU.md)

Local direct-connect fix for H1Z1 Return of the King (ROTK) in Russia.  
Play with **native direct UDP** without VPNs, proxies, or remote relays.

---

## What It Solves

On the tested connection, sustained ROTK UDP sessions consistently stopped receiving replies shortly after connection establishment when connecting to ROTK game servers hosted on foreign datacenters (OVH Western Europe).

This causes:
- The game launcher hanging during login or character loading;
- Region selection reporting servers as "low quality" or "unavailable";
- Loading into the lobby normally, but hanging indefinitely on "Waiting for world ready" when attempting to join a match.

**H1Z1 ROTK Russia** resolves this locally on your Windows PC: the project applies a local STUN-based desynchronization strategy to initial UDP packets. On the tested connection, this is sufficient to prevent the observed ROTK UDP session cutoff, allowing subsequent game traffic to flow **100% direct and unmodified** at native line speeds.

---

## What This Project Is NOT

- ❌ **Not a VPN** — Your public IP address is unchanged; traffic does not route through any remote VPS or relay.
- ❌ **Not a proxy** — No SOCKS5, HTTP, or VLESS tunneling is involved.
- ❌ **Not a cheat or hack** — It does not alter game memory, mechanics, hitboxes, or gameplay.
- ❌ **No game file modifications** — `H1Z1.exe`, game files, and launcher binaries remain 100% original.
- ❌ **No anti-cheat interference** — Does not touch, hook, or bypass BattlEye anti-cheat.

> [!NOTE]
> **Anti-Cheat Disclaimer**: The project does not inject into H1Z1, modify game memory, patch game files, or interact with BattlEye. It has been successfully tested in live ROTK gameplay. Future anti-cheat policy changes cannot be guaranteed.

---

## Latency & Routing Comparison

VLESS was playable and often stayed around roughly 60–80 ms, but the tunneled path introduced noticeable jitter and occasional latency spikes reaching approximately 140–170 ms on the tested setup. The direct local bypass keeps the native route and produced a much steadier connection with substantially reduced jitter compared with the tested VLESS path (~55–61 ms observed during testing).

```
TUNNELED ROUTE (VPN / VLESS):
H1Z1.exe ──► Remote Tunnel Server (e.g. Germany/Netherlands) ──► ROTK Server
             ▲ ~60–80 ms baseline with route jitter and latency spikes up to ~140–170 ms

NATIVE DIRECT ROUTE WITH THIS PROJECT (LOCAL UDP DESYNC):
H1Z1.exe ──► Local WinDivert Filter ──► Direct ISP Route ──► ROTK Server (OVH)
             ▲ Native direct route, much steadier latency, substantially reduced jitter
```

Because traffic travels directly along your physical ISP fiber route to the game server without detouring through third-party proxy nodes, latency stays at your physical connection's natural minimum.

---

## Verified Results

Tested and verified on live sessions:
- **Operating System**: Windows 10 & 11 (64-bit)
- **ISP**: Beeline (Russia), direct physical Ethernet
- **Game Version**: H1Z1 Return of the King (ROTK Live)
- **Observed Latency**: **~55–61 ms** stable observed during testing (verified in `DbDataCenters.log` as `Ping=61 Quality=high`)
- **Gameplay**: Successful login, character creation, match queueing, and sustained in-match gameplay.

> [!NOTE]
> This workaround has been empirically proven on the tested Beeline connection. Other Russian ISPs may configure filtering differently. Latency and stability depend on your personal ISP routing to Western Europe.

---

## Target Scope & Dynamic Match Servers

The WinDivert filter strictly isolates ROTK UDP traffic and **does not touch** your web browser, Discord, Steam, DNS, or general TCP/UDP traffic:

- **Login & Gateway**: `162.19.94.95` (ports `20042-20045`, `20140-20141`)
- **Match Server Subnet**: `162.19.126.0/24` (ports `20000 - 23000`)

> [!IMPORTANT]
> ROTK dynamically spins up game server instances across the `162.19.126.0/24` subnet (e.g. `162.19.126.166:20214`). The filter covers the full `/24` subnet so all dynamic match servers are protected automatically.

---

## Usage Modes: Portable vs. Auto Mode

### Option A: Auto Mode (Recommended — Installed)

Auto Mode installs a dedicated runtime into `%ProgramData%\H1Z1-ROTK-Russia` and registers a Windows scheduled task running at user logon:
- **Event-Driven Lifecycle**: Primarily event-driven via Windows WMI (`Win32_ProcessStartTrace` / `Win32_ProcessStopTrace`), with a low-frequency safety reconciliation in case a process event is missed. Idle CPU footprint remains practically 0%.
- **Automatic Toggle**: Automatically turns the bypass ON when `H1Z1.exe` starts, and turns it OFF 7 seconds after `H1Z1.exe` exits.
- **Strict Isolation**: Manages only this project's own `winws` process. Unrelated `winws` or `zapret` instances are never terminated.
- **Safe Driver Lifecycle**: Unhooks the WinDivert driver when H1Z1 closes, but only if no other tool is currently using WinDivert.
- **Independent from Downloads**: Once installed, you can safely move or delete the downloaded release folder!

**How to Install**:
1. Download **`H1Z1-ROTK-Russia-v1.2.1.zip`** from [Releases](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases) and extract it.
2. Right-click **`INSTALL_AUTO.cmd`** and select **Run as administrator**.
3. Done! Launch ROTK whenever you want to play.
4. To uninstall, run **`UNINSTALL_AUTO.cmd`** (from the release folder or from `C:\ProgramData\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd`).

### Option B: Manual Mode (100% Portable)

Manual Mode does **not** install anything to ProgramData and does not create scheduled tasks:
1. Right-click **`START.cmd`** and select **Run as administrator**.
2. Launch ROTK normally through the ROTK Launcher and click Play.
3. When finished playing, run **`STOP.cmd`** (or press any key in the `START` console window) to cleanly stop the bypass.

---

## Diagnostics & Management

- **`INSTALL_AUTO.cmd`**: Copies runtime to `%ProgramData%\H1Z1-ROTK-Russia` and registers the logon task.
- **`UNINSTALL_AUTO.cmd`**: Removes the scheduled task, stops the watcher, stops only our tracked bypass, and removes the ProgramData runtime.
- **`STATUS.cmd`**: Displays comprehensive status: Auto Mode task state, watcher PID, game process state, project bypass PID, detection of any other independent `winws` processes, and driver service state.
- **`START.cmd`**: Manually launches the portable bypass filter in background.
- **`STOP.cmd`**: Manually terminates only the portable bypass and unloads the driver if idle.

---

## Administrator Privileges

Scripts require administrator privileges because **WinDivert** functions as a kernel-level network packet filter driver. Windows restricts raw packet interception to elevated processes to ensure system security.

---

## Privacy & Security

- **Zero Telemetry**: No user data, game statistics, or network telemetry is collected or sent anywhere.
- **Zero Credentials**: Does not inspect, handle, or store login tokens, passwords, or session tickets.
- **Process Isolation**: Validates process executable paths before terminating; never touches unrelated third-party utilities.
- **Open Source & Auditable**: All batch scripts and filter configurations are plain text and fully inspectable.

---

## Documentation

- [Technical Architecture: How It Works](docs/HOW_IT_WORKS.md)
- [Empirical Findings & Measurement Matrix](docs/TECHNICAL_FINDINGS.md)
- [Troubleshooting & FAQ](docs/TROUBLESHOOTING.md)
- [Tested Server Endpoints](docs/TESTED_SERVERS.md)
- [Third-Party Software Notices](THIRD_PARTY_NOTICES.md)

---

## Credits & Disclaimer

This project utilizes upstream open-source networking components:
- **[zapret](https://github.com/bol-van/zapret)** by bol-van (MIT License)
- **[WinDivert](https://github.com/basil00/Divert)** by basil00 (LGPLv3 / GPLv2)
- **[Cygwin](https://cygwin.com/)** by Red Hat and Cygwin Contributors (LGPLv3+)

### Legal Disclaimer
This project is an independent community compatibility configuration. This project is **not** affiliated with, authorized, maintained, sponsored, or endorsed by Return of the King (ROTK), Daybreak Game Company, Standing Stone Games, BattlEye Innovations, bol-van, or the WinDivert project. All registered trademarks belong to their respective owners.
