# Security Policy

## 1. Local-Only Execution & Privacy

This project is strictly a local packet-level helper that operates entirely on your Windows computer:
- **No Telemetry / No Analytics**: The project does not collect, record, transmit, or monitor any user telemetry or game data.
- **No Remote Infrastructure**: There are no proxy servers, VPS nodes, or remote relays operated by this project.
- **No Credentials**: This project never interacts with, reads, or stores your ROTK account credentials, Steam passwords, session tokens, or player keys.
- **No Game File Modification**: Game executables (`H1Z1.exe`), launcher files, and anti-cheat modules (`BattlEye`) are never patched, modified, or hooked.

---

## 2. Safe Issue Reporting & Private Information

> [!CAUTION]
> **NEVER post sensitive personal information in public GitHub Issues or discussions!**

When reporting issues or diagnostics, **DO NOT** include:
- Passwords or account credentials
- Session tokens, tickets, or authorization headers
- VPN/VLESS configs or personal cryptographic keys
- Full game log files that might contain unique account GUIDs or IP addresses

When submitting diagnostic information, provide **only**:
1. Destination IP and port (e.g. `162.19.126.166:20214`)
2. Observed symptom (e.g. "hangs at title screen" or "match loading timeout")
3. Operating System version and ISP name

---

## 3. Reporting a Vulnerability

If you discover a security vulnerability in this project's scripts or configuration, please report it privately through GitHub Security Advisories:
- Go to the repository's **Security** tab.
- Click **Report a vulnerability**.
- Provide a clear description and reproducible steps.
