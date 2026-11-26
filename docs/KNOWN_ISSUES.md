# Known Issues & Open TODOs

## P1 (Open) — Dark & Low-Light Scenes
- **Status:** Open — partially mitigated at `1920x1080`, **still needs further work**.
- **Symptom:** Night driving scenes, low-light interiors, and dim corridors can still crush blacks and obscure character faces and shaded geometry silhouettes.
- **Current Baseline State:**
  - `crates/victory-gpu/src/ambient.rs` applies `seen()` UV scaling (`depth.GetDimensions`), `clear_air()` / `clean_reflect()` night floor passes, and `raise()` scene-tinted SSAO indirect lighting (`Role::Resolve`, `Role::Radiance`, `Role::Air` active).
  - Default launcher tuning: `VICTORY_AMBIENT=1.5`, `VICTORY_AMBIENT_FLOOR=0.42`, `VICTORY_AMBIENT_SHADE=0.70,0.65`, `VICTORY_AMBIENT_AIR=1.2`, `VICTORY_AMBIENT_REFLECT=0.30`, `VICTORY_AMBIENT_REFLECT_CLEAN=1`, `VICTORY_SHADOW_LIFT=0.20`, `VICTORY_COMPOSE_SHARPEN=0.50`.
- **Next Investigation Targets:**
  1. Direct inspection of night/dark-scene tonemapping and auto-exposure / histogram curves.
  2. Adaptive curves for `VICTORY_AMBIENT_FLOOR` and `VICTORY_SHADOW_LIFT` in low-luminance scenes without blowing out bright daylight exteriors.
  3. Luminance-aware SSAO / indirect-lighting floor masking so dark materials are not over-attenuated.
  4. `-RT` reference comparison (within RTX wave32 BVH stability constraints) to validate target baseline ambient levels.

## Other Known Limitations
- **First-launch Smooth Motion startup sensitivity:** With `-SmoothMotion` (`NvPresent64.dll`), the first launch can occasionally exit within ~0.5–5s before D3D12 initialization; re-running the launcher starts normally.
- **Base Native Performance Envelope:** On the Xbox Series S profile, demanding open-world scenes typically run around ~15–24 native FPS on high-end desktop GPUs; sustained 30+ FPS fluidity currently relies on Smooth Motion (`-SmoothMotion`) or further CPU/PCIe submission reductions.
- **Distant shimmer & texture streaming delay:** Distant foliage/building shimmer and brief texture streaming lag on rapid camera pans can occur.
- **Pre-existing untouched `indirect::tests` failures:** Running `cargo test -p victory-gpu --lib` hits 2 pre-existing budget test failures in untouched `crates/victory-gpu/src/indirect.rs` (`host_list_budget_starts_empty_at_each_submission` due to default `VICTORY_INDIRECT_REST=0`; `warp_batch_charges_every_execution` reports `spent == 0` under WARP).
- **System RAM:** 64 GB system RAM is recommended for sustained open-world memory usage.
