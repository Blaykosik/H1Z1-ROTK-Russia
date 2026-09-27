# How It Works: Technical Architecture

This document describes the root cause of the UDP flow termination observed on tested Russian ISP connections when playing H1Z1 ROTK, and explains how this local desync solution keeps the connection stable without a VPN.

---

## 1. The Direct UDP Problem

When H1Z1 connects to ROTK game servers hosted on foreign datacenters (specifically OVH in Western Europe), the network flow establishes an initial UDP handshake:

```mermaid
sequenceDiagram
    participant Game as H1Z1 Client
    participant ISP as ISP Filter (TSPU)
    participant Server as ROTK / OVH Server

    Game->>ISP: Datagram #1 (SessionRequest)
    ISP->>Server: Datagram #1
    Server->>ISP: SessionReply
    ISP->>Game: SessionReply (RTT ~55-60 ms)
    Note over ISP: State counter: 1 / 12 allowed
    Game->>ISP: Datagrams #2 .. #12 (Login / Auth)
    ISP->>Server: Datagrams #2 .. #12
    Server->>ISP: Replies #2 .. #12
    ISP->>Game: Replies #2 .. #12
    Note over ISP: Counter reaches 12 packets!
    Game->>ISP: Datagram #13 (Game World Data)
    Note over ISP: Packet #13 blackholed!
    ISP--xServer: DROPPED
    Note over Game: No incoming replies. Connection drops.
```

### Observed Characteristics:
- **Exact Packet Counter**: The block does not trigger based on a time duration or bandwidth limit. Probing at 1 packet per second survived for 11+ seconds before cutting off on packet #13. Probing at 10 packets per second was cut off after ~1.16 seconds.
- **Selective Protocol Filtering**: Known protocol flows (such as standard DNS or WebRTC/STUN traffic) are not subjected to this counter restriction.
- **Target Specificity**: Non-OVH game servers and Russian domestic endpoints operated with 0% packet loss, confirming the restriction specifically impacts foreign hosting subnets (OVH `AS16276`).

---

## 2. The STUN Desync Solution

Instead of routing all game traffic through a foreign VPN or remote proxy tunnel (which adds 70–100 ms of latency and route jitter), we apply a local packet-level desynchronization using `winws` and the kernel packet interception driver `WinDivert`.

```mermaid
sequenceDiagram
    participant Game as H1Z1 Client
    participant WinDivert as Local Filter (winws)
    participant ISP as ISP Filter (TSPU)
    participant Server as ROTK / OVH Server

    Game->>WinDivert: First Outbound UDP Datagram
    Note over WinDivert: Injects fake STUN Binding Request (RFC 5389)
    WinDivert->>ISP: [1] Fake STUN Datagram
    WinDivert->>ISP: [2] Real Game Datagram
    ISP->>ISP: Deep Packet Inspection classifies flow as WebRTC/STUN
    Note over ISP: Flow whitelisted! Counter disabled.
    ISP->>Server: [1] Fake STUN Datagram (Ignored by game engine)
    ISP->>Server: [2] Real Game Datagram (Processed normally)
    Server->>ISP: Game Session Reply
    ISP->>Game: Game Session Reply (Native RTT ~55-60 ms)
    Note over WinDivert: cutoff=d2: Desync disabled for remainder of flow
    loop Normal Gameplay
        Game->>Server: Unmodified Native UDP Packets (0% Loss)
        Server->>Game: Unmodified Native UDP Packets (0% Loss)
    end
```

### Key Technical Details:
1. **Single-Packet Handshake Prefix (`cutoff=d2`)**:
   `winws` injects a standard 100-byte STUN Binding Request (`stun.bin`, opcode `0x0001` with magic cookie `0x2112A442`) on the very first datagram of the flow.
2. **Intermediate Filter Classification**:
   The ISP filter inspects the first packet, matches the STUN header, and marks the entire 5-tuple as an authorized real-time voice/video/WebRTC communication.
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

Initially, an over-restricted filter covering only single IP addresses allowed successful login to the lobby, but entering a match failed because the match server (`162.19.126.166`) was not covered by the desync rule.

By expanding the filter to cover the complete `/24` subnet:
```text
(ip.DstAddr == 162.19.94.95 or (ip.DstAddr >= 162.19.126.0 and ip.DstAddr <= 162.19.126.255)) and ((udp.DstPort >= 20000 and udp.DstPort <= 23000))
```
Every match instance allocated by the ROTK infrastructure is automatically protected, while 100% of all other PC traffic (Discord, Steam, web browsers, DNS) remains completely excluded from the filter.
