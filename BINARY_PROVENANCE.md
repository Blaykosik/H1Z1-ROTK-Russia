# Binary Provenance & Upstream Verification

This document provides transparent, verifiable provenance records for every binary and executable artifact bundled with **H1Z1 ROTK Russia**.

Our core security principle: **Do not ask for blind trust — provide full verification.**

---

## 1. Provenance & Hash Verification Table

| File | Purpose | Upstream Project | Upstream Version / Commit | Official Upstream Repository | Bundled SHA-256 | Upstream Match | Modified? |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: | :---: |
| [`bin/winws.exe`](bin/winws.exe) | Windows packet desynchronization engine | [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) by bol-van | `v72.13` (`87e058624c72863db53bdaf7fb6f16576dddb6ab`) x86_64 | `https://github.com/bol-van/zapret-win-bundle` | `A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8` | **MATCH** | **NO** (Unchanged) |
| [`bin/WinDivert.dll`](bin/WinDivert.dll) | User-mode interface DLL for WinDivert driver | [WinDivert](https://github.com/basil00/WinDivert) by basil00 (bundled in zapret) | WinDivert 2.2 / zapret `v72.13` x86_64 | `https://github.com/bol-van/zapret-win-bundle` | `C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2` | **MATCH** | **NO** (Unchanged) |
| [`bin/WinDivert64.sys`](bin/WinDivert64.sys) | Windows kernel-mode packet filter driver (Digitally Signed) | [WinDivert](https://github.com/basil00/WinDivert) by basil00 (bundled in zapret) | WinDivert 2.2 / zapret `v72.13` x86_64 | `https://github.com/bol-van/zapret-win-bundle` | `8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2` | **MATCH** | **NO** (Unchanged) |
| [`bin/cygwin1.dll`](bin/cygwin1.dll) | POSIX emulation runtime required by winws.exe | [Cygwin](https://cygwin.com/) (bundled in zapret) | Cygwin 3.4.10 / zapret `v72.13` x86_64 | `https://github.com/bol-van/zapret-win-bundle` | `103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B` | **MATCH** | **NO** (Unchanged) |
| [`bin/stun.bin`](bin/stun.bin) | Standard RFC 5389 STUN Binding Request payload frame | Project Synthetic Artifact (RFC 5389 format) | RFC 5389 standard STUN packet (100 bytes) | In-repository (see hex dump below) | `9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641` | **N/A** | Project Artifact |

> [!NOTE]
> All upstream binary components (`winws.exe`, `WinDivert.dll`, `WinDivert64.sys`, and `cygwin1.dll`) are **bundled byte-for-byte unchanged from the official upstream zapret-win-bundle release artifact**. They are not recompiled, modified, patched, or repacked.

---

## 2. Origin & Full Inspection of `stun.bin`

`stun.bin` is a 100-byte inert binary payload file containing a single standard **STUN (Session Traversal Utilities for NAT) Binding Request** packet compliant with [RFC 5389](https://datatracker.ietf.org/doc/html/rfc5389).

It is used solely as a dummy UDP prefix sent once (`cutoff=d2`) to establish the connection context through DPI filtering equipment before actual game traffic begins.

### Byte-Level Hex Dump of `stun.bin`

```text
Offset    00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  ASCII
-------------------------------------------------------------------------
00000000  00 01 00 50 21 12 A4 42 5A 4B 4B 75 68 47 78 65  ...P!..BZKKuhGxe
00000010  70 6E 64 30 00 06 00 09 51 42 7A 50 3A 74 6E 57  pnd0....QBzP:tnW
00000020  6B 00 00 00 C0 57 00 04 00 00 03 E7 80 2A 00 08  k....W.......*..
00000030  B6 BC EF 7B B3 F7 28 98 00 25 00 00 00 24 00 04  ...{..(..%...$..
00000040  6E 00 1E FF 00 08 00 14 AA 4F 94 F9 1F F5 CE BE  n........O......
00000050  DF EC 9E 66 AD D3 DD 9B B7 95 ED 6E 80 28 00 04  ...f.......n.(..
00000060  2B 1F B6 35                                      +..5
```

### Protocol Breakdown
* `00 01`: STUN Message Type = `Binding Request` (`0x0001`)
* `00 50`: Message Length = 80 bytes (excluding 20-byte header = 100 bytes total)
* `21 12 A4 42`: STUN Magic Cookie (standard `0x2112A442`)
* `5A 4B 4B 75 68 47 78 65 70 6E 64 30`: Transaction ID (`ZKkKuhGxepnd0`)
* Followed by standard RFC 5389 attributes (`USERNAME`, `PRIORITY`, `USE-CANDIDATE`, `MESSAGE-INTEGRITY`, `FINGERPRINT`).

`stun.bin` contains **no executable code, no shellcode, and no instructions**. It is purely static data interpreted as a standard UDP packet.

---

## 3. How to Independently Verify Binaries Against Upstream

You do not need to take our word for binary authenticity. You can verify every file yourself in under 2 minutes:

### Step 1: Download Official zapret-win-bundle
Download the official `zapret-win-bundle` from bol-van's repository:
* URL: [https://github.com/bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)

### Step 2: Compare SHA-256 Checksums in PowerShell
Run the following PowerShell command on your machine:

```powershell
Get-FileHash .\bin\* -Algorithm SHA256 | Format-Table -AutoSize
```

Expected output:
```text
Algorithm Hash                                                             Path
--------- ----                                                             ----
SHA256    103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B cygwin1.dll
SHA256    9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641 stun.bin
SHA256    C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2 WinDivert.dll
SHA256    8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2 WinDivert64.sys
SHA256    A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8 winws.exe
```

The hashes of `winws.exe`, `WinDivert.dll`, `WinDivert64.sys`, and `cygwin1.dll` match the upstream release bit-for-bit.

---

## 4. Digital Signature of the Kernel Driver

`WinDivert64.sys` is a signed Windows kernel driver. You can verify its digital signature directly in Windows:

1. Right-click [`bin/WinDivert64.sys`](bin/WinDivert64.sys).
2. Click **Properties** -> **Digital Signatures**.
3. Inspect the signature certificate:
   * **Signer Name**: Basil (WinDivert upstream author)
   * **Status**: "This digital signature is OK."
