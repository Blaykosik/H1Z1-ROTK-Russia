# Tested Server Endpoints & Subnets

This document lists the specific ROTK server endpoints and IP ranges identified, tested, and protected by this project.

---

## 1. Verified ROTK Server Pool

| Role / Function | IP Address / Subnet | UDP Ports Observed | Filter Coverage | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Login Server** | `162.19.94.95` | `20042 - 20045` | Covered | Initial client authentication |
| **Client Gateway** | `162.19.94.95` | `20140 - 20141` | Covered | Character list & lobby state |
| **Primary Gateway** | `162.19.126.149` | `22220 - 22249` | Covered | Matchmaker orchestration |
| **Match Instance A** | `162.19.126.166` | `20206` | Covered | Dynamic game instance |
| **Match Instance B** | `162.19.126.166` | `20214` | Covered | Dynamic game instance |
| **Match Pool Range** | `162.19.126.0/24` | `20000 - 23000` | Covered | Covers `162.19.126.0` through `162.19.126.255` |

---

## 2. Non-OVH Control Servers (Unfiltered)

The following control endpoints were probed during baseline testing to evaluate whether restrictions were universal or specific to OVH foreign hosting subnets:

| Host / Datacenter | IP Address | Port | Baseline Packet Loss | Notes |
| :--- | :--- | :--- | :---: | :--- |
| **Pine Hosting (US)** | `66.51.99.99` | `20140` | **0.0%** (50/50 answered) | Unrestricted on direct Beeline route |
| **Domestic Ru Endpoints** | Various | DNS / Web | **0.0%** | Normal native delivery |

---

## 3. Subnet Expansion Rationale

When ROTK queues players for a match (`Attempting transfer to world ...`), it directs the client to an available dynamic game server node. Because nodes are allocated dynamically across the `162.19.126.0/24` hosting block, covering the entire subnet ensures uninterrupted connectivity across multiple consecutive games without manual reconfiguration.
