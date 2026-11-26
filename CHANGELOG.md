# Changelog

All notable changes in **VIctory-leonida** are documented in this file.

## [0.1.0-1080p-baseline] - 2026-11-26

Baseline rollback point for `1920x1080` NVIDIA RTX 4060 Ti 16 GB verification and dark-scene ambient calibration.

### Added
- Legal & compliance documentation: `LEGAL.md` (interoperability scope, zero-asset policy, no-affiliation disclaimer, DMCA takedown procedure, GPL-3.0 "AS IS" notice).
- Portable Windows launcher & utility scripts under `scripts/windows/`:
  - `scripts/windows/play-rtx-1080p.ps1`
  - `scripts/windows/smooth-motion.ps1`
  - `scripts/windows/warm-pipelines.ps1`
- Project tracking docs: `docs/KNOWN_ISSUES.md`, `docs/BENCHMARKS.md`, and `CHANGELOG.md`.
- Configurable `VICTORY_MERGE_RUNS` budget in `crates/victory-gpu/src/host.rs` (clamped `1..=65536`, set to `4096` alongside `VICTORY_LATE_WAIT_LISTS=512` in launcher).
- `.gitignore` rules for `/runs/` and `/backups/`.

### Changed & Integrated (GPL-3.0-or-later)
- **Shadow lock-free & AVX2 scan** (`crates/victory-gpu/src/shadow.rs`):
  - Integrated AVX2 `word_runs` in `Shadow::take` instead of scalar `dword_runs`.
  - Integrated lock-free `has_pending` fast path and `RwLock<CopiedState>` combining `pages` + `ranged` to eliminate mutex contention in `nothing_new` / `stale_under_writes`.
- **Parallel / borrowed texture readbacks** (`crates/victory-gpu/src/texback.rs`, `crates/victory-gpu/src/host.rs`):
  - Reused per-thread `SCRATCH` vectors, narrowed `TICKETS` lock scope, and added `land_many(&[&Back])` to avoid cloning `Vec<Back>` per landing pass.
- **Coalesced write-watch unguards & null descriptor templates** (`crates/victory-gpu/src/watch.rs`, `crates/victory-gpu/src/descriptor/host.rs`):
  - Merged contiguous 64 KiB `unguard` ranges into single `VirtualProtect` calls to reduce TLB shootdowns.
  - Added prebuilt CPU-only `null_template` + `copy_null_template` via `CopyDescriptorsSimple` for null CBV/SRV/UAV clears.
- **Incremental `BufferSweep`** (`crates/victory-gpu/src/draw.rs`):
  - Switched heap buffer pass to incremental per-part tracking (`part_spans`, `part_views`, `dirty_parts`, `HeapRanges::replace`) using `host.buffer_slots_of(part, parts)`.
- **Placed-view cache leak guard** (`crates/victory-gpu/src/descriptor.rs`):
  - Added `shape_key` tracking (`views_kept`) to cap redundant placed-view shape cache retention.
- **BC7 rotation fix** (`crates/victory-formats/src/bcpack.rs`):
  - Fixed `rotation()` to apply only to BC7 modes 4 and 5, with unit test `bc7_rotation_applies_only_to_modes_4_and_5`.
- **1080p ambient lighting calibration** (`crates/victory-gpu/src/ambient.rs`, `crates/victory-gpu/src/draw.rs`):
  - Calibrated `seen()` UV scaling via `depth.GetDimensions`, night floors (`clear_air`, `clean_reflect`), SSAO floor tint (`raise`), and relaxed `seen` size check.
- **Shader translator preserved:** Kept `crates/victory-shader` untouched to preserve warmed shader caches in `%LOCALAPPDATA%\VIctory\cache-pareto`.
