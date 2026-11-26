# Legal Notice, Interoperability Statement & DMCA Policy

## 1. Project Scope & Interoperability Purpose

**VIctory-leonida** is an independent, open-source Xbox Series runtime and Direct3D 12 / DXIL compatibility layer for Windows 11 x64. The project exists strictly for software preservation, research, debugging, and cross-platform interoperability under applicable laws (including interoperability and reverse-engineering exceptions such as 17 U.S.C. § 1201(f) and equivalent statutory provisions in other jurisdictions).

This repository does **not** promote, facilitate, or endorse software piracy or unauthorized distribution of copyrighted works.

## 2. Strict Zero-Asset Policy

This repository contains **only** original and GNU GPL v3.0-or-later source code, build configuration, documentation, and local helper scripts:

- **No** proprietary executables, DLLs, firmware images, OS kernels, or system files.
- **No** cryptographic keys, retail certificates, or circumvention secrets.
- **No** game assets, textures, audio, models, shaders, captures, screenshots, or binary dumps.

Compliance is enforced locally and before commits via `.gitignore` and `cargo xtask policy` (see [docs/asset-policy.md](docs/asset-policy.md)).

## 3. User Responsibility

Running any software with this compatibility layer requires the user to supply their own legally obtained title files dumped from hardware and software copies they legitimately own (`VICTORY_GAME_DIR`). Maintainers do not host, distribute, link to, or provide assistance with acquiring any copyrighted software or proprietary assets.

You are solely responsible for complying with all applicable copyright, export, and licensing laws in your jurisdiction.

## 4. No Affiliation & Trademarks

VIctory-leonida is an independent community project. It is **not** affiliated with, endorsed by, sponsored by, or associated with Microsoft Corporation, Xbox, NVIDIA Corporation, AMD, or any third-party software publisher, developer, or rights holder.

All product names, trademarks, and registered trademarks mentioned solely in technical compatibility contexts are the property of their respective owners.

## 5. DMCA & Copyright Takedown Procedure

If you are a copyright owner, authorized agent, or rights holder and believe in good faith that any material hosted in this repository infringes your copyright or contains proprietary content that should not be present, please submit a written notice to the maintainer (**`lepotane`**) via GitHub repository contact/Issues containing:

1. Identification of the copyrighted work claimed to have been infringed.
2. Identification of the specific material claimed to be infringing (exact file path, commit hash, or URL within `lepotane/VIctory-leonida`) so it can be located immediately.
3. Sufficient contact information (name, organization if applicable, email address, or GitHub handle).
4. A statement that you have a good-faith belief that the disputed use is not authorized by the copyright owner, its agent, or the law, and that the information in the notification is accurate.

Upon receipt of a valid notice, the maintainer will promptly investigate and remove or disable access to the identified material.

## 6. License, No Warranty & Limitation of Liability

This project is licensed under the **GNU General Public License v3.0 or later** (see [LICENSE](LICENSE)).

BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM **"AS IS"** WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.

IN NO EVENT SHALL ANY COPYRIGHT HOLDER, AUTHOR, OR MAINTAINER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OR INABILITY TO USE THIS SOFTWARE.
