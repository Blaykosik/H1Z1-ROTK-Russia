# How It Works: Technical Architecture

This document describes the root cause of the UDP flow termination observed on tested Russian ISP connections when playing H1Z1 ROTK, and explains how this local desync solution keeps the connection stable without a VPN.

---

## 1. The Direct UDP Problem

On the tested connection, sustained ROTK UDP sessions consistently stopped receiving replies shortly after connection establishment when connecting to ROTK game servers hosted on foreign datacenters (specifically OVH in Western Europe):

```mermaid
sequenceDiagram
    participant Game as H1Z1 Client
    participant ISP as Intermediate Network Filter
    participant Server as ROTK / OVH Server

    Game->>ISP: Datagram #1 (SessionRequest)
    ISP->>Server: Datagram #1
    Server->>ISP: SessionReply
    ISP->>Game: SessionReply (RTT ~55-60 ms)
    Game->>ISP: Subsequent Handshake Datagrams
    ISP->>Server: Subsequent Handshake Datagrams
    Server->>ISP: Handshake Replies
    ISP->>Game: Handshake Replies
    Note over ISP: Flow filter terminates unclassified UDP stream
    Game->>ISP: Datagram (Game World Data)
    Note over ISP: Datagrams dropped
    ISP--xServer: DROPPED
    Note over Game: No incoming replies. Connection drops.
```

### Observed Characteristics:
- **Connection Termination**: On the tested Beeline connection, direct unclassified UDP flows to OVH servers were terminated shortly after connection establishment if left untouched.
- **Selective Protocol Filtering**: Standard known protocols (such as standard DNS or WebRTC/STUN traffic) are not subjected to this restriction.
- **Target Specificity**: Non-OVH game servers and Russian domestic endpoints operated with 0% packet loss, confirming the restriction specifically impacts foreign hosting subnets (OVH `AS16276`).

---

## 2. The STUN Desync Solution

VLESS was playable and often stayed around roughly 60–80 ms, but the tunneled path introduced noticeable jitter and occasional latency spikes reaching approximately 140–170 ms on the tested setup. The direct local bypass keeps the native route and produced a much steadier connection with substantially reduced jitter compared with the tested VLESS path (~55–61 ms observed during testing).

The project applies a local STUN-based desynchronization strategy to initial UDP packets using `winws` and the kernel packet interception driver `WinDivert`.

```mermaid
sequenceDiagram
    participant Game as H1Z1 Client
    participant WinDivert as Local Filter (winws)
    participant ISP as Intermediate Network Filter
    participant Server as ROTK / OVH Server

    Game->>WinDivert: First Outbound UDP Datagram
    Note over WinDivert: Injects fake STUN Binding Request (RFC 5389)
    WinDivert->>ISP: [1] Fake STUN Datagram
    WinDivert->>ISP: [2] Real Game Datagram
    Note over ISP: Packet inspection allows flow (Hypothesis: STUN classification)
    ISP->>Server: [1] Fake STUN Datagram (Ignored by game engine)
    ISP->>Server: [2] Real Game Datagram (Processed normally)
    Server->>ISP: Game Session Reply
    ISP->>Game: Game Session Reply (Native RTT ~55-60 ms)
    Note over WinDivert: cutoff=d2: Desync disabled for remainder of flow
    loop Normal Gameplay
        Game->>Server: Unmodified Native UDP Packets
        Server->>Game: Unmodified Native UDP Packets
    end
```

### Key Technical Details:
1. **Single-Packet Handshake Prefix (`cutoff=d2`)**:
   `winws` injects a standard 100-byte STUN Binding Request (`stun.bin`, opcode `0x0001` with magic cookie `0x2112A442`) on the very first datagram of the flow.
2. **Intermediate Filter Behavior**:
   On the tested connection, the STUN prefix is sufficient to prevent the observed flow cutoff, allowing subsequent traffic to proceed. *(Note: The internal hardware classification mechanisms of provider filters cannot be independently inspected; the effectiveness of STUN classification is an empirical finding).*
3. **Server-Side Safety**:
   The ROTK server running on Linux receives the STUN datagram on port 20141 or 20214. Because the SOE/Daybreak game protocol engine does not recognize the STUN opcode, the server simply discards the STUN datagram and immediately processes the legitimate `SessionRequest` datagram right behind it.
4. **Zero Overhead for Active Gameplay**:
   Because of `--dpi-desync-cutoff=d2`, the desynchronization mechanism shuts off after the second packet of the flow. All subsequent game datagrams are passed 100% untouched at native wire speed directly to your physical network interface.
5. **Inbound Path Untouched**:
   The WinDivert filter captures only `outbound` traffic. Inbound packets from ROTK servers travel directly from your physical NIC to `H1Z1.exe` without passing through WinDivert, ensuring minimal latency and zero packet loss.

---

## 3. Server Endpoints & Dynamic Match Allocation

During live testing, two distinct server groups were discovered:

| Service | Destination IP | Destination Ports | Role |
| :--- | :--- | :--- | :--- |
| **Login & Gateway** | `162.19.94.95` | `20042-20045`, `20140-20141` | Account login, character selection, lobby menu |
| **Game Match Servers** | `162.19.126.0/24` | `20000 - 23000` | Dynamic match server instances (e.g. `162.19.126.166:20214`) |

By expanding the filter to cover the complete `/24` subnet:
```text
(ip.DstAddr == 162.19.94.95 or (ip.DstAddr >= 162.19.126.0 and ip.DstAddr <= 162.19.126.255)) and ((udp.DstPort >= 20000 and udp.DstPort <= 23000))
```
Every match instance allocated by the ROTK infrastructure is automatically protected, while 100% of all other PC traffic (Discord, Steam, web browsers, DNS) remains completely excluded from the filter.

---

## 4. Event-Driven Auto Mode Architecture (v1.2.1)

To avoid keeping a network packet filter permanently active on the system, Auto Mode provides a fully automated, headless lifecycle manager (`watcher.ps1`):

```mermaid
flowchart TD
    A[Windows User Logon] --> B[Task Scheduler starts watcher.ps1 from ProgramData]
    B --> C[Wait for Win32_ProcessStartTrace 'H1Z1.exe']
    C -- Event Fired / Safety Reconciliation --> D[Launch winws.exe from ProgramData & attach WinDivert]
    D --> E[Wait for Win32_ProcessStopTrace 'H1Z1.exe']
    E -- Event Fired / Safety Reconciliation --> F[Wait 7s Exit Grace Period]
    F --> G{Is H1Z1.exe restarted?}
    G -- Yes --> E
    G -- No --> H[Terminate ONLY project winws.exe]
    H --> I{Are other winws or tools active?}
    I -- No --> J[Safely unload WinDivert driver]
    I -- Yes --> K[Leave WinDivert driver intact for other tools]
    J --> C
    K --> C
```

- **Primarily Event-Driven via WMI**: Uses WMI kernel event listeners (`Win32_ProcessStartTrace` and `Win32_ProcessStopTrace`), with a low-frequency 5-second safety reconciliation tick in case an OS event is missed. Idle CPU consumption is practically 0%.
- **Stable `%ProgramData%` Location**: The runtime is installed to `%ProgramData%\H1Z1-ROTK-Russia`, making the service independent of whether the user moves or deletes the extracted download folder.
- **Strict Process Isolation**: Uses explicit PID and executable path validation (`(Get-Process).Path -eq $expectedPath`). Never terminates unrelated `winws`, `zapret`, or third-party DPI tools.
- **Safe Driver Lifecycle**: Checks whether any other `winws` or `goodbyedpi` process is active before unhooking the driver, preventing disruption to other tools.
- **Exit Grace Period**: When `H1Z1.exe` exits, the watcher waits 7 seconds before terminating `winws`. If the game was quickly restarted, the bypass remains active without dropping the driver.
- **Zero GUI**: Runs silently in the background with no taskbar icons or open console windows.
