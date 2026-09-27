# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
