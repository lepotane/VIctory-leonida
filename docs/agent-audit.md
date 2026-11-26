# Phase 1 Engineering Audit (`VIctory-leonida`)

**Date:** 2026-11-26  
**Target Platform:** Windows 11 x64 · AMD Ryzen 9 9950X3D (16C/32T) · NVIDIA GeForce RTX 4060 Ti 16 GB (Driver `621.40`, Wave32 host) · 64 GB RAM · Xbox Series S (`1920x1080`) profile

---

## 1. Workspace, Tooling & Baseline Inventory

### 1.1 Workspace Build, Clippy & Unit Tests
- `cargo build --release --locked -p victory`: **Succeeded** (`0` errors, `13` warnings in `victory-gpu`, including unused `ambient::overwrite`, `host::indirects` helpers, and `pipeline::known` `drop(copy)`).
- `cargo clippy --workspace`: **Succeeded (`exit 0`)** with warnings (`26` in `victory-gpu`, `3` in `victory-hle`, `1` in `victory`; `0` errors).
- `cargo test --workspace --no-fail-fast`:
  - `victory` (bin + `census` integration): `12 passed; 0 failed` (`10 + 2`)
  - `victory-core`: `13 passed; 0 failed`
  - `victory-formats`: `42 passed; 0 failed; 5 ignored`
  - `victory-game`: `3 passed; 0 failed`
  - `victory-gpu`: `337 passed; 2 failed; 34 ignored` *(pre-existing failures in untouched `crates/victory-gpu/src/indirect.rs`: `host_list_budget_starts_empty_at_each_submission` and `warp_batch_charges_every_execution`)*
  - `victory-hle` (lib + doc + `no_dll_planting`): `152 passed; 0 failed; 2 ignored` (`1 + 150 + 1`)
  - `victory-loader` (lib + `load_probe` + `title_dlls`): `42 passed; 0 failed` (`39 + 2 + 1`)
  - `victory-pe`: `36 passed; 0 failed`
  - `victory-pipeline`: `7 passed; 0 failed`
  - `victory-shader`: `281 passed; 0 failed; 4 ignored` (184.81s WARP/DXIL verification suite)
  - `xtask`: `6 passed; 0 failed`

### 1.2 PE Import Census (`victory census --missing`)
- **18 images scanned, 0 unreadable**, `962` imported functions (`124` HLE, `764` Host passthrough, `74` missing):
  - `libhttpclient.gdk.dll`: `38` missing (network/telemetry stubs — non-blocking offline)
  - `bink2scarlett.dll`: `23` missing (video playback DLL loaded via title DLL directory)
  - `xboxbvhbuilder.dll`: `7` missing (`XboxBvhBuilder` class exports — hardware/compute BVH builder DLL)
  - `amd_fidelityfx_loader_xbox.dll`: `4` missing (`ffxCreateContext`, `ffxDestroyContext`, `ffxDispatch`, `ffxQuery`)
  - `oleaut32.dll`: `2` missing (ordinals `#4`, `#6`)

### 1.3 Crash Log Summary (`%LOCALAPPDATA%\VIctory\data\7952987A\crashes.log`)
- 6 logged entries during bring-up:
  - 2x early guest breakpoint `0x80000003` during initial setup runs before preset configuration
  - 1x `D3D12SerializeVersionedRootSignature` failure (`0xe06d7363`)
  - 1x `DXGI_ERROR_DEVICE_HUNG` (`0x887A0006`) after `17 submissions sent ahead (VICTORY_RELAY=1) of 407 lists`
  - 2x guest null-write AV (`0xc0000005` at `+0x2215c35`) on first-launch Smooth Motion startup sensitivity

---

## 2. Category 1 — Lighting & Ray Tracing

### Architectural Reality (Verified in `docs/fork-ray-tracing.md` & `shaders.rpf`)
Target Series titles do **not** call host D3D12 DXR (`TraceRay` / `RayQuery` PSOs) directly. Instead:
- Static world BLAS/TLAS are pre-baked in console node layout (64-byte box16, 128-byte box32, triangle, instance nodes).
- Dynamic structures are rebuilt/rehydrated by **52 compute programs** from `XboxBvhBuilder.dll` using raw 40-bit addresses in guest memory.
- Traversal is software compute shaders emitting RDNA 2 `image_bvh_intersect_ray` / `image_bvh64_intersect_ray` per-node tests (emulated in DXIL via `crates/victory-shader/src/bvh.rs`).

### Findings
1. **Live Runs Use `ambient.rs` Stand-in (BVH Builder Off by Default):**
   - `VICTORY_BVH_BUILDER=1` adds ~40–84 ms/frame GPU cost on high-end cards and still suffers from dynamic BVH size readback overlap (~18–23% intact structures in multi-frame traces), dropping `269.7` builder dispatches/frame when off (`diag.err.log`).
   - Consequently, `crates/victory-gpu/src/ambient.rs` (`Role::Radiance`, `Role::Resolve`, `Role::Air`, `Role::Reflect`) is the active lighting path at `1920x1080`.
2. **P1 Visual Defect — Dark & Low-Light Interior Crushed Blacks:**
   - In night/indoor/corridor scenes, `ambient::raise` relies solely on visible-surface screen radiance (`CS_CacheScreenSpaceRadiance`) with a single `floor_light` term gated by `VICTORY_AMBIENT_FLOOR`, leaving shaded character silhouettes and dark rooms severely under-lit while bright exteriors risk over-lifting if scalar `VICTORY_AMBIENT` is raised globally.
   - `ambient::overwrite()` (`VICTORY_AMBIENT_OVERWRITE`) is currently **dead code** (flagged by `cargo clippy`), leaving stale unraytraced probe values (`was`) in `light` instead of cleanly blending/overwriting invalid probe tiles.
3. **5 Untranslated Shadow-Mask Trace Compute Shaders:**
   - `CS_TraceShadowRays_{Eighth,Quarter,Half,Full,FullAdaptive}` (`0xd45e36f`–`0xd474300`) fail translation with `emit: a descriptor read only as data` (dynamic descriptor heap indexing for BVH addresses). Enabling real BVH shadows in the future requires addressing this + dynamic BVH readback synchronization.

---

## 3. Category 2 — Missing Opcodes, 64-bit Image Atomics & DXIL Validation

Verified via `victory translate --validate` with `VICTORY_HOST_WAVE=32` against Windows SDK `dxil.dll` (`10.0.26100.0`):

### 3.1 `XboxBvhBuilder.dll` (Wave32 Target)
- **52 / 52** containers translated, structured, tracked, emitted, and **validated (`52 / 52`, 100%)**.

### 3.2 `shaders.rpf` (Wave32 Target)
- **Containers:** `26,503` (`614` duplicates skipped)
- **Decode & Structuring:** **`26,084 / 26,084` translated (`0` missing opcodes)**, `26,084 / 26,084` structured (`40,597,574` IR ops; all `image_atomic_*` variants already present and lowered in `opcodes.rs`/`lower.rs`).
- **Resource Tracking:** `25,889 / 26,084` (`195` failures: `resources: an address in an SGPR that is no root parameter`, all `GS_VoxelizeGeneric_*` geometry shaders).
- **DXIL Emit & Validation:**
  - **Vertex + Pixel (`VS`/`PS`):** `14,247 / 14,247` emitted, **`14,220` validated** (`27` validator errors)
  - **Compute (`CS`):** `2,651 / 2,682` emitted, **`2,651` validated** (`31` emit failures)
  - **Mesh (`MS`):** `8,765 / 8,765` emitted, **`8,673` validated** (`92` validator errors)

### 3.3 Exact Failure Breakdown (`150` Emit/Validator Errors + `195` Resource Errors)
| Count | Stage | Error / Reason | Representative Shaders / Runtime Impact |
| ---: | :---: | --- | --- |
| **195** | GS | `resources: an address in an SGPR that is no root parameter` | `GS_VoxelizeGeneric_*` (voxelizer geometry shaders) |
| **71** | MS | `validator: vertex plus primitive output size > 32768` | `MS_VS_PedTransform_Decals_*` (exceeds D3D12 SM6.5/6.6 mesh payload 32 KiB limit) |
| **38** *(sum)* | MS/PS | `validator: signature element {TEXCOORD, SV_IsFrontFace, COLOR} interpolation mode differs in same row` | `MSNC_VS_PropFoliageSkinDeferredFire` (`26`), `PS_PropFoliageDeferred_Fire_ExportDepth` (`11` across rows 6–9), `MSNC_VS_TransformUnlit` (`4`), `PS_InteriorDrawClearDepth` (`2`), `MS_VS_OctaSLODFire` (`2`) *(foliage/fire shaders)* |
| **26** | CS | `emit: no wave32 lowering for this wave64 program` | **`water_shading:CS_TransmissionVolumetrics*` (5)** (`#926c46bab3b86bd6`, `#a10179ab7eda0dc3` **dropped LIVE in gameplay**), **`vfx_triangleClip` (3)** (`#02384a60fda6f2d0` `CS_DefragHeap_ComputeRelocations` **dropped LIVE** + `CS_CollectTriangles*`), **`vfx_proj_decal_trail` (9)**, **`GpuParticleEmit` (7)**, **`shadowmask:CS_GenerateShadowMasks*SampleHairScreenSpace` (2)** |
| **5** | CS | `emit: a descriptor read only as data` | `shadowmask:CS_TraceShadowRays_{Eighth,Quarter,Half,Full,FullAdaptive}` |
| **3** | PS | `validator: out of bound coord must be undef` | `PS_MirrorReflectionDeferredTextured_AlphaClip_*` |

> **Key Finding:** All 3 compute shaders observed failing live in gameplay logs (`#926c46bab3b86bd6`, `#a10179ab7eda0dc3`, `#02384a60fda6f2d0`) belong to the **26 `no wave32 lowering for this wave64 program`** group (`emit/mod.rs` Wave32 widening/local-wave heuristics), NOT missing ISA opcodes.

---

## 4. Category 3 — Memory, Staging & Synchronization Overhead

Measured at `1920x1080` on RTX 4060 Ti 16 GB (verified local release & `diag` logs):

1. **CPU Submission Wall vs. GPU Time:**
   - **Native Frame Time (`n=15` world intervals):** `57.8 ms` avg (`19.4` med / `18.1` avg / `24.1` max FPS), of which **`35.3 ms` (`61%`) is CPU `preparing`** vs. only **`6.4 ms` on the GPU**.
   - Inside `preparing` (`diag.err.log` breakdown per frame):
     - **`15.5 – 19.4 ms` `waiting for flights`:** primarily synchronous stalls waiting on upload memory fills (`+0x180`, `+0x1e0` under shader-write declarations over `0x2a990000+0xae00000`, `11.0x` per frame) and host reads (`12.8–16.2 ms` `title memory read` in settles).
     - **`11.7 ms` avg (`11.6 – 12.9 ms` in diag) `list steps` / `heap buffers`:** `39,816` list calls/frame, `32` flushes over `10,250` refreshes (`~9,214` of them empty).
     - **`13.2 ms` avg `copies` (~98–113 MB/frame) + `6.5–7.5 ms` waiting for guards + `3.0–3.2 ms` `VirtualProtect` protection changes + `2.2–2.3 ms` write-watch kernel queries (`217` calls/frame over `1,359 MB`).**
2. **Dynamic Descriptor Slot Exhaustion:**
   - Observed LIVE in `play-coolfox-turbo-latest.err.log`:
     - `WARN victory_gpu::descriptor::host: no free dynamic descriptor slots: a table is not made n=22`
     - `WARN victory_gpu::draw: a draw whose descriptor table found no free slots is dropped`
   - Even with `VICTORY_DYNAMIC_SLOTS=524288`, sustained sessions exhaust dynamic descriptor slots and drop draw calls.
3. **VRAM Budget Pressure & Staging Churn:**
   - Release peak VRAM reaches **`15,280 MB`** (`diag`: `14,920–15,493 MB`) against the **`15,339 MB`** local GPU budget, spilling **`11,581 MB`** into shared system memory with **`1,299` texture-creation passes skipped for lack of room**.
   - Cumulative buffer churn: `971` upload buffers (`17,390 MB`), `12,649` shared buffers (`6,700 MB`), `13,622` card buffers (`1,734 MB`), and `696` barrier-group + `9` buffer barrier waits per frame.

---

## 5. Recommended First Isolated Target (Phase 2/3 Plan)

### Primary Recommendation: **Target A-1 — Luminance-Adaptive Dark-Scene Indirect Lighting & Stale Probe Suppression (`crates/victory-gpu/src/ambient.rs`)**
- **Why First:**
  1. **Direct P1 Blocker:** Directly resolves the #1 visual defect from `KNOWN_ISSUES.md` (crushed blacks in low-light interiors, corridors, and night driving scenes) without breaking bright daylight scenes.
  2. **Zero Shader-Cache Invalidation:** Keeps `crates/victory-shader` untouched so warmed caches (`%LOCALAPPDATA%\VIctory\cache-pareto`) remain 100% valid, avoiding PSO stutter regressions.
  3. **Minimal Surface & Safe Verification:** Confined to `crates/victory-gpu/src/ambient.rs` (resolving the `dead_code` clippy warning on `overwrite()` and tightening low-luma floor / sky-leak clamping / depth-edge crevice shading).
  4. **Preserves Swapchain/Pacing:** Zero changes to DXGI `Present` or queue relay timing.

### Queued Follow-Up Targets (One Per Cycle After Gate Pass)
- **Target B-1 (Wave64->Wave32 Compute Lowering):** Enable Wave32 lowering for the 3 live-dropped `water_shading` / `vfx_triangleClip` compute shaders (`#926c46bab3b86bd6`, `#a10179ab7eda0dc3`, `#02384a60fda6f2d0`) + remaining `GpuParticleEmit`/`shadowmask` hair compute shaders (`crates/victory-shader/src/emit/mod.rs`, `lower.rs`), plus fix the 3 `PS_MirrorReflectionDeferredTextured_AlphaClip` `out of bound coord must be undef` validator errors (`3` PS).
- **Target C-1 (Descriptor & Staging Sync Overhead):** Diagnose why `VICTORY_DYNAMIC_SLOTS=524288` still exhausts dynamic descriptor slots and drops draws, and reduce the `15.5–19.4 ms` flight-wait / `9,214` no-op refresh steps inside `crates/victory-gpu`.

---

## 6. Target B-1 Verification (`VICTORY_HOST_WAVE=32` & DXIL Validation)

Implemented runtime `VICTORY_HOST_WAVE` override (`crates/victory-gpu/src/host.rs`), Wave32 lowering improvements (`crates/victory-shader/src/emit/loose_lds.rs`, `lower.rs`, `mod.rs`: `ds_bpermute_b32` 32-lane half confinement, 8192-dword TGSM cap with uniform entry-block slot-0 aliasing for `wave_base`, `local_any` `scc_some`/`wave_wide`/`v_cndmask_b32`/`double_sum` support, and `VICTORY_WAVE_LDS_LOOSE`), and `CalculateLOD` array-slice coord undef handling (`op == 81`, keeping `VICTORY_WAVE_WIDE` off by default).

- **`victory-shader` unit suite:** `285 passed; 0 failed; 4 ignored` (including `a_level_query_of_an_array_takes_no_slice` and all 4 `backward_permute` GPU + DXIL validation tests).
- **`cargo clippy --workspace`:** `0` errors, `0` new warnings.
- **Target `--warm` check (`VICTORY_HOST_WAVE=32`):** `4 / 4` target compute hashes (`#926c46bab3b86bd6`, `#a10179ab7eda0dc3`, `#02384a60fda6f2d0`, `#6b82bc7d22016cb5`) translated cleanly.
- **Full `translate --validate` (`VICTORY_HOST_WAVE=32`, `dxil.dll` `10.0.26100.0`):**
  - `XboxBvhBuilder.dll`: `52 / 52` emitted and validated.
  - `shaders.rpf` (`26,084` programs):
    - **VS/PS:** `14,247` emitted, **`14,223` validated** *(up from `14,220`; `out of bound coord must be undef` reduced **`3 -> 0`**)*.
    - **Compute:** `2,677 / 2,682` emitted, **`2,677` validated (100% of emitted)** *(up from `2,651`; `no wave32 lowering for this wave64 program` reduced **`26 -> 0`** and TGSM `32900 > 32768` reduced **`2 -> 0`**, leaving only the 5 `descriptor read only as data` trace shaders)*.
    - **Mesh:** `8,765` emitted, `8,673` validated *(unchanged, 0 regressions)*.
