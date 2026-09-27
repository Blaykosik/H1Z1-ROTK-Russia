# Empirical Technical Findings & Measurement Matrix

This document summarizes the empirical testing and network telemetry collected during the development and validation of the H1Z1 ROTK direct UDP bypass.

---

## 1. Test Environment

- **Operating System**: Windows 10 / 11 x64
- **Physical Interface**: Realtek 2.5GbE PCIe Adapter (`192.168.1.11`)
- **Internet Service Provider**: Beeline (Russia)
- **Destination ASN**: AS16276 (OVH SAS, Western Europe)
- **Testing Period**: September 26–27, 2026

---

## 2. Experimental Measurement Matrix

| Test ID | Scenario / Strategy | Sent | Received | Packet Loss % | Last Reply | Median RTT | Max RTT | Jitter | Outcome / Analysis |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **BASE-LOGIN** | Native Direct (Login `162.19.94.95:20045`) | 50 | 3 | 94.0% | 1.14s | 1017.3 ms | 1116.6 ms | 87.4 ms | **Failure**: Cut off after initial replies. |
| **BASE-GW** | Native Direct (Gateway `162.19.126.149:22225`) | 50 | 12 | 76.0% | 1.16s | 59.9 ms | 63.2 ms | 1.3 ms | **Failure**: Exactly 12 packets answered, then 100% drop. |
| **BASE-MATCH** | Native Direct (Match `162.19.126.166:20214`) | 25 | 12 | 52.0% | 1.15s | 58.2 ms | 60.1 ms | 0.9 ms | **Failure**: Exactly 12 packets answered, matching the gateway pattern. |
| **TEST-NON-OVH**| Control (Pine Hosting US, non-OVH) | 50 | 50 | **0.0%** | 5.08s | 159.9 ms | 168.1 ms | 1.3 ms | **Control Pass**: Confirms restriction is specific to foreign OVH hosting subnets. |
| **STRAT-BADSUM**| Fake packet with bad L4 checksum | 50 | 8 | 84.0% | 0.76s | 58.3 ms | 60.3 ms | 1.6 ms | **Failure**: Intermediate filter counted both real and fake datagrams. |
| **STRAT-IPFRAG**| IPv4 fragmentation (`ipfrag-pos-udp=8`) | 50 | 1 | 98.0% | 0.05s | 61.3 ms | 61.3 ms | 0.0 ms | **Failure**: Intermediate firewalls drop trailing fragments lacking L4 headers. |
| **RATE-1PPS** | Baseline probing at 1 packet/sec | 20 | 12 | 40.0% | 11.06s | 56.5 ms | 59.2 ms | 1.1 ms | **Key Finding**: Cutoff is a strict **12-packet counter**, not an idle timeout! |
| **STRAT-STUN-D2**| Fake STUN prefix on packet #1 (`cutoff=d2`)| 50 | 50 | **0.0%** | 4.98s | **58.6 ms** | **60.5 ms** | **0.6 ms** | **SUCCESS**: Intermediate filter classifies flow as STUN; 0% packet loss. |
| **ENDUR-120S** | 120-second continuous stress test (25 pps) | **2,973** | **2,973** | **0.0%** | **120.05s** | **59.5 ms** | **69.6 ms** | **0.7 ms** | **Endurance Confirmed**: Sustained flow with zero drops and sub-millisecond jitter. |
| **MATCH-STUN** | Live Match Probe (`162.19.126.166:20214`) | 25 | 25 | **0.0%** | 2.45s | **57.4 ms** | **59.8 ms** | **0.5 ms** | **Match Server Unblocked**: Full delivery on dynamic game instances. |

---

## 3. Live Game Telemetry

Live testing with `H1Z1.exe` and ROTK Launcher confirmed:
1. **Lobby & Ping Evaluation**:
   - `DbDataCenters.log` recorded native ping to Amsterdam (AMS) datacenter:
     ```text
     InsertOrUpdate Id=2(AMS) Available=1 Selected=1 Home=1 Ping=61 Quality=high Message=
     BestDC: Id=2
     ```
   - In-game latency display showed green ping (~55–61 ms).
2. **Match Server Transfer**:
   - Dynamic transfer to world instance (`162.19.126.166:20214`) executed seamlessly.
   - Successful loading screen completion and full zone entry (`GAMESTATE_PREGAME` and `GAMESTATE_RUNNING`).
   - Active gameplay sustained with zero desynchronization or sudden disconnections.

---

## 4. Latency & Jitter Comparison: Direct Bypass vs. Tunneling (VLESS)

VLESS was playable and often stayed around roughly 60–80 ms, but the tunneled path introduced noticeable jitter and occasional latency spikes reaching approximately 140–170 ms on the tested setup. The direct local bypass keeps the native route and produced a much steadier ~55–61 ms connection.

| Route Profile | Median Latency | Observed Spikes / Jitter | Gameplay Impact |
| :--- | :---: | :---: | :--- |
| **VLESS Tunneling** | ~60–80 ms | 140–170 ms spikes | Playable, but periodic desync / stutter |
| **Native Direct Bypass** | **~55–61 ms** | **< 1.0 ms jitter** | 100% stable, physical fiber minimum |
