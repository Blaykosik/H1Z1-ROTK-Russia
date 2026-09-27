# H1Z1 ROTK Russia

**English** | [Русский](README_RU.md)

Local direct-connect fix for H1Z1 Return of the King (ROTK) in Russia.  
Play with **native direct UDP** and low ping without VPNs, proxies, or remote relays.

---

## What It Solves

On certain Russian internet providers (such as Beeline), direct UDP flows to ROTK game servers hosted on foreign datacenters (OVH) are cut off by deep packet inspection after an initial burst of ~12 packets.

This causes:
- The game launcher hanging during login or character loading;
- Region selection reporting servers as "low quality" or "unavailable";
- Loading into the lobby normally, but hanging indefinitely on "Waiting for world ready" when attempting to join a match.

**H1Z1 ROTK Russia** resolves this locally on your Windows PC by applying a single-packet protocol desynchronization header to ROTK UDP handshakes. Your ISP's filter classifies the flow as authorized real-time communication (STUN/WebRTC), allowing the game traffic to flow **100% direct and unmodified** at native line speeds.

---

## What This Project Is NOT

- ❌ **Not a VPN** — Your public IP address is unchanged; traffic does not route through any remote VPS or relay.
- ❌ **Not a proxy** — No SOCKS5, HTTP, or VLESS tunneling is involved.
- ❌ **Not a cheat or hack** — It does not alter game memory, mechanics, hitboxes, or gameplay.
- ❌ **No game file modifications** — `H1Z1.exe`, game files, and launcher binaries remain 100% original.
- ❌ **No anti-cheat interference** — Does not touch, hook, or bypass BattlEye anti-cheat.

---

## Why Latency Stays Low

```
WITHOUT THIS PROJECT (VPN / VLESS):
H1Z1.exe ──► Remote VPN Server (e.g. Germany/Netherlands) ──► ROTK Server
                     ▲ High ping (~140 - 170 ms), routing jitter, packet spikes

WITH THIS PROJECT (DIRECT UDP DESYNC):
H1Z1.exe ──► Local WinDivert Filter ──► ISP (Beeline) ──► ROTK Server (Direct OVH)
                     ▲ Native direct ping (~55 - 61 ms), zero routing overhead
```

Because traffic travels directly along your ISP's physical fiber route to the game server without detouring through third-party proxy nodes, ping remains at its true physical minimum.

---

## Verified Results

Tested and verified on live sessions:
- **Operating System**: Windows 10 & 11 (64-bit)
- **ISP**: Beeline (Russia), direct physical Ethernet
- **Game Version**: H1Z1 Return of the King (ROTK Live)
- **In-Game Ping**: **~55–61 ms** stable (verified in `DbDataCenters.log` as `Ping=61 Quality=high`)
- **Gameplay**: Successful login, character creation, match queueing, and sustained in-match gameplay.

> [!NOTE]
> This workaround has been empirically proven on Beeline Russia. Other Russian ISPs may enforce different filtering rules. Community test reports for other providers are welcome!

---

## Target Scope & Dynamic Match Servers

The WinDivert filter strictly isolates ROTK UDP traffic and **does not touch** your web browser, Discord, Steam, DNS, or general TCP/UDP traffic:

- **Login & Gateway**: `162.19.94.95` (ports `20042-20045`, `20140-20141`)
- **Match Server Subnet**: `162.19.126.0/24` (ports `20000 - 23000`)

> [!IMPORTANT]
> ROTK dynamically spins up game server instances across the `162.19.126.0/24` subnet (e.g. `162.19.126.166:20214`). The filter covers the full `/24` subnet so all dynamic match servers are protected automatically.

---

## Quick Start (Installation)

1. Go to the [Releases](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases) page and download `H1Z1-ROTK-Russia-v1.0.0.zip`.
2. Extract the ZIP archive anywhere on your PC.
3. Right-click **`START.cmd`** and select **Run as administrator**.
4. Launch ROTK normally through the ROTK Launcher and click Play.
5. When finished playing, run **`STOP.cmd`** (or press any key in the `START` console window) to cleanly unload the packet filter.

---

## Diagnostics & Management

- **`START.cmd`**: Validates administrator rights, verifies binary files, and activates the bypass filter.
- **`STATUS.cmd`**: Displays live status (ACTIVE / INACTIVE), process PID, and WinDivert driver state.
- **`STOP.cmd`**: Safely terminates only this project's filter instance and unloads the driver.

---

## Administrator Privileges

`START.cmd` requires administrator privileges because **WinDivert** functions as a kernel-level network packet filter driver. Windows restricts raw packet interception to elevated processes to ensure system security.

---

## Privacy & Security

- **Zero Telemetry**: No user data, game statistics, or network telemetry is collected or sent anywhere.
- **Zero Credentials**: Does not inspect, handle, or store login tokens, passwords, or session tickets.
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
