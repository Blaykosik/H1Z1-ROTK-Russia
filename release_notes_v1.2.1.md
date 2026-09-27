# H1Z1 ROTK Russia v1.2.1 HOTFIX

**H1Z1 ROTK Russia** — Local direct-connect UDP packet filter fix for H1Z1: Return of the King (ROTK) on Russian ISPs (Beeline direct route to OVH).

Version **v1.2.1** is a critical hotfix addressing process isolation, installation lifecycle stability, and documentation precision. **The proven network strategy and packet filter parameters remain byte-for-byte identical to v1.2.0.**

---

## What's Changed in v1.2.1

### 1. Strict Process & Driver Isolation (Zero Interference with Other `winws` / `zapret`)
* **Strict PID & Path Tracking**: All management scripts (`watcher.ps1`, `START.cmd`, `STOP.cmd`, `INSTALL_AUTO.cmd`, `UNINSTALL_AUTO.cmd`, `STATUS.cmd`) now validate both process ID and canonical binary path (`[System.IO.Path]::GetFullPath`).
* **No Blind Process Termination**: Completely eliminated all global `taskkill /IM winws.exe` and untracked `Stop-Process` commands. Only this project's dedicated `winws` instance is ever terminated.
* **Driver Service Coexistence**: WinDivert kernel driver is only stopped if NO other `winws` or `goodbyedpi` processes are running anywhere on the system. If you run zapret for YouTube/Discord, H1Z1-ROTK-Russia will never disrupt or terminate your other tools.

### 2. Decoupled Auto Mode Installation (`%ProgramData%`)
* `INSTALL_AUTO.cmd` copies the entire runtime, configs, watcher, and management scripts into `%ProgramData%\H1Z1-ROTK-Russia`.
* The Windows scheduled task targets `%ProgramData%\H1Z1-ROTK-Russia\watcher.ps1`, allowing users to safely move, archive, or delete the downloaded release ZIP folder without breaking Auto Mode.

### 3. Clean Uninstall Lifecycle
* `UNINSTALL_AUTO.cmd` unregisters the scheduled task, terminates the background watcher and bypass process, and cleanly removes `%ProgramData%\H1Z1-ROTK-Russia` even when launched directly from within the target folder.

### 4. Enhanced Status Diagnostics (`STATUS.cmd`)
* Differentiates between our managed bypass process and external `winws` instances (e.g. `Other winws: DETECTED [PID: ..., not managed]`).
* Displays real-time driver state, game process detection, and active desync profile.

### 5. Documentation Accuracy
* Clarified packet filtering description: reflects empirically observed UDP flow cessation shortly after initial handshake rather than an unverified universal packet count.
* Reframed STUN desync as an empirical packet-crafting workaround rather than a definitive statement about internal TSPU hardware states.
* Replaced "zero jitter" phrasing with measured ~55–61 ms steady direct latency and substantially reduced jitter compared to VLESS tunneling.
* Clarified Auto Mode architecture: primarily event-driven via Windows WMI (`Win32_ProcessStartTrace` / `Win32_ProcessStopTrace`) with 5s safety reconciliation.

---

## Русский / Russian Summary

Критический хотфикс v1.2.1:
* **Полная изоляция процессов**: скрипты проекта больше ни при каких обстоятельствах не трогают чужие процессы `winws.exe` (например, от zapret для YouTube/Discord). Завершается только собственный PID с проверкой полного пути исполняемого файла.
* **Безопасная работа драйвера**: сервис WinDivert выгружается только в том случае, если в системе нет других активных `winws` или `goodbyedpi`.
* **Автономная установка в `%ProgramData%`**: `INSTALL_AUTO.cmd` копирует рантайм в постоянную директорию `%ProgramData%\H1Z1-ROTK-Russia`. Скачанный архив и распакованную папку после установки можно удалять или перемещать.
* **Чистый деинсталлятор**: `UNINSTALL_AUTO.cmd` корректно удаляет задачу из планировщика, завершает процесс и удаляет папку рантайма даже при запуске прямо из неё.
* **Точная диагностика в `STATUS.cmd`**: видит чужие `winws.exe` и отображает их как неконтролируемые, не вмешиваясь в их работу.
* **Сетевая стратегия v1.2.0 не изменялась**: фильтр WinDivert, STUN-префикс и параметры desync полностью идентичны.

---

## Security & Verification / Безопасность и проверка

* 📖 **[Security, Trust & Anti-Cheat Architecture (EN)](https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/docs/SECURITY_AND_TRUST.md)**
* 📖 **[Безопасность, прозрачность и античит (RU)](https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/docs/SECURITY_AND_TRUST_RU.md)**
* 🔍 **[Binary Provenance & Upstream Verification Table](https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/BINARY_PROVENANCE.md)**
* 📋 **[Official SHA256SUMS.txt](https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/SHA256SUMS.txt)**

---

## Verification & Checksums

### Release Archive
| File | SHA-256 Checksum |
| :--- | :--- |
| `H1Z1-ROTK-Russia-v1.2.1.zip` | `3254258C51FC11BDBC4098BA1E4D9EA1994C6F56C04A009BD94E56E7379622C4` |

### Bundled Upstream Binaries (Verified Authentic)
| Binary | SHA-256 Checksum |
| :--- | :--- |
| `winws.exe` | `A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8` |
| `WinDivert.dll` | `C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2` |
| `WinDivert64.sys` | `8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2` |
| `cygwin1.dll` | `103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B` |
| `stun.bin` | `9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641` |
