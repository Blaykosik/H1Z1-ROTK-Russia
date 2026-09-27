# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.2.1] - 2026-09-27

### Fixed
- **Process Isolation (Zero Interference with Other `winws` / `zapret` Instances)**:
  - Strict PID tracking and canonical binary path validation (`[System.IO.Path]::GetFullPath`) in all scripts (`watcher.ps1`, `START.cmd`, `STOP.cmd`, `INSTALL_AUTO.cmd`, `UNINSTALL_AUTO.cmd`, `STATUS.cmd`).
  - Completely removed all global `taskkill /IM winws.exe` and untracked `Get-Process -Name winws | Stop-Process` commands.
  - Safe driver isolation: `WinDivert` service is only stopped if NO other `winws` or `goodbyedpi` processes are running anywhere on the system.
- **Stable `%ProgramData%` Auto Mode Installation**:
  - `INSTALL_AUTO.cmd` copies the full runtime, configurations, watcher, and management scripts into `%ProgramData%\H1Z1-ROTK-Russia`.
  - Windows scheduled task now targets the persistent `%ProgramData%` folder, allowing users to safely move or delete the extracted release archive without breaking Auto Mode.
- **Robust Uninstall Lifecycle**:
  - `UNINSTALL_AUTO.cmd` cleanly unregisters the scheduled task, terminates the running watcher process, terminates only the project's own `winws` process, and removes the `%ProgramData%\H1Z1-ROTK-Russia` folder even when executed directly from inside `%ProgramData%`.
- **Enhanced Status Diagnostics**:
  - `STATUS.cmd` accurately distinguishes between the project's managed bypass instance and third-party `winws` instances (e.g. YouTube/Discord zapret), reporting external instances as `DETECTED [PID: ..., not managed]` without interfering with them.

### Changed
- **Documentation Accuracy**:
  - Corrected packet-filtering description: replaced absolute "exactly 12 packets" claim with empirical observation of UDP flow cessation shortly after initial handshake (clarified that 12 packets was observed in synthetic probe tests).
  - Clarified STUN/DPI mechanism: framed the technique as an empirical packet-crafting workaround rather than a definitive assertion about internal TSPU/DPI hardware state machine transitions.
  - Removed "zero jitter" phrasing: documented real-world observed latency of ~55–61 ms with significantly reduced jitter and steadier frame pacing compared to VLESS tunneling.
  - Clarified Auto Mode architecture: primarily event-driven via Windows WMI (`Win32_ProcessStartTrace` / `Win32_ProcessStopTrace`), complemented by 5-second safety reconciliation in case of dropped OS events.

---

## [v1.2.0] - 2026-09-27

### Added
- **Headless Event-Driven Auto Mode**:
  - `INSTALL_AUTO.cmd` / `scripts/install_auto.cmd`: Registers an elevated Windows scheduled task (`H1Z1-ROTK-Russia Auto Mode`) triggered at user logon.
  - `UNINSTALL_AUTO.cmd` / `scripts/uninstall_auto.cmd`: Cleanly removes the scheduled task, terminates background watcher and bypass processes, and unloads kernel drivers.
  - `scripts/watcher.ps1`: Fully event-driven lifecycle monitor listening for `H1Z1.exe` execution events via WMI (`Win32_ProcessStartTrace` and `Win32_ProcessStopTrace`).
  - **7-Second Exit Grace Period**: Automatically protects against brief game restarts or crashes before tearing down the packet filter.
  - **Zero Polling & Zero GUI**: Consumes practically 0% CPU; runs completely silently without popup consoles or taskbar clutter.
  - **Dynamic Driver Lifecycle**: WinDivert is unloaded from kernel space whenever H1Z1 is not running.
- **Enhanced Status Diagnostics**:
  - `STATUS.cmd` / `scripts/status.cmd`: Displays real-time status of Auto Mode task, watcher process PID, H1Z1 game process state, bypass PID, and WinDivert kernel driver state.
- **Minimal Release ZIP Structure**:
  - Root directory contains only end-user action scripts (`START.cmd`, `STOP.cmd`, `STATUS.cmd`, `INSTALL_AUTO.cmd`, `UNINSTALL_AUTO.cmd`, and `README.txt`).
  - All background binaries, drivers, payload files, configurations, and licenses are cleanly organized inside an isolated `_runtime/` folder.

### Changed
- **Documentation Refinements**:
  - Replaced rough latency estimates with exact, verified comparisons between VLESS tunneling (~60–80 ms baseline with ~140–170 ms jitter/spikes) and direct local bypass (~55–61 ms steady connection).
  - Clarified packet filtering descriptions to reflect empirically observed behavior on tested Beeline connections without unproven claims about internal ISP/TSPU hardware architectures.
  - Formalized explicit anti-cheat disclosure and BattlEye safety boundaries.
- **Universal Layout Support**:
  - Action scripts (`START.cmd`, `STOP.cmd`, `STATUS.cmd`, `INSTALL_AUTO.cmd`, `UNINSTALL_AUTO.cmd`) dynamically detect whether they are running inside the Release ZIP layout (`_runtime/`) or git repository layout (`bin/` & `config/`).

---

## [v1.0.0] - 2026-09-27

### Added
- **Direct UDP Desync**: Local packet filtering workaround enabling direct UDP gameplay to Return of the King (ROTK) servers on tested Russian ISP paths (Beeline).
- **Target Filter Scope**:
  - ROTK Login & Gateway: `162.19.94.95`
  - Dynamic ROTK Match Server Pool: `162.19.126.0/24` (`162.19.126.0` - `162.19.126.255`)
  - Target UDP Ports: `20000 - 23000`
- **Zero Impact on PC Traffic**: WinDivert filter strictly isolates ROTK UDP; all other network traffic (TCP, DNS, Discord, Steam, browsers) remains 100% untouched.
- **Convenience Automation Scripts**:
  - `START.cmd` / `scripts/start.cmd`: Automated administrator check, runtime verification, and single-click startup.
  - `STOP.cmd` / `scripts/stop.cmd`: Safe process termination targeting only this project's PID, plus driver cleanup.
  - `STATUS.cmd` / `scripts/status.cmd`: Instant diagnostic verifying process PID and driver state.
- **Documentation**:
  - Dual-language README (`README.md` in English, `README_RU.md` in Russian).
  - Detailed technical documentation: [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md), [docs/TECHNICAL_FINDINGS.md](docs/TECHNICAL_FINDINGS.md), [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), and [docs/TESTED_SERVERS.md](docs/TESTED_SERVERS.md).
