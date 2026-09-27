# Changelog

All notable changes to this project are documented in this file.

---

## [v1.2.1] - 2026-09-27 (Current Stable Release)

* **Direct ROTK UDP workaround**: Native low-latency UDP packet filter based on `zapret` (`winws`) and `WinDivert`.
* **Headless Auto Mode**: Fully automated lifecycle management tied to the `H1Z1.exe` process via Windows WMI events.
* **Persistent Runtime Location**: Automated installation under `%ProgramData%\H1Z1-ROTK-Russia`.
* **Strict Process & Driver Isolation**: Complete isolation from unrelated `winws`, `zapret`, or other DPI bypass instances.
* **Dual-Language Documentation**: Comprehensive English and Russian user guides.
* **Security & Trust Framework**: Explicit anti-cheat policy, antivirus heuristic explanations, and privacy audit.
* **Binary Provenance**: Upstream verification table, standard RFC 5389 payload specification, and SHA-256 checksums.
