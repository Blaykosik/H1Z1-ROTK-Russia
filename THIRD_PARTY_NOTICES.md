# Third-Party Software Notices and Attribution

This project bundles and utilizes upstream open-source components to provide local network packet filtering on Windows. All bundled third-party software remains under the respective copyright and license terms of its original authors. This project does not claim ownership or authorship of these external tools.

---

## 1. zapret (winws)

- **Component**: `bin/winws.exe`
- **Author**: bol-van
- **Upstream Repository**: [https://github.com/bol-van/zapret](https://github.com/bol-van/zapret)
- **Version**: zapret v72.13 (commit `87e058624c72863db53bdaf7fb6f16576dddb6ab`)
- **License**: MIT License ([LICENSES/LICENSE.zapret.txt](LICENSES/LICENSE.zapret.txt))
- **SHA256**: `A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8`

---

## 2. WinDivert

- **Components**: `bin/WinDivert.dll`, `bin/WinDivert64.sys`
- **Author**: basil00
- **Upstream Repository**: [https://github.com/basil00/Divert](https://github.com/basil00/Divert)
- **Version**: WinDivert 2.2.0 / 2.2.2-A (official Authenticode-signed driver)
- **License**: GNU Lesser General Public License (LGPL) Version 3 / GNU General Public License (GPL) Version 2 ([LICENSES/LICENSE.windivert.txt](LICENSES/LICENSE.windivert.txt))
- **SHA256 (`WinDivert.dll`)**: `C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2`
- **SHA256 (`WinDivert64.sys`)**: `8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2`

*Note: WinDivert source code and build instructions are publicly available at the official repository linked above.*

---

## 3. Cygwin POSIX Emulation Library

- **Component**: `bin/cygwin1.dll`
- **Author**: Red Hat, Inc. and Cygwin Contributors
- **Upstream Project**: [https://cygwin.com/](https://cygwin.com/)
- **Upstream Source**: [https://sourceware.org/git/newlib-cygwin.git](https://sourceware.org/git/newlib-cygwin.git)
- **Version**: 3.4.10
- **License**: GNU Lesser General Public License (LGPL) Version 3 or later ([LICENSES/LICENSE.cygwin.txt](LICENSES/LICENSE.cygwin.txt))
- **SHA256**: `103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B`

---

## 4. STUN Test Datagram

- **Component**: `bin/stun.bin`
- **Description**: Standard 100-byte STUN Binding Request payload formatted according to RFC 5389 / RFC 8489. Used exclusively as a protocol header prefix to classify the UDP flow.
- **SHA256**: `9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641`
