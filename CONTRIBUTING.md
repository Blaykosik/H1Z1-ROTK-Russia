# Contributing to H1Z1 ROTK Russia

Thank you for your interest in improving direct connectivity for H1Z1 ROTK!

---

## 1. Core Principle: Preserve Verified Stability

The primary objective of this repository is maintaining a rock-solid, verified direct UDP connection.

> [!IMPORTANT]
> Any pull request that proposes changing the desync strategy, timing, or packet parameters **MUST** include empirical packet-level regression test results demonstrating 0% packet loss on live servers over extended testing sessions.

Do not submit changes that:
- Switch to untested upstream experimental tools without prior discussion and verification.
- Broaden the WinDivert filter to non-ROTK ports or services.
- Introduce auto-updaters, third-party network proxies, or closed-source helper binaries.

---

## 2. Reporting New ROTK Server Ranges

If ROTK adds new match server pools or changes login gateways that fall outside `162.19.94.95` and `162.19.126.0/24`:
1. Check the destination IP and UDP port from your local connection diagnostic.
2. Open a GitHub Issue using the **Server Endpoint Update** or **Bug Report** template.
3. Include only the destination IP and UDP port — never post session tickets or account tokens.

---

## 3. Pull Request Guidelines

1. Fork the repository and create your branch from `main`.
2. Test your changes locally on Windows using the provided scripts.
3. Ensure no personal configuration data, IP logs, or sensitive artifacts are included in your commit.
4. Keep commit messages concise, descriptive, and focused.
