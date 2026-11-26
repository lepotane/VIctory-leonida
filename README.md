# VIctory-leonida

An open-source Xbox Series compatibility layer for Windows 11 x64 (Direct3D 12 + DXIL shader recompiler) tuned for **1920x1080 (`1080p`)** on NVIDIA RTX 40-series GPUs.

> **Legal & Zero-Asset Notice ([LEGAL.md](LEGAL.md)):** This repository contains **strictly clean-room / GPL-3.0-or-later source code and documentation**. It contains **zero** copyrighted title files, executables, firmware, encryption keys, textures, shaders, screenshots, or binary dumps (enforced via `.gitignore` and `cargo xtask policy`; see [docs/asset-policy.md](docs/asset-policy.md)). Users must supply their own legally obtained Xbox Series title dump via `$env:VICTORY_GAME_DIR`. Not affiliated with Microsoft, Xbox, NVIDIA, or any title publisher. See [LEGAL.md](LEGAL.md) for full interoperability terms, disclaimers, and DMCA takedown contact details.

---

## Repository Structure

```text
.
├── apps/victory/              # Main runner binary crate
├── crates/
│   ├── victory-core/          # Runtime paths, outside-repo cache enforcement
│   ├── victory-formats/       # BCPack/Bink texture & archive decoders (BC7 mode 4/5 rotation fix)
│   ├── victory-gpu/           # D3D12 backend, shadow/watch/texback/draw/ambient optimizations
│   ├── victory-hle/           # Xbox GDK / OS service emulation & memory management
│   ├── victory-loader/        # PE/TLS loader
│   └── victory-shader/        # Xbox DXIL/GCN translator (kept untouched for cache reuse)
├── docs/
│   ├── BENCHMARKS.md          # Verified 1080p Before/After metrics & VRAM logs
│   ├── KNOWN_ISSUES.md        # Open issues (P1: Dark & Low-Light Scenes) & investigation notes
│   ├── architecture.md        # System design overview
│   ├── asset-policy.md        # Zero-proprietary-assets rule
│   └── findings.md / *.md     # Detailed optimization & RT research notes
├── scripts/
│   ├── play.ps1               # Generic cross-GPU runner
│   └── windows/               # Portable Windows 1080p RTX launcher & NVAPI Smooth Motion helpers
├── tests/                     # Integration test fixtures
├── xtask/                     # `cargo xtask policy` & git pre-commit hook installer
├── CHANGELOG.md               # Version history (`v0.1.0-1080p-baseline`)
├── LEGAL.md                   # Interoperability statement, Asset Policy, DMCA & Disclaimers
└── LICENSE                    # GNU GPL v3.0
```

---

## Quick Start (Windows 11 x64)

### Prerequisites
- Windows 10/11 x64, AVX2 CPU, Direct3D 12 GPU with Shader Model 6.6 and Mesh Shaders (RTX 4060 Ti 16 GB+ recommended; **64 GB system RAM** recommended)
- Rust toolchain (pinned in `rust-toolchain.toml`) + MSVC C++ Build Tools & Windows SDK

### 1. Build & Install Policy Hook
```powershell
cargo build --release --locked -p victory
cargo xtask install-hooks   # installs pre-commit `cargo xtask policy --staged`
```

*(Optionally create a `victory_rtx.exe` copy in `target\release\` — `scripts\windows\play-rtx-1080p.ps1` syncs this automatically.)*

### 2. Optional: Pre-warm Pipelines
Eliminates initial shader/PSO compile stutters into `%LOCALAPPDATA%\VIctory\cache-pareto`:
```powershell
.\scripts\windows\warm-pipelines.ps1
```

### 3. Launch at 1080p
Point at your own legally obtained title dump outside this repository and run the 1080p RTX preset:
```powershell
$env:VICTORY_GAME_DIR = 'D:\Games\MyXboxDump'
.\scripts\windows\play-rtx-1080p.ps1 -SmoothMotion
```

Useful flags:
- `-SmoothMotion`: Enables NVIDIA DRS Smooth Motion for `victory_rtx.exe` (~2x output FPS). Omit for native frames without interpolation.
- `-ManualMenus`: Disables automatic `Enter` presses during initial title menus.
- `-Windowed`: Runs windowed instead of borderless fullscreen.
- `-DisplayMode 1920x1080`: Sets display resolution reported to the title.
- In-game overlays: `F3` toggles the built-in top-left FPS/VRAM panel; `Alt+R` shows NVIDIA Smooth Motion output FPS.

---

## Performance Snapshot (`1920x1080`, Xbox Series S Profile)

Full measurement methodology and hardware details (Ryzen 9 9950X3D + RTX 4060 Ti 16 GB, Driver `621.40`) are in [docs/BENCHMARKS.md](docs/BENCHMARKS.md).

- **Native World FPS:** `19.4` median / `18.1` avg / `24.1` peak FPS (up from `16.5` median / `20.4` peak baseline)
- **With NVIDIA Smooth Motion (`-SmoothMotion`):** `~32.8 – 48.2 OUT FPS` (median `~38.8 OUT`)
- **Heap Buffer Pass Overhead:** `11.7 ms` avg (down **31.2%** from `17.0 ms` via incremental `BufferSweep`)
- **VRAM Footprint:** `14920 MB` diag / `15280 MB` release peak (within `15339 MB` 16 GB card budget, `0` refused views)

---

## Known Issues (See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md))

- **P1 Open — Dark & Low-Light Scenes:** Low-light interiors, dim corridors, and night driving scenes still crush shadows / remain darker than desired despite `ambient.rs` and `VICTORY_AMBIENT_FLOOR=0.42` calibration. Further tonemapping/exposure and SSAO floor tuning is planned next.
- **Startup Retry:** Very occasionally the first launch with Smooth Motion exits within 5s before D3D12 init; re-running the launcher succeeds normally.

---

## Credits & License

Licensed under the **GNU General Public License v3.0 or later** ([LICENSE](LICENSE)).

Built upon:
- **VIctory** — Core PE loader, HLE runtime, D3D12 backend, and DXIL recompiler
- **XCL** — Reference Xbox compatibility layer architecture and runtime documentation

Also grateful to upstream open-source GNU GPL v3.0 contributors across the compatibility-layer ecosystem whose license-compliant patches informed runtime and GPU optimizations.
