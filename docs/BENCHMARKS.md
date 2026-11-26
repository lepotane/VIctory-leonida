# 1080p RTX Benchmarks (`v0.1.0-1080p-baseline`)

## Test Environment
- **Date:** 2026-11-26
- **CPU:** AMD Ryzen 9 9950X3D (16C / 32T)
- **GPU:** NVIDIA GeForce RTX 4060 Ti 16 GB (Driver `621.40`)
- **Memory:** 64 GB RAM
- **OS:** Windows 11 x64
- **Profile & Resolution:** Xbox Series S (`1920x1080`, Borderless, `VICTORY_DYNAMIC_SLOTS=524288`, `VICTORY_LATE_WAIT_LISTS=512`, `VICTORY_MERGE_RUNS=4096`)
- **Baseline Reference (`Before`):** Pre-patch 1080p build with `ambient.rs` UV calibration
- **Tuned Build (`After`):** Integrated 8 CPU/GPU/format optimizations alongside flight/queue tuning (`crates/victory-shader` untouched to preserve `cache-pareto`)

## Release Build (`Smooth Motion` Active — `NvPresent64.dll` Loaded)
World-phase intervals filtered to `draws/frame >= 1000`:

| Metric (1920x1080 World Scene) | Before (`n=8`) | After (`n=15`) | Change |
| --- | --- | --- | --- |
| **Native FPS (Median / Avg)** | `16.5` / `16.4` FPS | **`19.4` / `18.1` FPS** | **+17.6% median** |
| **Native FPS (Min – Max)** | `11.9 – 20.4` FPS | **`12.7 – 24.1` FPS** | **+18.1% peak** |
| **Smooth Motion Output (~2x OUT)** | `~30.8 – 40.8 OUT` (med. `~33`) | **`~32.8 – 48.2 OUT` (med. `~38.8`)** | **Sustained 30+ FPS** |
| **Frame Time (`ms/frame` Med. / Min)** | `65.1` / `49.0` ms | **`58.4` / `41.5` ms** | **-10.3% median** |
| **Heap Buffers (Avg / Med. / Min)** | `17.0` / `12.4` / `3.1` ms | **`11.7` / `9.5` / `2.4` ms** | **-31.2% avg** |
| **Preparing / Shadow Copies (Avg)** | `37.4` / `15.1` ms | **`35.3` / `13.2` ms** | **-12.6% copy time** |
| **GPU Time (Avg)** | `9.1` ms | **`6.4` ms** | **-29.7% avg** |
| **Refused Views / Null Fallback** | `0` / `0` | **`0` / `0`** | Clean |
| **Peak Local VRAM Used** | `15183` MB | `15280` MB (budget `15339` MB) | Within budget |

## Diagnostics (`diag`) Verification (`1920x1080`)
- `display mode reported to the title width=1920 height=1080`
- Ambient stand-in roles verified active: `Role::Radiance`, `Role::Air`, `Role::Resolve`
- `unordered views refused 0x`, `buffer views left null as the host would refuse them: 0`
- Peak local VRAM observed in `diag`: `14920 MB` / `15339 MB` budget
- Visual inspection across interior cutscenes, close-up character scenes, and exterior sunlit/backlit window views confirmed sharp 1080p textures and no BC7 rotation/corruption artifacts. Dark/night scene brightness remains tracked in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Unit Tests
- `cargo test -p victory-formats bcpack`: `11 passed; 0 failed; 2 ignored` (includes `bc7_rotation_applies_only_to_modes_4_and_5`)
- `cargo test -p victory-gpu --lib`: `337 passed; 2 failed; 34 ignored` (all tests for edited modules passed; 2 failures are pre-existing in untouched `indirect::tests`)
- `cargo xtask policy`: asset-policy allowlist clean
