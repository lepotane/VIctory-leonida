//! Which processors our own threads run on, where a processor has two kinds
//! of cores. `cpu_sets` and `keep_on_fast_cores` are fxceless/victory-fork's
//! (`framelog.rs`, commit 0b0074e0, GPL-3.0-or-later, as this).

#[derive(Clone, Copy, Debug)]
struct CpuSetInfo {
    id: u32,
    logical_index: u8,
    efficiency: u8,
}

/// The system's processor sets of group 0: each one's id, logical index and
/// efficiency class (higher is faster).
fn cpu_sets_full() -> Vec<CpuSetInfo> {
    use windows_sys::Win32::System::SystemInformation::{GetSystemCpuSetInformation, SYSTEM_CPU_SET_INFORMATION};
    use windows_sys::Win32::System::Threading::GetCurrentProcess;
    let mut bytes = 0u32;
    // SAFETY: a size query, then the call into a buffer of that size.
    unsafe { GetSystemCpuSetInformation(std::ptr::null_mut(), 0, &mut bytes, GetCurrentProcess(), 0) };
    let mut buffer = vec![0u64; (bytes as usize).div_ceil(8).max(1)];
    // SAFETY: as above; the buffer holds `bytes` bytes, aligned for the records.
    let ok = unsafe { GetSystemCpuSetInformation(buffer.as_mut_ptr().cast(), bytes, &mut bytes, GetCurrentProcess(), 0) };
    let mut sets = Vec::new();
    let mut at = 0usize;
    while ok != 0 && at + size_of::<SYSTEM_CPU_SET_INFORMATION>() <= bytes as usize {
        // SAFETY: a record inside the buffer; each says its own size.
        let info = unsafe { &*(buffer.as_ptr().cast::<u8>().add(at).cast::<SYSTEM_CPU_SET_INFORMATION>()) };
        if info.Size == 0 {
            break;
        }
        // SAFETY: the record's type is CpuSet (the only one there is).
        let set = unsafe { &info.Anonymous.CpuSet };
        if set.Group == 0 {
            sets.push(CpuSetInfo {
                id: set.Id,
                logical_index: set.LogicalProcessorIndex,
                efficiency: set.EfficiencyClass,
            });
        }
        at += info.Size as usize;
    }
    sets
}

/// Group-0 L3 cache descriptors: `(cache_size_bytes, logical_processor_mask)`.
fn l3_caches() -> Vec<(u32, u64)> {
    use windows_sys::Win32::System::SystemInformation::{
        GetLogicalProcessorInformationEx, RelationCache, SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX,
    };
    let mut bytes = 0u32;
    // SAFETY: size query followed by read into sized buffer.
    unsafe { GetLogicalProcessorInformationEx(RelationCache, std::ptr::null_mut(), &mut bytes) };
    if bytes == 0 {
        return Vec::new();
    }
    let mut buffer = vec![0u64; (bytes as usize).div_ceil(8).max(1)];
    // SAFETY: buffer holds `bytes` bytes for variable-length cache records.
    let ok = unsafe { GetLogicalProcessorInformationEx(RelationCache, buffer.as_mut_ptr().cast(), &mut bytes) };
    let mut out = Vec::new();
    let mut at = 0usize;
    while ok != 0 && at + 8 <= bytes as usize {
        // SAFETY: record within valid buffer bounds; Size gives record length.
        let info = unsafe { &*(buffer.as_ptr().cast::<u8>().add(at).cast::<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX>()) };
        if info.Size == 0 {
            break;
        }
        if info.Relationship == RelationCache {
            // SAFETY: Relationship == RelationCache selects the Cache union variant.
            let cache = unsafe { &info.Anonymous.Cache };
            // SAFETY: GroupMask is valid for GroupCount == 0/1; GroupMasks[0] sits at the same offset.
            let gm = unsafe { &cache.Anonymous.GroupMask };
            if cache.Level == 3 && gm.Group == 0 && gm.Mask != 0 {
                out.push((cache.CacheSize, gm.Mask as u64));
            }
        }
        at += info.Size as usize;
    }
    out
}

/// Split group-0 CPU sets into `(fast, background)`: prefers heterogeneous
/// P/E efficiency classes first, and otherwise splits asymmetric L3 caches
/// (such as Ryzen X3D dual-CCD 96 MB V-Cache vs 32 MB L3).
fn split_cores(sets: &[CpuSetInfo], l3: &[(u32, u64)]) -> (Vec<u32>, Vec<u32>) {
    let best = sets.iter().map(|c| c.efficiency).max().unwrap_or(0);
    let worst = sets.iter().map(|c| c.efficiency).min().unwrap_or(0);
    if best > worst {
        let fast = sets.iter().filter(|c| c.efficiency == best).map(|c| c.id).collect();
        let bg = sets.iter().filter(|c| c.efficiency < best).map(|c| c.id).collect();
        return (fast, bg);
    }
    let max_l3 = l3.iter().map(|c| c.0).max().unwrap_or(0);
    let min_l3 = l3.iter().map(|c| c.0).min().unwrap_or(0);
    if max_l3 > min_l3 {
        let mut fast_mask = 0u64;
        let mut bg_mask = 0u64;
        for &(size, mask) in l3 {
            if size == max_l3 {
                fast_mask |= mask;
            } else {
                bg_mask |= mask;
            }
        }
        let fast = sets
            .iter()
            .filter(|c| c.logical_index < 64 && (fast_mask >> c.logical_index) & 1 != 0)
            .map(|c| c.id)
            .collect();
        let bg = sets
            .iter()
            .filter(|c| c.logical_index < 64 && (bg_mask >> c.logical_index) & 1 != 0)
            .map(|c| c.id)
            .collect();
        return (fast, bg);
    }
    (Vec::new(), Vec::new())
}

/// `VICTORY_FAST_CORES`: 0: no thread asks; 1: the threads a frame waits for
/// one by one; 2 (the default): the threads they share their work with too;
/// 3: those that work beside the rest as well (lists translated, descriptors
/// made): on Ryzen X3D keep latency-critical work on the V-Cache CCD while
/// background compile/upload workers run on the secondary CCD.
fn stage() -> u32 {
    static STAGE: std::sync::OnceLock<u32> = std::sync::OnceLock::new();
    *STAGE.get_or_init(|| std::env::var("VICTORY_FAST_CORES").ok().and_then(|v| v.trim().parse().ok()).unwrap_or(2))
}

/// Asks the system to run the calling thread, which a frame waits for, on
/// the fast cores only (P-cores or largest L3 V-Cache CCD).
pub(crate) fn keep_on_fast_cores(what: &str) {
    ask(what, 1, false);
}

/// [`keep_on_fast_cores`] for one of the threads a submission's preparing or
/// a landing shares its work with.
pub(crate) fn keep_helper_on_fast_cores(what: &str) {
    ask(what, 2, false);
}

/// [`keep_on_fast_cores`] for one of many threads whose work is ahead of what
/// a frame waits for.
pub(crate) fn keep_many_on_fast_cores(what: &str) {
    ask(what, 3, false);
}

/// Keeps heavy background compile/upload workers on the secondary CCD/E-cores
/// when asymmetric L3 caches or hybrid cores exist, avoiding L3 eviction on
/// the frame-critical CCD.
pub(crate) fn keep_on_background_cores(what: &str) {
    ask(what, 1, true);
}

fn core_groups() -> &'static (Vec<u32>, Vec<u32>, usize) {
    static GROUPS: std::sync::OnceLock<(Vec<u32>, Vec<u32>, usize)> = std::sync::OnceLock::new();
    GROUPS.get_or_init(|| {
        let sets = cpu_sets_full();
        let l3 = l3_caches();
        let (fast, bg) = split_cores(&sets, &l3);
        (fast, bg, sets.len())
    })
}

fn ask(what: &str, from: u32, background: bool) {
    use windows_sys::Win32::System::Threading::{GetCurrentThread, SetThreadSelectedCpuSets};
    if stage() < from {
        return;
    }
    let (fast, bg, of) = core_groups();
    let target = if background { bg } else { fast };
    // Symmetric topology (or nothing known): nothing to ask for.
    if target.is_empty() {
        return;
    }
    // SAFETY: our own thread and a list of the system's own set ids.
    let ok = unsafe { SetThreadSelectedCpuSets(GetCurrentThread(), target.as_ptr(), target.len() as u32) };
    if ok == 0 {
        tracing::warn!(what, background, error = %std::io::Error::last_os_error(), "the thread could not be pinned to its core group");
    } else {
        tracing::info!(what, background, count = target.len(), of, "thread pinned to core group (VICTORY_FAST_CORES=0: not)");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn asymmetric_l3_and_efficiency_split_cores() {
        let hybrid = [
            CpuSetInfo { id: 256, logical_index: 0, efficiency: 1 },
            CpuSetInfo { id: 257, logical_index: 1, efficiency: 1 },
            CpuSetInfo { id: 258, logical_index: 2, efficiency: 0 },
        ];
        assert_eq!(split_cores(&hybrid, &[]), (vec![256, 257], vec![258]));

        let x3d: Vec<CpuSetInfo> = (0..32u8)
            .map(|i| CpuSetInfo { id: 256 + u32::from(i), logical_index: i, efficiency: 0 })
            .collect();
        let l3 = [(96 << 20, 0x0000_FFFF), (32 << 20, 0xFFFF_0000)];
        let (fast, bg) = split_cores(&x3d, &l3);
        assert_eq!(fast, (256..272).collect::<Vec<_>>());
        assert_eq!(bg, (272..288).collect::<Vec<_>>());

        let symmetric: Vec<CpuSetInfo> = (0..16u8)
            .map(|i| CpuSetInfo { id: 256 + u32::from(i), logical_index: i, efficiency: 0 })
            .collect();
        assert_eq!(split_cores(&symmetric, &[(32 << 20, 0xFFFF)]), (Vec::new(), Vec::new()));
        assert!(!cpu_sets_full().is_empty());
        std::thread::spawn(|| {
            keep_on_fast_cores("test-fast");
            keep_on_background_cores("test-bg");
        })
        .join()
        .unwrap();
    }
}
