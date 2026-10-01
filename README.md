# H1Z1 ROTK Russia

[English](#english) | [Русский](#русский)

Local direct-connect fix for **H1Z1 Return of the King (ROTK)** in Russia.  
Play with **native direct UDP** without VPNs, VLESS tunneling, VPS nodes, or remote relays.

* **Current Stable**: `v1.2.1`
* **Download**: [Release v1.2.1 Archive](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases/tag/v1.2.1) (`H1Z1-ROTK-Russia-v1.2.1.zip`)

---

# English

## Table of Contents
1. [What Is This?](#what-is-this)
2. [What Problem Does It Solve?](#what-problem-does-it-solve)
3. [Quick Start](#quick-start)
4. [Auto Mode (Recommended)](#auto-mode-recommended)
5. [Manual Mode (Portable)](#manual-mode-portable)
6. [Status & Diagnostics](#status--diagnostics)
7. [How It Works](#how-it-works)
8. [Network Scope & Dynamic Match Servers](#network-scope--dynamic-match-servers)
9. [Performance & Latency](#performance--latency)
10. [Security & Trust](#security--trust)
11. [BattlEye & Anti-Cheat Policy](#battleye--anti-cheat-policy)
12. [Antivirus Detections & Heuristics](#antivirus-detections--heuristics)
13. [Binary Provenance & Checksums](#binary-provenance--checksums)
14. [Troubleshooting](#troubleshooting)
15. [Uninstallation](#uninstallation)
16. [Requirements & Limitations](#requirements--limitations)
17. [Third-Party Credits & Licenses](#third-party-credits--licenses)
18. [Disclaimer](#disclaimer)

---

## What Is This?
**H1Z1 ROTK Russia** is a lightweight, dedicated network packet filter profile for H1Z1: Return of the King (ROTK). Built on the well-known open-source packet manipulation engine **zapret** (`winws`) and the **WinDivert** kernel driver, it eliminates the artificial UDP flow cutoff encountered when connecting to foreign ROTK servers from Russian ISPs while preserving your native, unproxied physical internet connection.

---

## What Problem Does It Solve?
On the tested Beeline fiber connection in the Moscow region, sustained direct UDP streams to foreign hosting datacenters (specifically OVH in France/Germany) were terminated shortly after connection establishment if left unmodified.

This causes:
* Launcher hanging during login or character loading;
* Datacenter ping displaying "low quality" or "unavailable";
* Connecting to the lobby successfully, but hanging indefinitely on `"Waiting for world ready"` when entering a match.

While tunneling through a VPS (VPN / VLESS) can bypass the blockage, it introduces routing overhead, packet jitter, and latency spikes (~140–170 ms). This project resolves the problem **locally on your Windows PC** while keeping the route direct. In testing from the Moscow region, direct latency was **55–61 ms**.

---

## Quick Start
1. Download **`H1Z1-ROTK-Russia-v1.2.1.zip`** from [GitHub Releases](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases/tag/v1.2.1).
2. Extract the ZIP archive to any folder.
3. Choose either **Auto Mode** (install once, fully automated) or **Manual Mode** (portable, no install).

Verify the download checksum in PowerShell:
```powershell
Get-FileHash .\H1Z1-ROTK-Russia-v1.2.1.zip -Algorithm SHA256
```
Expected SHA-256: `657C44C9B4560171C17B241CF786CDB0309B55543C9D10D8480EFC10AF822DFA`

---

## Auto Mode (Recommended)
Auto Mode installs the runtime to `%ProgramData%\H1Z1-ROTK-Russia` and sets up a background event-driven monitor:
* **Event-Driven Lifecycle**: Uses Windows WMI kernel events (`Win32_ProcessStartTrace` and `Win32_ProcessStopTrace`) to monitor `H1Z1.exe`. Consumes practically 0% CPU at idle.
* **Automatic Toggle**: Turns the packet filter ON when `H1Z1.exe` starts, and unloads it 7 seconds after the game closes.
* **Safe Driver Management**: WinDivert is unloaded when the game exits, unless other tools (like YouTube/Discord zapret) are also using it.
* **Completely Headless**: Runs silently in the background with no console popups or system tray icons.
* **Independent of Download Folder**: Once installed, you can safely move or delete the extracted ZIP folder!

### How to Install:
1. Right-click **`INSTALL_AUTO.cmd`** and select **Run as administrator**.
2. Done! Launch ROTK whenever you want to play.

---

## Manual Mode (Portable)
Manual Mode does not install persistent components. WinDivert is loaded temporarily while the bypass is active and is unloaded when the bypass stops:
1. Right-click **`START.cmd`** and select **Run as administrator**.
2. Launch ROTK normally and play.
3. When finished, press any key in the `START` console window or run **`STOP.cmd`** to unload the filter.

---

## Status & Diagnostics
Run **`STATUS.cmd`** at any time to inspect:
* **Auto Mode Task**: Whether the Windows logon task is active;
* **Auto Watcher**: Whether the background WMI monitor process is running;
* **Game Process**: Whether `H1Z1.exe` is currently detected;
* **Project Bypass**: Whether this project's `winws` filter is active (PID);
* **Other winws**: Checks if an independent `winws` instance (e.g. for YouTube/Discord) is running—it will be reported as `not managed`, confirming strict isolation;
* **Driver Service**: Current status of the `WinDivert` kernel driver.

---

## How It Works
The project applies a STUN-based desynchronization strategy to the initial ROTK UDP packets. On the tested connection, this prevents the observed UDP flow interruption while the actual game traffic continues directly to the ROTK servers:

```
H1Z1.exe (Game Client)
  │
  ├──► [1] WinDivert driver intercepts outbound UDP to ROTK server
  │    └── winws injects dummy RFC 5389 STUN Binding Request prefix (stun.bin) on datagram #1
  │
  ├──► [2] Initial STUN-based desync packet sent; flow remains uninterrupted on tested route
  │
  ├──► [3] ROTK Server receives datagrams:
  │    ├── Ignores unrecognized STUN datagram
  │    └── Processes legitimate game session handshake datagram
  │
  └──► [4] Desync shuts off (--dpi-desync-cutoff=d2):
       All subsequent gameplay packets pass 100% UNMODIFIED at native line speed
```

* **Targeted Interception**: WinDivert intercepts only the initial packets of ROTK UDP flows.
* **Server-Side Safety**: ROTK servers ignore the inert STUN datagram and accept the game handshake.
* **Zero Active Gameplay Overhead**: After the second packet of each flow (`cutoff=d2`), packet modification completely stops. Inbound packets and active gameplay datagrams are never altered.

---

## Network Scope & Dynamic Match Servers
The WinDivert filter string is strictly bounded to ROTK server infrastructure:
```text
outbound and ip and udp and (ip.DstAddr == 162.19.94.95 or (ip.DstAddr >= 162.19.126.0 and ip.DstAddr <= 162.19.126.255)) and udp.DstPort >= 20000 and udp.DstPort <= 23000
```

* **Login & Gateway**: `162.19.94.95` (ports `20042-20045`, `20140-20141`)
* **Dynamic Match Server Pool**: `162.19.126.0/24` (ports `20000 - 23000`)
* **What is excluded**: Traffic outside the configured destination IP/protocol/port scope is excluded from this WinDivert filter (Discord, Steam, web browsers, DNS, other games).

---

## Performance & Latency
Testing on a direct Beeline fiber connection from the Moscow region, Russia, to OVH France:
* **Direct Bypass (This Project)**: **55–61 ms** latency during the tested gameplay sessions, with substantially less jitter. No packet loss was observed during those sessions.
* **Tunneling (VLESS / VPN)**: ~60–80 ms baseline with route jitter and periodic spikes up to 140–170 ms.

---

## Security & Trust
We believe in full transparency and verification rather than blind trust:
* ❌ **No DLL or code injection**: Does not use `CreateRemoteThread`, `SetWindowsHookEx`, or DLL injection.
* ❌ **No memory reading or tampering**: Does not call `OpenProcess`, `ReadProcessMemory`, or `WriteProcessMemory`.
* ❌ **No game file modifications**: `H1Z1.exe`, game assets, and launcher files remain 100% untouched.
* ❌ **No gameplay manipulation**: No aimbot, wallhack, speedhack, or hitbox tampering.
* ❌ **No BattlEye tampering**: Does not touch, hook, or disable the BattlEye anti-cheat engine.
* ❌ **Zero telemetry**: Collects no analytics, no user statistics, and sends no data anywhere.
* ❌ **Zero credential access**: Never accesses Steam passwords, session tokens, or ROTK account keys.
* ❌ **No proxy or remote relay**: Traffic is not routed through any developer-owned server.
* ❌ **No background auto-updater**: Never downloads or executes remote code dynamically.

---

## BattlEye & Anti-Cheat Policy
* The project runs as an independent Windows network filtering service alongside the game. It does not touch game memory, files, or anti-cheat components.
* According to the [official BattlEye FAQ](https://www.battleye.com/support/faq/):
  > *"When do you ban?"*  
  > *"We only ban for intentional cheating/hacking and software/hardware that is designed to circumvent BattlEye protection."*  
  > *"Incompatible third-party software may be blocked or result in a kick from the game, which is not in itself a ban."*
* **Honest Disclosures**:
  * We do **not** make marketing claims like "100% ban safe" or "impossible to get banned".
  * We are **not** officially endorsed or approved by BattlEye Innovations or the ROTK team.
  * Successfully tested in live ROTK gameplay, but future BattlEye/ROTK policies cannot be guaranteed.

---

## Antivirus Detections & Heuristics
Windows Defender or third-party antivirus software may occasionally flag `winws.exe` or `WinDivert64.sys` as `RiskTool`, `PUA`, or `HackTool`.
* **Why**: `WinDivert64.sys` is a low-level packet capture driver, and `winws.exe` modifies packet headers. Antivirus heuristics generically flag raw packet tools (the upstream author of zapret documents this explicitly).
* **Our Policy**: We **never** run commands like `Add-MpPreference -ExclusionPath` to silently whitelist files. All security decisions remain in your hands.
* **Verification Workflow**:
  1. Verify the release archive SHA-256 against the table below.
  2. Inspect the plain-text `.cmd` and `.ps1` scripts in any text editor.
  3. Only if satisfied, add an exclusion for `%ProgramData%\H1Z1-ROTK-Russia` or your portable folder.

---

## Binary Provenance & Checksums
All bundled third-party binaries are byte-for-byte unchanged from their documented upstream artifacts ([zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)). `stun.bin` is a project-owned static 100-byte STUN payload, not executable code:

| File | Purpose | Upstream Source | Upstream Version | SHA-256 Checksum | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| `bin/winws.exe` | Packet desync engine | [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) | `v72.13` x86_64 | `A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8` | Unmodified |
| `bin/WinDivert.dll` | User-mode driver DLL | [WinDivert](https://github.com/basil00/WinDivert) | WinDivert 2.2 / `v72.13` | `C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2` | Unmodified |
| `bin/WinDivert64.sys` | Kernel packet filter driver | [WinDivert](https://github.com/basil00/WinDivert) | WinDivert 2.2 / `v72.13` | `8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2` | Unmodified (Signed) |
| `bin/cygwin1.dll` | POSIX runtime library | [Cygwin](https://cygwin.com/) | Cygwin 3.4.10 / `v72.13` | `103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B` | Unmodified |
| `bin/stun.bin` | Dummy STUN packet prefix | Project Synthetic Frame | RFC 5389 (100 bytes) | `9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641` | Static Data |

* `stun.bin` is a static 100-byte RFC 5389 STUN Binding Request (`Magic Cookie: 0x2112A442`). It contains **no executable code or shellcode**.
* `WinDivert64.sys` carries an authentic digital signature from Basil (upstream author). Verify via file Properties -> Digital Signatures.

---

## Troubleshooting
* **"Administrator privileges are required"**: Right-click the `.cmd` script and choose **Run as administrator**. WinDivert requires elevation to filter packets.
* **Lobby connects, but Match loading hangs ("Waiting for world ready")**: ROTK might have allocated a match server in a newly added IP block outside `162.19.126.0/24`. Check your game log (`H1Z1 PlayClient (Live).log`) for the destination IP and open a GitHub Issue.
* **`winws.exe` fails to start**: Another program using WinDivert (such as GoodbyeDPI or a conflicting zapret instance) may be running. Stop the conflicting tool or run `STOP.cmd` and try again.
* **Antivirus quarantined a file**: Check your antivirus protection history, verify the file SHA-256 against the table above, and restore/exclude the file if verified.
* **How to verify status**: Run **`STATUS.cmd`** to see whether the watcher, game, bypass, and driver are active.

---

## Uninstallation
To completely remove Auto Mode:
1. Right-click **`UNINSTALL_AUTO.cmd`** and select **Run as administrator** (from your extracted folder or from `%ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd`).
2. The script unregisters the scheduled task, stops the watcher, terminates the bypass, and deletes `%ProgramData%\H1Z1-ROTK-Russia`.

For Manual Mode, simply delete the downloaded folder.

---

## Requirements & Limitations
* **OS**: Windows 10 or Windows 11 (64-bit).
* **Privileges**: Administrator rights required to load the WinDivert kernel driver.
* **ISP Coverage**: Tested on a Beeline fiber connection from the Moscow region to OVH. Results, including latency, may differ on other routes or ISPs.

---

## Third-Party Credits & Licenses
* **[zapret (winws)](https://github.com/bol-van/zapret)** by bol-van — MIT License ([LICENSES/LICENSE.zapret.txt](LICENSES/LICENSE.zapret.txt))
* **[WinDivert](https://github.com/basil00/Divert)** by basil00 — LGPLv3 / GPLv2 ([LICENSES/LICENSE.windivert.txt](LICENSES/LICENSE.windivert.txt))
* **[Cygwin](https://cygwin.com/)** by Red Hat and Cygwin Contributors — LGPLv3+ ([LICENSES/LICENSE.cygwin.txt](LICENSES/LICENSE.cygwin.txt))

---

## Disclaimer
This project is an independent community compatibility utility. It is **not** affiliated with, authorized, maintained, sponsored, or endorsed by Return of the King (ROTK), Daybreak Game Company, Standing Stone Games, BattlEye Innovations, bol-van, or the WinDivert project. All trademarks belong to their respective owners.

---

# Русский

## Содержание
1. [Что это такое?](#что-это-такое)
2. [Какую проблему решает проект?](#какую-проблему-решает-проект)
3. [Быстрый старт](#быстрый-старт)
4. [Авторежим (Рекомендуется)](#авторежим-рекомендуется)
5. [Ручной режим (Портативный)](#ручной-режим-портативный)
6. [Диагностика и статус](#диагностика-и-статус)
7. [Как это работает?](#как-это-работает)
8. [Область действия фильтра](#область-действия-фильтра)
9. [Сравнение задержки и стабильности](#сравнение-задержки-и-стабильности)
10. [Безопасность и приватность](#безопасность-и-приватность)
11. [Политика BattlEye и античит](#политика-battleye-и-античит)
12. [Срабатывания антивирусов и эвристика](#срабатывания-антивирусов-и-эвристика)
13. [Происхождение бинарников и контрольные суммы](#происхождение-бинарников-и-контрольные-суммы)
14. [Решение проблем](#решение-проблем)
15. [Удаление](#удаление)
16. [Системные требования и ограничения](#системные-требования-и-ограничения)
17. [Сторонние компоненты и лицензии](#сторонние-компоненты-и-лицензии)
18. [Правовая оговорка](#правовая-оговорка)

---

## Что это такое?
**H1Z1 ROTK Russia** — это узкоспециализированная конфигурация локального сетевого фильтра для игры H1Z1: Return of the King (ROTK). Проект создан на базе проверенного open-source движка **zapret** (`winws`) и драйвера **WinDivert**.

Если вы знакомы с zapret для YouTube/Discord: H1Z1 ROTK Russia использует тот же самый `winws`/WinDivert networking stack, но с узким профилем только для UDP-серверов ROTK. Это позволяет устранить искусственный обрыв UDP-сессий на российских провайдерах без использования VPN, VLESS, VPS или сторонних серверов.

---

## Какую проблему решает проект?
На протестированном подключении Билайн в Московском регионе UDP-сессии с зарубежными дата-центрами OVH (Франция/Германия) обрывались вскоре после установления соединения без применения обхода.

Это приводит к следующим симптомам:
* Лаунчер зависает при входе в учетную запись или загрузке персонажа;
* В меню выбора региона дата-центры отображаются со статусом «low quality» или «unavailable»;
* В лобби заходит успешно, но при поиске игры загрузка намертво зависает на экране `"Waiting for world ready"`.

Использование VPN или VLESS решает проблему обрыва, но создает дополнительный сетевой джиттер и скачки пинга (до 140–170 мс). Данный проект решает проблему **локально на вашем ПК**, сохраняя **прямой маршрут провайдера**. При тестировании в Московском регионе пинг по прямому маршруту составил **55–61 мс**.

---

## Быстрый старт
1. Скачайте архив **`H1Z1-ROTK-Russia-v1.2.1.zip`** со страницы [GitHub Releases](https://github.com/Blaykosik/H1Z1-ROTK-Russia/releases/tag/v1.2.1).
2. Распакуйте архив в удобное место.
3. Выберите подходящий режим: **Авторежим** (установка в один клик, полностью автоматическая работа) или **Ручной режим** (портативный запуск без установки).

Проверка контрольной суммы архива в PowerShell:
```powershell
Get-FileHash .\H1Z1-ROTK-Russia-v1.2.1.zip -Algorithm SHA256
```
Ожидаемый хэш SHA-256: `657C44C9B4560171C17B241CF786CDB0309B55543C9D10D8480EFC10AF822DFA`

---

## Авторежим (Рекомендуется)
Авторежим копирует необходимые файлы в системную папку `%ProgramData%\H1Z1-ROTK-Russia` и запускает фоновый монитор при входе в Windows:
* **Событийная модель WMI**: отслеживает запуск и завершение процесса `H1Z1.exe` через события ядра Windows (`Win32_ProcessStartTrace` / `Win32_ProcessStopTrace`). В режиме ожидания нагрузка на процессор практически 0%.
* **Автоматическое включение и выключение**: обход активируется при старте `H1Z1.exe` и автоматически выгружается через 7 секунд после закрытия игры.
* **Безопасная выгрузка драйвера**: сетевой драйвер WinDivert выгружается после закрытия игры, только если в системе нет других активных утилит (например, zapret для YouTube или Discord).
* **Полная изоляция процессов**: скрипты завершают исключительно собственный PID `winws.exe`, проверяя полный путь к исполняемому файлу. Чужие копии `winws` никогда не затрагиваются.
* **Работа без GUI**: служба работает полностью в фоне, не создавая окон консоли или значков в трее.
* **Независимость от загрузок**: после установки скачанный архив и распакованную папку можно безопасно переместить или удалить!

### Инструкция по установке:
1. Нажмите правой кнопкой мыши по **`INSTALL_AUTO.cmd`** и выберите **«Запуск от имени администратора»**.
2. Готово! Запускайте ROTK и играйте в любое время.

---

## Ручной режим (Портативный)
Ручной режим не устанавливает постоянные компоненты. WinDivert временно загружается на время работы обхода и выгружается после его остановки:
1. Нажмите правой кнопкой мыши по **`START.cmd`** и выберите **«Запуск от имени администратора»**.
2. Запустите лаунчер ROTK и заходите в игру.
3. После завершения игры нажмите любую клавишу в окне `START` или запустите **`STOP.cmd`** для остановки фильтра.

---

## Диагностика и статус
Запустите **`STATUS.cmd`** в любое время для проверки текущего состояния:
* **Auto Mode Task**: статус задачи авторежима в Планировщике Windows;
* **Auto Watcher**: статус и PID фонового процесса WMI-монитора;
* **Game Process**: обнаружен ли запущенный процесс `H1Z1.exe`;
* **H1Z1 ROTK Bypass**: статус и PID рабочего процесса `winws`;
* **Other winws**: проверка наличия сторонних копий `winws` (отображаются как `not managed`, подтверждая отсутствие вмешательства);
* **Driver Service**: текущее состояние службы драйвера `WinDivert`.

---

## Как это работает?
Проект применяет STUN-based desync-стратегию к начальным UDP-пакетам ROTK. На протестированном подключении этого достаточно, чтобы предотвратить наблюдаемый обрыв UDP-сессии, после чего игровой трафик продолжает идти напрямую к серверам ROTK:

```
H1Z1.exe (Игровой клиент)
  │
  ├──► [1] Драйвер WinDivert перехватывает исходящий UDP к серверам ROTK
  │    └── winws отправляет фиктивный префикс STUN Binding Request (stun.bin, RFC 5389)
  │
  ├──► [2] Отправлен начальный desync-пакет; поток не обрывается на протестированном маршруте
  │
  ├──► [3] Сервер ROTK получает пакеты:
  │    ├── Игнорирует неизвестный ему STUN-пакет
  │    └── Штатно обрабатывает следующий за ним пакет игровой сессии
  │
  └──► [4] Десинхронизация отключается (--dpi-desync-cutoff=d2):
       Все последующие игровые пакеты идут НАПРЯМУЮ БЕЗ ИЗМЕНЕНИЙ на полной скорости кабеля
```

* **Точечный перехват**: фильтр обрабатывает только первые пакеты UDP-потока ROTK.
* **Безопасность для сервера**: игровой сервер игнорирует тестовый STUN-пакет и штатно принимает рукопожатие игры.
* **Ноль накладных расходов в матче**: после второго пакета (`cutoff=d2`) модификация пакетов полностью выключается. Весь входящий трафик и активный геймплей идут без задержек напрямую через вашу сетевую карту.

---

## Область действия фильтра
Фильтр WinDivert строго ограничен адресами игровой инфраструктуры ROTK:
```text
outbound and ip and udp and (ip.DstAddr == 162.19.94.95 or (ip.DstAddr >= 162.19.126.0 and ip.DstAddr <= 162.19.126.255)) and udp.DstPort >= 20000 and udp.DstPort <= 23000
```

* **Логин и шлюз**: `162.19.94.95` (порты `20042-20045`, `20140-20141`)
* **Пул динамических серверов матчей**: `162.19.126.0/24` (порты `20000 - 23000`)
* **Что не затрагивается**: Трафик, не соответствующий заданным IP-адресам, протоколу и диапазону портов, не попадает под этот WinDivert-фильтр (Discord, Steam, браузеры, DNS, другие игры).

---

## Сравнение задержки и стабильности
Результаты тестирования на прямом подключении Билайн из Московского региона до OVH во Франции:
* **Прямой обход (данный проект)**: пинг **55–61 мс** во время тестовых игровых сессий, существенно меньше джиттера. Потери пакетов в этих сессиях не наблюдались.
* **Туннелирование (VLESS / VPN)**: базовый пинг ~60–80 мс с колебаниями и периодическими скачками задержки до 140–170 мс.

---

## Безопасность и приватность
Проект придерживается принципа полной открытости и проверяемости кода:
* ❌ **Нет инжектов кода и DLL**: не используются вызовы `CreateRemoteThread`, `SetWindowsHookEx` и перехват функций.
* ❌ **Нет чтения или изменения памяти**: в коде отсутствуют вызовы `OpenProcess`, `ReadProcessMemory` и `WriteProcessMemory`.
* ❌ **Нет изменения файлов игры**: `H1Z1.exe`, ресурсы и лаунчер остаются на 100% оригинальными.
* ❌ **Нет вмешательства в геймплей**: нет аимботов, вх, спидхаков или изменения хитбоксов.
* ❌ **Нет вмешательства в BattlEye**: проект не взаимодействует с API античита и не отключает его службы.
* ❌ **Ноль телеметрии**: нет сбора аналитики, системных метрик или трекеров.
* ❌ **Ноль доступа к учетным данным**: проект не касается паролей Steam, токенов сессий или ключей ROTK.
* ❌ **Нет удаленных прокси**: игровой трафик не проходит через серверы автора.
* ❌ **Нет автообновлений**: исполняемый код никогда не скачивается из сети в фоновом режиме.

---

## Политика BattlEye и античит
* Проект работает как независимый сетевой сервис Windows параллельно с игрой, не затрагивая процесс игры или античита.
* В [официальном FAQ BattlEye](https://www.battleye.com/support/faq/) указано:
  > *"When do you ban?"*  
  > *"Мы баним только за намеренное использование читов/хаков и ПО/оборудования, специально предназначенного для обхода защиты BattlEye."*  
  > *"Несовместимое стороннее ПО может быть заблокировано или привести к исключению (kick) из игры, что само по себе не является баном."*
* **Честная позиция**:
  * Мы **не** используем маркетинговые обещания вроде «100% защита от бана» или «бан невозможен».
  * Проект **не** имеет официального одобрения от BattlEye Innovations или команды ROTK.
  * Успешно протестировано в реальных матчах ROTK, однако будущие изменения политик BattlEye/ROTK не могут быть гарантированы.

---

## Срабатывания антивирусов и эвристика
Защитник Windows (Windows Defender) или сторонние антивирусы могут реагировать на `winws.exe` или `WinDivert64.sys` с пометками `RiskTool`, `PUA` или `HackTool`.
* **Причина**: драйвер `WinDivert64.sys` работает с сырыми пакетами на уровне ядра, а `winws.exe` изменяет заголовки пакетов. Эвристические анализаторы по умолчанию помечают сетевые низкоуровневые инструменты (автор zapret прямо предупреждает об этом в официальном репозитории).
* **Наша позиция**: скрипты проекта **никогда** не пытаются принудительно добавить себя в исключения Defender (команда `Add-MpPreference` исключена). Решение всегда остается за пользователем.
* **Рекомендуемый порядок проверки**:
  1. Сверьте контрольную сумму SHA-256 архива по таблице ниже.
  2. Просмотрите открытый исходный код скриптов `.cmd` и `.ps1` в блокноте.
  3. Только после самостоятельной проверки добавьте папку `%ProgramData%\H1Z1-ROTK-Russia` в исключения антивируса.

---

## Происхождение бинарников и контрольные суммы
Все сторонние бинарные файлы побайтово неизменны относительно задокументированных upstream-релизов ([zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)). `stun.bin` — собственный статический 100-байтовый STUN-пакет проекта, не являющийся исполняемым кодом:

| Файл | Назначение | Источник (Upstream) | Версия | Хэш SHA-256 | Статус |
| :--- | :--- | :--- | :--- | :--- | :---: |
| `bin/winws.exe` | Движок десинхронизации | [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) | `v72.13` x86_64 | `A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8` | Без изменений |
| `bin/WinDivert.dll` | Пользовательская DLL | [WinDivert](https://github.com/basil00/WinDivert) | WinDivert 2.2 / `v72.13` | `C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2` | Без изменений |
| `bin/WinDivert64.sys` | Сетевой драйвер ядра | [WinDivert](https://github.com/basil00/WinDivert) | WinDivert 2.2 / `v72.13` | `8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2` | Оригинал (Подписан) |
| `bin/cygwin1.dll` | POSIX рантайм для winws | [Cygwin](https://cygwin.com/) | Cygwin 3.4.10 / `v72.13` | `103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B` | Без изменений |
| `bin/stun.bin` | STUN-префикс пакета | Синтетический фрейм проекта | RFC 5389 (100 байт) | `9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641` | Статические данные |

* Файл `stun.bin` представляет собой 100-байтовый запрос STUN Binding Request по RFC 5389 (`Magic Cookie: 0x2112A442`) и **не содержит исполняемого кода**.
* Драйвер `WinDivert64.sys` имеет официальную цифровую подпись разработчика Basil. Проверить: Свойства файла -> Цифровые подписи.

---

## Решение проблем
* **«Administrator privileges are required»**: Запустите скрипт через правый клик -> **Запуск от имени администратора**. Драйверу WinDivert требуются системные привилегии.
* **В лобби пускает, а в катку нет («Waiting for world ready»)**: ROTK мог выделить сервер матча из нового пула IP, отличного от `162.19.126.0/24`. Проверьте лог игры (`H1Z1 PlayClient (Live).log`), найдите целевой IP/порт и откройте Issue на GitHub.
* **`winws.exe` не запускается**: Другая программа перехвата пакетов (например, GoodbyeDPI или zapret для Discord) может удерживать драйвер. Остановите стороннюю утилиту или выполните `STOP.cmd`.
* **Антивирус заблокировал или удалил файл**: Откройте историю защиты антивируса, сверьте хэш SHA-256 по таблице выше и добавьте рабочую папку в исключения.
* **Как проверить статус работы**: Запустите **`STATUS.cmd`** для отображения состояния вотчера, игры, байпаса и службы драйвера.

---

## Удаление
Полное удаление Авторежима:
1. Запустите **`UNINSTALL_AUTO.cmd`** от имени администратора (из распакованной папки или из `%ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd`).
2. Скрипт остановит службу, удалит задачу из Планировщика Windows и полностью удалит рабочую папку `%ProgramData%\H1Z1-ROTK-Russia`.

Для Ручного режима достаточно просто удалить распакованную папку.

---

## Системные требования и ограничения
* **Операционная система**: Windows 10 или Windows 11 (64-бит).
* **Права**: Права администратора для запуска драйвера ядра.
* **Провайдер**: Проверено на оптоволоконном подключении Билайн из Московского региона до OVH. На других маршрутах и у других операторов результаты, включая пинг, могут отличаться.

---

## Сторонние компоненты и лицензии
* **[zapret (winws)](https://github.com/bol-van/zapret)** автора bol-van — Лицензия MIT ([LICENSES/LICENSE.zapret.txt](LICENSES/LICENSE.zapret.txt))
* **[WinDivert](https://github.com/basil00/Divert)** автора basil00 — Лицензии LGPLv3 / GPLv2 ([LICENSES/LICENSE.windivert.txt](LICENSES/LICENSE.windivert.txt))
* **[Cygwin](https://cygwin.com/)** от Red Hat и контрибьюторов Cygwin — Лицензия LGPLv3+ ([LICENSES/LICENSE.cygwin.txt](LICENSES/LICENSE.cygwin.txt))

---

## Правовая оговорка
Этот проект является независимой любительской конфигурацией совместимости. Проект **не** связан, не спонсируется и не поддерживается Return of the King (ROTK), Daybreak Game Company, Standing Stone Games, BattlEye Innovations, bol-van или проектом WinDivert. Все торговые марки принадлежат их законным владельцам.
