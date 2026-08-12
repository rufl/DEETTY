# NoctEd Project-Index Qualification

Retained on 2026-07-31 with Zig 0.16.0 on Linux 7.1.5-arch1-2 x86_64, using a 16-vCPU `Genuine Intel(R) 0000` host.

## Method

`./scripts/nocted_project_index_qualification.sh` builds an isolated Debug and `ReleaseSafe` runner, creates real disposable 4K, 25K, and 100K-entry projects, measures a broad-match `modulefilezig` Quick Open query over the immutable index, then applies five coalesced structural events. The delta deletes two files, replaces an existing destination through a file rename, renames a directory containing about 1000 entries, and admits a new two-level directory plus file. Only the changed paths/subtree are read; the unchanged worktree is rebuilt from the retained immutable index rather than rescanned from disk.

Every mode/scale verifies exact Quick Open match/top-K/truncation state, final entry count and path state, directory rename, replacement-conflict resolution to current disk state, `.ignore` full-scan fallback, 257-event overflow fallback, two simultaneously retained immutable snapshots, allocator cleanup, root-process PSS/RSS sampling, and complete disposable-fixture cleanup. The 100,000-entry `ReleaseSafe` Quick Open path has a deliberately loose 500 ms regression budget; current retained time is 69.5 ms under DebugAllocator accounting.

Stable matrix receipt:

```text
nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true quick_open_scale=true quick_open_release_safe_budget_ms=500 directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true
```

## Retained Results

Times are monotonic-clock nanoseconds. Index bytes are the exact compact arena, entry, relationship, root, and storage bytes reported by the model. PSS/RSS are sampled observations of the verification process, not thresholds.

| Mode | Entries | Full scan ns | Quick Open ns | Delta ns | Index bytes | Two-snapshot bytes | Peak PSS KiB | Peak RSS KiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Debug | 4,000 | 18,517,686 | 14,130,291 | 63,039,136 | 283,981 | 563,989 | 6,796 | 6,916 |
| Debug | 25,000 | 108,685,173 | 85,345,894 | 319,158,935 | 1,753,645 | 3,503,317 | 14,416 | 14,424 |
| Debug | 100,000 | 423,793,216 | 317,935,435 | 1,135,052,875 | 7,002,445 | 14,000,917 | 39,204 | 39,212 |
| ReleaseSafe | 4,000 | 2,847,764 | 2,944,025 | 3,552,174 | 283,981 | 563,989 | 988 | 988 |
| ReleaseSafe | 25,000 | 16,970,817 | 18,239,940 | 18,710,990 | 1,753,645 | 3,503,317 | 6,944 | 6,956 |
| ReleaseSafe | 100,000 | 68,769,581 | 69,536,611 | 75,826,131 | 7,002,445 | 14,000,917 | 25,876 | 24,448 |

Each case applied five events and reported `delta_added=1003 delta_removed=1003`; the directory rename accounts for most of those entries. DebugAllocator requested bytes returned to zero and its leak check passed in every process.

The warning-fatal standalone native workflow separately retained the live worker/publication seam on X11:

```text
nocted_native_smoke_diagnostic pass=1 project_delta_updates=1 project_delta_fallbacks=0 project_delta_added=3 project_delta_removed=2 worker_lanes=2
```

## Proof Boundary

This closes the deterministic synthetic 4K/25K/100K index-size, broad-match Quick Open, full-scan, immutable-delta, directory-rename, replacement-conflict, ignore/overflow fallback, two-snapshot model-memory, allocator teardown, and root-process memory tranche. The 500 ms threshold has roughly 7x margin over the retained `ReleaseSafe` observation and exists to catch a return to whole-row DP copying, not to rank machines. The complementary [native project-lifecycle qualification](NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md) retains bounded current-project model/tree-draw, actual monitor-burst/UI publication, deterministic overflow recovery, and post-widget callback proof on X11 and Wayland; the [native endurance qualification](NOCTED_NATIVE_ENDURANCE_QUALIFICATION.md) closes the sustained one-host NCT-121/NCT-122 boundary.
